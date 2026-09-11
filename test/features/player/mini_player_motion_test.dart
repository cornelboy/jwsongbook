import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/shared/widgets/mini_player_bar.dart';

const _song = Song(
  id: 3,
  number: 3,
  title: 'Our Strength, Our Hope, Our Confidence',
  isDownloaded: true,
  isFavorited: false,
  hasSyncedLyrics: true,
);

class _Player extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState(
        currentSong: _song,
        position: Duration(seconds: 30),
        duration: Duration(minutes: 3),
      );

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> playPrevious() async {}

  @override
  Future<void> togglePlayPause() async {}

  @override
  Future<void> playNext() async {}
}

void main() {
  late GoRouter router;

  Future<void> mount(WidgetTester tester, {String location = '/songs'}) async {
    router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (_, __, child) => Scaffold(
            body: child,
            bottomNavigationBar: const MiniPlayerBar(),
          ),
          routes: [
            GoRoute(
              path: '/songs',
              builder: (_, __) => const Text('Songs'),
            ),
            GoRoute(
              path: '/now-playing',
              builder: (_, __) => const Text('Now Playing'),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerNotifierProvider.overrideWith(_Player.new)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  tearDown(() => router.dispose());

  Align reveal(WidgetTester tester) => tester.widget<Align>(
        find.byKey(const ValueKey('mini-player-reveal')),
      );

  testWidgets('restored mini player appears stationary on app opening',
      (tester) async {
    await mount(tester);

    expect(reveal(tester).heightFactor, 1);
    await tester.pump(const Duration(milliseconds: 250));
    expect(reveal(tester).heightFactor, 1);
  });

  testWidgets('leaving Now Playing shows a stationary mini player',
      (tester) async {
    await mount(tester, location: '/now-playing');
    expect(find.byKey(const ValueKey('mini-player-reveal')), findsNothing);

    router.go('/songs');
    await tester.pump();
    expect(reveal(tester).heightFactor, 1);
    await tester.pump(const Duration(milliseconds: 250));
    expect(reveal(tester).heightFactor, 1);
  });

  testWidgets('only explicit restore animates the mini player upward',
      (tester) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Minimize player'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Restore mini player'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Restore mini player'));
    await tester.pump();
    expect(reveal(tester).heightFactor, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(reveal(tester).heightFactor, greaterThan(0));
    expect(reveal(tester).heightFactor, lessThan(1));
    await tester.pumpAndSettle();
    expect(reveal(tester).heightFactor, 1);
  });
}
