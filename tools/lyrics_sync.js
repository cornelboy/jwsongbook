'use strict';

const engine = window.LyricsTiming;
const ui = Object.fromEntries([...document.querySelectorAll('[id]')].map((element) => [element.id, element]));
const audio = ui.audio;
const storageKey = 'jw-songbook-word-timing-v1';
let state = engine.create('');
let history = [];
let audioUrl = null;
let audioName = '';
let ready = false;
let frame = 0;
let saveTimer = 0;
let previewKey = '';

function message(text, error = false) {
  ui.status.textContent = text;
  ui.status.classList.toggle('error', error);
}

function saveDraft() {
  clearTimeout(saveTimer);
  if (!editedLyrics()) engine.updateSections(state, ui.lyricsInput.value);
  try {
    localStorage.setItem(storageKey, JSON.stringify({
      version: 1, state, audioName, title: ui.title.value,
      songNumber: ui.songNumber.value, lyrics: ui.lyricsInput.value,
      lead: ui.leadMs.value, speed: ui.speed.value,
    }));
    ui.saveState.textContent = 'Draft saved on this browser';
  } catch {
    ui.saveState.textContent = 'Draft saving unavailable';
    ui.saveState.title = 'Browser storage is unavailable. Keep this tab open until you export.';
  }
}

function restoreDraft() {
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey));
    if (!saved || saved.version !== 1) return;
    state = engine.restore(saved.state);
    ui.title.value = typeof saved.title === 'string' ? saved.title : '';
    ui.songNumber.value = /^\d{1,3}$/.test(saved.songNumber) ? saved.songNumber : '1';
    ui.lyricsInput.value = typeof saved.lyrics === 'string' ? saved.lyrics : engine.plainText(state);
    if (!editedLyrics()) engine.updateSections(state, ui.lyricsInput.value);
    if (['0', '100', '300', '500'].includes(saved.lead)) ui.leadMs.value = saved.lead;
    if (['0.5', '0.75', '0.85', '1'].includes(saved.speed)) ui.speed.value = saved.speed;
    audioName = typeof saved.audioName === 'string' ? saved.audioName : '';
    if (audioName) ui.audioHint.textContent = `Reselect ${audioName} to continue with your saved timings.`;
    ui.saveState.textContent = 'Saved draft restored';
    message('Draft restored. Choose the same audio file to continue.');
  } catch {
    ui.saveState.textContent = 'Could not restore a draft';
  }
}

function editedLyrics() {
  return JSON.stringify(engine.splitLines(ui.lyricsInput.value)) !== JSON.stringify(state.lines);
}

function activeTiming() { return state.timings[state.index]; }
function timeMs() { return audio.currentTime * 1000; }
function totalMs() { return ready ? audio.duration * 1000 : undefined; }

function applyTiming(change, notice) {
  if (!ready) return message('Choose an audio file and wait for it to load first.', true);
  if (editedLyrics()) return message('Lyrics have changed. Select Prepare words before timing them.', true);
  const next = engine.clone(state);
  try {
    change(next, timeMs());
    history.push(engine.clone(state));
    if (history.length > 250) history.shift();
    state = next;
    previewKey = '';
    render();
    saveDraft();
    message(notice || ui.phase.textContent);
  } catch (error) {
    message(error.message, true);
  }
}

function markWord() { applyTiming((next, time) => engine.mark(next, time)); }
function markEnd(joinNext = false) { applyTiming((next, time) => engine.finish(next, time, joinNext)); }

function undo() {
  if (!history.length) return;
  state = history.pop();
  if (!editedLyrics()) engine.updateSections(state, ui.lyricsInput.value);
  previewKey = '';
  render();
  saveDraft();
  message('Last timing action undone.');
}

function selectLine(lineIndex, wordIndex) {
  engine.select(state, lineIndex, wordIndex);
  render();
  saveDraft();
  message(ui.phase.textContent);
}

