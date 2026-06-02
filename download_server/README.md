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
