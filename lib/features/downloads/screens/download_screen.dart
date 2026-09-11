import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/features/downloads/actions/song_download_actions.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';
import 'package:jwsongbook/shared/widgets/offline_download_icon.dart';

class DownloadScreen extends ConsumerWidget {
  const DownloadScreen({super.key, required this.songNumber});

  final int songNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songAsync = ref.watch(_songByNumberProvider(songNumber));

    return Scaffold(
      appBar: AppBar(title: const Text('Song Download')),
      body: songAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load song',
          subtitle: e.toString(),
        ),
        data: (song) {
          if (song == null) {
            return const EmptyState(
              icon: Icons.music_note_outlined,
              title: 'Song not found',
            );
          }

          return _DownloadBody(song: song);
        },
      ),
    );
  }
}

class _DownloadBody extends ConsumerWidget {
  const _DownloadBody({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadStatus =
        ref.watch(downloadControllerProvider).statusFor(song.number);
    final hasLocalAudio = song.hasLocalAudio || downloadStatus.isDownloaded;
    const downloadsReady = AppConstants.hasSongManifestUrl;

    return ListView(
      padding: const EdgeInsets.all(AppConstants.screenPaddingH),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SongBadge(song: song),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: context.appText.displayTitle),
                  const SizedBox(height: 4),
                  Text(
                    hasLocalAudio
                        ? 'This song is available on this device.'
                        : 'This song is not stored on this device yet.',
                    style: context.appText.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (downloadStatus.isDownloading)
          _ProgressPanel(
            progress: downloadStatus.progress,
            onPause: () => ref
                .read(downloadControllerProvider.notifier)
                .pauseSong(song.number),
          )
        else if (downloadStatus.isPaused)
          _ActionPanel(
            icon: Icons.pause_circle_outline,
            title: 'Download paused',
            subtitle: 'Continue downloading from where it stopped.',
            actionLabel: 'Resume download',
            onPressed: () => _downloadSong(context, ref),
          )
        else if (hasLocalAudio)
          _ActionPanel(
            icon: Icons.check_rounded,
            displayIcon: OfflineStatusIcon.downloaded(
              size: 28,
              color: context.appColors.primaryPurple,
            ),
            title: 'Ready to play',
            subtitle: 'Audio is already available locally.',
            actionLabel: 'Play now',
            onPressed: () => _playSong(context, ref),
          )
        else
          _ActionPanel(
            icon: Icons.arrow_downward_rounded,
            displayIcon: OfflineStatusIcon.download(
              size: 28,
              color: context.appColors.primaryPurple,
            ),
            title: downloadsReady
                ? 'Download required'
                : 'Downloads will be available soon',
            subtitle: downloadsReady
                ? 'Save this song to play it offline.'
                : 'The app is ready for downloads. The server manifest still needs to be connected.',
            actionLabel: downloadsReady ? 'Download song' : 'Unavailable',
            onPressed:
                downloadsReady ? () => _downloadSong(context, ref) : null,
          ),
      ],
    );
  }

  Future<void> _downloadSong(BuildContext context, WidgetRef ref) async {
    await ref.read(downloadControllerProvider.notifier).downloadSong(song);
    if (!context.mounted) return;

    final status = ref.read(downloadControllerProvider).statusFor(song.number);
    if (status.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status.message ?? 'Download failed.')),
      );
    }
  }

  void _playSong(BuildContext context, WidgetRef ref) {
    if (context.mounted) {
      supersedePendingDownloadPlayback(ref);
      unawaited(context.push(AppRoutes.nowPlayingSongPath(song.number)));
    }
  }
}

class _SongBadge extends StatelessWidget {
  const _SongBadge({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryPurple.withAlpha(30),
        border: Border.all(color: colors.primaryPurple.withAlpha(80)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        song.paddedNumber,
        style: context.appText.songNumber.copyWith(fontSize: 17),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.progress, required this.onPause});

  final double? progress;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Downloading', style: context.appText.songTitle),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onPause,
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pause download'),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
    this.displayIcon,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onPressed;
  final Widget? displayIcon;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          displayIcon ??
              Icon(icon, color: context.appColors.primaryPurple, size: 28),
          const SizedBox(height: 14),
          Text(title, style: context.appText.songTitle),
          const SizedBox(height: 6),
          Text(subtitle, style: context.appText.bodyMedium),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPressed,
            icon: onPressed == null
                ? const Icon(Icons.lock_outline)
                : displayIcon ?? Icon(icon),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

final _songByNumberProvider = FutureProvider.family<Song?, int>(
  (ref, number) => ref.watch(songsRepositoryProvider).getByNumber(number),
);
