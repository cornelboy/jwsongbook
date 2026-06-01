# Next Steps From Recording And Research

## Summary

The screen recording shows that the core synced lyrics engine is working: playback, auto-scroll, active-line emphasis, and word-level highlighting are already visible. The research PDF points toward a broader "Lyrics Anywhere" direction, but it also makes clear that floating lyrics should come after the in-app player and lyrics experience feel polished.

The immediate priority is to make the Now Playing experience feel intentional and premium before adding an Android overlay or floating lyrics bubble.

## What To Build Next

1. Polish the Now Playing screen.
   The current player has a lot of unused vertical space and still feels like a basic tab page. It should become a lyric-first music player with a tighter header, better song identity, stronger controls, and less dead space.

2. Fix lyrics interaction issues.
   The Follow button can cover lyrics near the bottom of the screen. Move it away from lyric content, add top and bottom fade gradients, improve manual-scroll recovery, and support tapping a lyric line to seek.

3. Add a lyrics preview outside the full player.
   The research recommends a three-level lyrics model: preview lyrics, expanded lyrics, and immersive lyrics. The app already has the full lyrics experience; the missing layer is a mini-player/current-line preview.

4. Upgrade player controls.
   Current controls are previous, play/pause, and next. Prioritize controls that matter for songbook use: favorite, repeat, lyric timing offset, and a clearer scrub/progress experience.

5. Build compact/floating lyrics later.
   First add an in-app compact lyrics card. Android floating lyrics should be an opt-in feature after users already understand the value of lyrics inside the app.

## First Implementation Slice

- Move the Follow control so it does not cover lyrics.
- Add lyric edge fade gradients for a more polished karaoke surface.
- Allow tapping a lyric line to seek to that line.
- Keep the current sync behavior intact.
