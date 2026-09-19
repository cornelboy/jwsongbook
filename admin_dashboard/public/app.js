const elements = Object.fromEntries(
  [
    'workspacePath', 'songCount', 'audioCount', 'lyricsCount', 'draftCount',
    'publishCount', 'publishButton', 'refreshButton',
    'searchInput', 'songList', 'emptyList', 'addSongButton', 'editorEmpty',
    'songForm', 'editorMode', 'editorTitle', 'draftPill', 'numberInput',
    'versionInput', 'titleInput', 'durationInput', 'audioAsset', 'audioStatus',
    'audioInput', 'audioButton', 'audioPreview', 'audioProgress', 'lyricsAsset',
    'audioOptimizationControl', 'audioOptimizationInput',
    'audioOptimizationHelp', 'audioOptimizationResult',
    'lyricsStatus', 'lyricsInput', 'lyricsButton', 'lyricsProgress',
    'assetSummary', 'validationMessage', 'discardButton', 'resetButton',
    'saveButton', 'publishDialog', 'publishDescription', 'cancelPublishButton',
    'confirmPublishButton', 'toast',
  ].map((id) => [id, document.getElementById(id)]),
);

const model = {
  state: null,
  selectedNumber: null,
  filter: 'all',
  search: '',
  audioObjectUrl: null,
};

window.lucide?.createIcons();

document.addEventListener('DOMContentLoaded', () => {
  bindEvents();
  void refreshState();
});

function bindEvents() {
  elements.refreshButton.addEventListener('click', () => void refreshState());
  elements.searchInput.addEventListener('input', (event) => {
    model.search = event.target.value.trim().toLowerCase();
    renderList();
  });
  document.querySelectorAll('[data-filter]').forEach((button) => {
    button.addEventListener('click', () => setFilter(button.dataset.filter));
  });
  document.querySelector('[data-view="catalog"]').addEventListener(
    'click',
    () => setFilter('all'),
  );
  document.querySelectorAll('[data-add-song]').forEach((button) => {
    button.addEventListener('click', beginNewSong);
  });
  elements.addSongButton.addEventListener('click', beginNewSong);
  elements.songForm.addEventListener('submit', (event) => {
    event.preventDefault();
    void saveDraft({ announce: true });
  });
  elements.resetButton.addEventListener('click', resetEditor);
  elements.discardButton.addEventListener('click', () => void discardDraft());
  elements.audioButton.addEventListener('click', () => elements.audioInput.click());
  elements.lyricsButton.addEventListener('click', () => elements.lyricsInput.click());
  elements.audioInput.addEventListener('change', () => void uploadSelected('audio'));
  elements.lyricsInput.addEventListener('change', () => void uploadSelected('lyrics'));
  elements.publishButton.addEventListener('click', openPublishDialog);
  elements.cancelPublishButton.addEventListener('click', () => elements.publishDialog.close());
  elements.confirmPublishButton.addEventListener('click', () => void publishDrafts());
}

async function refreshState({ preserveSelection = true } = {}) {
  setBusy(elements.refreshButton, true);
  try {
    model.state = await api('/api/state');
    const canOptimize = Boolean(model.state.capabilities?.audioOptimization);
    elements.audioOptimizationInput.disabled = !canOptimize;
    elements.audioOptimizationControl.classList.toggle('disabled', !canOptimize);
    elements.audioOptimizationHelp.textContent = canOptimize
      ? 'Convert explicitly selected uploads to 128 kbps, 44.1 kHz stereo. Embedded artwork is removed.'
      : 'Install FFmpeg and FFprobe to enable optimization. Original MP3 uploads still work.';
    elements.workspacePath.textContent = model.state.contentRoot;
    elements.workspacePath.title = model.state.contentRoot;
    renderStats();
    renderList();
    if (preserveSelection && model.selectedNumber != null) {
      const song = mergedSongs().find((item) => item.number === model.selectedNumber);
      if (song) selectSong(song.number, { revealOnNarrow: false });
      else closeEditor();
    } else if (model.state.drafts.length > 0) {
      selectSong(model.state.drafts[0].number, { revealOnNarrow: false });
    } else if (model.state.songs.length > 0) {
      selectSong(model.state.songs[0].number, { revealOnNarrow: false });
    }
  } catch (error) {
    showToast(error.message, true);
  } finally {
    setBusy(elements.refreshButton, false);
  }
}

