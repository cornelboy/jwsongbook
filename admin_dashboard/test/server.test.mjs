import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import { access, mkdir, mkdtemp, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { request as httpRequest } from 'node:http';
import path from 'node:path';
import test from 'node:test';
import { promisify } from 'node:util';

import { createContentServer } from '../src/server.mjs';

const execFileAsync = promisify(execFile);

async function withServer(run, { mediaTools } = {}) {
  const root = await mkdtemp(path.join(tmpdir(), 'jw-songs-admin-'));
  await mkdir(path.join(root, 'audio'));
  await writeFile(path.join(root, 'audio', '162.mp3'), 'ID3existing audio');
  await writeFile(
    path.join(root, 'manifest.example.json'),
    JSON.stringify({
      version: 1,
      songs: [
        {
          number: 162,
          title: 'Existing song',
          audioUrl: 'audio/162.mp3',
          version: 1,
        },
      ],
    }),
  );

  const server = createContentServer({
    contentRoot: root,
    bundledCatalogPath: null,
    baselineMaxSongNumber: 162,
    ...(mediaTools ? { mediaTools } : {}),
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  const baseUrl = `http://127.0.0.1:${port}`;
  const session = await fetch(`${baseUrl}/api/state`).then((response) => response.json());
  const apiFetch = (url, options = {}) => {
    const method = (options.method ?? 'GET').toUpperCase();
    if (['GET', 'HEAD', 'OPTIONS'].includes(method)) return fetch(url, options);
    const headers = new Headers(options.headers);
    headers.set('X-CSRF-Token', session.csrfToken);
    if (!headers.has('Content-Type')) {
      headers.set(
        'Content-Type',
        /\/api\/drafts\/\d+\/(audio|lyrics)$/.test(url)
          ? 'application/octet-stream'
          : 'application/json',
      );
    }
    return fetch(url, {
      ...options,
      headers,
      body: options.body ?? (headers.get('Content-Type') === 'application/json' ? '{}' : undefined),
    });
  };
  try {
    await run({ root, baseUrl, apiFetch, csrfToken: session.csrfToken });
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

function mockMp3(size) {
  const value = Buffer.alloc(size);
  value.write('ID3');
  return value;
}

function fakeMediaTools({
  sourceBitRate = 320000,
  optimizedBitRate = 128000,
  sourceDuration = 180,
  optimizedDuration = 180.02,
  optimizedSize = 300,
  optimizedSampleRate = 44100,
  optimizedChannels = 2,
} = {}) {
  let transcodes = 0;
  return {
    get transcodes() { return transcodes; },
    async available() { return true; },
    async probe(file) {
      const optimized = file.endsWith('.optimized');
      return {
        codec: 'mp3',
        sampleRate: optimized ? optimizedSampleRate : 48000,
        channels: optimized ? optimizedChannels : 2,
        bitRate: optimized ? optimizedBitRate : sourceBitRate,
        durationSeconds: optimized ? optimizedDuration : sourceDuration,
      };
    },
    async transcode(_source, destination) {
      transcodes += 1;
      await writeFile(destination, mockMp3(optimizedSize));
    },
    async validateDecode() {},
  };
}

test('creates, stages, and publishes a complete future song', async () => {
  await withServer(async ({ root, baseUrl, apiFetch }) => {
    const initialState = await apiFetch(`${baseUrl}/api/state`).then(
      (result) => result.json(),
    );
    assert.equal(initialState.nextSongNumber, 163);

    let response = await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        number: 163,
        title: 'Future song',
        durationMs: 194000,
        version: 1,
      }),
    });
    assert.equal(response.status, 200);

    response = await apiFetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: { 'X-File-Name': 'song.mp3' },
      body: Buffer.from('ID3mock audio content'),
    });
    assert.equal(response.status, 200);

    const lyrics = [
      '[ti:Future song]',
      '[00:01.00]<00:01.00>Future <00:02.00>song.<00:03.00>',
    ].join('\n');
    response = await apiFetch(`${baseUrl}/api/drafts/163/lyrics`, {
      method: 'PUT',
      headers: { 'X-File-Name': 'song.elrc' },
      body: lyrics,
    });
    assert.equal(response.status, 200);

    response = await apiFetch(`${baseUrl}/api/publish`, { method: 'POST' });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      published: 1,
      totalSongs: 2,
      manifestPath: path.join(root, 'manifest.json'),
    });

    const manifest = JSON.parse(
      await readFile(path.join(root, 'manifest.json'), 'utf8'),
    );
    assert.deepEqual(manifest.songs.map((song) => song.number), [162, 163]);
    assert.equal(manifest.songs[1].title, 'Future song');
    assert.equal(manifest.songs[1].audioUrl, 'audio/163.mp3');
    assert.equal(manifest.songs[1].lyricsUrl, 'lyrics/163.elrc');
    assert.match(manifest.songs[1].audioSha256, /^[a-f0-9]{64}$/);
    assert.equal(
      await readFile(path.join(root, 'lyrics', '163.elrc'), 'utf8'),
      lyrics,
    );

    const finalState = await apiFetch(`${baseUrl}/api/state`).then(
      (result) => result.json(),
    );
    assert.equal(finalState.nextSongNumber, 164);
  });
});

