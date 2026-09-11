import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/data/models/playback_preferences.dart';
import 'package:jwsongbook/features/player/providers/lyrics_sync_provider.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/features/settings/screens/settings_screen.dart';
import 'package:jwsongbook/shared/widgets/playback_seek_slider.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final state = ref.watch(playerNotifierProvider);
    final notifier = ref.read(playerNotifierProvider.notifier);
    final lyrics = ref.watch(currentSongLyricsProvider).asData?.value;
    final followPaused = ref.watch(lyricsFollowPausedProvider);
    final settings = ref.watch(appSettingsNotifierProvider);

    final position = state.position;
    final duration = state.duration;
    final durationMs = duration.inMilliseconds;
    final isActivelyPlaying = state.isPlaying && !state.isCompleted;
    final sections = lyrics?.sections ?? const [];
    final currentSection = lyrics?.sectionAt(position.inMilliseconds);
    final markerPositions = durationMs <= 0
        ? const <double>[]
        : sections
            .skip(1)
            .map((section) => section.startMs / durationMs)
            .where((value) => value > 0 && value < 1)
            .toList(growable: false);
    final sectionLabel = currentSection != null && sections.length > 1
        ? 'Part ${currentSection.index + 1} of ${sections.length}'
        : null;

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

    void syncLyrics() {
      final request = ref.read(lyricsFollowRequestProvider.notifier);
      request.state = request.state + 1;
      ref.read(lyricsFollowPausedProvider.notifier).state = false;
    }

    String dragLabel(Duration previewPosition) {
      final previewSection = lyrics?.sectionAt(previewPosition.inMilliseconds);
      if (previewSection == null || sections.length <= 1) {
        return _formatDuration(previewPosition);
      }
      return 'Section ${previewSection.index + 1} of ${sections.length} - '
          '${_formatDuration(previewPosition)}';
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlaybackModeRow(
                isShuffleEnabled: state.isShuffleEnabled,
                repeatMode: state.repeatMode,
                sectionLabel: sectionLabel,
                showFollowLyrics: followPaused && settings.autoScrollEnabled,
                onShufflePressed: state.hasSong ? notifier.toggleShuffle : null,
                onRepeatPressed:
                    state.hasSong ? notifier.toggleRepeatMode : null,
                onFollowLyricsPressed: syncLyrics,
              ),
              PlaybackSeekSlider(
                key: ValueKey(state.currentSong?.id),
                position: position,
                duration: duration,
                onSeek: state.hasSong ? notifier.seek : null,
                showTimeLabels: true,
                timeStyle: TextStyle(
                  fontSize: 12,
                  color: colors.textMedium,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                timeLabelPadding: const EdgeInsets.symmetric(horizontal: 12),
                markerPositions: markerPositions,
                markerColor: colors.textInactive,
                thumbRadius: 7,
                trackHeight: 4,
                dragLabelBuilder: dragLabel,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    tooltip: 'Previous song',
                    icon: Icons.skip_previous_rounded,
                    onPressed: state.hasSong ? notifier.playPrevious : null,
                  ),
                  _ControlButton(
                    tooltip: 'Rewind 10 seconds',
                    icon: Icons.replay_10_rounded,
                    onPressed: state.hasSong
                        ? () => seekBy(-const Duration(seconds: 10))
                        : null,
                  ),
                  _PlayPauseButton(
                    isEnabled: state.hasSong,
                    isActivelyPlaying: isActivelyPlaying,
                    isLoading: state.isLoading,
                    onTap: notifier.togglePlayPause,
                  ),
                  _ControlButton(
                    tooltip: 'Forward 10 seconds',
                    icon: Icons.forward_10_rounded,
                    onPressed: state.hasSong
                        ? () => seekBy(const Duration(seconds: 10))
                        : null,
                  ),
                  _ControlButton(
                    tooltip: 'Next song',
                    icon: Icons.skip_next_rounded,
                    onPressed: state.hasSong ? notifier.playNext : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackModeRow extends StatelessWidget {
  const _PlaybackModeRow({
    required this.isShuffleEnabled,
    required this.repeatMode,
    required this.sectionLabel,
    required this.showFollowLyrics,
    required this.onShufflePressed,
    required this.onRepeatPressed,
    required this.onFollowLyricsPressed,
  });

  final bool isShuffleEnabled;
  final PlaybackRepeatMode repeatMode;
  final String? sectionLabel;
  final bool showFollowLyrics;
  final VoidCallback? onShufflePressed;
  final VoidCallback? onRepeatPressed;
  final VoidCallback onFollowLyricsPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final repeatActive = repeatMode != PlaybackRepeatMode.off;
    final (repeatIcon, repeatLabel) = switch (repeatMode) {
      PlaybackRepeatMode.off => (Icons.repeat_rounded, 'Repeat off'),
      PlaybackRepeatMode.one => (Icons.repeat_one_rounded, 'Repeat one'),
      PlaybackRepeatMode.all => (Icons.repeat_rounded, 'Repeat all'),
    };

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          _ModeIconButton(
            icon: Icons.shuffle_rounded,
            label: isShuffleEnabled ? 'Shuffle on' : 'Shuffle off',
            isActive: isShuffleEnabled,
            onPressed: onShufflePressed,
          ),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: showFollowLyrics
                    ? _FollowLyricsButton(
                        key: const ValueKey('follow'),
                        onPressed: onFollowLyricsPressed,
                      )
                    : Text(
                        sectionLabel ?? '',
                        key: ValueKey(sectionLabel),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          color: colors.textMedium,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
          _ModeIconButton(
            icon: repeatIcon,
            label: repeatLabel,
            isActive: repeatActive,
            onPressed: onRepeatPressed,
          ),
        ],
      ),
    );
  }
}

class _ModeIconButton extends StatelessWidget {
  const _ModeIconButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isActive ? colors.activeWordHighlight : colors.textMedium;

    return Semantics(
      button: true,
      toggled: isActive,
      label: label,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 48,
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 22,
          color: color,
          disabledColor: colors.textInactive,
          splashRadius: 22,
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? colors.primaryPurple.withAlpha(24)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

class _FollowLyricsButton extends StatelessWidget {
  const _FollowLyricsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.my_location_rounded, size: 17),
      label: const Text('Follow lyrics'),
      style: TextButton.styleFrom(
        foregroundColor: colors.activeWordHighlight,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 28,
      color: colors.textHigh,
      disabledColor: colors.textInactive,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      splashRadius: 23,
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
    final tooltip = isActivelyPlaying ? 'Pause' : 'Play';
    final colors = context.appColors;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return IconButton.filled(
      tooltip: tooltip,
      onPressed: isEnabled && !isLoading ? onTap : null,
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(Size.square(56)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textInactive;
          }
          return colors.primaryPurple;
        }),
        foregroundColor: WidgetStatePropertyAll(onPrimary),
      ),
      icon: isLoading
          ? SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: onPrimary,
              ),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                isActivelyPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                key: ValueKey(isActivelyPlaying),
                size: 34,
              ),
            ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
