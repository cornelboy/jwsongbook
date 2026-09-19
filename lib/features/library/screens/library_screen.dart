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
    final colors = context.appColors;
    final songsAsync = _query.isEmpty
        ? ref.watch(allSongsProvider)
        : ref.watch(searchSongsProvider(_query));
    final currentSong =
        ref.watch(playerNotifierProvider.select((s) => s.currentSong));
    final isPlaying = ref.watch(
      playerNotifierProvider.select(
        (state) => state.isPlaying && !state.isCompleted,
      ),
    );
    final downloadState = ref.watch(downloadControllerProvider);
    final hasQuery = _query.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        title: const Text('JW Songs'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
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
              style: context.appText.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search number or title',
                prefixIcon: Icon(
                  Icons.search,
                  color: colors.textMedium,
                ),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        color: colors.textMedium,
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                      )
                    : null,
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
            : ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _SongListHeading(
                    title: hasQuery ? 'Search Results' : 'All Songs',
                    count: songs.length,
                  ),
                  ...List.generate(songs.length, (index) {
                    final song = songs[index];
                    final downloadStatus = downloadState.statusFor(song.number);
                    return Column(
                      children: [
                        if (index > 0)
                          Divider(
                            height: 1,
                            color: colors.divider,
                            indent: 72,
                          ),
                        SongCard(
                          song: song,
                          isCurrentlyPlaying: currentSong?.id == song.id,
                          showPlaybackIndicator:
                              currentSong?.id == song.id && isPlaying,
                          downloadStatus: downloadStatus,
                          onTap: () => unawaited(_playSong(song, context)),
                          onDownloadTap: () => _handleDownloadAction(
                            song,
                            context,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Future<void> _playSong(Song song, BuildContext context) async {
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

  Future<void> _downloadSong(Song song, BuildContext context) async {
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
  ) {
    final status = ref.read(downloadControllerProvider).statusFor(song.number);
    if (status.isDownloading) {
      ref.read(downloadControllerProvider.notifier).pauseSong(song.number);
      return;
    }
    unawaited(_downloadSong(song, context));
  }
}

class _SongListHeading extends StatelessWidget {
  const _SongListHeading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 song' : '$count songs';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: context.appText.bodyMedium.copyWith(
              color: context.appColors.textHigh,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(label, style: context.appText.caption),
        ],
      ),
    );
  }
}

final allSongsProvider = StreamProvider<List<Song>>(
  (ref) => ref.watch(songsRepositoryProvider).watchAll(),
);

final searchSongsProvider = StreamProvider.family<List<Song>, String>(
  (ref, query) => ref.watch(songsRepositoryProvider).watchSearch(query),
);
