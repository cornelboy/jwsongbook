/* Shared by the browser editor and its timing tests. Times are audio milliseconds. */
(function (root) {
  'use strict';

  const words = (line) => line.match(/\S+/g) || [];
  const splitLines = (text) => text.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  const stamp = (ms) => Math.round(ms / 10) * 10;
  const validTime = (time) => Number.isSafeInteger(time) && time >= 0 && time < 6000000;

  function sectionStarts(text) {
    const starts = [];
    let lineIndex = 0;
    let newPart = true;
    for (const line of text.split(/\r?\n/)) {
      if (!line.trim()) { newPart = true; continue; }
      if (newPart) starts.push(lineIndex);
      lineIndex++;
      newPart = false;
    }
    return starts;
  }

  function updateSections(state, text) {
    if (JSON.stringify(splitLines(text)) !== JSON.stringify(state.lines)) {
      throw new Error('Prepare the changed lyric lines before updating parts.');
    }
    state.sectionStarts = sectionStarts(text);
  }

  function plainText(state) {
    return state.lines.map((line, i) => (i > 0 && state.sectionStarts?.includes(i) ? '\n' : '') + line).join('\n');
  }

  function create(text) {
    const lines = splitLines(text);
    return {
      lines,
      sectionStarts: sectionStarts(text),
      timings: lines.map((line) => ({ wordStarts: words(line).map(() => null), end: null })),
      index: 0,
      wordIndex: 0,
    };
  }

  function clone(state) { return JSON.parse(JSON.stringify(state)); }

  function complete(timing) {
    return timing.wordStarts.length > 0 && timing.wordStarts.every(validTime) && validTime(timing.end);
  }

  function select(state, lineIndex, wordIndex) {
    if (!state.lines[lineIndex]) throw new Error('Select a lyric line first.');
    state.index = lineIndex;
    const firstMissing = state.timings[lineIndex].wordStarts.indexOf(null);
    state.wordIndex = wordIndex ?? (firstMissing < 0 ? state.timings[lineIndex].wordStarts.length : firstMissing);
  }

  function mark(state, rawTime) {
    const timing = state.timings[state.index];
    if (!timing) throw new Error('Prepare lyrics or select a line first.');
    const i = state.wordIndex;
    if (i >= timing.wordStarts.length) throw new Error('All words are marked. Mark the line end when singing finishes.');
    const time = stamp(rawTime);
    if (!validTime(time)) throw new Error('Choose a valid position in the audio.');
    const previous = i > 0 ? timing.wordStarts[i - 1] : state.timings[state.index - 1]?.end;
    const next = i + 1 < timing.wordStarts.length ? timing.wordStarts[i + 1] : timing.end;
    if (previous != null && (i > 0 ? time <= previous : time < previous)) {
      throw new Error(i > 0 ? 'This word must start after the previous word. Seek forward or select the word to correct.' : 'This line starts before the previous line ends. Correct its end or seek forward.');
    }
    if (next != null && time >= next) throw new Error('This word must start before the next timestamp. Select the correct word or retake this line.');
    timing.wordStarts[i] = time;
    state.wordIndex = i + 1;
  }

  function finish(state, rawTime, joinNext = false) {
    const timing = state.timings[state.index];
    if (!timing || timing.wordStarts.some((time) => time == null)) throw new Error('Mark every word in this line before its end.');
    const time = stamp(rawTime);
    if (!validTime(time) || time <= timing.wordStarts.at(-1)) throw new Error('Mark the end after the final word has finished.');
    const nextTiming = state.timings[state.index + 1];
    if (nextTiming?.wordStarts[0] != null && time > nextTiming.wordStarts[0]) throw new Error('This end overlaps the next line. Seek back or correct the next line first.');
    if (joinNext && (!nextTiming || nextTiming.wordStarts.some((value) => value != null) || nextTiming.end != null)) {
      throw new Error('Use Next line now only when the following line has no timings.');
    }
    timing.end = time;
    if (nextTiming) {
      select(state, state.index + 1);
      if (joinNext) mark(state, time);
    } else {
      state.index = state.lines.length;
      state.wordIndex = 0;
    }
  }

  function issues(state, durationMs) {
    const result = [];
    if (!state.lines.length) return ['Prepare your lyrics first.'];
    state.lines.forEach((line, i) => {
      const timing = state.timings[i];
      const prefix = `Line ${i + 1}: `;
      if (/[<>\[\]]/.test(line)) result.push(prefix + 'remove timestamp tags or square brackets from the plain lyrics.');
      if (!timing || timing.wordStarts.length !== words(line).length) {
        result.push(prefix + 'word timings do not match the lyrics.');
        return;
      }
      const missing = timing.wordStarts.filter((time) => !validTime(time)).length;
      if (missing) result.push(prefix + `mark ${missing} remaining ${missing === 1 ? 'word' : 'words'}.`);
      if (!validTime(timing.end)) result.push(prefix + 'mark the line end.');
      timing.wordStarts.forEach((time, j) => {
        if (j && validTime(time) && validTime(timing.wordStarts[j - 1]) && time <= timing.wordStarts[j - 1]) {
          result.push(prefix + 'word timestamps must increase.');
        }
      });
      if (validTime(timing.end) && timing.wordStarts.some((time) => validTime(time) && time >= timing.end)) {
        result.push(prefix + 'the end must follow every word.');
      }
      if (i && validTime(timing.wordStarts[0]) && validTime(state.timings[i - 1]?.end) && timing.wordStarts[0] < state.timings[i - 1].end) {
        result.push(prefix + 'overlaps the preceding line.');
      }
      if (Number.isFinite(durationMs) && validTime(timing.end) && timing.end > stamp(durationMs)) {
        result.push(prefix + 'ends beyond the selected audio.');
      }
    });
    return result;
  }

  function format(ms) {
    if (ms == null || !Number.isFinite(ms)) return '—';
    const value = Math.max(0, stamp(ms));
    return `${String(Math.floor(value / 60000)).padStart(2, '0')}:${String(Math.floor(value % 60000 / 1000)).padStart(2, '0')}.${String(Math.floor(value % 1000 / 10)).padStart(2, '0')}`;
  }

  function elrc(state, title, durationMs) {
    const errors = issues(state, durationMs);
    if (errors.length) throw new Error(errors[0]);
    const safeTitle = title.replace(/[\r\n\[\]]/g, ' ').trim();
    return [`[ti:${safeTitle || 'Kingdom Song'}]`, '[ar:Kingdom Songs]', '', ...state.lines.map((line, i) => {
      const timing = state.timings[i];
      return (i > 0 && state.sectionStarts?.includes(i) ? '\n' : '') + `[${format(timing.wordStarts[0])}]` + words(line).map((word, j) => `<${format(timing.wordStarts[j])}>${word}`).join(' ') + `<${format(timing.end)}>`;
    }), ''].join('\n');
  }

  function restore(input) {
    if (!input || !Array.isArray(input.lines) || input.lines.some((line) => typeof line !== 'string' || !line.trim())) throw new Error('Invalid saved lyrics.');
    const state = create(input.lines.join('\n'));
    if (input.sectionStarts !== undefined) {
      const starts = input.sectionStarts;
      if (!Array.isArray(starts) || (state.lines.length && starts[0] !== 0) || starts.some((index, i) => !Number.isSafeInteger(index) || index < 0 || index >= state.lines.length || (i > 0 && index <= starts[i - 1]))) throw new Error('Invalid saved part boundaries.');
      state.sectionStarts = [...starts];
    }
    if (!Array.isArray(input.timings) || input.timings.length !== state.lines.length) throw new Error('Invalid saved timings.');
    input.timings.forEach((timing, i) => {
      if (!timing || !Array.isArray(timing.wordStarts) || timing.wordStarts.length !== state.timings[i].wordStarts.length || timing.wordStarts.some((time) => time !== null && !validTime(time)) || (timing.end !== null && !validTime(timing.end))) throw new Error('Invalid saved word timestamps.');
    });
    state.timings = clone(input.timings);
    if (state.lines.length) select(state, Math.min(Math.max(Number.isSafeInteger(input.index) ? input.index : 0, 0), state.lines.length - 1));
    return state;
  }

  const api = { words, splitLines, sectionStarts, updateSections, plainText, create, clone, complete, select, mark, finish, issues, format, elrc, restore };
  root.LyricsTiming = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(globalThis);
