import 'dart:async';

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

final floatingLyricsPanelOpenProvider = StateProvider<bool>((ref) => false);

/// Preserved Flutter reference for the floating lyrics design.
///
/// The production floating bubble is the Android overlay service so it can work
/// outside the app. Keep this widget as the design source for that native view.
class FloatingLyricsButton extends ConsumerStatefulWidget {
  const FloatingLyricsButton({super.key});

  @override
  ConsumerState<FloatingLyricsButton> createState() =>
      _FloatingLyricsButtonState();
}

class _FloatingLyricsButtonState extends ConsumerState<FloatingLyricsButton> {
  Offset? _position;
  bool _isDragging = false;
  bool _isButtonPressed = false;

  static const double _buttonSize = 60;
  static const double _touchSize = 110;
  static const double _edgePadding = 16;
  static const double _panelGap = 10;
  static const double _panelPreferredWidth = 300;
  static const double _panelEstimatedHeight = 220;
  static const Duration _snapDuration = Duration(milliseconds: 165);

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(
      playerNotifierProvider.select((state) => state.currentSong),
    );
    final location = GoRouterState.of(context).uri.toString();
    final isPanelOpen = ref.watch(floatingLyricsPanelOpenProvider);

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
            final defaultY = (constraints.maxHeight * 0.22).clamp(
              _edgePadding,
              maxY,
            );
            final defaultPosition = Offset(maxX, defaultY);
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
                if (isPanelOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => ref
                          .read(floatingLyricsPanelOpenProvider.notifier)
                          .state = false,
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (isPanelOpen)
                  Positioned(
                    left: panelPosition.dx,
                    top: panelPosition.dy,
                    width: panelWidth,
                    child: _FloatingLyricsPanel(
                      onClose: () => ref
                          .read(floatingLyricsPanelOpenProvider.notifier)
                          .state = false,
                    ),
                  ),
                AnimatedPositioned(
                  duration: _isDragging ? Duration.zero : _snapDuration,
                  curve: Curves.easeOutCubic,
                  left: position.dx - ((_touchSize - _buttonSize) / 2),
                  top: position.dy - ((_touchSize - _buttonSize) / 2),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      ref.read(floatingLyricsPanelOpenProvider.notifier).state =
                          !isPanelOpen;
                    },
                    onTapDown: (_) {
                      setState(() => _isButtonPressed = true);
                    },
                    onTapUp: (_) {
                      setState(() => _isButtonPressed = false);
                    },
                    onTapCancel: () {
                      setState(() => _isButtonPressed = false);
                    },
                    onPanStart: (details) {
                      setState(() {
                        _isDragging = true;
                        _isButtonPressed = false;
                        _position = _dragPositionFromGlobal(
                          context: context,
                          constraints: constraints,
                          globalPosition: details.globalPosition,
                        );
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _position = _dragPositionFromGlobal(
                          context: context,
                          constraints: constraints,
                          globalPosition: details.globalPosition,
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
                        child: Tooltip(
                          message: 'Show lyrics',
                          child: AnimatedScale(
                            scale: _isButtonPressed ? 0.94 : 1,
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOutCubic,
                            child: _FloatingLyricsIcon(
                              isOpen: isPanelOpen,
                              isDragging: _isDragging,
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

  Offset _dragPositionFromGlobal({
    required BuildContext context,
    required BoxConstraints constraints,
    required Offset globalPosition,
  }) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final localPosition =
        renderBox?.globalToLocal(globalPosition) ?? globalPosition;
    final rawPosition =
        localPosition - const Offset(_buttonSize / 2, _buttonSize / 2);

    return Offset(
      rawPosition.dx.clamp(0.0, constraints.maxWidth - _buttonSize),
      rawPosition.dy.clamp(0.0, constraints.maxHeight - _buttonSize),
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

class _FloatingLyricsIcon extends StatelessWidget {
  const _FloatingLyricsIcon({
    required this.isOpen,
    required this.isDragging,
  });

  final bool isOpen;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: _FloatingLyricsButtonState._buttonSize,
      height: _FloatingLyricsButtonState._buttonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primaryPurple,
        border: Border.all(
          color: isOpen
              ? colorScheme.onPrimary.withAlpha(190)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primaryPurple.withAlpha(isDragging ? 95 : 70),
            blurRadius: isDragging ? 22 : 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        Icons.lyrics_outlined,
        color: colorScheme.onPrimary,
        size: 28,
      ),
    );
  }
}

class _FloatingLyricsPanel extends ConsumerWidget {
  const _FloatingLyricsPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerNotifierProvider);
    final song = playerState.currentSong;
    final colors = context.appColors;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final lyricsAsync = ref.watch(currentSongLyricsProvider);
    final cursor = ref.watch(syncCursorProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.primaryPurple.withAlpha(70)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(150),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(song: song, onClose: onClose),
            const SizedBox(height: 12),
            lyricsAsync.when(
              loading: () => const SizedBox(
                height: 78,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _EmptyLyricsPreview(message: e.toString()),
              data: (lyrics) => _LyricsPreview(
                lyrics: lyrics,
                cursor: cursor,
                positionMs: playerState.positionMs,
              ),
            ),
            const SizedBox(height: 12),
            _PanelActions(playerState: playerState),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.song, required this.onClose});

  final Song song;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryPurple.withAlpha(36),
            border: Border.all(color: colors.primaryPurple.withAlpha(100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(song.paddedNumber, style: context.appText.songNumber),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appText.bodyMedium.copyWith(
                  color: colors.textHigh,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('Floating lyrics', style: context.appText.caption),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close lyrics',
          onPressed: onClose,
          icon: const Icon(Icons.close, size: 18),
          color: colors.textMedium,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
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

    return _LyricLinePreview(
      line: lyrics.lines[cursor.lineIndex],
      isActive: true,
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
    return _LyricLinePreview(line: line, isActive: false);
  }
}

class _LyricLinePreview extends StatelessWidget {
  const _LyricLinePreview({required this.line, required this.isActive});

  final SyncedLine line;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      style: context.appText.lyricsActive.copyWith(
        color: isActive ? colors.primaryPurple : colors.textMedium,
        fontSize: isActive ? 24 : 22,
        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          line.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
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
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lyrics_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: context.appText.bodyMedium)),
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
        const Spacer(),
        IconButton.outlined(
          tooltip: 'Open full player',
          onPressed: () {
            ref.read(floatingLyricsPanelOpenProvider.notifier).state = false;
            unawaited(context.push(AppRoutes.nowPlaying));
          },
          icon: const Icon(Icons.open_in_full, size: 18),
        ),
      ],
    );
  }
}
