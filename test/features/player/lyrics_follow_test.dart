import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:jwsongbook/core/theme/app_theme.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/app_settings.dart';
import 'package:jwsongbook/data/models/synced_lyrics_model.dart';
import 'package:jwsongbook/features/player/providers/lyrics_sync_provider.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/features/player/widgets/lyrics_view.dart';
import 'package:jwsongbook/features/settings/screens/settings_screen.dart';

const _song = Song(
  id: 3,
  number: 3,
  title: 'Test song',
  isDownloaded: true,
  isFavorited: false,
  hasSyncedLyrics: true,
);

class _Player extends PlayerNotifier {
  _Player({this.initialState});

  final PlayerState? initialState;

  @override
  PlayerState build() =>
      initialState ??
      const PlayerState(
        currentSong: _song,
        isPlaying: true,
        position: Duration(seconds: 100),
        duration: Duration(seconds: 800),
      );
  void position(int milliseconds) =>
      state = state.copyWith(position: Duration(milliseconds: milliseconds));
  void playing(bool value) => state = state.copyWith(isPlaying: value);
  @override
  Future<void> seekMs(int ms) async => state = state.copyWith(
        position: Duration(milliseconds: ms),
        seekRevision: state.seekRevision + 1,
      );
}

class _Settings extends AppSettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
  void autoScroll(bool enabled) =>
      state = state.copyWith(autoScrollEnabled: enabled);
}

final _lyrics = SyncedLyrics.fromLines(
  List.generate(
    40,
    (i) => SyncedLine(
      index: i,
      sectionIndex: 0,
      startMs: i * 20000,
      endMs: (i + 1) * 20000,
      text: 'Lyric line $i',
      words: const [],
    ),
  ),
);

Future<
    ({
      _Player player,
      _Settings settings,
      ProviderContainer container,
      ScrollController scroll
    })> _mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final player = _Player();
  final settings = _Settings();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerNotifierProvider.overrideWith(() => player),
        appSettingsNotifierProvider.overrideWith(() => settings),
        currentSongLyricsProvider.overrideWith((ref) async => _lyrics),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: LyricsView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 100));
  final container =
      ProviderScope.containerOf(tester.element(find.byType(LyricsView)));
  final scroll = tester
      .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
      .controller!;
  return (
    player: player,
    settings: settings,
    container: container,
    scroll: scroll
  );
}

Future<void> _drag(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(SingleChildScrollView), Offset(0, dy));
  await tester.pumpAndSettle();
}