function renderStats() {
  const stats = model.state.stats;
  elements.songCount.textContent = stats.songs;
  elements.audioCount.textContent = stats.audio;
  elements.lyricsCount.textContent = stats.lyrics;
  elements.draftCount.textContent = stats.drafts;
  elements.publishCount.textContent = stats.drafts;
  elements.publishButton.disabled = stats.drafts === 0;
}

function mergedSongs() {
  if (!model.state) return [];
  const songs = new Map(model.state.songs.map((song) => [song.number, { ...song }]));
  for (const draft of model.state.drafts) {
    songs.set(draft.number, { ...songs.get(draft.number), ...draft, isDraft: true });
  }
  return [...songs.values()].sort((a, b) => a.number - b.number);
}

function renderList() {
  if (!model.state) return;
  const songs = mergedSongs().filter((song) => {
    const matchesSearch =
      !model.search ||
      String(song.number).includes(model.search) ||
      String(song.title ?? '').toLowerCase().includes(model.search);
    const matchesFilter =
      model.filter === 'all' ||
      (model.filter === 'draft' && song.isDraft) ||
      (model.filter === 'incomplete' && (!song.audioUrl || !song.lyricsUrl));
    return matchesSearch && matchesFilter;
  });

  elements.songList.replaceChildren(...songs.map(songRow));
  elements.emptyList.classList.toggle('hidden', songs.length !== 0);
  window.lucide?.createIcons();
}

function songRow(song) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = `song-row${song.number === model.selectedNumber ? ' selected' : ''}`;
  button.dataset.songNumber = song.number;
  button.innerHTML = `
    <span class="song-identity">
      <span class="song-number">${padded(song.number)}</span>
      <span class="song-title">
        <strong>${escapeHtml(song.title || `Untitled song ${song.number}`)}</strong>
        <span>${song.isDraft ? 'Unpublished changes' : 'Published catalog'}</span>
      </span>
    </span>
    <span class="content-badges">
      <span class="badge ${song.audioUrl ? 'ready' : 'missing'}">${song.audioUrl ? 'Audio' : 'No audio'}</span>
      <span class="badge ${song.lyricsUrl ? 'ready' : 'missing'}">${song.lyricsUrl ? 'Lyrics' : 'No lyrics'}</span>
      ${song.isDraft ? '<span class="badge draft">Draft</span>' : ''}
    </span>
    <span class="song-version">v${Number(song.version) || 1}</span>
  `;
  button.addEventListener('click', () => selectSong(song.number));
  return button;
}

