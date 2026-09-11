import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { createContentServer } from '../src/server.mjs';

async function withServer(run) {
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
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    await run({ root, baseUrl: `http://127.0.0.1:${port}` });
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

test('creates, stages, and publishes a complete future song', async () => {
  await withServer(async ({ root, baseUrl }) => {
    const initialState = await fetch(`${baseUrl}/api/state`).then(
      (result) => result.json(),
    );
    assert.equal(initialState.nextSongNumber, 163);

    let response = await fetch(`${baseUrl}/api/drafts`, {
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

    response = await fetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: { 'X-File-Name': 'song.mp3' },
      body: Buffer.from('ID3mock audio content'),
    });
    assert.equal(response.status, 200);

    const lyrics = [
      '[ti:Future song]',
      '[00:01.00]<00:01.00>Future <00:02.00>song.<00:03.00>',
    ].join('\n');
    response = await fetch(`${baseUrl}/api/drafts/163/lyrics`, {
      method: 'PUT',
      headers: { 'X-File-Name': 'song.elrc' },
      body: lyrics,
    });
    assert.equal(response.status, 200);

    response = await fetch(`${baseUrl}/api/publish`, { method: 'POST' });
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

    const finalState = await fetch(`${baseUrl}/api/state`).then(
      (result) => result.json(),
    );
    assert.equal(finalState.nextSongNumber, 164);
  });
});

test('publishes a catalog-only song and reports it in state', async () => {
  await withServer(async ({ baseUrl }) => {
    const response = await fetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ number: 163, title: 'Metadata first' }),
    });
    assert.equal(response.status, 200);

    const publish = await fetch(`${baseUrl}/api/publish`, { method: 'POST' });
    assert.equal(publish.status, 200);

    const state = await fetch(`${baseUrl}/api/state`).then((result) => result.json());
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
    assert.equal(state.stats.songs, 162);
    assert.equal(state.stats.audio, 1);
    assert.equal(state.nextSongNumber, 163);
    assert.equal(state.songs[0].title, 'Managed title');
    assert.equal(state.songs[161].title, 'My Spiritual Need');
  } finally {
    await new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
});

test('rejects invalid metadata and malformed assets', async () => {
  await withServer(async ({ baseUrl }) => {
    let response = await fetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ number: 0, title: '' }),
    });
    assert.equal(response.status, 400);

    await fetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ number: 163, title: 'Future song' }),
    });

    response = await fetch(`${baseUrl}/api/drafts/163/audio`, {
      method: 'PUT',
      headers: { 'X-File-Name': 'not-a-song.mp3' },
      body: Buffer.from('plain text'),
    });
    assert.equal(response.status, 400);

    response = await fetch(`${baseUrl}/api/drafts/163/lyrics`, {
      method: 'PUT',
      headers: { 'X-File-Name': 'bad.elrc' },
      body: 'lyrics without timestamps',
    });
    assert.equal(response.status, 400);
  });
});

test('updates an existing song without deleting untouched metadata', async () => {
  await withServer(async ({ baseUrl }) => {
    await fetch(`${baseUrl}/api/drafts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        number: 162,
        title: 'Corrected title',
        version: 2,
      }),
    });
    await fetch(`${baseUrl}/api/publish`, { method: 'POST' });

    const state = await fetch(`${baseUrl}/api/state`).then((result) => result.json());
    assert.equal(state.songs[0].title, 'Corrected title');
    assert.equal(state.songs[0].audioUrl, 'audio/162.mp3');
    assert.equal(state.songs[0].version, 2);
  });
});

test('a missing static asset returns 404 without stopping the server', async () => {
  await withServer(async ({ baseUrl }) => {
    const missing = await fetch(`${baseUrl}/favicon.ico`);
    assert.equal(missing.status, 404);

    const state = await fetch(`${baseUrl}/api/state`);
    assert.equal(state.status, 200);
    assert.equal((await state.json()).stats.songs, 1);
  });
});
