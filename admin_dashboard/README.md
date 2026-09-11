# JW Songs Content Manager

A local-first administration dashboard for maintaining the song catalog,
staging MP3 and Enhanced LRC files, and publishing the static manifest consumed
by the Flutter app.

## Start

Node.js 20 or newer is required.

On Windows, double-click `launch-dashboard.cmd` in the project root. It starts
the server in the background and opens the dashboard. Running it again simply
opens the already-running dashboard. Use `stop-dashboard.cmd` when you want to
stop the background server.

The equivalent terminal commands are:

```powershell
cd admin_dashboard
npm install
npm start
```

Open `http://127.0.0.1:4173`. The server binds only to the local machine and
uses a sibling `jwsongbook-downloads` repository when it exists. Otherwise it
falls back to `../download_server` as an example workspace.

The dashboard merges its generated snapshot of the Flutter app's bundled
catalog with entries managed for remote delivery. This keeps all 162 existing
titles visible while clearly identifying songs that still need audio or lyrics.
The mobile app merges remote entries into its local catalog metadata without
deleting user state. Audio and lyrics themselves are downloaded from the
remote catalog rather than bundled in the application.
**Add song** therefore suggests 163 in a new workspace.

To manage a different workspace:

```powershell
node src/server.mjs --content-root D:\path\jwsongbook-downloads --port 4173
```

For a future app whose bundled catalog ends at a different number, pass
`--baseline-max <number>` or set `BASELINE_MAX_SONG_NUMBER`.

After changing the bundled seed list in `songs_repository.dart`, refresh the
dashboard snapshot with:

```powershell
npm run sync-catalog
```

## Add Song 163

1. Select **Add song**. The next available number is filled automatically.
2. Enter the official title, optional duration, and asset version.
3. Select **Save draft**. A title-only draft is valid.
4. Use the file controls to stage `163.mp3` and optionally `163.elrc`.
5. Review the Audio and Lyrics status indicators.
6. Select **Publish changes** and confirm.

Publishing copies validated assets to `audio/` and `lyrics/`, then replaces
`manifest.json` last. The mobile app discovers the new catalog entry during its
background manifest refresh after the download repository is deployed. A song
can be published without audio or lyrics; the missing files can be attached in
a later version.

## Deploy To The App

The dashboard publishes to the local download repository; it does not push to
GitHub automatically. Review the generated manifest and files, then commit and
push `jwsongbook-downloads`. GitHub Pages serves that repository at the manifest
URL configured by the Flutter app. Keeping deployment separate prevents an
accidental draft or incorrect media file from immediately reaching users.

## Safety Model

- Draft metadata is stored in `.admin/draft.json`.
- Uploaded files remain in `.admin/uploads/` until publication.
- Song numbers and metadata are validated before writing.
- MP3 headers and word-level ELRC timestamps are checked.
- File size limits are 100 MB for audio and 5 MB for lyrics.
- SHA-256 hashes are recorded in the manifest.
- Existing metadata is merged instead of being silently discarded.
- Assets are placed before the manifest is swapped.
- The local server exposes content only from `audio/` and `lyrics/`.

The `.admin` workspace and generated media are ignored by Git.

## Tests

```powershell
npm test
```

The API tests use temporary directories and never modify the real content
workspace.

## Future Hosted Version

The dashboard UI already talks to a small HTTP API. A public deployment can
replace the local workspace implementation with authenticated API endpoints,
database-backed catalog metadata, object storage, audit history, and a CDN
without changing the mobile manifest contract.
