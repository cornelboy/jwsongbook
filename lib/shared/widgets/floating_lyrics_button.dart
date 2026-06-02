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

class FloatingLyricsButton extends ConsumerWidget {
  const FloatingLyricsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(
      playerNotifierProvider.select((state) => state.currentSong),
    );
    final location = GoRouterState.of(context).uri.toString();

    if (song == null || location.startsWith(AppRoutes.nowPlaying)) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      heroTag: 'floating-lyrics-button',
      mini: true,
      tooltip: 'Show lyrics',
      onPressed: () => _showLyricsPanel(context),
      child: Text(
        song.paddedNumber,
        style: AppTypography.songNumber.copyWith(
          color: AppColors.background,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _showLyricsPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (_) => const _CompactLyricsPanel(),
    );
  }
}

class _CompactLyricsPanel extends ConsumerWidget {
  const _CompactLyricsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerNotifierProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final lyricsAsync = ref.watch(currentSongLyricsProvider);
    final cursor = ref.watch(syncCursorProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(song: song),
          const SizedBox(height: 18),
          lyricsAsync.when(
            loading: () => const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _EmptyLyricsPreview(message: e.toString()),
            data: (lyrics) => _LyricsPreview(
              lyrics: lyrics,
              cursor: cursor,
            ),
          ),
          const SizedBox(height: 18),
          _PanelActions(playerState: playerState),
        ],
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
  const _LyricsPreview({required this.lyrics, required this.cursor});

  final SyncedLyrics lyrics;
  final SyncCursor cursor;

  @override
  Widget build(BuildContext context) {
    if (lyrics.isEmpty) {
      return const _EmptyLyricsPreview(
        message: 'Synced lyrics for this song are coming soon.',
      );
    }

    final activeIndex = cursor.lineIndex >= 0 ? cursor.lineIndex : 0;
    final previewLines = lyrics.lines.skip(activeIndex).take(3).toList();

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
              Navigator.of(context).pop();
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
