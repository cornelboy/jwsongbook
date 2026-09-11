import { createHash } from 'node:crypto';
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
const defaultBaselineMaxSongNumber = 162;

export function createContentServer({
  contentRoot = defaultContentRoot,
  publicDir = defaultPublicDir,
  baselineMaxSongNumber = defaultBaselineMaxSongNumber,
  bundledCatalogPath = defaultBundledCatalogPath,
} = {}) {
  const workspace = new ContentWorkspace(
    path.resolve(contentRoot),
    validateBaselineMaxSongNumber(baselineMaxSongNumber),
    bundledCatalogPath == null ? null : path.resolve(bundledCatalogPath),
  );

  return createServer(async (request, response) => {
    try {
      const url = new URL(request.url ?? '/', 'http://localhost');
      const method = request.method ?? 'GET';

      if (method === 'GET' && url.pathname === '/api/state') {
        return sendJson(response, 200, await workspace.state());
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

  stageAsset({ number, kind, request, fileName }) {
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
      const upload = await writeRequestToFile(request, target, config.maxBytes);

      try {
        if (kind === 'audio') {
          await validateMp3(target);
          drafts[draftIndex] = {
            ...drafts[draftIndex],
            audioUrl: `audio/${padded}.mp3`,
            audioSize: upload.size,
            audioSha256: upload.sha256,
          };
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
        await this.publishStagedAsset(draft, 'audio');
        await this.publishStagedAsset(draft, 'lyrics');
        const clean = { ...draft };
        delete clean.lyricsLines;
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
    if (!url) return;
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
      return;
    }

    if (isAudio) await validateMp3(staged);
    else await validateElrc(staged);
    await replaceFile(staged, path.join(this.root, relativePath));
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
    'Content-Type': contentType(file),
    'Content-Length': details.size,
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
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
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  response.end(body);
}

function sendEmpty(response, status) {
  response.writeHead(status, { 'Cache-Control': 'no-store' });
  response.end();
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
