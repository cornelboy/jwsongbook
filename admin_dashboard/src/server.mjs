import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { spawn } from 'node:child_process';
import { createReadStream, createWriteStream, existsSync } from 'node:fs';
import {
  access,
  copyFile,
  mkdir,
  open,
  readFile,
  rename,
  rm,
  stat,
  writeFile,
} from 'node:fs/promises';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const moduleDir = path.dirname(fileURLToPath(import.meta.url));
const defaultPublicDir = path.resolve(moduleDir, '..', 'public');
const lucideBundle = path.resolve(
  moduleDir,
  '..',
  'node_modules',
  'lucide',
  'dist',
  'umd',
  'lucide.min.js',
);
const exampleContentRoot = path.resolve(moduleDir, '..', '..', 'download_server');
const siblingDownloadRepository = path.resolve(
  moduleDir,
  '..',
  '..',
  '..',
  'jwsongbook-downloads',
);
const defaultContentRoot = existsSync(siblingDownloadRepository)
  ? siblingDownloadRepository
  : exampleContentRoot;
const defaultBundledCatalogPath = path.resolve(
  moduleDir,
  '..',
  'data',
  'bundled_catalog.json',
);
const maxJsonBytes = 256 * 1024;
const maxAudioBytes = 100 * 1024 * 1024;
const maxLyricsBytes = 5 * 1024 * 1024;
const defaultBaselineMaxSongNumber = 163;
const csrfHeaderName = 'x-csrf-token';
const loopbackHostnames = new Set(['127.0.0.1', '::1', 'localhost']);
const targetAudioBitrate = 128000;
const targetAudioSampleRate = 44100;
const targetAudioChannels = 2;
const mediaCommandTimeoutMs = 120000;
const mediaCommandOutputLimit = 128 * 1024;

export function createContentServer({
  contentRoot = defaultContentRoot,
  publicDir = defaultPublicDir,
  baselineMaxSongNumber = defaultBaselineMaxSongNumber,
  bundledCatalogPath = defaultBundledCatalogPath,
  mediaTools = new FfmpegMediaTools(),
} = {}) {
  const csrfToken = randomBytes(32).toString('base64url');
  const workspace = new ContentWorkspace(
    path.resolve(contentRoot),
    validateBaselineMaxSongNumber(baselineMaxSongNumber),
    bundledCatalogPath == null ? null : path.resolve(bundledCatalogPath),
    mediaTools,
  );

  return createServer(async (request, response) => {
    try {
      const url = new URL(request.url ?? '/', 'http://localhost');
      const method = request.method ?? 'GET';
      validateRequestSource(request);
      if (!['GET', 'HEAD', 'OPTIONS'].includes(method)) {
        validateMutationRequest(request, csrfToken, url.pathname);
      }

      if (method === 'GET' && url.pathname === '/api/state') {
        return sendJson(response, 200, {
          ...(await workspace.state()),
          csrfToken,
        });
      }

      if (method === 'POST' && url.pathname === '/api/drafts') {
        const body = await readJson(request);
        return sendJson(response, 200, await workspace.saveDraft(body));
      }

      const assetRoute = url.pathname.match(
        /^\/api\/drafts\/(\d+)\/(audio|lyrics)$/,
      );
      if (method === 'GET' && assetRoute) {
        const file = await workspace.stagedAsset(
          parseSongNumber(assetRoute[1]),
          assetRoute[2],
        );
        return await streamFile(response, file, false);
      }
      if (method === 'PUT' && assetRoute) {
        const number = parseSongNumber(assetRoute[1]);
        const kind = assetRoute[2];
        const result = await workspace.stageAsset({
          number,
          kind,
          request,
          fileName: request.headers['x-file-name'],
          optimizeAudio: request.headers['x-optimize-audio'] === 'true',
        });
        return sendJson(response, 200, result);
      }

      const draftRoute = url.pathname.match(/^\/api\/drafts\/(\d+)$/);
      if (method === 'DELETE' && draftRoute) {
        await workspace.deleteDraft(parseSongNumber(draftRoute[1]));
        return sendEmpty(response, 204);
      }

      if (method === 'POST' && url.pathname === '/api/publish') {
        return sendJson(response, 200, await workspace.publish());
      }

      if (method === 'GET' && url.pathname.startsWith('/content/')) {
        const relativePath = decodeURIComponent(url.pathname.slice(9));
        return await serveContentFile(response, workspace.root, relativePath);
      }

      if (method === 'GET' && url.pathname === '/vendor/lucide.js') {
        return await streamFile(response, lucideBundle, false);
      }

      if (method === 'GET' || method === 'HEAD') {
        return await serveStatic(
          response,
          publicDir,
          url.pathname,
          method === 'HEAD',
        );
      }

      throw new HttpError(404, 'Route not found.');
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 500;
      const message =
        error instanceof HttpError ? error.message : 'Unexpected server error.';
      if (!(error instanceof HttpError)) console.error(error);
      sendJson(response, status, { error: message });
    }
  });
}