void main() {
  Future<void> verifyStableReentry(
    WidgetTester tester,
    PlayerState initialState,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final player = _Player(initialState: initialState);
    final settings = _Settings();
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerNotifierProvider.overrideWith(() => player),
          appSettingsNotifierProvider.overrideWith(() => settings),
          currentSongLyricsProvider.overrideWith((ref) async => _lyrics),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, show, __) => Scaffold(
              body: show ? const LyricsView() : const Text('Away'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    visible.value = false;
    await tester.pumpAndSettle();
    visible.value = true;
    await tester.pumpAndSettle();

    final opacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 1);
    final scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    final positionedOffset = scroll.offset;
    expect(positionedOffset, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(scroll.offset, closeTo(positionedOffset, .1));
  }

  testWidgets('reopening paused lyrics positions instantly and stays still',
      (tester) async {
    await verifyStableReentry(
      tester,
      const PlayerState(
        currentSong: _song,
        position: Duration(seconds: 100),
        duration: Duration(seconds: 800),
      ),
    );
  });

  testWidgets('reopening completed lyrics positions instantly at the end',
      (tester) async {
    await verifyStableReentry(
      tester,
      const PlayerState(
        currentSong: _song,
        position: Duration(seconds: 800),
        duration: Duration(seconds: 800),
        processingState: ProcessingState.completed,
      ),
    );
  });

  testWidgets('reopening playing lyrics does not animate from the top',
      (tester) async {
    await verifyStableReentry(
      tester,
      const PlayerState(
        currentSong: _song,
        isPlaying: true,
        position: Duration(seconds: 100),
        duration: Duration(seconds: 800),
        processingState: ProcessingState.ready,
      ),
    );
  });

  testWidgets('visible lyrics resume after five seconds with a slow catch-up',
      (tester) async {
    final app = await _mount(tester);
    final original = app.scroll.offset;
    await _drag(tester, 80);
    final dragged = app.scroll.offset;
    expect(dragged, lessThan(original));
    expect(app.container.read(lyricsFollowPausedProvider), isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(app.scroll.offset, closeTo(dragged, .1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(app.scroll.offset, greaterThan(dragged));
    expect(app.scroll.offset, lessThan(original - 1));
    await tester.pumpAndSettle();
    expect(app.scroll.offset, closeTo(original, 1));
  });

  testWidgets('off-screen lyrics stay manual until Follow is requested',
      (tester) async {
    final app = await _mount(tester);
    await _drag(tester, -450);
    final dragged = app.scroll.offset;
    expect(app.container.read(lyricsFollowPausedProvider), isTrue);
    await tester.pump(const Duration(seconds: 8));
    expect(app.scroll.offset, closeTo(dragged, .1));
    app.container.read(lyricsFollowRequestProvider.notifier).state++;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(app.scroll.offset, lessThan(dragged));
    expect(app.container.read(lyricsFollowPausedProvider), isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('another drag restarts the five-second wait', (tester) async {
    final app = await _mount(tester);
    await _drag(tester, 60);
    await tester.pump(const Duration(seconds: 3));
    await _drag(tester, 30);
    final dragged = app.scroll.offset;
    await tester.pump(const Duration(seconds: 3));
    expect(app.scroll.offset, closeTo(dragged, .1));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(app.scroll.offset, greaterThan(dragged));
  });

  testWidgets('pausing cancels the countdown and playing starts a fresh wait',
      (tester) async {
    final app = await _mount(tester);
    await _drag(tester, 80);
    await tester.pump(const Duration(seconds: 3));
    app.player.playing(false);
    await tester.pump();
    final paused = app.scroll.offset;
    await tester.pump(const Duration(seconds: 8));
    expect(app.scroll.offset, closeTo(paused, .1));
    app.player.playing(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(app.scroll.offset, closeTo(paused, .1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(app.scroll.offset, greaterThan(paused));
  });

  testWidgets('the existing edge return is smooth and not interrupted by ticks',
      (tester) async {
    final app = await _mount(tester);
    // Put the current line near the bottom while retaining its visibility.
    await _drag(tester, 260);
    expect(app.container.read(lyricsFollowPausedProvider), isFalse);
    final dragged = app.scroll.offset;
    app.player.position(239100);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final early = app.scroll.offset;
    app.player.position(239300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final middle = app.scroll.offset;
    expect(early, greaterThan(dragged));
    expect(middle, greaterThan(early));
    await tester.pumpAndSettle();
    expect(app.scroll.offset, greaterThan(middle + 1));
  });

  testWidgets(
      'dragging interrupts a return and disabling auto-scroll cancels the wait',
      (tester) async {
    final app = await _mount(tester);
    await _drag(tester, 80);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 150));
    await _drag(tester, -450);
    final dragged = app.scroll.offset;
    expect(app.container.read(lyricsFollowPausedProvider), isTrue);
    await tester.pump(const Duration(seconds: 6));
    expect(app.scroll.offset, closeTo(dragged, .1));
    app.container.read(lyricsFollowRequestProvider.notifier).state++;
    await tester.pumpAndSettle();
    await _drag(tester, 60);
    app.settings.autoScroll(false);
    await tester.pump();
    final disabled = app.scroll.offset;
    await tester.pump(const Duration(seconds: 6));
    expect(app.scroll.offset, closeTo(disabled, .1));
  });

  testWidgets('tap-to-seek keeps working and cancels a pending wait',
      (tester) async {
    final app = await _mount(tester);
    await _drag(tester, 60);
    await tester.tap(find.text('Lyric line 6'));
    await tester.pumpAndSettle();
    expect(app.player.state.positionMs, 120000);
    expect(app.container.read(lyricsFollowPausedProvider), isFalse);
    final offset = app.scroll.offset;
    await tester.pump(const Duration(seconds: 6));
    expect(app.scroll.offset, closeTo(offset, .1));
  });
}
