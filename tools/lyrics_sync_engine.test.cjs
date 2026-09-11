const { test } = require('node:test');
const assert = require('node:assert/strict');
const timing = require('./lyrics_sync_engine.js');

test('preserves part breaks in exports and restored drafts without timing changes', () => {
  const song = timing.create('\nFirst line\n\n\nSecond line\n');
  [1000, 2000].forEach((time) => timing.mark(song, time)); timing.finish(song, 3000);
  [3500, 4000].forEach((time) => timing.mark(song, time)); timing.finish(song, 5000);
  assert.deepEqual(song.sectionStarts, [0, 1]);
  assert.match(timing.elrc(song, 'Parts'), /<00:03.00>\n\n\[00:03.50\]/);
  const restored = timing.restore(JSON.parse(JSON.stringify(song)));
  assert.deepEqual(restored.sectionStarts, [0, 1]);
  const taps = timing.clone(song.timings);
  timing.updateSections(song, 'First line\nSecond line');
  assert.deepEqual(song.sectionStarts, [0]);
  assert.deepEqual(song.timings, taps);
  assert.equal(timing.plainText(restored), 'First line\n\nSecond line');
  assert.throws(() => timing.restore({ ...song, sectionStarts: [0, 50] }), /part boundaries/);
});

test('exports only tapped timestamps, preserving rests and held final notes', () => {
  const song = timing.create('Sing with joy\nGive thanks');
  timing.mark(song, 10320);
  timing.mark(song, 10680);
  timing.mark(song, 11250);
  timing.finish(song, 14320);
  timing.mark(song, 19500);
  timing.mark(song, 20020);
  timing.finish(song, 25500);
  assert.deepEqual(timing.issues(song, 26000), []);
  assert.equal(timing.elrc(song, 'Test song', 26000), '[ti:Test song]\n[ar:Kingdom Songs]\n\n[00:10.32]<00:10.32>Sing <00:10.68>with <00:11.25>joy<00:14.32>\n[00:19.50]<00:19.50>Give <00:20.02>thanks<00:25.50>\n');
});

test('refuses incomplete words and missing line ends without inventing timestamps', () => {
  const song = timing.create('One two');
  timing.mark(song, 1000);
  assert.throws(() => timing.finish(song, 2000), /every word/);
  assert.throws(() => timing.elrc(song, 'Incomplete'), /remaining word/);
  timing.mark(song, 1500);
  assert.throws(() => timing.elrc(song, 'Missing end'), /line end/);
  const before = timing.clone(song);
  assert.throws(() => timing.mark(song, 1700), /All words/);
  assert.deepEqual(song, before, 'extra taps must not overwrite the final word');
});

test('no-gap transition finishes the line and marks exactly the next first word', () => {
  const song = timing.create('One\nTwo three');
  timing.mark(song, 1000);
  timing.finish(song, 1500, true);
  assert.equal(song.timings[0].end, 1500);
  assert.deepEqual(song.timings[1].wordStarts, [1500, null]);
  assert.equal(song.wordIndex, 1);
  timing.mark(song, 1800);
  timing.finish(song, 2200);
  assert.deepEqual(timing.issues(song), []);
});

test('short phrases are not silently stretched to 500 ms', () => {
  const song = timing.create('Yes');
  timing.mark(song, 1010);
  timing.finish(song, 1180);
  assert.match(timing.elrc(song, 'Short'), /<00:01.01>Yes<00:01.18>/);
});

test('rejects duplicate and backward taps, including centisecond collisions', () => {
  const song = timing.create('One two');
  timing.mark(song, 1001);
  const before = timing.clone(song);
  assert.throws(() => timing.mark(song, 1004), /after the previous/);
  assert.throws(() => timing.mark(song, 900), /after the previous/);
  assert.deepEqual(song, before);
  timing.mark(song, 1010);
  assert.throws(() => timing.finish(song, 1000), /after the final/);
});

test('selecting a word does not change it; a correction respects its neighbours', () => {
  const song = timing.create('One two three');
  [1000, 2000, 3000].forEach((time) => timing.mark(song, time));
  timing.finish(song, 4500);
  timing.select(song, 0, 1);
  assert.deepEqual(song.timings[0].wordStarts, [1000, 2000, 3000]);
  assert.throws(() => timing.mark(song, 900), /previous/);
  assert.throws(() => timing.mark(song, 3100), /next timestamp/);
  timing.mark(song, 2300);
  assert.deepEqual(song.timings[0].wordStarts, [1000, 2300, 3000]);
  assert.equal(song.timings[0].end, 4500);
});

test('does not overlap neighbouring lines or overwrite a timed next line', () => {
  const song = timing.create('One\nTwo');
  timing.mark(song, 1000); timing.finish(song, 1500);
  assert.throws(() => timing.mark(song, 1400), /previous line ends/);
  timing.mark(song, 2000); timing.finish(song, 2500);
  timing.select(song, 0);
  const before = timing.clone(song);
  assert.throws(() => timing.finish(song, 2100), /overlaps/);
  assert.throws(() => timing.finish(song, 1800, true), /no timings/);
  assert.deepEqual(song, before);
});

test('checks the selected audio duration and malformed restored timing order', () => {
  const song = timing.create('One two');
  timing.mark(song, 1000); timing.mark(song, 2000); timing.finish(song, 4000);
  assert.throws(() => timing.elrc(song, 'Too long', 3000), /beyond the selected audio/);
  song.timings[0].wordStarts = [2000, 1000];
  assert.throws(() => timing.elrc(song, 'Invalid'), /must increase/);
});

test('restores partial drafts and protects against broken persisted state', () => {
  const song = timing.create('One two'); timing.mark(song, 1000);
  const restored = timing.restore(JSON.parse(JSON.stringify(song)));
  assert.equal(restored.wordIndex, 1);
  assert.deepEqual(restored.timings, song.timings);
  assert.throws(() => timing.restore({ lines: ['One'], timings: [] }), /Invalid/);
  assert.throws(() => timing.restore({ lines: ['One'], timings: [{ wordStarts: [null], end: -1 }] }), /Invalid/);
});

test('keeps Unicode words and punctuation while preventing ELRC tag injection', () => {
  const song = timing.create('We’re singing, joyfully!');
  [1000, 1500, 2000].forEach((time) => timing.mark(song, time)); timing.finish(song, 3500);
  assert.match(timing.elrc(song, 'A title\n[bad]'), /We’re <00:01.50>singing, <00:02.00>joyfully!/);
  const invalid = timing.create('<00:01.00>One');
  assert.match(timing.issues(invalid)[0], /remove timestamp tags/);
});