ui.prepare.addEventListener('click', () => {
  const lines = engine.splitLines(ui.lyricsInput.value);
  if (!lines.length) return message('Paste the plain lyrics first.', true);
  if (lines.some((line) => /[<>\[\]]/.test(line))) return message('Use plain lyrics without timestamp tags or square brackets.', true);
  if (editedLyrics()) {
    const hasTimings = state.timings.some((timing) => timing.wordStarts.some((time) => time != null));
    if (hasTimings && !window.confirm('Preparing different lyrics replaces the current word timings. Continue?')) return;
    audio.pause();
    state = engine.create(ui.lyricsInput.value);
    history = [];
  }
  engine.updateSections(state, ui.lyricsInput.value);
  ui.setup.open = !ready;
  previewKey = '';
  render();
  saveDraft();
  message(ready ? 'Press play, then mark the first word when it begins.' : 'Words prepared. Choose the matching audio file to begin.');
});

ui.audioFile.addEventListener('change', () => {
  const file = ui.audioFile.files[0];
  if (!file) return;
  audio.pause();
  ready = false;
  if (audioUrl) URL.revokeObjectURL(audioUrl);
  audioUrl = URL.createObjectURL(file);
  audioName = file.name;
  audio.src = audioUrl;
  audio.defaultPlaybackRate = Number(ui.speed.value);
  audio.playbackRate = Number(ui.speed.value);
  audio.load();
  ui.audioHint.textContent = 'Audio stays on your device. Timings use this recording’s playback position.';
  message('Loading audio…');
  render();
  saveDraft();
});

audio.addEventListener('loadedmetadata', () => {
  audio.playbackRate = Number(ui.speed.value);
  ready = Number.isFinite(audio.duration) && audio.duration > 0;
  render();
  message(ready ? 'Audio ready. Press play and mark each word as it begins.' : 'This audio has no readable duration. Choose another file.', !ready);
});
audio.addEventListener('error', () => {
  ready = false;
  render();
  message('The browser could not load this recording. Choose a playable MP3 file.', true);
});

async function togglePlayback() {
  if (!ready) return;
  if (!audio.paused) return audio.pause();
  try {
    if (audio.ended) audio.currentTime = 0;
    await audio.play();
  } catch {
    message('Playback could not start. Try Play again or reselect the audio.', true);
  }
}

function seekBy(seconds) {
  if (!ready) return;
  audio.currentTime = Math.max(0, Math.min(audio.duration, audio.currentTime + seconds));
  updateTransport();
}

ui.playPause.addEventListener('click', togglePlayback);
ui.back3.addEventListener('click', () => seekBy(-3));
ui.forward3.addEventListener('click', () => seekBy(3));
ui.seek.addEventListener('input', () => {
  if (ready) audio.currentTime = Number(ui.seek.value);
  updateTransport();
  renderPreview();
});
ui.speed.addEventListener('change', () => {
  audio.defaultPlaybackRate = Number(ui.speed.value);
  audio.playbackRate = Number(ui.speed.value);
  saveDraft();
});
ui.leadMs.addEventListener('change', () => { previewKey = ''; renderPreview(); saveDraft(); });

// Capture the initial press, including on touchscreens, instead of the later release.
function bindTimingPress(button, action) {
  button.addEventListener('pointerdown', (event) => {
    if (event.button !== 0 || !event.isPrimary || button.disabled) return;
    event.preventDefault();
    action();
  });
  button.addEventListener('click', (event) => {
    if (event.detail === 0 && !button.disabled) action(); // Keyboard / assistive activation.
  });
}
bindTimingPress(ui.markWord, markWord);
bindTimingPress(ui.markEnd, () => markEnd());
bindTimingPress(ui.markNext, () => markEnd(true));
ui.undo.addEventListener('click', undo);
ui.previousLine.addEventListener('click', () => selectLine(state.index - 1));
ui.nextLineButton.addEventListener('click', () => selectLine(state.index + 1));
ui.retakeLine.addEventListener('click', () => {
  if (!activeTiming()) return;
  const start = activeTiming().wordStarts[0];
  history.push(engine.clone(state));
  activeTiming().wordStarts.fill(null);
  activeTiming().end = null;
  state.wordIndex = 0;
  audio.pause();
  if (ready && start != null) audio.currentTime = Math.max(0, start / 1000 - 2);
  previewKey = '';
  render();
  saveDraft();
  message('Line cleared. Press play to retake it, or Undo to restore its timings.');
});