test('publishes a catalog-only song and reports it in state', async () => {
  await withServer(async ({ baseUrl, apiFetch }) => {
    const response = await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ number: 163, title: 'Metadata first' }),
    });
    assert.equal(response.status, 200);

    const publish = await apiFetch(`${baseUrl}/api/publish`, { method: 'POST' });
    assert.equal(publish.status, 200);

    const state = await apiFetch(`${baseUrl}/api/state`).then((result) => result.json());
    assert.equal(state.stats.songs, 2);
    assert.equal(state.stats.audio, 1);
    assert.equal(state.stats.lyrics, 0);
    assert.equal(state.songs[1].title, 'Metadata first');
  });
});

test('merges managed content over the complete bundled catalog', async () => {
  const root = await mkdtemp(path.join(tmpdir(), 'jw-songs-admin-bundled-'));
  await writeFile(
    path.join(root, 'manifest.example.json'),
    JSON.stringify({
      version: 1,
      songs: [
        {
          number: 1,
          title: 'Managed title',
          audioUrl: 'audio/001.mp3',
          version: 2,
        },
      ],
    }),
  );

  const server = createContentServer({ contentRoot: root });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    const state = await fetch(`http://127.0.0.1:${port}/api/state`).then(
      (result) => result.json(),
    );
    assert.equal(state.stats.songs, 163);
    assert.equal(state.stats.audio, 1);
    assert.equal(state.nextSongNumber, 164);
    assert.equal(state.songs[0].title, 'Managed title');
    assert.equal(state.songs[162].title, 'Happy Are These Eyes');
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
});

test('rejects invalid metadata and malformed assets', async () => {
  await withServer(async ({ baseUrl, apiFetch }) => {
    let response = await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ number: 0, title: '' }),
    });
    assert.equal(response.status, 400);

    await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ number: 163, title: 'Future song' }),
    });

    response = await apiFetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: { 'X-File-Name': 'not-a-song.mp3' },
      body: Buffer.from('plain text'),
    });
    assert.equal(response.status, 400);

    response = await apiFetch(`${baseUrl}/api/drafts/163/lyrics`, {
      method: 'PUT',
      headers: { 'X-File-Name': 'bad.elrc' },
      body: 'lyrics without timestamps',
    });
    assert.equal(response.status, 400);
  });
});

test('updates an existing song without deleting untouched metadata', async () => {
  await withServer(async ({ baseUrl, apiFetch }) => {
    await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        number: 162,
        title: 'Corrected title',
        version: 2,
      }),
    });
    await apiFetch(`${baseUrl}/api/publish`, { method: 'POST' });

    const state = await apiFetch(`${baseUrl}/api/state`).then((result) => result.json());
    assert.equal(state.songs[0].title, 'Corrected title');
    assert.equal(state.songs[0].audioUrl, 'audio/162.mp3');
    assert.equal(state.songs[0].version, 2);
  });
});

test('a missing static asset returns 404 without stopping the server', async () => {
  await withServer(async ({ baseUrl, apiFetch }) => {
    const missing = await apiFetch(`${baseUrl}/favicon.ico`);
    assert.equal(missing.status, 404);

    const state = await apiFetch(`${baseUrl}/api/state`);
    assert.equal(state.status, 200);
    assert.equal((await state.json()).stats.songs, 1);
  });
});

test('rejects mutations without the valid session token', async () => {
  await withServer(async ({ baseUrl, csrfToken }) => {
    const body = JSON.stringify({ number: 164, title: 'Blocked draft' });
    let response = await fetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
    });
    assert.equal(response.status, 403);

    response = await fetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': `${csrfToken}invalid`,
      },
      body,
    });
    assert.equal(response.status, 403);
  });
});

test('rejects cross-origin, cross-site, and non-localhost requests', async () => {
  await withServer(async ({ baseUrl, csrfToken }) => {
    const mutation = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
      },
      body: JSON.stringify({ number: 164, title: 'Blocked draft' }),
    };
    let response = await fetch(`${baseUrl}/api/drafts`, {
      ...mutation,
      headers: { ...mutation.headers, Origin: 'https://attacker.example' },
    });
    assert.equal(response.status, 403);

    response = await fetch(`${baseUrl}/api/drafts`, {
      ...mutation,
      headers: { ...mutation.headers, 'Sec-Fetch-Site': 'cross-site' },
    });
    assert.equal(response.status, 403);

    const target = new URL(baseUrl);
    const hostStatus = await new Promise((resolve, reject) => {
      const request = httpRequest({
        hostname: target.hostname,
        port: target.port,
        path: '/api/state',
        headers: { Host: 'attacker.example' },
      }, (result) => {
        result.resume();
        result.once('end', () => resolve(result.statusCode));
      });
      request.once('error', reject);
      request.end();
    });
    assert.equal(hostStatus, 403);
  });
});

