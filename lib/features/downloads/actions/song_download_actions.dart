import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';

/// Changes whenever the user makes a new, explicit song selection.
///
/// A download may finish after the user has chosen a different song. Its old
/// "download, then play" request must not override that newer choice.
final songPlaybackIntentProvider = StateProvider<int>((ref) => 0);

void supersedePendingDownloadPlayback(WidgetRef ref) {
  final notifier = ref.read(songPlaybackIntentProvider.notifier);
  notifier.state++;
}

Future<void> downloadAndPlaySong({
  required BuildContext context,
  required WidgetRef ref,
  required Song song,
}) async {
  if (!AppConstants.hasSongManifestUrl) {
    _showSnackBar(context, 'Downloads will be available soon.');
    return;
  }

  final status = ref.read(downloadControllerProvider).statusFor(song.number);
  if (status.isDownloading) {
    _showSnackBar(context, 'Download already in progress.');
    return;
  }

  final intent = ref.read(songPlaybackIntentProvider.notifier).state + 1;
  ref.read(songPlaybackIntentProvider.notifier).state = intent;

  await downloadSongAndMaybePlay(
    context: context,
    ref: ref,
    song: song,
    playAfterDownload: true,
    playbackIntent: intent,
  );
}

Future<void> downloadSongAndMaybePlay({
  required BuildContext context,
  required WidgetRef ref,
  required Song song,
  required bool playAfterDownload,
  int? playbackIntent,
}) async {
  await ref.read(downloadControllerProvider.notifier).downloadSong(song);
  if (!context.mounted) return;

  final status = ref.read(downloadControllerProvider).statusFor(song.number);
  if (status.hasError) {
    _showSnackBar(
      context,
      status.message ?? 'Download failed.',
      isError: true,
      actionLabel: 'Retry',
      onAction: () {
        if (!context.mounted) return;
        unawaited(
          playAfterDownload
              ? downloadAndPlaySong(context: context, ref: ref, song: song)
              : downloadSongAndMaybePlay(
                  context: context,
                  ref: ref,
                  song: song,
                  playAfterDownload: false,
                ),
        );
      },
    );
    return;
  }

  if (status.isDownloading || status.isPaused) {
    return;
  }

  if (!playAfterDownload) {
    return;
  }

  if (playbackIntent == null ||
      ref.read(songPlaybackIntentProvider) != playbackIntent) {
    return;
  }

  if (context.mounted) {
    unawaited(context.push(AppRoutes.nowPlayingSongPath(song.number)));
  }
}

void _showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: isError
          ? Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: context.appColors.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : Text(message),
      duration: const Duration(seconds: 6),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              onPressed: onAction,
            ),
    ),
  );
}
