import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:jwsongbook/features/library/widgets/song_options_sheet.dart';
import 'package:jwsongbook/shared/widgets/offline_download_icon.dart';

class SongCard extends ConsumerWidget {
  const SongCard({
    super.key,
    required this.song,
    required this.onTap,
    this.playlistId,
    this.onDownloadTap,
    this.downloadStatus = const SongDownloadStatus.idle(),
    this.isCurrentlyPlaying = false,
    this.showPlaybackIndicator = false,
    this.showDownloadedIndicator = true,
    this.showOptions = true,
  });

  final Song song;
  final VoidCallback? onTap;
  final int? playlistId;
  final VoidCallback? onDownloadTap;
  final SongDownloadStatus downloadStatus;
  final bool isCurrentlyPlaying;
  final bool showPlaybackIndicator;
  final bool showDownloadedIndicator;
  final bool showOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 12,
            bottom: 12,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 3,
              decoration: BoxDecoration(
                color: isCurrentlyPlaying
                    ? colors.primaryPurple
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _SongNumberBadge(
                  paddedNumber: song.paddedNumber,
                  isActive: isCurrentlyPlaying,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: context.appText.songTitle.copyWith(
                          color: isCurrentlyPlaying
                              ? colors.primaryPurple
                              : colors.textHigh,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: showPlaybackIndicator
                      ? const _PlayingIndicator()
                      : _DownloadAction(
                          key: ValueKey(
                            '${song.hasLocalAudio || downloadStatus.isDownloaded}-'
                            '${downloadStatus.isDownloading}-'
                            '${downloadStatus.isPaused}-'
                            '${downloadStatus.hasError}-'
                            '$showDownloadedIndicator',
                          ),
                          hasLocalAudio:
                              song.hasLocalAudio || downloadStatus.isDownloaded,
                          status: downloadStatus,
                          onTap: onDownloadTap,
                          showDownloadedIndicator: showDownloadedIndicator,
                        ),
                ),
                if (showOptions)
                  IconButton(
                    onPressed: () => showSongOptions(
                      context,
                      ref,
                      song,
                      playlistId: playlistId,
                    ),
                    icon: Icon(
                      Icons.more_vert,
                      color: colors.textMedium,
                      size: 22,
                    ),
                    tooltip: 'Options for song ${song.paddedNumber}',
                    splashRadius: 22,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator();

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Now playing',
      child: SizedBox.square(
        key: const ValueKey('playing-indicator'),
        dimension: 48,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = reducedMotion ? 0.5 : _controller.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(3, (index) {
                  final wave = math.sin((progress + index / 3) * math.pi * 2);
                  final height = 8.0 + ((wave + 1) / 2) * 12;
                  return Padding(
                    padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
                    child: Container(
                      width: 3,
                      height: height,
                      decoration: BoxDecoration(
                        color: colors.primaryPurple,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SongNumberBadge extends StatelessWidget {
  const _SongNumberBadge({
    required this.paddedNumber,
    required this.isActive,
  });

  final String paddedNumber;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isActive ? colors.primaryPurple.withAlpha(36) : colors.card,
        border: Border.all(
          color:
              isActive ? colors.primaryPurple.withAlpha(110) : colors.divider,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        paddedNumber,
        style: context.appText.songNumber.copyWith(
          color: isActive ? colors.primaryPurple : colors.textMedium,
        ),
      ),
    );
  }
}

class _DownloadAction extends StatelessWidget {
  const _DownloadAction({
    super.key,
    required this.hasLocalAudio,
    required this.status,
    required this.onTap,
    required this.showDownloadedIndicator,
  });

  final bool hasLocalAudio;
  final SongDownloadStatus status;
  final VoidCallback? onTap;
  final bool showDownloadedIndicator;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (hasLocalAudio) {
      if (!showDownloadedIndicator) return const SizedBox.shrink();

      return Tooltip(
        message: 'Available offline',
        child: Semantics(
          label: 'Available offline',
          child: const SizedBox.square(
            dimension: 48,
            child: Center(
              child: OfflineStatusIcon.downloaded(),
            ),
          ),
        ),
      );
    }

    if (status.isDownloading) {
      final progress = status.progress;
      final progressLabel =
          progress == null ? null : '${(progress.clamp(0, 1) * 100).round()}%';

      return Semantics(
        button: true,
        label: 'Pause download',
        value: progressLabel,
        child: IconButton(
          onPressed: onTap,
          tooltip: 'Pause download',
          icon: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: progress,
                  color: colors.primaryPurple,
                  backgroundColor: colors.divider,
                ),
              ),
              Icon(
                Icons.pause_rounded,
                size: 18,
                color: colors.textHigh,
              ),
            ],
          ),
        ),
      );
    }

    if (status.isPaused) {
      return IconButton(
        onPressed: onTap,
        tooltip: 'Resume download',
        icon: Icon(
          Icons.play_arrow_rounded,
          color: colors.primaryPurple,
          size: 24,
        ),
      );
    }

    return IconButton(
      onPressed: onTap,
      icon: const OfflineStatusIcon.download(),
      tooltip: status.hasError ? 'Retry download' : 'Download',
      splashRadius: 22,
    );
  }
}
