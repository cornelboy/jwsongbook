# JW Songs Launch Readiness Phases

Date: August 26, 2026
Status: Alpha / internal testing

This roadmap breaks the work into clear phases so each one can be completed and verified before moving to the next. The app should not be treated as launch-ready until every phase has passed.

## Phase 1 - Stabilize Core Playback

Goal: Songs must play reliably in the app, in the background, and from system controls.

Tasks:
- Confirm play, pause, previous, next, seek forward, and seek backward work without delay.
- Confirm finished songs show the correct stopped/paused state in the notification panel.
- Confirm notification controls show play/pause plus previous/next.
- Confirm closing the app from the recent apps screen stops playback.
- Confirm normal Android back navigation does not wrongly kill playback.
- Run a 30-minute continuous playback test with no crash.

Exit criteria:
- No crash during playback, seek, song end, notification control use, or app backgrounding.
- Notification state always matches the real audio state.

## Phase 2 - Lock Lyrics Sync Behavior

Goal: Lyrics must stay aligned after normal user actions.

Tasks:
- Verify sync after seeking forward.
- Verify sync after seeking backward.
- Verify sync after replaying a finished song.
- Verify sync after manually scrolling and pressing the sync button.
- Keep the sync button near the mini player where users naturally look for playback correction.
- Keep auto-scroll behavior simple: manual scrolling can temporarily move the user away, and the sync button should return them to the active lyric position.
- Keep congregation mode disabled for now and preserve a note explaining why.

Exit criteria:
- Sync returns to the correct active line from any valid playback position.
- Replay from the end starts lyrics from the beginning immediately.
- No stuck lyric lines.

## Phase 3 - Finalize Floating Lyrics Bubble

Goal: The FLB should feel like a reliable Musixmatch-style companion, not an experimental overlay.

Tasks:
- Confirm the bigger FLB button size is comfortable and not intrusive.
- Use the new FLB icon consistently.
- Confirm the bubble snaps flush to the left or right edge.
- Confirm the expanded panel switches side when dragged across the screen.
- Confirm the panel remains draggable while music is playing.
- Confirm tapping the button opens and closes the panel.
- Confirm tapping inside the app closes the expanded panel first before the page responds.
- Confirm the expander opens the lyrics page and collapses the FLB back to icon.
- Confirm the drag-to-close target is visible, subtle, and does not push the bubble out of frame.

Exit criteria:
- FLB drag, open, close, expand, side-switch, and dismiss behavior are predictable on the phone.
- FLB keeps updating lyrics when the app is minimized.
- FLB controls affect JW Songs only, not Spotify or another media app.

## Phase 4 - Downloads And Offline Use

Goal: The app must work well even with poor internet.

Tasks:
- Make Download all show stable progress based on the full download session, not a recount after leaving and returning.
- Keep individual download controls simple and avoid per-song pause.
- Add pause/resume only for Download all.
- Confirm downloaded/deleted song states update immediately in the song list.
- Confirm deleting one song and deleting all songs work from Settings.
- Confirm downloaded songs play in airplane mode.
- Confirm failed downloads show clear retry behavior.

Exit criteria:
- Offline playback works for downloaded songs.
- Download progress is understandable and does not reset confusingly.
- Delete/download state refreshes without restarting the app.

## Phase 5 - Content And Future Lyrics Readiness

Goal: The app must support more songs and future synced lyrics without fragile code changes.

Tasks:
- Keep song loading driven by manifests, not hardcoded song counts.
- Keep title cleanup rules consistent, including removing unnecessary quote marks.
- Preserve placeholders for songs without synced lyrics.
- Document the folder and process used by the lyric sync tool.
- Ensure adding future lyrics does not require changing playback UI code.

Exit criteria:
- New songs and new `.elrc` lyrics can be added through the content pipeline.
- Songs without synced lyrics still play cleanly.

## Phase 6 - Performance And App Size

Goal: The app should feel light and run well on different Android phones.

Tasks:
- Keep audio files downloadable instead of bundling all full audio in the APK.
- Build and test a release APK/AAB, not only debug APKs.
- Measure installed app size after fresh install.
- Measure memory usage during playback and FLB use.
- Check startup time.
- Check battery behavior during 30 minutes of playback.

Exit criteria:
- Installed app size is acceptable for the chosen distribution model.
- No major memory growth during normal use.
- Startup and playback start times feel fast on mid-range Android phones.

## Phase 7 - Cross-Device QA

Goal: The app should work beyond one Samsung phone.

Tasks:
- Test on at least three Android versions if possible.
- Test one low or mid-range phone.
- Test one newer Android phone.
- Test with wired headphones, Bluetooth, and speaker output.
- Test screen rotation and different display sizes.
- Test notification controls on each device.
- Test overlay permission flow on each device.

Exit criteria:
- No device-specific blocker remains.
- Any known device limitation is documented.

## Phase 8 - Release Packaging

Goal: Build the version that can actually be shared or submitted.

Tasks:
- Set final app name, icon, splash screen, version, and package metadata.
- Remove debug-only behavior.
- Confirm Android permissions are only what the app needs.
- Create signed release build.
- Run `flutter analyze`.
- Run automated tests.
- Install the release build on a real phone and smoke test.

Exit criteria:
- Signed release APK/AAB builds successfully.
- Release install works on a real device.
- No debug labels, broken icons, or unfinished launch assets remain.

## Phase 9 - Private Beta

Goal: Find real-world issues before public launch.

Tasks:
- Share the app with a small trusted group.
- Ask testers to try playback, downloads, lyrics sync, notification controls, and FLB.
- Collect device model, Android version, and reproduction steps for every issue.
- Fix P0/P1 bugs before adding new features.
- Re-test fixed issues on the same device where possible.

Exit criteria:
- No known crash.
- No known playback blocker.
- No known download blocker.
- FLB is stable enough for daily use.

## Phase 10 - Public Launch

Goal: Release only after the core worship experience is stable.

Tasks:
- Prepare store listing or distribution page.
- Prepare screenshots.
- Write a short description that explains the app without overpromising.
- Confirm content, naming, and permissions are appropriate.
- Upload the signed build.
- Monitor early feedback closely.

Exit criteria:
- Launch build is signed, tested, and documented.
- Support process is ready for bug reports.

## Phase 11 - Post-Launch Improvements

Goal: Improve the app without destabilizing the core experience.

Backlog candidates:
- Phone music player mode for local songs.
- More synced lyrics.
- Better lyrics authoring and sync workflow.
- Improved download server reliability.
- Optional audio enhancement/equalizer if it can be implemented without damaging sound quality.
- Congregation mode redesign if there is a clear use case and stable sync behavior.
- Future AI and congregation tools only after the music experience is dependable.

Exit criteria:
- New features are added only after the current release remains stable.
- Core playback, sync, downloads, and FLB behavior remain protected by regression tests.

