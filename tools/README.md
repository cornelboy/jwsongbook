# Lyrics Sync Tool

Open `lyrics_sync.html` in a browser to create `.elrc` files from plain lyrics.

The tool uses a professional line timing workflow:

- Mark when each line starts.
- Mark when each line ends.
- Leave natural gaps between line end and the next line start for instrumentals, rests, and breathing space.
- Let the tool estimate word timing inside each line from the line's start and end.
- For difficult lines, tap exact word timings with `W`.
- Preview with a small lead offset so lyrics appear slightly before they are sung.

## Basic Workflow

1. Open `tools/lyrics_sync.html`.
2. Choose the matching MP3 from `assets/audio`.
3. Enter the song number, for example `1`.
4. Enter the title.
5. Keep `Preview lead` at `300 ms` unless you want a different feel.
6. Paste plain lyrics with one sung lyric line per row.
7. Click `Prepare lines`.
8. Press play on the audio.
9. Press `S` exactly when the current lyric line starts.
10. Press `E` exactly when the current lyric line ends.
11. Repeat until all lines are complete.
12. Replay the song and watch the `Live Preview` section.
13. Fix any bad line by clicking that line, rewinding, then marking its start/end again.
14. Click `Generate .elrc`.
15. Download the file and place it in `assets/lyrics`, for example `001.elrc`.

## Keyboard Shortcuts

- `S`: mark the start of the current line and the first word.
- `E`: mark the end of the current line.
- `W`: mark the next word in the selected line.
- `Space` or `Enter`: mark the current line's end and the next line's start at the same timestamp.
- `Backspace`: undo the previous timing action.
- `Left Arrow`: rewind the audio by 3 seconds.

## How To Handle Instrumentals

Do not add a fake lyric line for instrumental music.

Instead:

1. Press `E` when the previous lyric line finishes.
2. Wait while the instrumental plays.
3. Press `S` when the next lyric line starts.

That gap is preserved naturally because the generated `.elrc` has no lyric line during that time.

## How To Handle Slow Final Lines

For lines that slow down at the end, the end timestamp matters.

Example:

```text
With joy and with zeal, we will proclaim.
```

Press `S` when `With` starts.
Press `E` when `proclaim` actually finishes, not when the next musical beat starts.

The tool will stretch the estimated word timings across that longer line duration, which improves slow endings.

For the cleanest final line:

1. Click the final line in the timing table.
2. Rewind a few seconds before the line starts.
3. Press `S` when the line starts. This also marks the first word.
4. Press `W` as each remaining word is sung.
5. Press `E` when the final held word fully finishes.

When all words have `W` timestamps, the generated `.elrc` uses your exact word
timings for that line instead of estimated timings.

## How To Handle Lines With No Gap Between Them

If the next line begins immediately after the current line, press `Space`.

This does two things at once:

- Ends the current line.
- Starts the next line at the same timestamp.

Use this for fast transitions.

## Quality Checklist

Before using a generated file in the app:

1. Every lyric line should have both a start and an end time.
2. Instrumentals should be represented by empty time gaps, not fake lyric text.
3. The first sung line should not start during the intro music.
4. The last line should end when the singing ends.
5. Replay the audio inside the tool and watch `Live Preview` before downloading.
6. If a line appears too early or too late, click that line and redo its start/end.
7. If the line changes feel correct but the active word feels off, use exact word timing mode on that line.

## Preview Lead

The tool has a `Preview lead` field. The default is `300 ms`.

This means the preview highlights the next lyric about 0.3 seconds before the
audio reaches the timestamp. That usually feels better because singers need to
see the next lyric just before singing it.

The exported `.elrc` still stores the true audio timestamps you tapped. The app
also applies a 300 ms visual lead during playback.

## Current Limitation

For normal lines, estimated word timing is usually enough after accurate line
starts and ends. For expressive lines, use `W` to record exact word timings.