export class ContentWorkspace {
  constructor(
    root,
    baselineMaxSongNumber = defaultBaselineMaxSongNumber,
    bundledCatalogPath = defaultBundledCatalogPath,
    mediaTools = new FfmpegMediaTools(),
  ) {
    this.root = root;
    this.baselineMaxSongNumber = validateBaselineMaxSongNumber(
      baselineMaxSongNumber,
    );
    this.adminDir = path.join(root, '.admin');
    this.stagingDir = path.join(this.adminDir, 'uploads');
    this.draftPath = path.join(this.adminDir, 'draft.json');
    this.manifestPath = path.join(root, 'manifest.json');
    this.exampleManifestPath = path.join(root, 'manifest.example.json');
    this.bundledCatalogPath = bundledCatalogPath;
    this.mediaTools = mediaTools;
    this.operation = Promise.resolve();
  }

  async state() {
    const [published, drafts] = await Promise.all([
      this.loadPublished(),
      this.loadDrafts(),
    ]);
    const songs = published.songs.toSorted((a, b) => a.number - b.number);
    const draftSongs = drafts.toSorted((a, b) => a.number - b.number);
    const highestManagedNumber = [...songs, ...draftSongs].reduce(
      (highest, song) => Math.max(highest, song.number),
      this.baselineMaxSongNumber,
    );
    return {
      contentRoot: this.root,
      capabilities: {
        audioOptimization: await this.mediaTools.available(),
      },
      manifestExists: await exists(this.manifestPath),
      nextSongNumber: highestManagedNumber + 1,
      songs,
      drafts: draftSongs,
      stats: {
        songs: songs.length,
        audio: songs.filter((song) => Boolean(song.audioUrl)).length,
        lyrics: songs.filter((song) => Boolean(song.lyricsUrl)).length,
        drafts: draftSongs.length,
      },
    };
  }

  async stagedAsset(number, kind) {
    const extension = kind === 'audio' ? '.mp3' : '.elrc';
    const folder = kind === 'audio' ? 'audio' : 'lyrics';
    const file = path.join(
      this.stagingDir,
      folder,
      `${String(number).padStart(3, '0')}${extension}`,
    );
    if (!(await exists(file))) throw new HttpError(404, 'Draft file not found.');
    return file;
  }

  saveDraft(input) {
    return this.enqueue(async () => {
      const metadata = validateMetadata(input);
      const [published, drafts] = await Promise.all([
        this.loadPublished(),
        this.loadDrafts(),
      ]);
      const current = drafts.find((song) => song.number === metadata.number);
      const publishedSong = published.songs.find(
        (song) => song.number === metadata.number,
      );
      const next = {
        ...(publishedSong ?? {}),
        ...(current ?? {}),
        ...metadata,
      };
      const updated = drafts.filter((song) => song.number !== metadata.number);
      updated.push(next);
      await this.writeDrafts(updated);
      return next;
    });
  }