test('requires an appropriate content type for every mutation', async () => {
  await withServer(async ({ baseUrl, csrfToken }) => {
    const response = await fetch(`${baseUrl}/api/publish`, {
      method: 'POST',
      headers: {
        'Content-Type': 'text/plain',
        'X-CSRF-Token': csrfToken,
      },
      body: '{}',
    });
    assert.equal(response.status, 415);
  });
});

test('explicitly optimizes a new MP3 and reports its savings', async () => {
  const mediaTools = fakeMediaTools({ optimizedSize: 300 });
  await withServer(async ({ baseUrl, apiFetch }) => {
    await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      body: JSON.stringify({ number: 163, title: 'Optimized song' }),
    });
    const response = await apiFetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: {
        'X-File-Name': 'large.mp3',
        'X-Optimize-Audio': 'true',
      },
      body: mockMp3(1000),
    });
    assert.equal(response.status, 200);
    const draft = await response.json();
    assert.equal(draft.version, 1);
    assert.equal(draft.audioSize, 300);
    assert.equal(
      draft.audioSha256,
      createHash('sha256').update(mockMp3(300)).digest('hex'),
    );
    assert.deepEqual(draft._audioOptimization, {
      status: 'optimized',
      originalSize: 1000,
      selectedSize: 300,
      savingsBytes: 700,
      savingsPercent: 70,
      bitrateKbps: 128,
      sampleRate: 44100,
      channels: 2,
    });
    assert.equal(mediaTools.transcodes, 1);
  }, { mediaTools });
});

test('skips recompression when the source is already 128 kbps', async () => {
  const mediaTools = fakeMediaTools({ sourceBitRate: 128000 });
  await withServer(async ({ baseUrl, apiFetch }) => {
    await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      body: JSON.stringify({ number: 163, title: 'Efficient song' }),
    });
    const response = await apiFetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: {
        'X-File-Name': 'efficient.mp3',
        'X-Optimize-Audio': 'true',
      },
      body: mockMp3(800),
    });
    const draft = await response.json();
    assert.equal(response.status, 200);
    assert.equal(draft.audioSize, 800);
    assert.equal(draft._audioOptimization.status, 'skipped');
    assert.equal(draft._audioOptimization.reason, 'already-efficient');
    assert.equal(mediaTools.transcodes, 0);
  }, { mediaTools });
});

test('optimized replacement increments a published audio version', async () => {
  const mediaTools = fakeMediaTools({ optimizedSize: 250 });
  await withServer(async ({ root, baseUrl, apiFetch }) => {
    await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      body: JSON.stringify({ number: 162, title: 'Existing song', version: 1 }),
    });
    const upload = await apiFetch(`${baseUrl}/api/drafts/162/audio`, {
      method: 'PUT',
      headers: {
        'X-File-Name': 'replacement.mp3',
        'X-Optimize-Audio': 'true',
      },
      body: mockMp3(900),
    });
    assert.equal((await upload.json()).version, 2);
    assert.equal((await apiFetch(`${baseUrl}/api/publish`, { method: 'POST' })).status, 200);
    const manifest = JSON.parse(await readFile(path.join(root, 'manifest.json'), 'utf8'));
    assert.equal(manifest.songs[0].version, 2);
    assert.equal(manifest.songs[0].audioSize, 250);
    assert.match(manifest.songs[0].audioSha256, /^[a-f0-9]{64}$/);
    assert.equal('_audioOptimization' in manifest.songs[0], false);
  }, { mediaTools });
});

test('rejects optimized output whose duration differs by over 50 ms', async () => {
  const mediaTools = fakeMediaTools({ optimizedDuration: 180.051 });
  await withServer(async ({ baseUrl, apiFetch }) => {
    await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      body: JSON.stringify({ number: 163, title: 'Bad duration' }),
    });
    const response = await apiFetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: {
        'X-File-Name': 'bad-duration.mp3',
        'X-Optimize-Audio': 'true',
      },
      body: mockMp3(1000),
    });
    assert.equal(response.status, 422);
    assert.match((await response.json()).error, /50 ms/);
  }, { mediaTools });
});

