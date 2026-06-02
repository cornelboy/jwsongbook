import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/models/synced_lyrics_model.dart';
import 'package:jwsongbook/features/player/providers/lyrics_sync_provider.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';

class FloatingLyricsButton extends ConsumerStatefulWidget {
  const FloatingLyricsButton({super.key});

  @override
  ConsumerState<FloatingLyricsButton> createState() =>
      _FloatingLyricsButtonState();
}

class _FloatingLyricsButtonState extends ConsumerState<FloatingLyricsButton> {
  Offset? _position;
  bool _isPanelOpen = false;
  bool _isDragging = false;

  static const double _buttonSize = 52;
  static const double _touchSize = 68;
  static const double _edgePadding = 16;
  static const double _panelGap = 10;
  static const double _panelPreferredWidth = 320;
  static const double _panelEstimatedHeight = 300;
  static const Duration _snapDuration = Duration(milliseconds: 165);

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(
      playerNotifierProvider.select((state) => state.currentSong),
    );
    final location = GoRouterState.of(context).uri.toString();

    if (song == null || location.startsWith(AppRoutes.nowPlaying)) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxX = constraints.maxWidth - _buttonSize - _edgePadding;
            final maxY = constraints.maxHeight - _buttonSize - _edgePadding;
            final defaultPosition = Offset(maxX, maxY);
            final position = _clampPosition(
              _position ?? defaultPosition,
              maxX,
              maxY,
            );
            final isRightSide =
                position.dx + (_buttonSize / 2) >= constraints.maxWidth / 2;
            final panelWidth = (constraints.maxWidth -
                    _buttonSize -
                    (_edgePadding * 3) -
                    _panelGap)
                .clamp(220.0, _panelPreferredWidth);
            final panelPosition = _panelPosition(
              buttonPosition: position,
              isRightSide: isRightSide,
              panelWidth: panelWidth,
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
            );

            return Stack(
              children: [
                if (_isPanelOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _isPanelOpen = false),
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (_isPanelOpen)
                  Positioned(
                    left: panelPosition.dx,
                    top: panelPosition.dy,
                    width: panelWidth,
                    child: const _FloatingLyricsPanel(),
                  ),
                AnimatedPositioned(
                  duration: _isDragging ? Duration.zero : _snapDuration,
                  curve: Curves.easeOutCubic,
                  left: position.dx - ((_touchSize - _buttonSize) / 2),
                  top: position.dy - ((_touchSize - _buttonSize) / 2),
                  child: GestureDetector(
                    onPanStart: (_) {
                      setState(() => _isDragging = true);
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _position = _clampPosition(
                          position + details.delta,
                          maxX,
                          maxY,
                        );
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _isDragging = false;
                        _position = Offset(
                          isRightSide ? maxX : _edgePadding,
                          position.dy,
                        );
                      });
                    },
                    onPanCancel: () {
                      setState(() => _isDragging = false);
                    },
                    child: SizedBox(
                      width: _touchSize,
                      height: _touchSize,
                      child: Center(
                        child: SizedBox(
                          width: _buttonSize,
                          height: _buttonSize,
                          child: FloatingActionButton(
                            heroTag: 'floating-lyrics-button',
                            mini: true,
                            tooltip: 'Show lyrics',
                            onPressed: () {
                              setState(() => _isPanelOpen = !_isPanelOpen);
                            },
                            child: Text(
                              song.paddedNumber,
                              style: AppTypography.songNumber.copyWith(
                                color: AppColors.background,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Offset _clampPosition(Offset value, double maxX, double maxY) {
    return Offset(
      value.dx.clamp(_edgePadding, maxX),
      value.dy.clamp(_edgePadding, maxY),
    );
  }

  Offset _panelPosition({
    required Offset buttonPosition,
    required bool isRightSide,
    required double panelWidth,
    required double maxWidth,
    required double maxHeight,
  }) {
    final x = isRightSide
        ? buttonPosition.dx - panelWidth - _panelGap
        : buttonPosition.dx + _buttonSize + _panelGap;
    final y = (buttonPosition.dy - 86).clamp(
      _edgePadding,
      maxHeight - _panelEstimatedHeight - _edgePadding,
    );

    return Offset(
      x.clamp(_edgePadding, maxWidth - panelWidth - _edgePadding),
      y,
    );
  }
}

class _FloatingLyricsPanel extends ConsumerWidget {
  const _FloatingLyricsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerNotifierProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final lyricsAsync = ref.watch(currentSongLyricsProvider);
    final cursor = ref.watch(syncCursorProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(song: song),
            const SizedBox(height: 14),
            lyricsAsync.when(
              loading: () => const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _EmptyLyricsPreview(message: e.toString()),
              data: (lyrics) => _LyricsPreview(
                lyrics: lyrics,
                cursor: cursor,
                positionMs: playerState.positionMs,
              ),
            ),
            const SizedBox(height: 14),
            _PanelActions(playerState: playerState),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withAlpha(36),
            border: Border.all(color: AppColors.primaryPurple.withAlpha(100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(song.paddedNumber, style: AppTypography.songNumber),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.songTitle,
              ),
              const Text('Compact lyrics', style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _LyricsPreview extends StatelessWidget {
  const _LyricsPreview({
    required this.lyrics,
    required this.cursor,
    required this.positionMs,
  });

  final SyncedLyrics lyrics;
  final SyncCursor cursor;
  final int positionMs;

  @override
  Widget build(BuildContext context) {
    if (lyrics.isEmpty) {
      return const _EmptyLyricsPreview(
        message: 'Synced lyrics for this song are coming soon.',
      );
    }

    if (cursor.lineIndex < 0) {
      final nextLine = _nextLineAfter(positionMs);
      if (nextLine == null) {
        return const _EmptyLyricsPreview(message: 'Waiting for lyrics');
      }
      return _UpcomingLyricPreview(line: nextLine);
    }

    final previewLines = lyrics.lines.skip(cursor.lineIndex).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(previewLines.length, (index) {
        final line = previewLines[index];
        final isActive = index == 0 && cursor.lineIndex >= 0;
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == previewLines.length - 1 ? 0 : 12,
          ),
          child: Text(
            line.text,
            maxLines: isActive ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: (isActive
                    ? AppTypography.lyricsActive
                    : AppTypography.bodyLarge)
                .copyWith(
              color: isActive ? AppColors.primaryPurple : AppColors.textMedium,
              fontSize: isActive ? 24 : 17,
            ),
          ),
        );
      }),
    );
  }

  SyncedLine? _nextLineAfter(int positionMs) {
    for (final line in lyrics.lines) {
      if (line.startMs > positionMs) return line;
    }
    return null;
  }
}

class _UpcomingLyricPreview extends StatelessWidget {
  const _UpcomingLyricPreview({required this.line});

  final SyncedLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        line.text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.lyricsActive.copyWith(
          color: AppColors.textMedium,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyLyricsPreview extends StatelessWidget {
  const _EmptyLyricsPreview({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lyrics_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: AppTypography.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

class _PanelActions extends ConsumerWidget {
  const _PanelActions({required this.playerState});

  final PlayerState playerState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActivelyPlaying = playerState.isPlaying && !playerState.isCompleted;

    return Row(
      children: [
        IconButton.filled(
          onPressed: () =>
              ref.read(playerNotifierProvider.notifier).togglePlayPause(),
          icon: Icon(isActivelyPlaying ? Icons.pause : Icons.play_arrow),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              context.go(AppRoutes.nowPlaying);
            },
            icon: const Icon(Icons.open_in_full, size: 18),
            label: const Text('Open full player'),
          ),
        ),
      ],
    );
  }
}