  stageAsset({ number, kind, request, fileName, optimizeAudio = false }) {
    return this.enqueue(async () => {
      const drafts = await this.loadDrafts();
      const draftIndex = drafts.findIndex((song) => song.number === number);
      if (draftIndex < 0) {
        throw new HttpError(409, 'Save the song metadata before adding files.');
      }

      const config = kind === 'audio'
        ? { extension: '.mp3', maxBytes: maxAudioBytes, folder: 'audio' }
        : { extension: '.elrc', maxBytes: maxLyricsBytes, folder: 'lyrics' };
      if (
        typeof fileName !== 'string' ||
        path.extname(fileName).toLowerCase() !== config.extension
      ) {
        throw new HttpError(400, `Choose a ${config.extension} file.`);
      }

      const padded = String(number).padStart(3, '0');
      const targetDir = path.join(this.stagingDir, config.folder);
      const target = path.join(targetDir, `${padded}${config.extension}`);
      await mkdir(targetDir, { recursive: true });
      if (optimizeAudio && kind !== 'audio') {
        throw new HttpError(400, 'Only MP3 audio can be optimized.');
      }
      const source = optimizeAudio ? `${target}.source` : target;
      const upload = await writeRequestToFile(request, source, config.maxBytes);

      try {
        if (kind === 'audio') {
          await validateMp3(source);
          const optimization = optimizeAudio
            ? await optimizeUploadedAudio({
                source,
                target,
                mediaTools: this.mediaTools,
                originalSize: upload.size,
              })
            : null;
          const selected = optimizeAudio
            ? await fileDetails(target)
            : upload;
          const published = await this.loadPublished();
          const publishedSong = published.songs.find(
            (song) => song.number === number && song.audioUrl,
          );
          const nextVersion = publishedSong
            ? Math.max(
                Number(drafts[draftIndex].version) || 1,
                (Number(publishedSong.version) || 1) + 1,
              )
            : Number(drafts[draftIndex].version) || 1;
          drafts[draftIndex] = {
            ...drafts[draftIndex],
            audioUrl: `audio/${padded}.mp3`,
            audioSize: selected.size,
            audioSha256: selected.sha256,
            version: nextVersion,
          };
          if (optimization) drafts[draftIndex]._audioOptimization = optimization;
          else delete drafts[draftIndex]._audioOptimization;
        } else {
          const validation = await validateElrc(target);
          drafts[draftIndex] = {
            ...drafts[draftIndex],
            lyricsUrl: `lyrics/${padded}.elrc`,
            lyricsSize: upload.size,
            lyricsSha256: upload.sha256,
            lyricsLines: validation.lines,
          };
        }
      } catch (error) {
        await rm(target, { force: true });
        await rm(source, { force: true });
        throw error;
      }

      await this.writeDrafts(drafts);
      return drafts[draftIndex];
    });
  }

  deleteDraft(number) {
    return this.enqueue(async () => {
      const drafts = await this.loadDrafts();
      const updated = drafts.filter((song) => song.number !== number);
      if (updated.length === drafts.length) {
        throw new HttpError(404, `Song ${number} has no draft.`);
      }
      await this.writeDrafts(updated);
      const padded = String(number).padStart(3, '0');
      await Promise.all([
        rm(path.join(this.stagingDir, 'audio', `${padded}.mp3`), {
          force: true,
        }),
        rm(path.join(this.stagingDir, 'lyrics', `${padded}.elrc`), {
          force: true,
        }),
      ]);
    });
  }

  publish() {
    return this.enqueue(async () => {
      const [published, drafts] = await Promise.all([
        this.loadPublished(),
        this.loadDrafts(),
      ]);
      if (drafts.length === 0) {
        throw new HttpError(409, 'There are no draft changes to publish.');
      }

      const merged = new Map(
        published.songs.map((song) => [song.number, { ...song }]),
      );
      for (const draft of drafts) {
        validateMetadata(draft);
        const publishedAudio = await this.publishStagedAsset(draft, 'audio');
        await this.publishStagedAsset(draft, 'lyrics');
        const clean = { ...draft };
        delete clean.lyricsLines;
        delete clean._audioOptimization;
        if (publishedAudio) {
          clean.audioSize = publishedAudio.size;
          clean.audioSha256 = publishedAudio.sha256;
        }
        merged.set(draft.number, clean);
      }

      const manifest = {
        version: Math.max(1, Number(published.version) || 1),
        generatedAt: new Date().toISOString(),
        songs: [...merged.values()].toSorted((a, b) => a.number - b.number),
      };
      assertUniqueNumbers(manifest.songs);
      await writeJsonAtomically(this.manifestPath, manifest);
      await rm(this.draftPath, { force: true });
      await rm(this.stagingDir, { recursive: true, force: true });
      return {
        published: drafts.length,
        totalSongs: manifest.songs.length,
        manifestPath: this.manifestPath,
      };
    });
  }

  async publishStagedAsset(song, kind) {
    const isAudio = kind === 'audio';
    const url = isAudio ? song.audioUrl : song.lyricsUrl;
    if (!url) return null;
    const relativePath = normalizeAssetPath(url, kind);
    const staged = path.join(this.stagingDir, relativePath);
    if (!(await exists(staged))) {
      const published = path.join(this.root, relativePath);
      if (!(await exists(published))) {
        throw new HttpError(
          409,
          `Song ${song.number} references missing ${kind}.`,
        );
      }
      return null;
    }

    if (isAudio) await validateMp3(staged);
    else await validateElrc(staged);
    const destination = path.join(this.root, relativePath);
    await replaceFile(staged, destination);
    return fileDetails(destination);
  }

