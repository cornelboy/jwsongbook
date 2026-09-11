# Projection Mode Note

Congregation Mode is disabled for now.

Reason:
- The current setting changes lyric font size and alignment inside the normal
  phone player, which has caused sync and scrolling edge cases.
- Projection use is a different workflow from personal listening and should not
  be treated as a simple display toggle.

Future implementation:
- Build a dedicated Projection Mode screen instead of reusing the normal lyrics
  screen.
- Keep audio timing and lyric sync logic shared with the normal player.
- Use a projection-specific layout with large centered lyrics, fewer visible
  lines, and predictable block transitions.
- Test separately on different phone sizes, landscape mode, screen mirroring,
  HDMI/USB-C output, and external displays.

Until this is rebuilt, the app should always use the normal lyrics layout.
