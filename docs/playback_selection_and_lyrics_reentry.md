# Playback selection and lyrics re-entry

Implemented September 7, 2026.

- A pending "download, then play" request is superseded by any newer explicit
  song choice. The original download still completes but cannot take over the
  player. A second undownloaded choice becomes the new pending request.
- Removing one offline song reports `Song NNN removed.` in both the song menu
  and download management. Removing several reports the exact count.
- A newly mounted lyrics view lays out invisibly, jumps to the current playback
  line with zero-duration positioning, and then becomes visible. Subsequent
  live following, seeking, and manual Follow actions keep their animations.
  Paused, playing, and completed re-entry states are covered by widget tests.
- Chorus and instrumental labels were deliberately left unchanged for this
  iteration.

## Mini-player motion

Navigation and session restoration now render the expanded mini player in its
final position with no entrance motion. The slide-up transition is reserved for
an explicit tap or upward swipe on the collapsed progress strip. Changing songs
also resets to the expanded, stationary state. Focused widget tests cover app
opening, leaving Now Playing, and explicit collapse/restore.

Final verification: `flutter analyze --no-pub` reported no issues and all 72
Flutter tests passed.