function selectSong(number, { revealOnNarrow = true } = {}) {
  const song = mergedSongs().find((item) => item.number === number);
  if (!song) return;
  model.selectedNumber = number;
  releaseAudioObjectUrl();
  elements.editorEmpty.classList.add('hidden');
  elements.songForm.classList.remove('hidden');
  elements.editorMode.textContent = song.isDraft ? 'Unpublished change' : 'Published song';
  elements.editorTitle.textContent = `${padded(song.number)} · ${song.title || 'Untitled song'}`;
  elements.draftPill.classList.toggle('hidden', !song.isDraft);
  elements.discardButton.classList.toggle('hidden', !song.isDraft);
  elements.numberInput.value = song.number;
  elements.versionInput.value = Number(song.version) || 1;
  elements.titleInput.value = song.title ?? '';
  elements.durationInput.value = formatDuration(song.durationMs);
  renderAssets(song);
  setValidation('Review the metadata and stage any replacement files.');
  renderList();
  if (revealOnNarrow && window.matchMedia('(max-width: 850px)').matches) {
    elements.songForm.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
}

function beginNewSong() {
  model.selectedNumber = null;
  releaseAudioObjectUrl();
  elements.editorEmpty.classList.add('hidden');
  elements.songForm.classList.remove('hidden');
  elements.editorMode.textContent = 'New catalog entry';
  elements.editorTitle.textContent = 'Add a song';
  elements.draftPill.classList.add('hidden');
  elements.discardButton.classList.add('hidden');
  elements.songForm.reset();
  elements.numberInput.value = model.state.nextSongNumber;
  elements.versionInput.value = 1;
  renderAssets({});
  setValidation('A title is enough to publish a catalog-only song.');
  elements.titleInput.focus();
  renderList();
  if (window.matchMedia('(max-width: 850px)').matches) {
    elements.songForm.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
}

function closeEditor() {
  model.selectedNumber = null;
  releaseAudioObjectUrl();
  elements.songForm.classList.add('hidden');
  elements.editorEmpty.classList.remove('hidden');
  renderList();
}

function resetEditor() {
  if (model.selectedNumber == null) beginNewSong();
  else selectSong(model.selectedNumber);
}

function renderAssets(song) {
  const hasAudio = Boolean(song.audioUrl);
  const hasLyrics = Boolean(song.lyricsUrl);
  const optimization = song._audioOptimization;
  elements.audioAsset.classList.toggle('ready', hasAudio);
  elements.lyricsAsset.classList.toggle('ready', hasLyrics);
  elements.audioStatus.textContent = hasAudio
    ? `${song.audioUrl}${song.audioSize ? ` · ${formatBytes(song.audioSize)}` : ''}`
    : 'MP3, up to 100 MB';
  elements.lyricsStatus.textContent = hasLyrics
    ? `${song.lyricsUrl}${song.lyricsLines ? ` · ${song.lyricsLines} lines` : ''}`
    : 'Enhanced LRC, word timestamps required';
  elements.assetSummary.textContent = `${Number(hasAudio) + Number(hasLyrics)} of 2 files`;
  elements.audioPreview.classList.toggle('hidden', !hasAudio);
  elements.audioOptimizationResult.classList.toggle('hidden', !optimization);
  if (optimization) {
    elements.audioOptimizationResult.textContent = optimization.status === 'optimized'
      ? `Optimized: ${formatBytes(optimization.originalSize)} → ${formatBytes(optimization.selectedSize)} (${optimization.savingsPercent}% smaller).`
      : optimization.reason === 'not-smaller'
        ? `Optimization skipped: the result was not smaller. Kept the original ${formatBytes(optimization.originalSize)} file.`
        : `Optimization skipped: this file was already efficient. Kept the original ${formatBytes(optimization.originalSize)} file.`;
  }
  if (hasAudio) {
    elements.audioPreview.src = song.isDraft && song.audioSha256
      ? `/api/drafts/${song.number}/audio`
      : `/content/${song.audioUrl}`;
  } else {
    elements.audioPreview.removeAttribute('src');
  }
  elements.audioPreview.load();
}

async function saveDraft({ announce }) {
  const metadata = formMetadata();
  if (!metadata) return null;
  setBusy(elements.saveButton, true);
  try {
    const draft = await api('/api/drafts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(metadata),
    });
    model.selectedNumber = draft.number;
    await refreshState();
    setValidation('Draft saved. It is not visible to the mobile app yet.', 'success');
    if (announce) showToast(`Song ${padded(draft.number)} saved as a draft.`);
    return draft;
  } catch (error) {
    setValidation(error.message, 'error');
    return null;
  } finally {
    setBusy(elements.saveButton, false);
  }
}

function formMetadata() {
  const number = Number(elements.numberInput.value);
  const title = elements.titleInput.value.trim();
  const version = Number(elements.versionInput.value);
  const durationMs = parseDuration(elements.durationInput.value.trim());
  if (!Number.isSafeInteger(number) || number <= 0) {
    setValidation('Enter a positive, unique song number.', 'error');
    elements.numberInput.focus();
    return null;
  }
  if (!title) {
    setValidation('Enter the official song title.', 'error');
    elements.titleInput.focus();
    return null;
  }
  if (!Number.isSafeInteger(version) || version <= 0) {
    setValidation('Version must be a positive whole number.', 'error');
    elements.versionInput.focus();
    return null;
  }
  if (durationMs === false) {
    setValidation('Duration must use mm:ss, such as 03:14.', 'error');
    elements.durationInput.focus();
    return null;
  }
  return { number, title, version, ...(durationMs == null ? {} : { durationMs }) };
}

async function uploadSelected(kind) {
  const input = kind === 'audio' ? elements.audioInput : elements.lyricsInput;
  const file = input.files?.[0];
  if (!file) return;
  // Saving the draft refreshes the editor, which resets this checkbox. Capture
  // the user's explicit choice before that asynchronous refresh can occur.
  const optimizeAudio = kind === 'audio' && elements.audioOptimizationInput.checked;
  const draft = await saveDraft({ announce: false });
  if (!draft) {
    input.value = '';
    return;
  }

  const progress = kind === 'audio' ? elements.audioProgress : elements.lyricsProgress;
  progress.classList.remove('hidden');
  progress.firstElementChild.style.width = '0%';
  try {
    const uploaded = await uploadFile(`/api/drafts/${draft.number}/${kind}`, file, (percentage) => {
      progress.firstElementChild.style.width = `${percentage}%`;
    }, { optimizeAudio });
    if (kind === 'audio') {
      releaseAudioObjectUrl();
      model.audioObjectUrl = URL.createObjectURL(file);
      elements.audioPreview.src = model.audioObjectUrl;
      elements.audioPreview.classList.remove('hidden');
      elements.audioPreview.load();
    }
    await refreshState();
    const optimization = uploaded?._audioOptimization;
    setValidation(
      optimization?.status === 'optimized'
        ? `Audio optimized from ${formatBytes(optimization.originalSize)} to ${formatBytes(optimization.selectedSize)} (${optimization.savingsPercent}% smaller) and staged.`
        : optimization?.status === 'skipped'
          ? 'Audio was already efficient, so the original MP3 was staged without recompression.'
          : `${kind === 'audio' ? 'Audio' : 'Lyrics'} validated and staged.`,
      'success',
    );
    showToast(`${file.name} is ready to publish.`);
  } catch (error) {
    setValidation(error.message, 'error');
  } finally {
    window.setTimeout(() => progress.classList.add('hidden'), 350);
    input.value = '';
  }
}

async function discardDraft() {
  if (model.selectedNumber == null) return;
  setBusy(elements.discardButton, true);
  try {
    const number = model.selectedNumber;
    await api(`/api/drafts/${number}`, { method: 'DELETE' });
    await refreshState({ preserveSelection: false });
    const published = model.state.songs.find((song) => song.number === number);
    if (published) selectSong(number);
    else closeEditor();
    showToast(`Draft for song ${padded(number)} discarded.`);
  } catch (error) {
    showToast(error.message, true);
  } finally {
    setBusy(elements.discardButton, false);
  }
}

function openPublishDialog() {
  const count = model.state?.drafts.length ?? 0;
  if (!count) return;
  elements.publishDescription.textContent =
    `${count} ${count === 1 ? 'song change' : 'song changes'} and staged files will become available to the mobile app.`;
  elements.publishDialog.showModal();
}

async function publishDrafts() {
  setBusy(elements.confirmPublishButton, true);
  try {
    const result = await api('/api/publish', { method: 'POST' });
    elements.publishDialog.close();
    await refreshState();
    showToast(`Published ${result.published} ${result.published === 1 ? 'song' : 'songs'}.`);
  } catch (error) {
    showToast(error.message, true);
  } finally {
    setBusy(elements.confirmPublishButton, false);
  }
}

function setFilter(filter) {
  model.filter = filter;
  document.querySelectorAll('[data-filter]').forEach((button) => {
    button.classList.toggle('selected', button.dataset.filter === filter);
    if (button.classList.contains('nav-item')) {
      button.classList.toggle('active', button.dataset.filter === filter);
    }
  });
  const catalogNav = document.querySelector('[data-view="catalog"]');
  catalogNav.classList.toggle('active', filter === 'all');
  renderList();
}

async function api(url, options) {
  const requestOptions = { ...(options ?? {}) };
  const method = (requestOptions.method ?? 'GET').toUpperCase();
  if (!['GET', 'HEAD', 'OPTIONS'].includes(method)) {
    requestOptions.headers = new Headers(requestOptions.headers);
    requestOptions.headers.set('X-CSRF-Token', model.state?.csrfToken ?? '');
    if (!requestOptions.headers.has('Content-Type')) {
      requestOptions.headers.set('Content-Type', 'application/json');
    }
    if (requestOptions.body == null && requestOptions.headers.get('Content-Type') === 'application/json') {
      requestOptions.body = '{}';
    }
  }
  const response = await fetch(url, requestOptions);
  if (response.status === 204) return null;
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error || `Request failed (${response.status}).`);
  return body;
}