  async loadPublished() {
    const source = (await exists(this.manifestPath))
      ? this.manifestPath
      : this.exampleManifestPath;
    const [bundled, manifest] = await Promise.all([
      this.loadBundledCatalog(),
      (await exists(source))
        ? readJsonFile(source)
        : Promise.resolve({ version: 1, songs: [] }),
    ]);
    if (!Array.isArray(manifest.songs)) {
      throw new HttpError(500, 'The published manifest has no songs array.');
    }
    const merged = new Map(
      bundled.map((song) => [song.number, { ...song }]),
    );
    for (const song of manifest.songs.map(normalizeExistingSong)) {
      merged.set(song.number, { ...merged.get(song.number), ...song });
    }
    const songs = [...merged.values()];
    assertUniqueNumbers(songs);
    return { ...manifest, songs };
  }

  async loadBundledCatalog() {
    if (
      this.bundledCatalogPath == null ||
      !(await exists(this.bundledCatalogPath))
    ) {
      return [];
    }
    const catalog = await readJsonFile(this.bundledCatalogPath);
    if (!Array.isArray(catalog.songs)) {
      throw new HttpError(500, 'The bundled catalog has no songs array.');
    }
    return catalog.songs.map((song) => {
      const normalized = normalizeExistingSong(song);
      validateMetadata(normalized);
      return normalized;
    });
  }

  async loadDrafts() {
    if (!(await exists(this.draftPath))) return [];
    const draft = await readJsonFile(this.draftPath);
    if (!Array.isArray(draft.songs)) {
      throw new HttpError(500, 'The draft file is invalid.');
    }
    return draft.songs.map(normalizeExistingSong);
  }

  async writeDrafts(songs) {
    assertUniqueNumbers(songs);
    await mkdir(this.adminDir, { recursive: true });
    await writeJsonAtomically(this.draftPath, {
      updatedAt: new Date().toISOString(),
      songs: songs.toSorted((a, b) => a.number - b.number),
    });
  }

  enqueue(operation) {
    const result = this.operation.then(operation, operation);
    this.operation = result.catch(() => {});
    return result;
  }
}

function validateMetadata(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new HttpError(400, 'Song metadata must be a JSON object.');
  }
  const number = parseSongNumber(input.number);
  const title = typeof input.title === 'string' ? input.title.trim() : '';
  if (!title || title.length > 200) {
    throw new HttpError(400, 'Title must contain between 1 and 200 characters.');
  }
  const durationMs = optionalNonNegativeInteger(input.durationMs, 'durationMs');
  const version = input.version == null
    ? 1
    : positiveInteger(input.version, 'version');
  return {
    number,
    title,
    ...(durationMs == null ? {} : { durationMs }),
    version,
  };
}

function normalizeExistingSong(song) {
  if (!song || typeof song !== 'object' || Array.isArray(song)) {
    throw new HttpError(500, 'A manifest song entry is invalid.');
  }
  const number = parseSongNumber(song.number);
  return { ...song, number };
}

function parseSongNumber(value) {
  const number = typeof value === 'string' ? Number(value) : value;
  if (!Number.isSafeInteger(number) || number <= 0) {
    throw new HttpError(400, 'Song number must be a positive integer.');
  }
  return number;
}

function positiveInteger(value, field) {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new HttpError(400, `${field} must be a positive integer.`);
  }
  return value;
}

function optionalNonNegativeInteger(value, field) {
  if (value == null || value === '') return null;
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new HttpError(400, `${field} must be a non-negative integer.`);
  }
  return value;
}

function validateBaselineMaxSongNumber(value) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new Error('Baseline max song number must be a non-negative integer.');
  }
  return value;
}

function assertUniqueNumbers(songs) {
  const numbers = new Set();
  for (const song of songs) {
    if (numbers.has(song.number)) {
      throw new HttpError(409, `Song number ${song.number} is duplicated.`);
    }
    numbers.add(song.number);
  }
}

function normalizeAssetPath(value, kind) {
  if (typeof value !== 'string') {
    throw new HttpError(409, `Invalid ${kind} path.`);
  }
  const normalized = value.replaceAll('\\', '/');
  const expected = kind === 'audio' ? /^audio\/\d+\.mp3$/ : /^lyrics\/\d+\.elrc$/;
  if (!expected.test(normalized)) {
    throw new HttpError(409, `Unsafe ${kind} path in draft.`);
  }
  return normalized;
}

