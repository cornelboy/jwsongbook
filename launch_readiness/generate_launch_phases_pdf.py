from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
)


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "jw_songs_launch_readiness_phases.pdf"


PHASES = [
    (
        "Phase 1 - Stabilize Core Playback",
        "Songs must play reliably in the app, in the background, and from system controls.",
        [
            "Confirm play, pause, previous, next, seek forward, and seek backward work without delay.",
            "Confirm finished songs show the correct stopped/paused state in the notification panel.",
            "Confirm notification controls show play/pause plus previous/next.",
            "Confirm closing the app from the recent apps screen stops playback.",
            "Confirm normal Android back navigation does not wrongly kill playback.",
            "Run a 30-minute continuous playback test with no crash.",
        ],
        [
            "No crash during playback, seek, song end, notification control use, or app backgrounding.",
            "Notification state always matches the real audio state.",
        ],
    ),
    (
        "Phase 2 - Lock Lyrics Sync Behavior",
        "Lyrics must stay aligned after normal user actions.",
        [
            "Verify sync after seeking forward.",
            "Verify sync after seeking backward.",
            "Verify sync after replaying a finished song.",
            "Verify sync after manually scrolling and pressing the sync button.",
            "Keep the sync button near the mini player where users naturally look for playback correction.",
            "Keep auto-scroll behavior simple: manual scrolling can temporarily move the user away, and the sync button should return them to the active lyric position.",
            "Keep congregation mode disabled for now and preserve a note explaining why.",
        ],
        [
            "Sync returns to the correct active line from any valid playback position.",
            "Replay from the end starts lyrics from the beginning immediately.",
            "No stuck lyric lines.",
        ],
    ),
    (
        "Phase 3 - Finalize Floating Lyrics Bubble",
        "The FLB should feel like a reliable Musixmatch-style companion, not an experimental overlay.",
        [
            "Confirm the bigger FLB button size is comfortable and not intrusive.",
            "Use the new FLB icon consistently.",
            "Confirm the bubble snaps flush to the left or right edge.",
            "Confirm the expanded panel switches side when dragged across the screen.",
            "Confirm the panel remains draggable while music is playing.",
            "Confirm tapping the button opens and closes the panel.",
            "Confirm tapping inside the app closes the expanded panel first before the page responds.",
            "Confirm the expander opens the lyrics page and collapses the FLB back to icon.",
            "Confirm the drag-to-close target is visible, subtle, and does not push the bubble out of frame.",
        ],
        [
            "FLB drag, open, close, expand, side-switch, and dismiss behavior are predictable on the phone.",
            "FLB keeps updating lyrics when the app is minimized.",
            "FLB controls affect JW Songs only, not Spotify or another media app.",
        ],
    ),
    (
        "Phase 4 - Downloads And Offline Use",
        "The app must work well even with poor internet.",
        [
            "Make Download all show stable progress based on the full download session, not a recount after leaving and returning.",
            "Keep individual download controls simple and avoid per-song pause.",
            "Add pause/resume only for Download all.",
            "Confirm downloaded/deleted song states update immediately in the song list.",
            "Confirm deleting one song and deleting all songs work from Settings.",
            "Confirm downloaded songs play in airplane mode.",
            "Confirm failed downloads show clear retry behavior.",
        ],
        [
            "Offline playback works for downloaded songs.",
            "Download progress is understandable and does not reset confusingly.",
            "Delete/download state refreshes without restarting the app.",
        ],
    ),
    (
        "Phase 5 - Content And Future Lyrics Readiness",
        "The app must support more songs and future synced lyrics without fragile code changes.",
        [
            "Keep song loading driven by manifests, not hardcoded song counts.",
            "Keep title cleanup rules consistent, including removing unnecessary quote marks.",
            "Preserve placeholders for songs without synced lyrics.",
            "Document the folder and process used by the lyric sync tool.",
            "Ensure adding future lyrics does not require changing playback UI code.",
        ],
        [
            "New songs and new .elrc lyrics can be added through the content pipeline.",
            "Songs without synced lyrics still play cleanly.",
        ],
    ),
    (
        "Phase 6 - Performance And App Size",
        "The app should feel light and run well on different Android phones.",
        [
            "Keep audio files downloadable instead of bundling all full audio in the APK.",
            "Build and test a release APK/AAB, not only debug APKs.",
            "Measure installed app size after fresh install.",
            "Measure memory usage during playback and FLB use.",
            "Check startup time.",
            "Check battery behavior during 30 minutes of playback.",
        ],
        [
            "Installed app size is acceptable for the chosen distribution model.",
            "No major memory growth during normal use.",
            "Startup and playback start times feel fast on mid-range Android phones.",
        ],
    ),
    (
        "Phase 7 - Cross-Device QA",
        "The app should work beyond one Samsung phone.",
        [
            "Test on at least three Android versions if possible.",
            "Test one low or mid-range phone.",
            "Test one newer Android phone.",
            "Test with wired headphones, Bluetooth, and speaker output.",
            "Test screen rotation and different display sizes.",
            "Test notification controls on each device.",
            "Test overlay permission flow on each device.",
        ],
        [
            "No device-specific blocker remains.",
            "Any known device limitation is documented.",
        ],
    ),
    (
        "Phase 8 - Release Packaging",
        "Build the version that can actually be shared or submitted.",
        [
            "Set final app name, icon, splash screen, version, and package metadata.",
            "Remove debug-only behavior.",
            "Confirm Android permissions are only what the app needs.",
            "Create signed release build.",
            "Run flutter analyze.",
            "Run automated tests.",
            "Install the release build on a real phone and smoke test.",
        ],
        [
            "Signed release APK/AAB builds successfully.",
            "Release install works on a real device.",
            "No debug labels, broken icons, or unfinished launch assets remain.",
        ],
    ),
    (
        "Phase 9 - Private Beta",
        "Find real-world issues before public launch.",
        [
            "Share the app with a small trusted group.",
            "Ask testers to try playback, downloads, lyrics sync, notification controls, and FLB.",
            "Collect device model, Android version, and reproduction steps for every issue.",
            "Fix P0/P1 bugs before adding new features.",
            "Re-test fixed issues on the same device where possible.",
        ],
        [
            "No known crash.",
            "No known playback blocker.",
            "No known download blocker.",
            "FLB is stable enough for daily use.",
        ],
    ),
    (
        "Phase 10 - Public Launch",
        "Release only after the core worship experience is stable.",
        [
            "Prepare store listing or distribution page.",
            "Prepare screenshots.",
            "Write a short description that explains the app without overpromising.",
            "Confirm content, naming, and permissions are appropriate.",
            "Upload the signed build.",
            "Monitor early feedback closely.",
        ],
        [
            "Launch build is signed, tested, and documented.",
            "Support process is ready for bug reports.",
        ],
    ),
    (
        "Phase 11 - Post-Launch Improvements",
        "Improve the app without destabilizing the core experience.",
        [
            "Phone music player mode for local songs.",
            "More synced lyrics.",
            "Better lyrics authoring and sync workflow.",
            "Improved download server reliability.",
            "Optional audio enhancement/equalizer if it can be implemented without damaging sound quality.",
            "Congregation mode redesign if there is a clear use case and stable sync behavior.",
            "Future AI and congregation tools only after the music experience is dependable.",
        ],
        [
            "New features are added only after the current release remains stable.",
            "Core playback, sync, downloads, and FLB behavior remain protected by regression tests.",
        ],
    ),
]


