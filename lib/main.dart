import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:jwsongbook/app.dart';
import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/data/repositories/app_settings_repository.dart';
import 'package:jwsongbook/data/repositories/playback_preferences_repository.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/data/services/song_download_service.dart';

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
    androidNotificationChannelName: 'JW Songs Playback',
    androidNotificationIcon: 'mipmap/ic_launcher',
    notificationColor: AppColors.primaryPurple,
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: false,
    preloadArtwork: true,
  );

  // ── Bootstrap Riverpod ───────────────────────────────────────────────────
  final container = ProviderContainer();

  await container.read(appSettingsRepositoryProvider).load();

  // Restore playback preferences before widgets can read player state.
  await container.read(playbackPreferencesRepositoryProvider).load();

  // Merge bundled metadata on every launch so app updates can add songs
  // without replacing favorites, downloads, lyrics, or playback history.
  await container.read(songsRepositoryProvider).syncBundledCatalog();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const JwSongbookApp(),
    ),
  );

  // Keep startup offline-first. Remote catalog additions appear as soon as a
  // manifest refresh succeeds, but a network failure never blocks the app.
  unawaited(_refreshRemoteCatalog(container));
}

Future<void> _refreshRemoteCatalog(ProviderContainer container) async {
  if (!AppConstants.hasSongManifestUrl) return;

  try {
    await container.read(songDownloadServiceProvider).fetchAndSyncManifest(
          Uri.parse(AppConstants.songManifestUrl),
        );
  } on Object catch (error, stackTrace) {
    developer.log(
      'Remote song catalog refresh failed; using the local catalog.',
      name: 'JW Songs startup',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
