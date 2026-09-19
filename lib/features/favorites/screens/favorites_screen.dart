import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/features/downloads/actions/song_download_actions.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:jwsongbook/features/library/widgets/song_card.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final favoritesAsync = ref.watch(_favoritesProvider);
    final currentSong =
        ref.watch(playerNotifierProvider.select((s) => s.currentSong));
    final isPlaying = ref.watch(
      playerNotifierProvider.select(
        (state) => state.isPlaying && !state.isCompleted,
      ),
    );
    final downloadState = ref.watch(downloadControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load favorites',
          subtitle: e.toString(),
        ),
        data: (songs) => songs.isEmpty
            ? EmptyState(
                icon: Icons.favorite_outline,
                title: 'No favorites yet',
                subtitle:
                    'Open a song’s three-dot menu and choose Add to favorites.',
                action: FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.library),
                  icon: const Icon(Icons.library_music_outlined),
                  label: const Text('Browse songs'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FavoritesHeader(count: songs.length),
                  Divider(height: 1, color: colors.divider),
                  Expanded(
                    child: ListView.separated(
                      itemCount: songs.length,
                      padding: const EdgeInsets.only(bottom: 8),
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: colors.divider,
                        indent: 76,
                      ),
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final downloadStatus =
                            downloadState.statusFor(song.number);
                        return SongCard(
                          song: song,
                          isCurrentlyPlaying: currentSong?.id == song.id,
                          showPlaybackIndicator:
                              currentSong?.id == song.id && isPlaying,
                          downloadStatus: downloadStatus,
                          showDownloadedIndicator: false,
                          onTap: () => unawaited(_playSong(song, context, ref)),
                          onDownloadTap: () => _handleDownloadAction(
                            song,
                            context,
                            ref,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _playSong(
    Song song,
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!song.hasLocalAudio) {
      await downloadAndPlaySong(
        context: context,
        ref: ref,
        song: song,
      );
      return;
    }

    if (context.mounted) {
      supersedePendingDownloadPlayback(ref);
      unawaited(context.push(AppRoutes.nowPlayingSongPath(song.number)));
    }
  }

  Future<void> _downloadSong(
    Song song,
    BuildContext context,
    WidgetRef ref,
  ) async {
    await downloadSongAndMaybePlay(
      context: context,
      ref: ref,
      song: song,
      playAfterDownload: false,
    );
  }

  void _handleDownloadAction(
    Song song,
    BuildContext context,
    WidgetRef ref,
  ) {
    final status = ref.read(downloadControllerProvider).statusFor(song.number);
    if (status.isDownloading) {
      ref.read(downloadControllerProvider.notifier).pauseSong(song.number);
      return;
    }
    unawaited(_downloadSong(song, context, ref));
  }
}

class _FavoritesHeader extends StatelessWidget {
  const _FavoritesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 favorite' : '$count favorites';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        0,
        AppConstants.screenPaddingH,
        12,
      ),
      child: Text(label, style: context.appText.caption),
    );
  }
}

final _favoritesProvider = StreamProvider<List<Song>>(
  (ref) => ref.watch(songsRepositoryProvider).watchFavorites(),
);