document.addEventListener('keydown', (event) => {
  if (event.repeat || event.ctrlKey || event.metaKey || event.altKey || event.isComposing || ui.exportDialog.open) return;
  const target = event.target;
  if (target.closest('input, textarea, select, [contenteditable="true"]')) return;
  // Enter and Space on focused buttons keep their native, single activation.
  if (event.code === 'Space' && target.closest('button, summary')) return;
  const actions = { KeyW: markWord, KeyE: () => markEnd(), KeyN: () => markEnd(true), Space: togglePlayback, KeyP: togglePlayback, Backspace: undo, ArrowLeft: () => seekBy(-3), ArrowRight: () => seekBy(3) };
  if (actions[event.code]) { event.preventDefault(); actions[event.code](); }
});

for (const field of [ui.title, ui.songNumber, ui.lyricsInput]) {
  field.addEventListener('input', () => {
    ui.saveState.textContent = 'Saving draft…';
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveDraft, 250);
    if (!editedLyrics()) {
      engine.updateSections(state, ui.lyricsInput.value);
      render();
    }
    updateControls();
  });
}
window.addEventListener('pagehide', saveDraft);

function render() {
  const timing = activeTiming();
  const words = timing ? engine.words(state.lines[state.index]) : [];
  ui.setupSummary.textContent = state.lines.length ? `Song ${ui.songNumber.value} · ${state.lines.length} lines · ${audioName || 'Choose audio'}` : 'Load your audio and paste the lyrics to begin';
  const parts = state.sectionStarts || [0];
  const partIndex = parts.filter((start) => start <= state.index).length;
  ui.activeLineLabel.textContent = timing ? `Part ${partIndex} of ${parts.length} · Line ${state.index + 1} of ${state.lines.length}` : 'Word timing';
  ui.currentLine.textContent = timing ? state.lines[state.index] : state.lines.length ? 'Ready for a final listen.' : 'Every word, exactly when it’s sung.';
  ui.phase.textContent = timing
    ? state.wordIndex < words.length ? `Mark “${words[state.wordIndex]}” when it begins. (${state.wordIndex + 1} / ${words.length})` : 'Every word marked. End the line after the final held note.'
    : state.lines.length ? 'Review the playback, correct any words, then export.' : 'Prepare your lyrics, then press play below.';
  ui.lineStart.textContent = engine.format(timing?.wordStarts[0]);
  ui.lineEnd.textContent = engine.format(timing?.end);
  ui.nextLine.textContent = state.lines[state.index + 1] ? `Up next · ${state.lines[state.index + 1]}` : timing ? 'Final line · let the last note finish before marking the end.' : 'The first word sets the line start. Mark the end after the final held note.';
  ui.wordGrid.replaceChildren();
  words.forEach((word, i) => {
    const chip = document.createElement('button');
    chip.className = `word-chip${timing.wordStarts[i] != null ? ' done' : ''}${i === state.wordIndex ? ' active' : ''}`;
    chip.setAttribute('aria-pressed', String(i === state.wordIndex));
    chip.dataset.wordIndex = String(i);
    const text = document.createElement('strong'); text.textContent = word;
    const time = document.createElement('span'); time.className = 'word-time';
    time.textContent = timing.wordStarts[i] == null ? i === state.wordIndex ? 'NEXT TO MARK' : 'Not timed' : engine.format(timing.wordStarts[i]);
    chip.append(text, time);
    chip.addEventListener('click', () => {
      selectLine(state.index, i);
      ui.wordGrid.querySelector(`[data-word-index="${i}"]`).focus({ preventScroll: true });
    });
    ui.wordGrid.append(chip);
  });
  renderLines();
  updateControls();
  updateTransport();
  renderPreview();
}

