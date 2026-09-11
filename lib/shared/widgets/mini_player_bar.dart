import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/shared/widgets/playback_seek_slider.dart';

final miniPlayerCollapsedProvider = StateProvider<bool>((ref) => false);
final miniPlayerAnimateExpansionProvider = StateProvider<bool>((ref) => false);

/// Persistent mini player shown above navigation while a song is loaded.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerNotifierProvider);
    final song = playerState.currentSong;
    final isCollapsed = ref.watch(miniPlayerCollapsedProvider);
    final animateExpansion = ref.watch(miniPlayerAnimateExpansionProvider);

    ref.listen<int?>(
      playerNotifierProvider.select((state) => state.currentSong?.id),
      (previous, next) {
        if (next != null && next != previous) {
          ref.read(miniPlayerAnimateExpansionProvider.notifier).state = false;
          ref.read(miniPlayerCollapsedProvider.notifier).state = false;
        }
      },
    );

    if (song == null) return const SizedBox.shrink();

    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.nowPlaying)) {
      if (isCollapsed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ref.read(miniPlayerAnimateExpansionProvider.notifier).state = false;
          ref.read(miniPlayerCollapsedProvider.notifier).state = false;
        });
      }
      return const SizedBox.shrink();
    }

    if (isCollapsed) {
      return _CollapsedPlaybackProgress(
        position: playerState.position,
        duration: playerState.duration,
        onExpand: () {
          ref.read(miniPlayerAnimateExpansionProvider.notifier).state = true;
          ref.read(miniPlayerCollapsedProvider.notifier).state = false;
        },
      );
    }

    final notifier = ref.read(playerNotifierProvider.notifier);
    return _ExpandedMiniPlayer(
      key: ValueKey(song.id),
      songNumber: song.paddedNumber,
      songTitle: song.title,
      position: playerState.position,
      duration: playerState.duration,
      isPlaying: playerState.isPlaying && !playerState.isCompleted,
      isLoading: playerState.isLoading,
      animateExpansion: animateExpansion,
      onOpen: () => unawaited(context.push(AppRoutes.nowPlaying)),
      onSeek: notifier.seek,
      onPrevious: notifier.playPrevious,
      onPlayPause: notifier.togglePlayPause,
      onNext: notifier.playNext,
      onMinimized: () {
        ref.read(miniPlayerAnimateExpansionProvider.notifier).state = false;
        ref.read(miniPlayerCollapsedProvider.notifier).state = true;
      },
      onExpansionFinished: () {
        ref.read(miniPlayerAnimateExpansionProvider.notifier).state = false;
      },
    );
  }
}

class _ExpandedMiniPlayer extends StatefulWidget {
  const _ExpandedMiniPlayer({
    required this.songNumber,
    required this.songTitle,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isLoading,
    required this.animateExpansion,
    required this.onOpen,
    required this.onSeek,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onMinimized,
    required this.onExpansionFinished,
    super.key,
  });

  final String songNumber;
  final String songTitle;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final bool animateExpansion;
  final VoidCallback onOpen;
  final Future<void> Function(Duration position) onSeek;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onMinimized;
  final VoidCallback onExpansionFinished;

  @override
  State<_ExpandedMiniPlayer> createState() => _ExpandedMiniPlayerState();
}

