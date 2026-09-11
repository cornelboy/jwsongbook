import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:jwsongbook/core/theme/app_theme.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/app_settings.dart';
import 'package:jwsongbook/data/models/synced_lyrics_model.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/features/player/providers/lyrics_sync_provider.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/features/player/screens/player_screen.dart';
import 'package:jwsongbook/features/settings/screens/settings_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockSongsRepository extends Mock implements SongsRepository {}

class _PlayingPlayerNotifier extends PlayerNotifier {
  _PlayingPlayerNotifier(this.song);

  final Song song;

  @override
  PlayerState build() => PlayerState(
        currentSong: song,
        isPlaying: true,
        duration: const Duration(minutes: 3),
        processingState: ProcessingState.ready,
      );

  @override
  Future<void> playSong(Song song, {bool keepQueue = false}) async {}

  void setPlaying(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
  }
}

class _TestSettingsNotifier extends AppSettingsNotifier {
  _TestSettingsNotifier({this.initialSettings = const AppSettings()});

  final AppSettings initialSettings;
  int discoveryImpressions = 0;
  int discoveryCompletions = 0;
  bool _presentedThisSession = false;

  @override
  AppSettings build() => initialSettings;

  @override
  bool get canPresentFloatingLyricsDiscovery =>
      !_presentedThisSession && state.canShowFloatingLyricsDiscovery;

  @override
  void recordFloatingLyricsDiscoveryImpression() {
    if (!canPresentFloatingLyricsDiscovery) return;
    discoveryImpressions += 1;
    _presentedThisSession = true;
    state = state.copyWith(
      floatingLyricsDiscoveryImpressions:
          state.floatingLyricsDiscoveryImpressions + 1,
    );
  }

  @override
  void completeFloatingLyricsDiscovery() {
    discoveryCompletions += 1;
    _presentedThisSession = true;
    state = state.copyWith(floatingLyricsDiscoveryCompleted: true);
  }
}

void main() {
  testWidgets(
    'first playback delays and auto-dismisses Floating Lyrics discovery',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const song = Song(
        id: 1,
        number: 1,
        title: "Jehovah's Attributes",
        isDownloaded: false,
        isFavorited: false,
        hasSyncedLyrics: true,
      );
      final songsRepository = _MockSongsRepository();
      final playerNotifier = _PlayingPlayerNotifier(song);
      final settingsNotifier = _TestSettingsNotifier();

      when(() => songsRepository.watchByNumber(1))
          .thenAnswer((_) => Stream.value(song));
      when(() => songsRepository.getByNumber(1)).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsRepositoryProvider.overrideWithValue(songsRepository),
            playerNotifierProvider.overrideWith(() => playerNotifier),
            appSettingsNotifierProvider.overrideWith(() => settingsNotifier),
            currentSongLyricsProvider.overrideWith(
              (ref) async => const SyncedLyrics(lines: []),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const PlayerScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(settingsNotifier.discoveryImpressions, 0);
      expect(find.text('Floating lyrics'), findsNothing);

      await tester.pump(const Duration(seconds: 9));
      expect(settingsNotifier.discoveryImpressions, 0);
      expect(find.text('Floating lyrics'), findsNothing);

      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(settingsNotifier.discoveryImpressions, 1);
      expect(settingsNotifier.state.floatingLyricsDiscoveryCompleted, isFalse);
      expect(find.text('Floating lyrics'), findsOneWidget);
      expect(find.byTooltip('Not now'), findsOneWidget);
      expect(find.text('Set up'), findsOneWidget);

      await tester.pump(const Duration(seconds: 15));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Floating lyrics'), findsNothing);

      await tester.pump(const Duration(seconds: 20));
      expect(settingsNotifier.discoveryImpressions, 1);
      expect(find.text('Floating lyrics'), findsNothing);
    },
  );

  testWidgets(
    'pausing resets the Floating Lyrics discovery delay',
    (tester) async {
      const song = Song(
        id: 1,
        number: 1,
        title: "Jehovah's Attributes",
        isDownloaded: true,
        isFavorited: false,
        hasSyncedLyrics: true,
      );
      final songsRepository = _MockSongsRepository();
      final playerNotifier = _PlayingPlayerNotifier(song);
      final settingsNotifier = _TestSettingsNotifier();

      when(() => songsRepository.watchByNumber(1))
          .thenAnswer((_) => Stream.value(song));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsRepositoryProvider.overrideWithValue(songsRepository),
            playerNotifierProvider.overrideWith(() => playerNotifier),
            appSettingsNotifierProvider.overrideWith(() => settingsNotifier),
            currentSongLyricsProvider.overrideWith(
              (ref) async => const SyncedLyrics(lines: []),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const PlayerScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      playerNotifier.setPlaying(false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(settingsNotifier.discoveryImpressions, 0);
      expect(find.text('Floating lyrics'), findsNothing);

      playerNotifier.setPlaying(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(settingsNotifier.discoveryImpressions, 1);
      expect(find.text('Floating lyrics'), findsOneWidget);
    },
  );

  testWidgets(
    'Not now permanently completes Floating Lyrics discovery',
    (tester) async {
      const song = Song(
        id: 1,
        number: 1,
        title: "Jehovah's Attributes",
        isDownloaded: true,
        isFavorited: false,
        hasSyncedLyrics: true,
      );
      final songsRepository = _MockSongsRepository();
      final playerNotifier = _PlayingPlayerNotifier(song);
      final settingsNotifier = _TestSettingsNotifier();

      when(() => songsRepository.watchByNumber(1))
          .thenAnswer((_) => Stream.value(song));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsRepositoryProvider.overrideWithValue(songsRepository),
            playerNotifierProvider.overrideWith(() => playerNotifier),
            appSettingsNotifierProvider.overrideWith(() => settingsNotifier),
            currentSongLyricsProvider.overrideWith(
              (ref) async => const SyncedLyrics(lines: []),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const PlayerScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 250));

      final closeButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.close_rounded),
      );
      closeButton.onPressed!();
      await tester.pump();

      expect(settingsNotifier.discoveryCompletions, 1);
      expect(settingsNotifier.state.floatingLyricsDiscoveryCompleted, isTrue);
      expect(
        find.text('You can enable Floating Lyrics anytime in Settings.'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(find.text('Floating lyrics'), findsNothing);
    },
  );

  testWidgets(
    'second-session impression reaches the discovery cap',
    (tester) async {
      const song = Song(
        id: 1,
        number: 1,
        title: "Jehovah's Attributes",
        isDownloaded: true,
        isFavorited: false,
        hasSyncedLyrics: true,
      );
      final songsRepository = _MockSongsRepository();
      final playerNotifier = _PlayingPlayerNotifier(song);
      final settingsNotifier = _TestSettingsNotifier(
        initialSettings: const AppSettings(
          floatingLyricsDiscoveryImpressions: 1,
        ),
      );

      when(() => songsRepository.watchByNumber(1))
          .thenAnswer((_) => Stream.value(song));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            songsRepositoryProvider.overrideWithValue(songsRepository),
            playerNotifierProvider.overrideWith(() => playerNotifier),
            appSettingsNotifierProvider.overrideWith(() => settingsNotifier),
            currentSongLyricsProvider.overrideWith(
              (ref) async => const SyncedLyrics(lines: []),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const PlayerScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));

      expect(settingsNotifier.discoveryImpressions, 1);
      expect(settingsNotifier.state.floatingLyricsDiscoveryImpressions, 2);
      expect(
        settingsNotifier.state.canShowFloatingLyricsDiscovery,
        isFalse,
      );
      expect(find.text('Floating lyrics'), findsOneWidget);
    },
  );
}
