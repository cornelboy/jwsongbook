import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerNotifierProvider);
    final notifier = ref.read(playerNotifierProvider.notifier);

    final position = state.position;
    final duration = state.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    final isActivelyPlaying = state.isPlaying && !state.isCompleted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Seek bar ──────────────────────────────────────────────────────
        Slider(
          value: progress.clamp(0.0, 1.0),
          onChanged: state.hasSong
              ? (v) => notifier.seekMs(
                    (v * duration.inMilliseconds).round(),
                  )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(position), style: _timeStyle),
              Text(_formatDuration(duration), style: _timeStyle),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Transport controls ────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous song
            IconButton(
              icon: const Icon(Icons.skip_previous),
              iconSize: 36,
              color:
                  state.hasSong ? AppColors.textMedium : AppColors.textInactive,
              onPressed: state.hasSong ? notifier.playPrevious : null,
            ),
            const SizedBox(width: 8),
            // Play / Pause
            GestureDetector(
              onTap: state.hasSong ? notifier.togglePlayPause : null,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.hasSong
                      ? AppColors.primaryPurple
                      : AppColors.textInactive,
                ),
                child: state.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isActivelyPlaying ? Icons.pause : Icons.play_arrow,
                        size: 36,
                        color: Colors.white,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            // Next song
            IconButton(
              icon: const Icon(Icons.skip_next),
              iconSize: 36,
              color:
                  state.hasSong ? AppColors.textMedium : AppColors.textInactive,
              onPressed: state.hasSong ? notifier.playNext : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  static const _timeStyle = TextStyle(
    fontSize: 12,
    color: AppColors.textMedium,
  );

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