function renderLines() {
  const oldScroll = ui.lines.scrollTop;
  ui.lines.replaceChildren();
  let complete = 0;
  state.lines.forEach((line, i) => {
    const timing = state.timings[i];
    const done = engine.complete(timing);
    if (done) complete++;
    const button = document.createElement('button');
    button.className = `line${i === state.index ? ' active' : ''}${done ? ' done' : ''}`;
    button.setAttribute('aria-current', String(i === state.index));
    const number = document.createElement('span'); number.className = 'line-number'; number.textContent = String(i + 1).padStart(2, '0');
    const text = document.createElement('span'); text.className = 'line-text'; text.textContent = line;
    const meta = document.createElement('span'); meta.className = 'line-meta';
    const count = timing.wordStarts.filter((time) => time != null).length;
    const partLabel = state.sectionStarts?.includes(i) ? `Part ${state.sectionStarts.indexOf(i) + 1} · ` : '';
    meta.textContent = partLabel + (done ? `${engine.format(timing.wordStarts[0])} — ${engine.format(timing.end)} · Complete` : `${count} / ${timing.wordStarts.length} words${count === timing.wordStarts.length ? ' · Needs end' : ''}`);
    text.append(meta); button.append(number, text);
    button.addEventListener('click', () => selectLine(i));
    ui.lines.append(button);
  });
  if (!state.lines.length) ui.lines.textContent = 'Your lines will appear here.';
  ui.lines.scrollTop = oldScroll;
  const selected = ui.lines.querySelector('.active');
  if (selected) {
    // Scroll only the line list. Never pull the whole page away from timing controls.
    const bounds = ui.lines.getBoundingClientRect();
    const item = selected.getBoundingClientRect();
    if (item.top < bounds.top) ui.lines.scrollTop -= bounds.top - item.top;
    else if (item.bottom > bounds.bottom) ui.lines.scrollTop += item.bottom - bounds.bottom;
  }
  ui.lineCount.textContent = `${complete} / ${state.lines.length}`;
  const progress = state.lines.length ? Math.round(complete / state.lines.length * 100) : 0;
  ui.progressFill.style.width = `${progress}%`;
  ui.progressTrack.setAttribute('aria-valuenow', String(progress));
}

function updateControls() {
  const timing = activeTiming();
  const canMark = ready && !!timing && !editedLyrics();
  const allWords = timing && timing.wordStarts.every((time) => time != null);
  const nextTiming = state.timings[state.index + 1];
  ui.markWord.disabled = !canMark || state.wordIndex >= timing.wordStarts.length;
  ui.markWordLabel.textContent = timing && state.wordIndex < timing.wordStarts.length ? `Mark “${engine.words(state.lines[state.index])[state.wordIndex]}”` : 'All words marked';
  if (!state.lines.length) ui.markWordLabel.textContent = 'Mark word';
  ui.markEnd.disabled = !canMark || !allWords;
  ui.markNext.disabled = !canMark || !allWords || !nextTiming || nextTiming.wordStarts.some((time) => time != null) || nextTiming.end != null;
  ui.undo.disabled = !history.length;
  ui.retakeLine.disabled = !timing || timing.wordStarts.every((time) => time == null);
  ui.previousLine.disabled = !state.lines.length || state.index <= 0;
  ui.nextLineButton.disabled = !state.lines.length || state.index >= state.lines.length - 1;
  for (const button of [ui.playPause, ui.back3, ui.forward3, ui.seek]) button.disabled = !ready;
}

function updateTransport() {
  ui.audioName.textContent = audioName || 'No audio selected';
  ui.currentTime.textContent = engine.format(timeMs());
  ui.duration.textContent = ready ? engine.format(totalMs()) : '00:00.00';
  ui.seek.max = ready ? String(audio.duration) : '1';
  ui.seek.value = String(audio.currentTime);
  ui.seek.setAttribute('aria-valuetext', `${engine.format(timeMs())} of ${ready ? engine.format(totalMs()) : 'no audio'}`);
  ui.playPause.textContent = audio.paused ? 'Play' : 'Pause';
  ui.playPause.setAttribute('aria-label', audio.paused ? 'Play audio' : 'Pause audio');
}

