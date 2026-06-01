import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/features/player/widgets/lyrics_view.dart';
import 'package:jwsongbook/features/player/widgets/player_controls.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, this.initialSongNumber});

  /// When navigated to via /song/:number, auto-play this song exactly once.
  final int? initialSongNumber;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger only once on mount — never on rebuild.
    if (widget.initialSongNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final song = await ref
            .read(songsRepositoryProvider)
            .getByNumber(widget.initialSongNumber!);
        if (song != null && mounted) {
          await ref.read(playerNotifierProvider.notifier).playSong(song);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerNotifierProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Now Playing')),
        body: const EmptyState(
          icon: Icons.music_note_outlined,
          title: 'Nothing playing',
          subtitle: 'Pick a song from the library to start.',
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _NowPlayingHeader(song: song),
            const Expanded(child: LyricsView()),
            const PlayerControls(),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingHeader extends StatelessWidget {
  const _NowPlayingHeader({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            _SongNumberBadge(song: song),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.songTitle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Kingdom Song',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            _FavoriteButton(song: song),
          ],
        ),
      ),
    );
  }
}

class _SongNumberBadge extends StatelessWidget {
  const _SongNumberBadge({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryPurple.withAlpha(70)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            song.paddedNumber,
            style: AppTypography.songNumber.copyWith(fontSize: 15),
          ),
          Text(
            'Song',
            style: AppTypography.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(
        song.isFavorited ? Icons.favorite : Icons.favorite_outline,
        color: song.isFavorited ? AppColors.primaryPurple : null,
      ),
      onPressed: () => ref.read(songsRepositoryProvider).toggleFavorite(song),
    );
  }
}
