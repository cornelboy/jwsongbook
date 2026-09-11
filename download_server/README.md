# Download Server

The app expects a static JSON manifest plus audio/lyrics files:

- `manifest.json`
- `audio/001.mp3`
- `lyrics/001.elrc`

Use the generator so large media files stay out of Git:

```powershell
dart run tools/prepare_download_server.dart
```

That writes the server package to `build/download_server`.

For a separate downloads repo, use this shape:

```text
jwsongbook-downloads/
  audio/
    001.mp3
    002.mp3
    003.mp3
  lyrics/
    001.elrc
```

Then generate the manifest directly in that repo:

```powershell
dart run tools/prepare_download_server.dart --source D:\path\jwsongbook-downloads --output D:\path\jwsongbook-downloads
```

If your MP3 files are in a different folder, pass it directly:

```powershell
dart run tools/prepare_download_server.dart --audio-dir D:\path\all-mp3-files --output D:\path\jwsongbook-downloads
```

The `lyrics/` folder is optional. Manifest entries can be audio-only until
`.elrc` files are ready.

## Adding future songs

The database does not have a fixed maximum song number. To add a song without
shipping a new app build, add a manifest entry with its official number and
title:

```json
{
  "number": 163,
  "title": "Official song title",
  "durationMs": 194000,
  "audioUrl": "audio/163.mp3",
  "lyricsUrl": "lyrics/163.elrc"
}
```

`durationMs`, `audioUrl`, and `lyricsUrl` are optional. A title-only entry will
appear in the catalog but cannot be played until its audio URL is added. An
audio-only entry can update assets for a song already known to the app, but a
new catalog row requires a non-empty title. Keep each song number unique.

The generator preserves titles already present in `manifest.json`, so metadata
added by hand is not lost when the server package is regenerated.

For local phone testing:

```powershell
cd build\download_server
python -m http.server 8080 --bind 0.0.0.0
```

Then run/install the app with your PC LAN IP:

```powershell
flutter run -d RF8M329FC9T --dart-define=SONG_MANIFEST_URL=http://YOUR_PC_IP:8080/manifest.json
```

The manifest may use relative URLs. The app resolves them relative to
`manifest.json`, so the same package can later move to GitHub Pages or another
static host without changing each song entry.