def bullet_list(items, styles):
    return ListFlowable(
        [
            ListItem(
                Paragraph(item, styles["BulletText"]),
                leftIndent=0,
                bulletColor=colors.HexColor("#BB86FC"),
            )
            for item in items
        ],
        bulletType="bullet",
        start="circle",
        leftIndent=13,
        bulletIndent=2,
    )


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#3A3344"))
    canvas.setLineWidth(0.5)
    canvas.line(18 * mm, 15 * mm, 192 * mm, 15 * mm)
    canvas.setFillColor(colors.HexColor("#6F6678"))
    canvas.setFont("Helvetica", 8)
    canvas.drawString(18 * mm, 10 * mm, "JW Songs Launch Readiness")
    canvas.drawRightString(192 * mm, 10 * mm, f"Page {doc.page}")
    canvas.restoreState()


def build():
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="TitleMain",
            parent=styles["Title"],
            fontName="Helvetica-Bold",
            fontSize=24,
            leading=30,
            textColor=colors.HexColor("#F2EDF7"),
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Subtitle",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=10.5,
            leading=15,
            textColor=colors.HexColor("#C8C0D0"),
            spaceAfter=14,
        )
    )
    styles.add(
        ParagraphStyle(
            name="PhaseHeading",
            parent=styles["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=14,
            leading=18,
            textColor=colors.HexColor("#BB86FC"),
            spaceBefore=10,
            spaceAfter=4,
        )
    )
    styles.add(
        ParagraphStyle(
            name="SectionLabel",
            parent=styles["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=9,
            leading=12,
            textColor=colors.HexColor("#F2EDF7"),
            spaceBefore=6,
            spaceAfter=2,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BodyClean",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=9.5,
            leading=13.5,
            textColor=colors.HexColor("#DAD4E2"),
            spaceAfter=4,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BulletText",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=8.8,
            leading=12,
            textColor=colors.HexColor("#DAD4E2"),
            spaceAfter=2,
        )
    )

    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=20 * mm,
        title="JW Songs Launch Readiness Phases",
        author="Codex",
    )

    story = [
        Paragraph("JW Songs Launch Readiness Phases", styles["TitleMain"]),
        Paragraph("Date: August 26, 2026<br/>Status: Alpha / internal testing", styles["Subtitle"]),
        Paragraph(
            "This roadmap breaks the launch work into clear phases so each one can be completed and verified before moving to the next. The app should not be treated as launch-ready until every phase has passed.",
            styles["BodyClean"],
        ),
        Spacer(1, 6),
    ]

    for index, (title, goal, tasks, exit_criteria) in enumerate(PHASES, start=1):
        if index in {5, 9}:
            story.append(PageBreak())
        story.append(Paragraph(title, styles["PhaseHeading"]))
        story.append(Paragraph(f"<b>Goal:</b> {goal}", styles["BodyClean"]))
        story.append(Paragraph("Tasks", styles["SectionLabel"]))
        story.append(bullet_list(tasks, styles))
        story.append(Paragraph("Exit Criteria", styles["SectionLabel"]))
        story.append(bullet_list(exit_criteria, styles))
        story.append(Spacer(1, 5))

    doc.build(story, onFirstPage=footer, onLaterPages=footer)


if __name__ == "__main__":
    build()

