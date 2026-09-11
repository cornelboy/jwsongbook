# Lyrics following and song parts

Updated: September 7, 2026

## Following after a drag

- Tapping a lyric still seeks to that line.
- Dragging pauses following until the drag and its momentum end.
- If the playing lyric remains visible, following resumes after five seconds
  without another drag. Another drag starts a new wait.
- The existing return when upcoming lyrics leave the safe visible area can
  still happen earlier than that timer.
- If the playing lyric was dragged off-screen, the Follow lyrics button stays
  available and no automatic-resume timer is started.
- Timer, edge-triggered, and manual returns use an 800–1,200 ms animation based
  on the distance. Playback ticks do not interrupt this animation.
- Normal line-by-line following keeps its existing timing.
- Pausing cancels the wait; playback starts a fresh wait when applicable.
  Seeking, changing songs, or dragging cancels a pending return.

## Song parts

Blank lines between timed lyric groups are explicit part boundaries. The timing
tool now preserves these in exports and drafts. Adding or removing only part
breaks does not reset word timestamps.

Song 003 has two verse parts, each including its chorus. Its new blank line is
before lyric line 15, at 01:37.91. All 28 lyric lines and 153 word timestamps
are unchanged. The content manifest was updated to song version 2 and published
in download-repository commit `1ea2dc0`.

Installed lyrics are not automatically replaced by a new manifest version.
For this test, remove only Song 003 from downloaded songs and download it again.
This does not require clearing the app's data or other downloaded songs.

## Verification

- Passed: Flutter analysis, with no issues.
- Passed: all 54 Flutter tests, including seven follow-flow widget regressions.
- Passed: all 11 timing-engine tests.
- Passed: browser checks for part editing, timestamp preservation, export,
  restored drafts, and desktop/mobile layouts.
- Passed: Song 003 parsed by the app's ELRC parser as two parts with 28 lines
  and 153 words.
- Pending: physical-phone check of the return animation and updated part label.
  No device was connected over ADB during this change.
