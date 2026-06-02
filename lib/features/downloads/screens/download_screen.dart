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
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';

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
    const downloadsReady = AppConstants.songManifestUrl != null;

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
                  Text(song.title, style: AppTypography.displayTitle),
                  const SizedBox(height: 4),
                  Text(
                    hasLocalAudio
                        ? 'This song is available on this device.'
                        : 'This song is not stored on this device yet.',
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (downloadStatus.isDownloading)
          _ProgressPanel(progress: downloadStatus.progress)
        else if (hasLocalAudio)
          _ActionPanel(
            icon: Icons.check_circle_outline,
            title: 'Ready to play',
            subtitle: 'Audio is already available locally.',
            actionLabel: 'Play now',
            onPressed: () => _playSong(context, ref),
          )
        else
          _ActionPanel(
            icon: Icons.download_outlined,
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

  Future<void> _playSong(BuildContext context, WidgetRef ref) async {
    await ref.read(playerNotifierProvider.notifier).playSong(song);
    if (context.mounted) {
      context.go(AppRoutes.nowPlaying);
    }
  }
}

class _SongBadge extends StatelessWidget {
  const _SongBadge({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withAlpha(30),
        border: Border.all(color: AppColors.primaryPurple.withAlpha(80)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        song.paddedNumber,
        style: AppTypography.songNumber.copyWith(fontSize: 17),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Downloading', style: AppTypography.songTitle),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 28),
          const SizedBox(height: 14),
          Text(title, style: AppTypography.songTitle),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTypography.bodyMedium),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(onPressed == null ? Icons.lock_outline : icon),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.divider),
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
