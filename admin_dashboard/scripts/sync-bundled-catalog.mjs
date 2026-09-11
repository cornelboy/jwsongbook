import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, '..', '..');
const sourcePath = path.join(
  projectRoot,
  'lib',
  'data',
  'repositories',
  'songs_repository.dart',
);
const outputPath = path.resolve(scriptDir, '..', 'data', 'bundled_catalog.json');

const source = await readFile(sourcePath, 'utf8');
const seedStart = source.indexOf('final List<SongsCompanion> _kSeedSongs');
if (seedStart < 0) throw new Error('Could not find the bundled song catalog.');

const seedSource = source.slice(seedStart);
const entryPattern = /SongsCompanion\.insert\(\s*number:\s*(\d+),\s*title:\s*("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')\s*,?\s*\)/gs;
const songs = [...seedSource.matchAll(entryPattern)].map((match) => ({
  number: Number(match[1]),
  title: decodeDartString(match[2]),
}));

if (songs.length === 0) throw new Error('The bundled catalog contains no songs.');
for (let index = 0; index < songs.length; index += 1) {
  const expectedNumber = index + 1;
  if (songs[index].number !== expectedNumber || !songs[index].title) {
    throw new Error(`Invalid bundled catalog entry at song ${expectedNumber}.`);
  }
}

await mkdir(path.dirname(outputPath), { recursive: true });
await writeFile(
  outputPath,
  `${JSON.stringify({ version: 1, songs }, null, 2)}\n`,
  'utf8',
);
console.log(`Synced ${songs.length} bundled songs to ${outputPath}`);

function decodeDartString(literal) {
  const body = literal.slice(1, -1);
  return body.replace(
    /\\(u\{[0-9a-fA-F]+\}|u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|n|r|t|b|f|v|'|"|\\|\$)/g,
    (_, escape) => {
      if (escape.startsWith('u{')) {
        return String.fromCodePoint(Number.parseInt(escape.slice(2, -1), 16));
      }
      if (escape.startsWith('u')) {
        return String.fromCharCode(Number.parseInt(escape.slice(1), 16));
      }
      if (escape.startsWith('x')) {
        return String.fromCharCode(Number.parseInt(escape.slice(1), 16));
      }
      return {
        n: '\n',
        r: '\r',
        t: '\t',
        b: '\b',
        f: '\f',
        v: '\v',
        "'": "'",
        '"': '"',
        '\\': '\\',
        '$': '$',
      }[escape];
    },
  );
}
