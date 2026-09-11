import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/features/downloads/actions/song_download_actions.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';

const song = Song(
  id: 1,
  number: 1,
  title: 'Downloading song',
  isDownloaded: false,
  isFavorited: false,
  hasSyncedLyrics: false,
);

class _Downloads extends DownloadController {
  final finished = Completer<void>();

  @override
  DownloadState build() => const DownloadState();

  @override
  Future<void> downloadSong(Song song) async {
    state = state.withSong(
      song.number,
      const SongDownloadStatus.downloading(progress: 0.5),
    );
    await finished.future;
    state = state.withSong(song.number, const SongDownloadStatus.downloaded());
  }
}

class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => unawaited(
                downloadAndPlaySong(context: context, ref: ref, song: song),
              ),
              child: const Text('Download then play'),
            ),
            TextButton(
              onPressed: () => supersedePendingDownloadPlayback(ref),
              child: const Text('Choose another song'),
            ),
          ],
        ),
      );
}

void main() {
  Future<({GoRouter router, _Downloads downloads})> mount(
    WidgetTester tester,
  ) async {
    final downloads = _Downloads();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const _Harness()),
        GoRoute(
          path: AppRoutes.nowPlaying,
          builder: (_, state) => Text(
            'Playing ${state.uri.queryParameters['song']}',
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadControllerProvider.overrideWith(() => downloads),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    return (router: router, downloads: downloads);
  }

  testWidgets('a newer song choice cancels pending download autoplay',
      (tester) async {
    final app = await mount(tester);
    addTearDown(app.router.dispose);

    await tester.tap(find.text('Download then play'));
    await tester.pump();
    await tester.tap(find.text('Choose another song'));
    app.downloads.finished.complete();
    await tester.pumpAndSettle();

    expect(find.text('Playing 1'), findsNothing);
    expect(find.text('Choose another song'), findsOneWidget);
  });

  testWidgets('download still plays when no newer choice replaces it',
      (tester) async {
    final app = await mount(tester);
    addTearDown(app.router.dispose);

    await tester.tap(find.text('Download then play'));
    await tester.pump();
    app.downloads.finished.complete();
    await tester.pumpAndSettle();

    expect(find.text('Playing 1'), findsOneWidget);
  });
}