async function writeRequestToFile(request, target, maxBytes) {
  const temporary = `${target}.part`;
  const hash = createHash('sha256');
  const output = createWriteStream(temporary, { flags: 'w' });
  let size = 0;
  try {
    for await (const chunk of request) {
      size += chunk.length;
      if (size > maxBytes) {
        throw new HttpError(413, 'The selected file is too large.');
      }
      hash.update(chunk);
      if (!output.write(chunk)) {
        await new Promise((resolve) => output.once('drain', resolve));
      }
    }
    await new Promise((resolve, reject) => {
      output.end(resolve);
      output.once('error', reject);
    });
    if (size === 0) throw new HttpError(400, 'The selected file is empty.');
    await replaceFile(temporary, target, { move: true });
    return { size, sha256: hash.digest('hex') };
  } catch (error) {
    output.destroy();
    await rm(temporary, { force: true });
    throw error;
  }
}

async function optimizeUploadedAudio({
  source,
  target,
  mediaTools,
  originalSize,
}) {
  if (!(await mediaTools.available())) {
    throw new HttpError(
      503,
      'Audio optimization requires FFmpeg and FFprobe on this computer.',
    );
  }
  const sourceProbe = normalizeAudioProbe(await mediaTools.probe(source));
  if (sourceProbe.bitRate <= targetAudioBitrate) {
    await replaceFile(source, target, { move: true });
    return {
      status: 'skipped',
      reason: 'already-efficient',
      originalSize,
      selectedSize: originalSize,
      savingsBytes: 0,
      savingsPercent: 0,
    };
  }

  const optimized = `${target}.optimized`;
  await rm(optimized, { force: true });
  try {
    await mediaTools.transcode(source, optimized);
    await validateMp3(optimized);
    await mediaTools.validateDecode(optimized);
    const optimizedProbe = normalizeAudioProbe(await mediaTools.probe(optimized));
    validateOptimizedAudio(sourceProbe, optimizedProbe);
    const optimizedDetails = await fileDetails(optimized);
    if (optimizedDetails.size >= originalSize) {
      await replaceFile(source, target, { move: true });
      return {
        status: 'skipped',
        reason: 'not-smaller',
        originalSize,
        selectedSize: originalSize,
        savingsBytes: 0,
        savingsPercent: 0,
      };
    }
    await replaceFile(optimized, target, { move: true });
    await rm(source, { force: true });
    const savingsBytes = originalSize - optimizedDetails.size;
    return {
      status: 'optimized',
      originalSize,
      selectedSize: optimizedDetails.size,
      savingsBytes,
      savingsPercent: Math.round(savingsBytes / originalSize * 1000) / 10,
      bitrateKbps: 128,
      sampleRate: targetAudioSampleRate,
      channels: targetAudioChannels,
    };
  } finally {
    await rm(optimized, { force: true });
  }
}

function normalizeAudioProbe(probe) {
  const codec = String(probe?.codec ?? '').toLowerCase();
  const sampleRate = Number(probe?.sampleRate);
  const channels = Number(probe?.channels);
  const bitRate = Number(probe?.bitRate);
  const durationSeconds = Number(probe?.durationSeconds);
  if (
    codec !== 'mp3' ||
    !Number.isFinite(sampleRate) || sampleRate <= 0 ||
    !Number.isSafeInteger(channels) || channels <= 0 ||
    !Number.isFinite(bitRate) || bitRate <= 0 ||
    !Number.isFinite(durationSeconds) || durationSeconds <= 0
  ) {
    throw new HttpError(400, 'FFprobe could not validate this MP3 audio stream.');
  }
  return { codec, sampleRate, channels, bitRate, durationSeconds };
}

function validateOptimizedAudio(source, optimized) {
  const bitrateTolerance = targetAudioBitrate * 0.06;
  if (
    optimized.codec !== 'mp3' ||
    optimized.sampleRate !== targetAudioSampleRate ||
    optimized.channels !== targetAudioChannels ||
    Math.abs(optimized.bitRate - targetAudioBitrate) > bitrateTolerance
  ) {
    throw new HttpError(
      422,
      'Optimized audio did not match MP3, 128 kbps, 44.1 kHz stereo requirements.',
    );
  }
  if (Math.abs(source.durationSeconds - optimized.durationSeconds) > 0.05) {
    throw new HttpError(
      422,
      'Optimized audio duration differs from the original by more than 50 ms.',
    );
  }
}