class _ExpandedMiniPlayerState extends State<_ExpandedMiniPlayer>
    with SingleTickerProviderStateMixin {
  static const _barHeight = 116.0;
  static const _dismissThreshold = 0.35;
  static const _flingVelocity = 700.0;
  late final AnimationController _collapseController;
  bool _isCompletingMinimize = false;

  @override
  void initState() {
    super.initState();
    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.animateExpansion ? 1 : 0,
    );
    if (widget.animateExpansion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_animateExpansion());
      });
    }
  }

  @override
  void dispose() {
    _collapseController.dispose();
    super.dispose();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isCompletingMinimize) return;
    _collapseController.value =
        (_collapseController.value + details.delta.dy / _barHeight)
            .clamp(0.0, 1.0);
  }

  void _resetDrag() {
    if (_isCompletingMinimize) return;
    unawaited(
      _collapseController.animateBack(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _animateExpansion() async {
    if (_isCompletingMinimize) return;
    await _collapseController.animateBack(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
    if (mounted) widget.onExpansionFinished();
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isCompletingMinimize) return;
    final velocity = details.primaryVelocity ?? 0;
    final shouldMinimize = _collapseController.value >= _dismissThreshold ||
        velocity >= _flingVelocity;
    if (shouldMinimize) {
      unawaited(_animateMinimize());
    } else {
      _resetDrag();
    }
  }

  Future<void> _animateMinimize() async {
    if (_isCompletingMinimize) return;
    _isCompletingMinimize = true;
    await _collapseController.animateTo(1, curve: Curves.easeOutCubic);
    if (mounted) widget.onMinimized();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: 'Mini player for ${widget.songTitle}',
      hint: 'Swipe down to minimize player',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        onVerticalDragCancel: _resetDrag,
        child: AnimatedBuilder(
          animation: _collapseController,
          builder: (context, child) {
            final progress = _collapseController.value;
            return ClipRect(
              child: Align(
                key: const ValueKey('mini-player-reveal'),
                alignment: Alignment.topCenter,
                heightFactor: 1 - progress,
                child: Transform.translate(
                  offset: Offset(0, progress * _barHeight),
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            height: _barHeight,
            color: colors.surfaceElevated,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniPlayerHandle(
                  icon: Icons.keyboard_arrow_down_rounded,
                  label: 'Minimize player',
                  onTap: _animateMinimize,
                ),
                SizedBox(
                  height: 12,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      activeTrackColor: colors.primaryPurple,
                      inactiveTrackColor: colors.divider,
                      thumbColor: colors.primaryPurple,
                      overlayColor: colors.primaryPurple.withAlpha(28),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4,
                        disabledThumbRadius: 0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: PlaybackSeekSlider(
                      position: widget.position,
                      duration: widget.duration,
                      onSeek: widget.duration > Duration.zero
                          ? widget.onSeek
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _SongBadge(paddedNumber: widget.songNumber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.songTitle,
                            style: context.appText.bodyMedium.copyWith(
                              color: colors.textHigh,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Previous song',
                          icon:
                              const Icon(Icons.skip_previous_rounded, size: 22),
                          color: colors.textHigh,
                          splashRadius: 20,
                          onPressed: widget.onPrevious,
                        ),
                        _PlayPauseButton(
                          isPlaying: widget.isPlaying,
                          isLoading: widget.isLoading,
                          onTap: widget.onPlayPause,
                        ),
                        IconButton(
                          tooltip: 'Next song',
                          icon: const Icon(Icons.skip_next_rounded, size: 22),
                          color: colors.textHigh,
                          disabledColor: colors.textInactive,
                          splashRadius: 20,
                          onPressed: widget.onNext,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerHandle extends StatelessWidget {
  const _MiniPlayerHandle({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: Center(
              child: _HandleCapsule(
                icon: icon,
                foregroundColor: colors.textMedium,
                backgroundColor: colors.card,
                borderColor: colors.divider,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedPlaybackProgress extends StatelessWidget {
  const _CollapsedPlaybackProgress({
    required this.position,
    required this.duration,
    required this.onExpand,
  });

  final Duration position;
  final Duration duration;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final durationMs = duration.inMilliseconds;
    final progress = durationMs <= 0
        ? 0.0
        : (position.inMilliseconds / durationMs).clamp(0.0, 1.0);

    return Semantics(
      button: true,
      label: 'Restore mini player',
      hint: 'Tap or swipe up',
      value: '${(progress * 100).round()} percent',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onExpand,
        onVerticalDragUpdate: (details) {
          if ((details.primaryDelta ?? 0) < -4) onExpand();
        },
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -250) onExpand();
        },
        child: SizedBox(
          height: 48,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colors.divider,
                    valueColor: AlwaysStoppedAnimation(colors.primaryPurple),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: ExcludeSemantics(
                  child: _HandleCapsule(
                    icon: Icons.keyboard_arrow_up_rounded,
                    foregroundColor: colors.primaryPurple,
                    backgroundColor: colors.primaryPurple.withAlpha(24),
                    borderColor: colors.primaryPurple.withAlpha(70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandleCapsule extends StatelessWidget {
  const _HandleCapsule({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: foregroundColor),
    );
  }
}

class _SongBadge extends StatelessWidget {
  const _SongBadge({required this.paddedNumber});

  final String paddedNumber;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.primaryPurple.withAlpha(36),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        paddedNumber,
        style: context.appText.caption.copyWith(
          color: colors.primaryPurple,
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
    final label = isPlaying ? 'Pause' : 'Play';
    final colors = context.appColors;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isLoading ? null : onTap,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryPurple,
                ),
                alignment: Alignment.center,
                child: isLoading
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: onPrimary,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 24,
                        color: onPrimary,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