function uploadFile(url, file, onProgress, { optimizeAudio = false } = {}) {
  return new Promise((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open('PUT', url);
    request.setRequestHeader('X-CSRF-Token', model.state?.csrfToken ?? '');
    request.setRequestHeader('Content-Type', file.type || 'application/octet-stream');
    request.setRequestHeader('X-File-Name', file.name);
    if (optimizeAudio) request.setRequestHeader('X-Optimize-Audio', 'true');
    request.upload.addEventListener('progress', (event) => {
      if (event.lengthComputable) onProgress(Math.round(event.loaded / event.total * 100));
    });
    request.addEventListener('load', () => {
      let body = {};
      try { body = JSON.parse(request.responseText || '{}'); } catch { /* noop */ }
      if (request.status >= 200 && request.status < 300) resolve(body);
      else reject(new Error(body.error || `Upload failed (${request.status}).`));
    });
    request.addEventListener('error', () => reject(new Error('Upload connection failed.')));
    request.send(file);
  });
}

function setValidation(message, type = '') {
  elements.validationMessage.classList.remove('error', 'success');
  if (type) elements.validationMessage.classList.add(type);
  elements.validationMessage.querySelector('span').textContent = message;
}

function showToast(message, isError = false) {
  elements.toast.classList.toggle('error', isError);
  elements.toast.querySelector('span').textContent = message;
  elements.toast.classList.remove('hidden');
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => elements.toast.classList.add('hidden'), 3600);
}

function setBusy(button, busy) {
  button.disabled = busy;
  button.setAttribute('aria-busy', String(busy));
  const icon = button.querySelector('svg');
  icon?.classList.toggle('spin', busy);
}

function parseDuration(value) {
  if (!value) return null;
  const match = value.match(/^(\d{1,3}):(\d{2})$/);
  if (!match || Number(match[2]) > 59) return false;
  return (Number(match[1]) * 60 + Number(match[2])) * 1000;
}

function formatDuration(milliseconds) {
  if (!Number.isSafeInteger(milliseconds) || milliseconds < 0) return '';
  const seconds = Math.round(milliseconds / 1000);
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

function formatBytes(bytes) {
  if (!Number.isFinite(bytes)) return '';
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

function padded(number) { return String(number).padStart(3, '0'); }

function escapeHtml(value) {
  const span = document.createElement('span');
  span.textContent = value;
  return span.innerHTML;
}

function releaseAudioObjectUrl() {
  if (model.audioObjectUrl) URL.revokeObjectURL(model.audioObjectUrl);
  model.audioObjectUrl = null;
}
