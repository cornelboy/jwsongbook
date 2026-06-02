import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';

/// Persistent mini-player bar shown above the bottom navigation when a song
/// is loaded.  Tapping it navigates to the full [PlayerScreen].
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  static const double _barHeight = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerNotifierProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(playerNotifierProvider.notifier);
    final progress = playerState.duration.inMilliseconds > 0
        ? playerState.position.inMilliseconds /
            playerState.duration.inMilliseconds
        : 0.0;
    final isActivelyPlaying = playerState.isPlaying && !playerState.isCompleted;

    // Don't show mini player when the user is already on the Now Playing tab.
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.nowPlaying)) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => context.go(AppRoutes.nowPlaying),
      child: Container(
        height: _barHeight,
        color: AppColors.surfaceElevated,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin progress bar along the top edge.
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: AppColors.divider,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Song number badge.
                    _SongBadge(paddedNumber: song.paddedNumber),
                    const SizedBox(width: 12),
                    // Title — fills remaining space.
                    Expanded(
                      child: Text(
                        song.title,
                        style: AppTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Previous.
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 22),
                      color: AppColors.textMedium,
                      splashRadius: 20,
                      onPressed: notifier.playPrevious,
                    ),
                    // Play / Pause.
                    _PlayPauseButton(
                      isPlaying: isActivelyPlaying,
                      isLoading: playerState.isLoading,
                      onTap: notifier.togglePlayPause,
                    ),
                    // Next.
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 22),
                      color: AppColors.textMedium,
                      splashRadius: 20,
                      onPressed: notifier.playNext,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongBadge extends StatelessWidget {
  const _SongBadge({required this.paddedNumber});

  final String paddedNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withAlpha(36),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        paddedNumber,
        style: AppTypography.caption.copyWith(
          color: AppColors.primaryPurple,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryPurple,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 22,
                color: Colors.white,
              ),
      ),
    );
  }
}