async function fileDetails(file) {
  const details = await stat(file);
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(file)) hash.update(chunk);
  return { size: details.size, sha256: hash.digest('hex') };
}

class FfmpegMediaTools {
  constructor({ ffmpegPath = 'ffmpeg', ffprobePath = 'ffprobe' } = {}) {
    this.ffmpegPath = ffmpegPath;
    this.ffprobePath = ffprobePath;
    this.availability = null;
  }

  available() {
    this.availability ??= Promise.all([
      runMediaCommand(this.ffmpegPath, ['-version'], { timeoutMs: 10000 }),
      runMediaCommand(this.ffprobePath, ['-version'], { timeoutMs: 10000 }),
    ]).then(() => true, () => false);
    return this.availability;
  }

  async probe(file) {
    const result = await runMediaCommand(this.ffprobePath, [
      '-v', 'error',
      '-select_streams', 'a:0',
      '-show_entries', 'stream=codec_name,sample_rate,channels,bit_rate:format=duration,bit_rate',
      '-of', 'json',
      file,
    ]);
    let parsed;
    try {
      parsed = JSON.parse(result.stdout);
    } catch {
      throw new HttpError(422, 'FFprobe returned invalid audio metadata.');
    }
    const stream = parsed.streams?.[0] ?? {};
    return {
      codec: stream.codec_name,
      sampleRate: stream.sample_rate,
      channels: stream.channels,
      bitRate: stream.bit_rate ?? parsed.format?.bit_rate,
      durationSeconds: parsed.format?.duration,
    };
  }

  transcode(source, destination) {
    return runMediaCommand(this.ffmpegPath, [
      '-hide_banner', '-loglevel', 'error', '-nostdin', '-y',
      '-i', source,
      '-map', '0:a:0', '-vn', '-map_metadata', '-1',
      '-c:a', 'libmp3lame', '-b:a', '128k',
      '-ar', '44100', '-ac', '2',
      '-f', 'mp3',
      destination,
    ]);
  }

  validateDecode(file) {
    return runMediaCommand(this.ffmpegPath, [
      '-hide_banner', '-loglevel', 'error', '-xerror', '-nostdin',
      '-i', file, '-map', '0:a:0', '-f', 'null', '-',
    ]);
  }
}

function runMediaCommand(
  executable,
  args,
  { timeoutMs = mediaCommandTimeoutMs } = {},
) {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, args, {
      shell: false,
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    let outputBytes = 0;
    let settled = false;
    let timer;
    let terminationTimer;
    let pendingError;
    const finish = (error, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      clearTimeout(terminationTimer);
      if (error) reject(error);
      else resolve(value);
    };
    const terminate = (error) => {
      if (pendingError || settled) return;
      pendingError = error;
      child.kill();
      terminationTimer = setTimeout(() => {
        child.kill('SIGKILL');
        finish(pendingError);
      }, 5000);
    };
    const collect = (target) => (chunk) => {
      outputBytes += chunk.length;
      if (outputBytes > mediaCommandOutputLimit) {
        terminate(new HttpError(422, 'Media tool output exceeded the safety limit.'));
        return;
      }
      if (target === 'stdout') stdout += chunk.toString('utf8');
      else stderr += chunk.toString('utf8');
    };
    child.stdout.on('data', collect('stdout'));
    child.stderr.on('data', collect('stderr'));
    child.once('error', () => {
      finish(new HttpError(503, 'FFmpeg or FFprobe could not be started.'));
    });
    child.once('close', (code) => {
      if (pendingError) finish(pendingError);
      else if (code === 0) finish(null, { stdout, stderr });
      else finish(new HttpError(422, `Media validation failed${stderr ? `: ${stderr.trim().slice(0, 500)}` : '.'}`));
    });
    timer = setTimeout(() => {
      terminate(new HttpError(504, 'Media processing timed out.'));
    }, timeoutMs);
  });
}

async function validateMp3(file) {
  const handle = await open(file);
  try {
    const header = Buffer.alloc(3);
    const { bytesRead } = await handle.read(header, 0, 3, 0);
    const hasId3 = bytesRead >= 3 && header.toString('ascii') === 'ID3';
    const hasFrameSync =
      bytesRead >= 2 && header[0] === 0xff && (header[1] & 0xe0) === 0xe0;
    if (!hasId3 && !hasFrameSync) {
      throw new HttpError(400, 'The selected file is not a recognizable MP3.');
    }
  } finally {
    await handle.close();
  }
}

