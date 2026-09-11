# Lyrics Timing Studio

Open `tools/lyrics_sync.html` in a browser to create word-timed Enhanced LRC
files. Keep `lyrics_sync_engine.js` and `lyrics_sync.js` beside the HTML file.

## Word Timing Workflow

1. Choose the matching MP3 from the download catalog's `audio/` folder.
2. Enter the song number and title.
3. Paste plain lyrics with one sung line per row and a blank line between parts.
   Each blank-line break becomes a part in the app's “Part X of Y” indicator.
   Adding or removing only these breaks preserves existing word timestamps.
   Leave out verse numbers,
   section labels, timestamp tags, and instrumental labels.
4. Select **Prepare words**. Song setup can then collapse to leave room for timing.
5. Press **Play** in the player fixed at the bottom of the screen.
6. Press **W**, or tap **Mark word**, at the beginning of each sung word.
   The selected word card and the button show the next word to mark.
7. Press **E**, or **End line**, when the final word finishes, including its
   held note. The next line is selected automatically.
8. Continue through the song, replay it in **Playback preview**, and correct
   any inaccurate words.
9. Select **Export .elrc**, resolve any listed timing issues, then download.
   Song 3 downloads as `003.elrc`.
10. Upload the file to the matching song in the content dashboard. Publishing
    writes it under `lyrics/NNN.elrc` and updates the local manifest. Commit
    and push the download repository separately to deliver it to the app.

The first word's tap sets the line start automatically. Every word must be
marked; the tool does not distribute or estimate word timings. Export requires
every word and line end, increasing timestamps, no overlapping lines, and
timings within the loaded audio's duration.

## Player And Controls

Audio controls stay together with the timing buttons at the bottom, including
while you scroll through the song or edit words. The controls include play/pause,
a seek slider, three-second rewind/forward, and 0.5×, 0.75×, 0.85×, or normal speed.

| Key | Action |
| --- | --- |
| W | Mark the selected word, then select the following word |
| E | Mark the final word's end and move to the next line |
| N | End the current line and mark the next line's first word together |
| Space / P | Play or pause |
| Left / Right Arrow | Seek backward / forward three seconds |
| Backspace | Undo the last timing action |

Shortcuts do not run while typing in fields or while the export dialog is open.
Space and Enter on a focused button retain their normal button activation.
Holding a timing key does not record repeated marks.

Tap timing is captured on the initial pointer press. Playback speed changes do
not scale exported timestamps: the tool always records the audio position.

## Gaps And Held Notes

For an instrumental or breathing gap, finish the previous line with **E**, wait,
and press **W** when the next line's first word begins. The gap is preserved.

For a transition with no gap, use **N / Next line now** when the next line begins.
This records its first word as well as the previous line's end. The following
**W** tap records the next line's second word.

Hold off on **End line** until the final sung word has actually finished.
The exported trailing timestamp preserves its full duration.

## Correcting A Word Or Line

Select a line from **Song lines**, then select the word card to correct.
Selection does not overwrite timestamps. Seek back, replay, and press **W**
at the right moment. Corrections must stay between neighbouring timestamps.

**Retake line** clears that line's words and end, pauses audio, and rewinds to
two seconds before its previous start. Press Play to record it again.
**Undo** restores the cleared timings or the most recent timing action.

## Preview And Drafts

The default preview lead is **300 ms**. It advances only the visual preview;
the exported file retains the actual tapped audio positions. Choose **Off**
to compare the preview directly with the recording.

The tool saves lyrics, metadata, and timing progress in local browser storage
when available. Reloading restores the draft; reselect the same audio file to
continue. Audio itself and undo history are not stored. The saving indicator
reports when storage is unavailable. Keep the page open in that case.

A draft belongs to the current browser and page origin; opening the tool at
a different URL, in another browser, or clearing browser storage does not
carry that draft over. The previous line-focused tool had no autosave: keep
any old working tab open until its work is exported.

## Mobile Layout

The editor stacks into one column, uses tappable word cards, and keeps playback
and timing controls at the bottom. Song lines appear below the timing workspace.
The HTML and both JavaScript files must be accessible to the phone; the desktop
dashboard's `127.0.0.1` address is not a phone-accessible address.

## Timing Tests

Run from the project root:

```powershell
node --test tools/lyrics_sync_engine.test.cjs
```

Tests cover exact export, incomplete timings, short phrases, instrumental
gaps, held notes, immediate line transitions, corrections, timestamp order,
audio bounds, draft restoration, and Unicode lyrics.
