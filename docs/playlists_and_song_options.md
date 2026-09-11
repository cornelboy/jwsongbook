# Playlists and song options

Implemented September 7, 2026.

## User flow

- Bottom navigation: Songs, Now Playing, Favorites, Playlists.
- Settings opens from the gear in the Songs app bar, with back navigation.
- Song rows in Songs, Favorites and playlist details have a three-dot menu.
- Menus support favorite/unfavorite, add to playlist, download/pause/resume,
  and confirmed removal of the offline copy. Playlist rows also offer removal
  from that playlist.
- Create a named playlist from its tab or from a song menu. Names are trimmed,
  required, and limited to 80 characters. Adding an existing member is a no-op.
- Add songs with number/title search, drag handles to arrange them, rename a
  playlist, and delete it with confirmation. Deleting a playlist never deletes
  songs, downloaded files, or favorites.

## Storage and playback

Drift schema 5 adds `playlists` and `playlist_entries`. Migration from schema 4
does not modify songs or lyrics. Membership uses song IDs, ordered positions,
foreign keys, and a composite primary key to prevent duplicate membership.
Reordering is transactional and rejects a stale/mismatched membership list.

Play in order starts a snapshot of the downloaded members in the saved order
and disables shuffle. Undownloaded members remain in the playlist but are
skipped for playback; tapping one explains that a download is needed first.
Next, Previous, track completion and repeat use the playlist queue. Repeat off
stops at its end. Repeat one/all retain their existing meanings. Selecting a
song from the main library or Favorites returns to the normal library queue.

The queue snapshot is saved with playback preferences for session restoration.
Editing or deleting a saved playlist does not interrupt its current snapshot;
the edits apply the next time the playlist is played.

## Verification

Final automated run: all 64 Flutter tests passed; `flutter analyze --no-pub`
reported no issues. The separate screenshot-enabled widget run also passed.

- Database tests: names, duplicate prevention, order, removal, cascades,
  preservation of favorite/download state, schema-4 upgrade with existing lyrics,
  file-backed persistence after reopening, playback preference compatibility.
- Real player notifier with mocked audio: ordered Next/Previous, automatic
  advancement, repeat wrapping, skipping undownloaded songs, library reset.
- Widget flows with real SQLite: song menus, favorite state, cancelled download
  removal, create/add, continuous drag gesture, play handoff, rename/delete,
  and Settings/back plus Playlists tab in the navigation shell.
- The nested-navigation tests caught and fixed confirmation buttons using the
  page's navigator instead of the dialog's navigator.
- Optional screenshot capture: run `playlists_flow_test.dart` with
  `--dart-define=CAPTURE_PLAYLIST_UI=true` and `PLAYLIST_QA_FONTS` pointing to the
  Flutter SDK's `bin/cache/artifacts/material_fonts` directory. Screenshots go to
  `tmp/playlist-qa`. They are widget-test renders, not physical-phone screenshots.

Physical-phone installation and playback acceptance remain pending while ADB
reports no attached device. Do not clear app data to install this update.
