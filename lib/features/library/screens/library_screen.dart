import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/features/library/widgets/song_card.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = _query.isEmpty
        ? ref.watch(allSongsProvider)
        : ref.watch(searchSongsProvider(_query));
    final currentSong =
        ref.watch(playerNotifierProvider.select((s) => s.currentSong));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kingdom Songs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPaddingH,
              0,
              AppConstants.screenPaddingH,
              12,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Search by number or title…',
                prefixIcon: Icon(Icons.search, color: AppColors.textMedium),
                suffixIcon: null,
              ),
            ),
          ),
        ),
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load songs',
          subtitle: e.toString(),
        ),
        data: (songs) => songs.isEmpty
            ? const EmptyState(
                icon: Icons.search_off,
                title: 'No songs found',
                subtitle: 'Try a different search term.',
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
                    onTap: () => _playSong(song, context),
                    onFavoriteTap: () => _toggleFavorite(song),
                  );
                },
              ),
      ),
    );
  }

  void _playSong(Song song, BuildContext context) {
    ref.read(playerNotifierProvider.notifier).playSong(song);
    context.go(AppRoutes.nowPlaying);
  }

  void _toggleFavorite(Song song) {
    ref.read(songsRepositoryProvider).toggleFavorite(song);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final allSongsProvider =
    StreamProvider<List<Song>>((ref) => ref.watch(songsRepositoryProvider).watchAll());

final searchSongsProvider = StreamProvider.family<List<Song>, String>(
  (ref, query) => ref.watch(songsRepositoryProvider).watchSearch(query),
);