async function validateElrc(file) {
  const text = await readFile(file, 'utf8');
  const lyricLines = text
    .split(/\r?\n/)
    .filter((line) => /^\[\d{2,}:\d{2}(?:\.\d{1,3})?\]/.test(line));
  if (lyricLines.length === 0) {
    throw new HttpError(400, 'The ELRC file has no timestamped lyric lines.');
  }
  if (!lyricLines.some((line) => /<\d{2,}:\d{2}(?:\.\d{1,3})?>/.test(line))) {
    throw new HttpError(400, 'The ELRC file has no word-level timestamps.');
  }
  return { lines: lyricLines.length };
}

async function replaceFile(source, destination, { move = false } = {}) {
  await mkdir(path.dirname(destination), { recursive: true });
  const next = `${destination}.next`;
  const backup = `${destination}.backup`;
  await rm(next, { force: true });
  if (move) await rename(source, next);
  else await copyFile(source, next);

  const hadDestination = await exists(destination);
  try {
    if (hadDestination) {
      await rm(backup, { force: true });
      await rename(destination, backup);
    }
    await rename(next, destination);
    await rm(backup, { force: true });
  } catch (error) {
    await rm(next, { force: true });
    if (hadDestination && (await exists(backup)) && !(await exists(destination))) {
      await rename(backup, destination);
    }
    throw error;
  }
}

async function writeJsonAtomically(destination, value) {
  const temporary = `${destination}.json.part`;
  await mkdir(path.dirname(destination), { recursive: true });
  await writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
  await replaceFile(temporary, destination, { move: true });
}

async function readJson(request) {
  const body = await readBody(request, maxJsonBytes);
  try {
    return JSON.parse(body.toString('utf8'));
  } catch {
    throw new HttpError(400, 'Request body must contain valid JSON.');
  }
}

async function readJsonFile(file) {
  try {
    return JSON.parse(await readFile(file, 'utf8'));
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new HttpError(500, `${path.basename(file)} contains invalid JSON.`);
    }
    throw error;
  }
}

async function readBody(request, maxBytes) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > maxBytes) throw new HttpError(413, 'Request body is too large.');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

async function serveStatic(response, publicDir, pathname, headOnly) {
  const relative = pathname === '/' ? 'index.html' : pathname.slice(1);
  const file = safeJoin(publicDir, relative);
  if (!(await exists(file)) || !(await stat(file)).isFile()) {
    throw new HttpError(404, 'Page not found.');
  }
  return streamFile(response, file, headOnly);
}

async function serveContentFile(response, root, relativePath) {
  if (!/^(audio\/\d+\.mp3|lyrics\/\d+\.elrc)$/.test(relativePath)) {
    throw new HttpError(404, 'Content file not found.');
  }
  const file = safeJoin(root, relativePath);
  if (!(await exists(file))) throw new HttpError(404, 'Content file not found.');
  return streamFile(response, file, false);
}

async function streamFile(response, file, headOnly) {
  const details = await stat(file);
  response.writeHead(200, {
    ...securityHeaders({
      'Content-Type': contentType(file),
      'Content-Length': details.size,
    }),
  });
  if (headOnly) return response.end();
  createReadStream(file).pipe(response);
}

function safeJoin(root, relativePath) {
  const target = path.resolve(root, relativePath);
  const prefix = `${path.resolve(root)}${path.sep}`;
  if (target !== path.resolve(root) && !target.startsWith(prefix)) {
    throw new HttpError(400, 'Unsafe file path.');
  }
  return target;
}

function contentType(file) {
  switch (path.extname(file).toLowerCase()) {
    case '.html': return 'text/html; charset=utf-8';
    case '.css': return 'text/css; charset=utf-8';
    case '.js': return 'text/javascript; charset=utf-8';
    case '.json': return 'application/json; charset=utf-8';
    case '.mp3': return 'audio/mpeg';
    case '.elrc': return 'text/plain; charset=utf-8';
    default: return 'application/octet-stream';
  }
}

function sendJson(response, status, value) {
  if (response.headersSent) return;
  const body = JSON.stringify(value);
  response.writeHead(status, securityHeaders({
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  }));
  response.end(body);
}

function sendEmpty(response, status) {
  response.writeHead(status, securityHeaders());
  response.end();
}

