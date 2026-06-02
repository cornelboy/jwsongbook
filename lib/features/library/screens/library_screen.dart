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
    final downloadState = ref.watch(downloadControllerProvider);
    final hasQuery = _query.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kingdom Songs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPaddingH,
              0,
              AppConstants.screenPaddingH,
              12,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: AppTypography.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Search number or title',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textMedium,
                    ),
                    suffixIcon: hasQuery
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            color: AppColors.textMedium,
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                _LibraryStatusLine(query: _query, songsAsync: songsAsync),
              ],
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
                padding: const EdgeInsets.only(bottom: 8),
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
                    downloadStatus: downloadState.statusFor(song.number),
                    onTap: () => _playSong(song, context),
                    onDownloadTap: () => _openDownload(song, context),
                    onFavoriteTap: () => _toggleFavorite(song),
                  );
                },
              ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _playSong(Song song, BuildContext context) {
    if (!song.hasLocalAudio) {
      _openDownload(song, context);
      return;
    }

    ref.read(playerNotifierProvider.notifier).playSong(song);
    context.go(AppRoutes.nowPlaying);
  }

  void _openDownload(Song song, BuildContext context) {
    context.go(AppRoutes.downloadPath(song.number));
  }

  void _toggleFavorite(Song song) {
    ref.read(songsRepositoryProvider).toggleFavorite(song);
  }
}

class _LibraryStatusLine extends StatelessWidget {
  const _LibraryStatusLine({required this.query, required this.songsAsync});

  final String query;
  final AsyncValue<List<Song>> songsAsync;

  @override
  Widget build(BuildContext context) {
    final text = songsAsync.maybeWhen(
      data: (songs) {
        final label = songs.length == 1 ? 'song' : 'songs';
        if (query.isEmpty) return '${songs.length} $label';
        return '${songs.length} found for "$query"';
      },
      orElse: () => ' ',
    );

    return Row(
      children: [
        const Icon(Icons.library_music_outlined, size: 16),
        const SizedBox(width: 6),
        Text(text, style: AppTypography.caption),
      ],
    );
  }
}

final allSongsProvider = StreamProvider<List<Song>>(
  (ref) => ref.watch(songsRepositoryProvider).watchAll(),
);

final searchSongsProvider = StreamProvider.family<List<Song>, String>(
  (ref, query) => ref.watch(songsRepositoryProvider).watchSearch(query),
);
