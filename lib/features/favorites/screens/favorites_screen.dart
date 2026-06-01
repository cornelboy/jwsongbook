import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
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
            ? const EmptyState(
                icon: Icons.favorite_outline,
                title: 'No favorites yet',
                subtitle:
                    'Tap the heart icon on any song in the library to save it here.',
              )
            : ListView.separated(
                itemCount: songs.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: AppColors.divider,
                  indent: 72,
                ),
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return SongCard(
                    song: song,
                    isCurrentlyPlaying: currentSong?.id == song.id,
                    onTap: () => _playSong(song, context, ref),
                    onFavoriteTap: () =>
                        ref.read(songsRepositoryProvider).toggleFavorite(song),
                  );
                },
              ),
      ),
    );
  }

  void _playSong(Song song, BuildContext context, WidgetRef ref) {
    ref.read(playerNotifierProvider.notifier).playSong(song);
    context.go(AppRoutes.nowPlaying);
  }
}

final _favoritesProvider = StreamProvider<List<Song>>(
  (ref) => ref.watch(songsRepositoryProvider).watchFavorites(),
);
