import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jwsongbook/core/theme/app_theme.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/repositories/lyrics_repository.dart';
import 'package:jwsongbook/data/repositories/playlists_repository.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/data/services/song_download_service.dart';
import 'package:jwsongbook/features/library/screens/library_screen.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/features/playlists/screens/playlist_detail_screen.dart';
import 'package:jwsongbook/features/playlists/screens/playlists_screen.dart';
import 'package:jwsongbook/shared/widgets/offline_download_icon.dart';
import 'package:jwsongbook/shared/widgets/scaffold_with_bottom_nav.dart';

const captureKey = ValueKey('playlist-ui-capture');
Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_PLAYLIST_UI')) return;
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory =
        await Directory('tmp/playlist-qa').create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _Player extends PlayerNotifier {
  List<int>? played;
  int playPauseToggles = 0;

  @override
  PlayerState build() => const PlayerState();

  @override
  Future<void> togglePlayPause() async {
    playPauseToggles += 1;
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  @override
  Future<void> playPlaylist(List<Song> songs, {int startIndex = 0}) async {
    played = songs.map((s) => s.number).toList();
    state = state.copyWith(
      currentSong: songs[startIndex],
      isPlaying: true,
    );
  }
}

class _RecordingPlaylists extends PlaylistsRepository {
  _RecordingPlaylists(super.db);
  final orders = <List<int>>[];
  @override
  Future<void> reorder(int id, List<int> songIds) {
    orders.add(List.of(songIds));
    return super.reorder(id, songIds);
  }
}

class _TestDownloadService extends SongDownloadService {
  _TestDownloadService(this.db)
      : super(
          songsRepository: SongsRepository(db.songsDao),
          lyricsRepository: LyricsRepository(db.lyricsDao, db),
        );

  final AppDatabase db;

  @override
  Future<void> removeDownload(Song song) =>
      db.songsDao.markDownloadRemoved(song.id);
}

Future<void> flush(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pumpAndSettle();
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    const fontsPath = String.fromEnvironment('PLAYLIST_QA_FONTS');
    if (fontsPath.isEmpty) return;
    for (final font in [
      ('Roboto', 'roboto-regular.ttf'),
      ('MaterialIcons', 'materialicons-regular.otf'),
    ]) {
      final loader = FontLoader(font.$1)
        ..addFont(
          File('$fontsPath/${font.$2}')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  late AppDatabase db;
  late _RecordingPlaylists repo;
  late _Player player;
  late GoRouter router;

  Future<void> mount(
    WidgetTester tester, {
    String location = '/library',
    double width = 390,
    bool shell = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _RecordingPlaylists(db);
    player = _Player();
    await tester.runAsync(() async {
      for (var i = 1; i <= 3; i++) {
        await db.songsDao.upsert(
          SongsCompanion.insert(
            number: i,
            title: 'Song $i',
            isDownloaded: const Value(true),
            audioFilePath: Value('$i.mp3'),
          ),
        );
      }
    });
    router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              shell ? ScaffoldWithBottomNav(child: child) : child,
          routes: [
            GoRoute(
              path: '/library',
              builder: (_, __) => const LibraryScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, __) => Scaffold(
                appBar: AppBar(title: const Text('Settings page')),
              ),
            ),
            GoRoute(
              path: '/now-playing',
              builder: (_, __) => const Scaffold(body: Text('Player')),
            ),
            GoRoute(
              path: '/playlists',
              builder: (_, __) => const PlaylistsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => PlaylistDetailScreen(
                    playlistId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          playlistsRepositoryProvider.overrideWithValue(repo),
          songDownloadServiceProvider.overrideWithValue(
            _TestDownloadService(db),
          ),
          playerNotifierProvider.overrideWith(() => player),
        ],
        child: MaterialApp.router(
          theme: const bool.fromEnvironment('CAPTURE_PLAYLIST_UI')
              ? AppTheme.dark.copyWith(
                  textTheme:
                      AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
                  primaryTextTheme: AppTheme.dark.primaryTextTheme
                      .apply(fontFamily: 'Roboto'),
                )
              : AppTheme.dark,
          routerConfig: router,
          builder: (_, child) =>
              RepaintBoundary(key: captureKey, child: child!),
        ),
      ),
    );
    await flush(tester);
  }

  tearDown(() async {
    router.dispose();
    await db.close();
  });

  testWidgets(
      'song menu favorites, cancelled removal and create/add playlist at 320px',
      (tester) async {
    await mount(tester, width: 320);
    final downloadedMark = tester.widget<OfflineStatusIcon>(
      find
          .byWidgetPredicate(
            (widget) => widget is OfflineStatusIcon && widget.isDownloaded,
          )
          .first,
    );
    expect(downloadedMark.size, 22);
    expect(downloadedMark.color, isNull);
    await tester.tap(find.byTooltip('Options for song 001'));
    await tester.pumpAndSettle();
    expect(find.text('Add to favorites'), findsOneWidget);
    expect(find.text('Add to playlist'), findsOneWidget);
    await capture(tester, 'song-menu-320');
    await tester.tap(find.text('Add to favorites'));
    await flush(tester);
    expect(
      await tester.runAsync(() => db.songsDao.getByNumber(1)),
      isA<Song>().having((s) => s.isFavorited, 'favorite', true),
    );
    await tester.tap(find.byTooltip('Options for song 001'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from favorites'), findsOneWidget);
    await tester.tap(find.text('Remove download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => db.songsDao.getByNumber(1)))?.isDownloaded,
      true,
    );
    await tester.tap(find.byTooltip('Options for song 001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    expect(find.text('Song 001 removed.'), findsOneWidget);
    expect(
      (await tester.runAsync(() => db.songsDao.getByNumber(1)))?.isDownloaded,
      false,
    );
    await flush(tester);
    expect(find.byType(OfflineStatusIcon), findsWidgets);
    final downloadMark = tester.widget<OfflineStatusIcon>(
      find
          .byWidgetPredicate(
            (widget) => widget is OfflineStatusIcon && !widget.isDownloaded,
          )
          .first,
    );
    expect(downloadMark.size, downloadedMark.size);
    expect(downloadMark.color, downloadedMark.color);
    await tester.tap(find.byTooltip('Options for song 001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to playlist'));
    await flush(tester);
    await tester.tap(find.text('New playlist'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create playlist'),
          )
          .onPressed,
      isNull,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('e.g. Meeting songs'), findsOneWidget);
    await capture(tester, 'playlist-create-sheet');
    await tester.enterText(find.byType(TextField).last, 'Practice');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create playlist'),
    );
    await flush(tester);
    final items = await tester.runAsync(() => repo.watchAll().first);
    expect(items!.single.name, 'Practice');
    expect(
      (await tester.runAsync(() => repo.getSongs(items.single.id)))!
          .single
          .number,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('playlist create, add songs, reorder, play, rename and delete',
      (tester) async {
    await mount(tester, location: '/playlists');
    await tester.tap(find.widgetWithText(FilledButton, 'New playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Evening');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create playlist'),
    );
    await flush(tester);
    expect(find.text('Evening'), findsOneWidget);
    await tester.tap(find.byTooltip('Add songs'));
    await flush(tester);
    await tester.tap(find.text('Song 3'));
    await flush(tester);
    await tester.tap(find.text('Song 1'));
    await flush(tester);
    await tester.tap(find.byTooltip('Back'));
    await flush(tester);
    final id = (await tester.runAsync(() => repo.watchAll().first))!.single.id;
    expect(
      (await tester.runAsync(() => repo.getSongs(id)))!.map((s) => s.number),
      [3, 1],
    );
    expect(find.text('Offline'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('playlist-play-button'))),
      const Size.square(56),
    );
    router.go('/playlists');
    await flush(tester);
    expect(find.byTooltip('Options for Evening'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Evening playlist cover')),
      findsOneWidget,
    );
    await capture(tester, 'playlists-list');
    await tester.tap(find.byTooltip('Options for Evening'));
    await tester.pumpAndSettle();
    expect(find.text('Rename playlist'), findsOneWidget);
    expect(find.text('Delete playlist'), findsOneWidget);
    await tester.tap(find.text('Rename playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await flush(tester);
    await tester.tap(find.text('Evening'));
    await flush(tester);
    expect(find.byTooltip('Drag to reorder'), findsNothing);
    await tester.tap(find.byTooltip('Edit song order'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(find.byTooltip('Options for song 003'), findsNothing);
    expect(find.byTooltip('Drag to reorder'), findsNWidgets(2));
    await capture(tester, 'playlist-before-drag');
    final drag = await tester.startGesture(
      tester.getCenter(find.byTooltip('Drag to reorder').first),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await drag.moveBy(const Offset(0, 20));
    await tester.pump();
    for (var step = 0; step < 12; step++) {
      await drag.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    await capture(tester, 'playlist-during-drag');
    await drag.up();
    await flush(tester);
    expect(
      repo.orders,
      isNotEmpty,
      reason: 'Handle gesture must request a reorder',
    );
    expect(
      (await tester.runAsync(() => repo.getSongs(id)))!.map((s) => s.number),
      [1, 3],
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Drag to reorder'), findsNothing);
    await capture(tester, 'playlist-detail');
    await tester.tap(find.byTooltip('Play playlist in order'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    expect(player.played, [1, 3]);
    expect(find.text('Player'), findsNothing);
    expect(find.byTooltip('Pause playlist'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('playing-indicator')), findsOneWidget);

    await tester.tap(find.text('Song 1'));
    await tester.pumpAndSettle();
    expect(find.text('Player'), findsOneWidget);
    router.pop();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    expect(find.text('Evening'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause playlist'));
    await flush(tester);
    expect(player.playPauseToggles, 1);
    expect(find.byTooltip('Play playlist in order'), findsOneWidget);

    await tester.tap(find.byTooltip('Options for song 001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from this playlist'));
    await flush(tester);
    expect((await tester.runAsync(() => repo.getSongs(id)))!.single.number, 3);
    await tester.tap(find.byTooltip('Playlist options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Morning');
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await flush(tester);
    expect(find.text('Morning'), findsOneWidget);
    await tester.tap(find.byTooltip('Playlist options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await flush(tester);
    expect(await tester.runAsync(() => repo.watchAll().first), isEmpty);
    expect(find.text('Your songs, your order'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('settings gear pushes a page and back returns to Songs',
      (tester) async {
    await mount(tester, shell: true);
    expect(
      find.widgetWithText(NavigationDestination, 'Playlists'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(NavigationDestination, 'Settings'),
      findsNothing,
    );
    await capture(tester, 'songs-navigation');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings page'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('JW Songs'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Playlists'));
    await flush(tester);
    expect(find.text('Your songs, your order'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('playlist actions stay compact with a missing song at 320px',
      (tester) async {
    await mount(tester, location: '/playlists', width: 320);
    final id = await tester.runAsync(() => repo.create('Hope'));
    await tester.runAsync(() async {
      await repo.add(id!, 1);
      await db.songsDao.markDownloadRemoved(1);
    });
    router.go('/playlists/$id');
    await flush(tester);

    expect(find.text('Download'), findsOneWidget);
    expect(
      find.byTooltip('Download all unavailable songs'),
      findsOneWidget,
    );
    expect(find.byType(OfflineStatusIcon), findsNWidgets(2));
    expect(find.text('1 song • 0 downloaded'), findsOneWidget);
    expect(find.text('1 unavailable offline'), findsOneWidget);
    await capture(tester, 'playlist-missing-320');
    expect(
      tester.getSize(find.byKey(const ValueKey('playlist-play-button'))),
      const Size.square(56),
    );
    expect(find.byTooltip('Drag to reorder'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