function renderPreview() {
  const position = timeMs() + Number(ui.leadMs.value);
  let lineIndex = -1;
  for (let i = state.timings.length - 1; i >= 0; i--) {
    const timing = state.timings[i];
    if (timing.wordStarts[0] != null && position >= timing.wordStarts[0] && (timing.end == null || position < timing.end)) { lineIndex = i; break; }
  }
  const timing = state.timings[lineIndex];
  let activeWord = -1;
  if (timing) timing.wordStarts.forEach((time, i) => { if (time != null && position >= time) activeWord = i; });
  const key = `${lineIndex}:${activeWord}:${timing?.end ?? ''}:${Number(ui.leadMs.value)}`;
  if (key === previewKey) return;
  previewKey = key;
  ui.previewLine.replaceChildren();
  if (lineIndex < 0) {
    ui.previewLine.textContent = state.lines.length ? '♪' : 'Your timed words will appear here.';
    ui.previewMeta.textContent = state.lines.length ? 'Instrumental / waiting for a timed word' : 'Preview lead changes only the display. Your taps use the audio’s actual time.';
    return;
  }
  engine.words(state.lines[lineIndex]).forEach((word, i) => {
    const span = document.createElement('span');
    span.className = `preview-word${i < activeWord ? ' past' : i === activeWord ? ' active' : ''}`;
    span.textContent = word; ui.previewLine.append(span, ' ');
  });
  ui.previewMeta.textContent = `Line ${lineIndex + 1} · ${timing.end == null ? 'Recording — end not marked' : 'Exact word timestamps'} · ${ui.leadMs.value} ms visual lead`;
}

function tick() {
  updateTransport(); renderPreview();
  if (!audio.paused) frame = requestAnimationFrame(tick);
}
audio.addEventListener('play', () => { cancelAnimationFrame(frame); tick(); });
for (const event of ['pause', 'ended']) audio.addEventListener(event, () => { cancelAnimationFrame(frame); updateTransport(); renderPreview(); });
for (const event of ['timeupdate', 'seeked']) audio.addEventListener(event, () => { updateTransport(); renderPreview(); });

ui.exportButton.addEventListener('click', () => {
  if (!editedLyrics()) engine.updateSections(state, ui.lyricsInput.value);
  const errors = engine.issues(state, totalMs());
  if (editedLyrics()) errors.unshift('Lyrics have changed. Prepare the updated words before exporting.');
  if (!ui.songNumber.validity.valid || !ui.songNumber.value) errors.unshift('Enter a song number from 1 to 999.');
  audio.pause();
  ui.output.value = errors.length ? '' : engine.elrc(state, ui.title.value, totalMs());
  ui.output.classList.toggle('hidden', !!errors.length);
  ui.exportErrors.replaceChildren();
  for (const error of errors) { const item = document.createElement('li'); item.textContent = error; ui.exportErrors.append(item); }
  ui.exportSummary.textContent = errors.length ? 'Finish these timings before exporting. No word timestamps will be estimated.' : `${state.lines.length} lines · ${state.lines.reduce((sum, line) => sum + engine.words(line).length, 0)} timed words · Ready for the Content Manager`;
  ui.exportStatus.textContent = '';
  ui.download.disabled = ui.copy.disabled = !!errors.length;
  ui.exportDialog.showModal();
});
ui.closeExport.addEventListener('click', () => ui.exportDialog.close());
ui.download.addEventListener('click', () => {
  if (!ui.output.value) return;
  const number = String(Number(ui.songNumber.value)).padStart(3, '0');
  const url = URL.createObjectURL(new Blob([ui.output.value], { type: 'text/plain;charset=utf-8' }));
  const link = document.createElement('a'); link.href = url; link.download = `${number}.elrc`;
  document.body.append(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 30000);
  ui.exportStatus.textContent = `Download requested: ${number}.elrc. Upload it to Song ${number} in the Content Manager.`;
});
ui.copy.addEventListener('click', async () => {
  try { await navigator.clipboard.writeText(ui.output.value); ui.exportStatus.textContent = 'Copied to clipboard.'; }
  catch { ui.output.focus(); ui.output.select(); ui.exportStatus.textContent = 'Copy is unavailable here. The text is selected for manual copying, or use Download .elrc.'; }
});

restoreDraft();
render();
new ResizeObserver(() => {
  document.documentElement.style.setProperty('--dock-height', `${ui.playerDock.getBoundingClientRect().height}px`);
}).observe(ui.playerDock);
