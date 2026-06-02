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

    void seekBy(Duration delta) {
      final target = position + delta;
      if (target < Duration.zero) {
        notifier.seek(Duration.zero);
      } else if (duration > Duration.zero && target > duration) {
        notifier.seek(duration);
      } else {
        notifier.seek(target);
      }
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: state.hasSong
                    ? (v) => notifier.seekMs(
                          (v * duration.inMilliseconds).round(),
                        )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position), style: _timeStyle),
                    Text(_formatDuration(duration), style: _timeStyle),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ControlButton(
                    icon: Icons.skip_previous,
                    onPressed: state.hasSong ? notifier.playPrevious : null,
                    color: AppColors.textInactive,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  _ControlButton(
                    icon: Icons.replay_10,
                    onPressed: state.hasSong
                        ? () => seekBy(-const Duration(seconds: 10))
                        : null,
                    color: AppColors.textHigh,
                    size: 31,
                  ),
                  const SizedBox(width: 18),
                  _PlayPauseButton(
                    isEnabled: state.hasSong,
                    isActivelyPlaying: isActivelyPlaying,
                    isLoading: state.isLoading,
                    onTap: notifier.togglePlayPause,
                  ),
                  const SizedBox(width: 18),
                  _ControlButton(
                    icon: Icons.forward_10,
                    onPressed: state.hasSong
                        ? () => seekBy(const Duration(seconds: 10))
                        : null,
                    color: AppColors.textHigh,
                    size: 31,
                  ),
                  const SizedBox(width: 10),
                  _ControlButton(
                    icon: Icons.skip_next,
                    onPressed: state.hasSong ? notifier.playNext : null,
                    color: AppColors.textInactive,
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _RepeatModeButton(
                repeatMode: state.repeatMode,
                onPressed: state.hasSong ? notifier.toggleRepeatMode : null,
              ),
            ],
          ),
        ),
      ),
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

class _RepeatModeButton extends StatelessWidget {
  const _RepeatModeButton({
    required this.repeatMode,
    required this.onPressed,
  });

  final PlaybackRepeatMode repeatMode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isActive = repeatMode != PlaybackRepeatMode.off;
    final (icon, label) = switch (repeatMode) {
      PlaybackRepeatMode.off => (Icons.repeat, 'Repeat off'),
      PlaybackRepeatMode.one => (Icons.repeat_one, 'Repeat song'),
      PlaybackRepeatMode.all => (Icons.repeat, 'Repeat all'),
    };

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor:
            isActive ? AppColors.primaryPurple : AppColors.textMedium,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.color = AppColors.textMedium,
    this.size = 28,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return IconButton(
      icon: Icon(icon),
      iconSize: size,
      color: enabled ? color : AppColors.textInactive,
      onPressed: onPressed,
      splashRadius: 24,
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isEnabled,
    required this.isActivelyPlaying,
    required this.isLoading,
    required this.onTap,
  });

  final bool isEnabled;
  final bool isActivelyPlaying;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled ? AppColors.primaryPurple : AppColors.textInactive,
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryPurple.withAlpha(70),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                isActivelyPlaying ? Icons.pause : Icons.play_arrow,
                size: 38,
                color: Colors.white,
              ),
      ),
    );
  }
}
