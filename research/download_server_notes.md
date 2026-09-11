# Download Server Notes

## Current Direction

- Add all audio files first because the MP3 files are already available.
- Add `.elrc` synced lyric files later as they are prepared.
- The app already supports manifest entries without `lyricsUrl`, so audio-only downloads are valid.

## How The Server Works

- The server is static file hosting, not a custom backend.
- It hosts:
  - `manifest.json`
  - `audio/001.mp3`, `audio/002.mp3`, etc.
  - later: `lyrics/001.elrc`, `lyrics/002.elrc`, etc.
- The app reads `manifest.json` to know which song files are available and where to download them.
- Users need internet only to download songs that are not already stored on their device.
- After a song is downloaded, it is saved locally and can play offline.

## GitHub Pages Option

- GitHub Pages is free for public repositories.
- It can host static files and is a good first/testing option.
- Use a separate repo for downloads, not the main app repo.
- Example URL shape:
  - `https://cornelboy.github.io/jwsongbook-downloads/manifest.json`
  - `https://cornelboy.github.io/jwsongbook-downloads/audio/001.mp3`
- GitHub Pages has soft usage limits, so it is fine for early testing but may not be best for heavy public audio downloads.

## Longer-Term Option

- Cloudflare R2 is a better long-term fit for many MP3 downloads.
- It is designed for object/file storage and avoids many bandwidth concerns compared with GitHub Pages.
- The same static folder structure can move from GitHub Pages to R2 later.

## Next Practical Step

- Create a separate `jwsongbook-downloads` repository.
- Put all MP3 files under `audio/`.
- Generate `manifest.json`.
- Enable GitHub Pages for that repo.
- Build/install the app with:

```powershell
flutter build apk --release --dart-define=SONG_MANIFEST_URL=https://cornelboy.github.io/jwsongbook-downloads/manifest.json
```

For local testing, keep using:

```powershell
dart run tools/prepare_download_server.dart --source <folder-with-assets> --output build/download_server
python -m http.server 8080 --bind 0.0.0.0
```
