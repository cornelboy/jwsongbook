# Floating Lyrics Bubble

The Flutter internal bubble in `lib/shared/widgets/floating_lyrics_button.dart`
is the design reference for the external Android overlay.

Runtime UX:

- Settings exposes one feature: `Floating Lyrics Bubble`.
- The app requests Android display-over-other-apps permission before enabling it.
- When enabled, the native overlay is the only floating bubble shown.
- The old internal in-app bubble is not mounted in the app shell.

Design source of truth:

- 60dp purple circular lyrics button.
- 110dp touch area.
- 8dp panel radius.
- Dark `#242424` panel with purple border.
- Song number badge, song title, `Floating lyrics` subtitle.
- Current lyric preview plus play/pause and open-full-player actions.

Keep the native overlay visually aligned with the Flutter reference whenever the
internal bubble design is adjusted.
