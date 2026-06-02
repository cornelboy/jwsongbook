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
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:jwsongbook/features/library/widgets/song_card.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(_favoritesProvider);
    final currentSong =
        ref.watch(playerNotifierProvider.select((s) => s.currentSong));
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
                subtitle: 'Tap the heart icon on a song to save it here.',
                action: FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.library),
                  icon: const Icon(Icons.library_music_outlined),
                  label: const Text('Browse songs'),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FavoritesHeader(count: songs.length),
                  const Divider(height: 1, color: AppColors.divider),
                  Expanded(
                    child: ListView.separated(
                      itemCount: songs.length,
                      padding: const EdgeInsets.only(bottom: 8),
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: AppColors.divider,
                        indent: 76,
                      ),
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return SongCard(
                          song: song,
                          isCurrentlyPlaying: currentSong?.id == song.id,
                          downloadStatus: downloadState.statusFor(song.number),
                          onTap: () => _playSong(song, context, ref),
                          onDownloadTap: () =>
                              _downloadSong(song, context, ref),
                          onFavoriteTap: () => ref
                              .read(songsRepositoryProvider)
                              .toggleFavorite(song),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _playSong(Song song, BuildContext context, WidgetRef ref) {
    if (!song.hasLocalAudio) {
      _downloadSong(song, context, ref);
      return;
    }

    ref.read(playerNotifierProvider.notifier).playSong(song);
    context.go(AppRoutes.nowPlaying);
  }

  Future<void> _downloadSong(
    Song song,
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref.read(downloadControllerProvider.notifier).downloadSong(song);
    if (!context.mounted) return;

    final status = ref.read(downloadControllerProvider).statusFor(song.number);
    if (status.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status.message ?? 'Download failed.')),
      );
    }
  }
}

class _FavoritesHeader extends StatelessWidget {
  const _FavoritesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? 'song saved' : 'songs saved';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        0,
        AppConstants.screenPaddingH,
        12,
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, size: 16, color: AppColors.primaryPurple),
          const SizedBox(width: 6),
          Text('$count $label', style: AppTypography.caption),
        ],
      ),
    );
  }
}

final _favoritesProvider = StreamProvider<List<Song>>(
  (ref) => ref.watch(songsRepositoryProvider).watchFavorites(),
);
