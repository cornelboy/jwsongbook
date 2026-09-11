# Content Expansion Notes

The app must support adding more songs later.

Do not treat the current Kingdom Songs catalog as permanently complete in
future feature work. The current local seed list and remote download manifest
are the starting catalog, but future releases may add more songs or revise
existing entries.

Implementation guidance:

- Avoid hard-coding UI logic to one fixed final song count.
- Prefer manifest/database-driven song availability.
- Keep download logic tolerant of new song numbers appearing in the manifest.
- Keep catalog metadata available locally, while serving all audio and lyrics
  through the remote download catalog.
- Preserve existing user data such as favorites, downloaded status, and recent
  playback when catalog metadata is updated.

Synced lyrics may also be added later.

Do not assume every playable song has an `.elrc` file. The app should keep
working when a song has audio but no synced lyrics yet.

Implementation guidance:

- If synced lyrics are missing, show a clean empty/placeholder lyrics state.
- When an `.elrc` file is added later, import it without requiring the audio to
  be downloaded again.
- Keep lyrics metadata independent from audio download metadata where possible.
- Treat the lyrics sync workflow as incremental: songs can move from audio-only
  to synced-lyrics-ready over time.

Current lyric sync tool:

- Tool file: `tools/lyrics_sync.html`
- Tool instructions: `tools/README.md`
- Generated lyrics are uploaded through the content dashboard.

## Deferred Contingency: Replacing Published Content

The content dashboard can replace an existing remote MP3 or `.elrc` file and
regenerate the download manifest, but it cannot directly modify content that
is already stored on a user's device.

Current behavior:

- The app refreshes the remote manifest at startup and merges catalog metadata.
- Missing lyrics can be downloaded from the Now Playing screen.
- Lyrics that are already installed are not automatically checked for a newer
  revision.
- A manifest song `version` is parsed, but it is not persisted or compared with
  the locally installed content version.
- The dashboard writes SHA-256 values, but the Flutter manifest model does not
  currently consume or persist them.

Required permanent update flow:

1. Track audio and lyrics revisions independently using `audioVersion` and
   `lyricsVersion` (and preferably their SHA-256 hashes).
2. Require a lyrics revision increment when the dashboard publishes a
   replacement `.elrc` file.
3. After a manifest refresh, compare each installed revision with the remote
   revision.
4. Download only the changed asset to a temporary file.
5. Validate the downloaded file before replacing the installed copy.
6. Atomically replace the file and transactionally re-import lyrics into Drift.
7. Invalidate the active lyrics provider so corrected lyrics appear without an
   app-data reset or an audio re-download.
8. Preserve the old working content if download, validation, or import fails,
   and retry on a later online launch.
9. Use a revisioned URL or cache-busting query to prevent a CDN from serving an
   older file at the same path.

This work is intentionally deferred because the release policy is append-only:
published audio and lyrics will be finalized before public release, and later
catalog changes will add new song numbers rather than replace existing files.
Keep this design as a recovery path in case a correction is ever unavoidable.

## Server-Only Media Decision

Audio and `.elrc` files are not bundled in the APK. Songs 001-003 use the same
remote download path as every other song.

- The APK retains local catalog metadata so the library can render immediately.
- A song becomes playable only after its audio is downloaded.
- Lyrics are downloaded and imported with the song when the manifest provides
  an `.elrc` URL.
- Users can download individual songs or use Download all for offline use.
- A first installation has no playable songs while offline.
- Removing bundled MP3 files reduces the APK by roughly 9 MB with the current
  three-song starter set.
- Newly published songs are added through the dashboard, followed by a commit
  and push of the download repository.
