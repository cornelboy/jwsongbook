import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'data/repositories/songs_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── System UI ────────────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // ── Background audio (just_audio_background) ─────────────────────────────
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.jwsongbook.audio',
    androidNotificationChannelName: 'Kingdom Songs Playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  // ── Bootstrap Riverpod ───────────────────────────────────────────────────
  final container = ProviderContainer();

  // Seed the database with song titles if this is the first launch.
  await container.read(songsRepositoryProvider).seedIfEmpty();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const JwSongbookApp(),
    ),
  );
}