function validateRequestSource(request) {
  const authority = request.headers.host;
  if (typeof authority !== 'string' || !isLoopbackAuthority(authority)) {
    throw new HttpError(403, 'Dashboard requests must use a localhost address.');
  }

  const fetchSite = request.headers['sec-fetch-site'];
  if (fetchSite && fetchSite !== 'same-origin' && fetchSite !== 'none') {
    throw new HttpError(403, 'Cross-origin dashboard requests are forbidden.');
  }

  const origin = request.headers.origin;
  if (origin) {
    let parsedOrigin;
    try {
      parsedOrigin = new URL(origin);
    } catch {
      throw new HttpError(403, 'Invalid request origin.');
    }
    if (
      parsedOrigin.protocol !== 'http:' ||
      parsedOrigin.host.toLowerCase() !== authority.toLowerCase() ||
      !loopbackHostnames.has(parsedOrigin.hostname.toLowerCase())
    ) {
      throw new HttpError(403, 'Cross-origin dashboard requests are forbidden.');
    }
  }
}

function isLoopbackAuthority(authority) {
  try {
    const parsed = new URL(`http://${authority}`);
    return (
      parsed.username === '' &&
      parsed.password === '' &&
      loopbackHostnames.has(parsed.hostname.toLowerCase())
    );
  } catch {
    return false;
  }
}

function validateMutationRequest(request, expectedToken, pathname) {
  const suppliedToken = request.headers[csrfHeaderName];
  if (
    typeof suppliedToken !== 'string' ||
    !constantTimeEqual(suppliedToken, expectedToken)
  ) {
    throw new HttpError(403, 'Missing or invalid dashboard session token.');
  }

  const mediaType = String(request.headers['content-type'] ?? '')
    .split(';', 1)[0]
    .trim()
    .toLowerCase();
  const assetRoute = pathname.match(/^\/api\/drafts\/\d+\/(audio|lyrics)$/);
  const permittedTypes = assetRoute?.[1] === 'audio'
    ? new Set(['audio/mpeg', 'audio/mp3', 'application/octet-stream'])
    : assetRoute?.[1] === 'lyrics'
      ? new Set(['text/plain', 'application/octet-stream'])
      : new Set(['application/json']);
  if (!permittedTypes.has(mediaType)) {
    throw new HttpError(415, 'Unsupported request content type.');
  }
}

function constantTimeEqual(actual, expected) {
  const actualBytes = Buffer.from(actual);
  const expectedBytes = Buffer.from(expected);
  return actualBytes.length === expectedBytes.length &&
    timingSafeEqual(actualBytes, expectedBytes);
}

function securityHeaders(extra = {}) {
  return {
    'Cache-Control': 'no-store',
    'Content-Security-Policy': "default-src 'self'; connect-src 'self'; img-src 'self' blob:; media-src 'self' blob:; script-src 'self'; style-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'",
    'Cross-Origin-Resource-Policy': 'same-origin',
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    ...extra,
  };
}

async function exists(file) {
  try {
    await access(file);
    return true;
  } catch {
    return false;
  }
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function parseArguments(args) {
  let contentRoot = process.env.CONTENT_ROOT || defaultContentRoot;
  let host = process.env.HOST || '127.0.0.1';
  let port = Number(process.env.PORT || 4173);
  let baselineMaxSongNumber = Number(
    process.env.BASELINE_MAX_SONG_NUMBER || defaultBaselineMaxSongNumber,
  );
  for (let index = 0; index < args.length; index += 1) {
    switch (args[index]) {
      case '--content-root': contentRoot = args[++index]; break;
      case '--host': host = args[++index]; break;
      case '--port': port = Number(args[++index]); break;
      case '--baseline-max': baselineMaxSongNumber = Number(args[++index]); break;
      default: throw new Error(`Unknown argument: ${args[index]}`);
    }
  }
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error('Port must be an integer between 0 and 65535.');
  }
  validateBaselineMaxSongNumber(baselineMaxSongNumber);
  if (!loopbackHostnames.has(String(host).toLowerCase())) {
    throw new Error(
      'The dashboard may only bind to 127.0.0.1, ::1, or localhost.',
    );
  }
  return { contentRoot, host, port, baselineMaxSongNumber };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const options = parseArguments(process.argv.slice(2));
  const server = createContentServer({
    contentRoot: options.contentRoot,
    baselineMaxSongNumber: options.baselineMaxSongNumber,
  });
  server.listen(options.port, options.host, () => {
    const address = server.address();
    const port = typeof address === 'object' && address ? address.port : options.port;
    console.log(`JW Songs Content Manager: http://${options.host}:${port}`);
    console.log(`Content workspace: ${path.resolve(options.contentRoot)}`);
  });
}