test('keeps the original when optimized output is not smaller', async () => {
  const mediaTools = fakeMediaTools({ optimizedSize: 1200 });
  await withServer(async ({ baseUrl, apiFetch }) => {
    await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      body: JSON.stringify({ number: 163, title: 'No savings' }),
    });
    const response = await apiFetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: {
        'X-File-Name': 'compact.mp3',
        'X-Optimize-Audio': 'true',
      },
      body: mockMp3(1000),
    });
    const draft = await response.json();
    assert.equal(response.status, 200);
    assert.equal(draft.audioSize, 1000);
    assert.equal(draft._audioOptimization.reason, 'not-smaller');
    assert.equal(draft._audioOptimization.savingsBytes, 0);
  }, { mediaTools });
});

test('rejects output with invalid optimized audio specifications', async () => {
  const mediaTools = fakeMediaTools({ optimizedSampleRate: 48000 });
  await withServer(async ({ root, baseUrl, apiFetch }) => {
    await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      body: JSON.stringify({ number: 163, title: 'Wrong sample rate' }),
    });
    const response = await apiFetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: {
        'X-File-Name': 'wrong-spec.mp3',
        'X-Optimize-Audio': 'true',
      },
      body: mockMp3(1000),
    });
    assert.equal(response.status, 422);
    assert.match((await response.json()).error, /44\.1 kHz stereo/);
    const staged = path.join(root, '.admin', 'uploads', 'audio', '163.mp3');
    await assert.rejects(access(staged));
    await assert.rejects(access(`${staged}.source`));
    await assert.rejects(access(`${staged}.optimized`));
  }, { mediaTools });
});

test('reports unavailable tools without accepting an optimization request', async () => {
  const mediaTools = {
    async available() { return false; },
    async probe() { throw new Error('probe must not run'); },
    async transcode() { throw new Error('transcode must not run'); },
    async validateDecode() { throw new Error('decode must not run'); },
  };
  await withServer(async ({ root, baseUrl, apiFetch }) => {
    const state = await apiFetch(`${baseUrl}/api/state`).then((value) => value.json());
    assert.equal(state.capabilities.audioOptimization, false);
    await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      body: JSON.stringify({ number: 163, title: 'Unavailable tools' }),
    });
    const response = await apiFetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: {
        'X-File-Name': 'source.mp3',
        'X-Optimize-Audio': 'true',
      },
      body: mockMp3(1000),
    });
    assert.equal(response.status, 503);
    const staged = path.join(root, '.admin', 'uploads', 'audio', '163.mp3');
    await assert.rejects(access(staged));
    await assert.rejects(access(`${staged}.source`));
  }, { mediaTools });
});

test('serves an explicit audio optimization control wired to the upload header', async () => {
  await withServer(async ({ baseUrl, apiFetch }) => {
    const html = await apiFetch(`${baseUrl}/`).then((value) => value.text());
    const script = await apiFetch(`${baseUrl}/app.js`).then((value) => value.text());
    assert.match(html, /id="audioOptimizationInput"/);
    assert.match(html, /Optimize new MP3 uploads/);
    assert.match(script, /X-Optimize-Audio/);
    assert.match(script, /128 kbps, 44\.1 kHz stereo/);
  });
});

test('optimizes and validates a real FFmpeg-generated MP3 when tools are available', async (context) => {
  try {
    await Promise.all([
      execFileAsync('ffmpeg', ['-version'], { windowsHide: true }),
      execFileAsync('ffprobe', ['-version'], { windowsHide: true }),
    ]);
  } catch {
    context.skip('FFmpeg and FFprobe are not installed.');
    return;
  }
  const fixtureDir = await mkdtemp(path.join(tmpdir(), 'jw-songs-ffmpeg-'));
  const fixture = path.join(fixtureDir, 'source.mp3');
  await execFileAsync('ffmpeg', [
    '-hide_banner', '-loglevel', 'error', '-nostdin', '-y',
    '-f', 'lavfi', '-i', 'sine=frequency=440:duration=3',
    '-c:a', 'libmp3lame', '-b:a', '320k', '-ar', '48000', '-ac', '2',
    fixture,
  ], { windowsHide: true, timeout: 30000 });
  const source = await readFile(fixture);
  await withServer(async ({ baseUrl, apiFetch }) => {
    await apiFetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      body: JSON.stringify({ number: 163, title: 'Real FFmpeg fixture' }),
    });
    const response = await apiFetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: {
        'X-File-Name': 'fixture.mp3',
        'X-Optimize-Audio': 'true',
      },
      body: source,
    });
    assert.equal(response.status, 200, await response.text());
    const state = await apiFetch(`${baseUrl}/api/state`).then((value) => value.json());
    const draft = state.drafts.find((song) => song.number === 163);
    assert.equal(draft._audioOptimization.status, 'optimized');
    assert.ok(draft.audioSize < source.length);
  });
});
