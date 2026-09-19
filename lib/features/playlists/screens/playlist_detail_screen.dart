import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/playlists_repository.dart';
import 'package:jwsongbook/features/downloads/actions/song_download_actions.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:jwsongbook/features/library/screens/library_screen.dart';
import 'package:jwsongbook/features/library/widgets/song_card.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/features/playlists/widgets/playlist_cover.dart';
import 'package:jwsongbook/features/playlists/widgets/playlist_dialogs.dart';
import 'package:jwsongbook/shared/widgets/offline_download_icon.dart';

final playlistDownloadInProgressProvider =
    StateProvider.autoDispose.family<bool, int>((ref, playlistId) => false);
final playlistReorderModeProvider =
    StateProvider.autoDispose.family<bool, int>((ref, playlistId) => false);

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});
  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).asData?.value ?? [];
    final matches = playlists.where((p) => p.id == playlistId);
    final playlist = matches.isEmpty ? null : matches.first;
    final downloads = ref.watch(downloadControllerProvider);
    final downloadInProgress =
        ref.watch(playlistDownloadInProgressProvider(playlistId));
    final isReordering = ref.watch(playlistReorderModeProvider(playlistId));
    final playerState = ref.watch(playerNotifierProvider);
    final current = playerState.currentSong?.id;
    return Scaffold(
      appBar: AppBar(
        title: isReordering ? const Text('Reorder songs') : null,
        actions: [
          if (isReordering)
            TextButton(
              onPressed: () => ref
                  .read(playlistReorderModeProvider(playlistId).notifier)
                  .state = false,
              child: const Text('Done'),
            )
          else if (playlist != null)
            PopupMenuButton<String>(
              tooltip: 'Playlist options',
              onSelected: (action) async {
                final repo = ref.read(playlistsRepositoryProvider);
                if (action == 'rename') {
                  final name =
                      await askPlaylistName(context, initial: playlist.name);
                  if (name != null && context.mounted) {
                    await playlistAction(
                      context,
                      () => repo.rename(playlistId, name),
                    );
                  }
                } else {
                  final confirmed = await confirmPlaylistAction(
                    context,
                    title: 'Delete playlist?',
                    message: 'Delete “${playlist.name}”? '
                        'Your songs, downloads and favorites will not be removed.',
                    action: 'Delete',
                  );
                  if (!confirmed || !context.mounted) return;
                  await playlistAction(context, () async {
                    await repo.delete(playlistId);
                    if (context.mounted) context.go(AppRoutes.playlists);
                  });
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename playlist'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete playlist'),
                ),
              ],
            ),
        ],
      ),
      body: ref.watch(playlistSongsProvider(playlistId)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Could not load songs.')),
            data: (songs) {
              final playable = songs
                  .where(
                    (song) =>
                        song.hasLocalAudio ||
                        downloads.statusFor(song.number).isDownloaded,
                  )
                  .toList();
              final missing = songs
                  .where(
                    (song) =>
                        !song.hasLocalAudio &&
                        !downloads.statusFor(song.number).isDownloaded,
                  )
                  .toList();
              final hasCurrentPlaylistSong =
                  current != null && songs.any((song) => song.id == current);
              final isPlaylistPlaying = hasCurrentPlaylistSong &&
                  playerState.isPlaying &&
                  !playerState.isCompleted;
              return Column(
                children: [
                  if (isReordering)
                    _ReorderInstructions(songCount: songs.length)
                  else
                    _PlaylistHeader(
                      playlistName: playlist?.name ?? 'Playlist',
                      songCount: songs.length,
                      downloadedCount: playable.length,
                      unavailableCount: missing.length,
                      downloadInProgress: downloadInProgress,
                      onPlay: playable.isEmpty
                          ? null
                          : hasCurrentPlaylistSong
                              ? () => unawaited(
                                    ref
                                        .read(playerNotifierProvider.notifier)
                                        .togglePlayPause(),
                                  )
                              : () => _play(
                                    context,
                                    ref,
                                    songs,
                                    songs.indexOf(playable.first),
                                  ),
                      isPlaying: isPlaylistPlaying,
                      onDownload: missing.isEmpty || downloadInProgress
                          ? null
                          : () => unawaited(
                                _downloadMissing(context, ref, missing),
                              ),
                      onAddSongs: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              _AddSongsScreen(playlistId: playlistId),
                        ),
                      ),
                      onReorder: songs.length < 2
                          ? null
                          : () => ref
                              .read(
                                playlistReorderModeProvider(playlistId)
                                    .notifier,
                              )
                              .state = true,
                    ),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: songs.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final ids = songs.map((s) => s.id).toList();
                        ids.insert(newIndex, ids.removeAt(oldIndex));
                        playlistAction(
                          context,
                          () => ref
                              .read(playlistsRepositoryProvider)
                              .reorder(playlistId, ids),
                        );
                      },
                      itemBuilder: (context, i) {
                        final song = songs[i];
                        final status = downloads.statusFor(song.number);
                        return Row(
                          key: ValueKey(song.id),
                          children: [
                            Expanded(
                              child: SongCard(
                                song: song,
                                playlistId: playlistId,
                                isCurrentlyPlaying: current == song.id,
                                showPlaybackIndicator: current == song.id &&
                                    playerState.isPlaying &&
                                    !playerState.isCompleted,
                                downloadStatus: status,
                                showOptions: !isReordering,
                                onTap: isReordering
                                    ? null
                                    : current == song.id
                                        ? () => unawaited(
                                              context.push(
                                                AppRoutes.nowPlaying,
                                              ),
                                            )
                                        : () => _play(context, ref, songs, i),
                                onDownloadTap: () {
                                  if (status.isDownloading) {
                                    ref
                                        .read(
                                          downloadControllerProvider.notifier,
                                        )
                                        .pauseSong(song.number);
                                  } else {
                                    downloadSongAndMaybePlay(
                                      context: context,
                                      ref: ref,
                                      song: song,
                                      playAfterDownload: false,
                                    );
                                  }
                                },
                              ),
                            ),
                            if (isReordering)
                              ReorderableDragStartListener(
                                index: i,
                                child: const Tooltip(
                                  message: 'Drag to reorder',
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Icon(Icons.drag_handle),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _downloadMissing(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
  ) async {
    ref.read(playlistDownloadInProgressProvider(playlistId).notifier).state =
        true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Downloading ${songs.length} ${songs.length == 1 ? 'song' : 'songs'}…',
        ),
      ),
    );

    try {
      await ref.read(downloadControllerProvider.notifier).downloadSongs(songs);
      if (!context.mounted) return;
      final state = ref.read(downloadControllerProvider);
      final downloaded = songs
          .where((song) => state.statusFor(song.number).isDownloaded)
          .length;
      final failed =
          songs.where((song) => state.statusFor(song.number).hasError).length;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failed == 0
                ? '$downloaded ${downloaded == 1 ? 'song' : 'songs'} downloaded.'
                : '$downloaded downloaded. $failed failed.',
          ),
        ),
      );
    } finally {
      if (context.mounted) {
        ref
            .read(playlistDownloadInProgressProvider(playlistId).notifier)
            .state = false;
      }
    }
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
    int index,
  ) async {
    if (!songs[index].hasLocalAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download this song first, then tap to play.'),
        ),
      );
      return;
    }
    await ref
        .read(playerNotifierProvider.notifier)
        .playPlaylist(songs, startIndex: index);
    supersedePendingDownloadPlayback(ref);
  }
}

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({
    required this.playlistName,
    required this.songCount,
    required this.downloadedCount,
    required this.unavailableCount,
    required this.downloadInProgress,
    required this.onPlay,
    required this.isPlaying,
    required this.onDownload,
    required this.onAddSongs,
    required this.onReorder,
  });

  final String playlistName;
  final int songCount;
  final int downloadedCount;
  final int unavailableCount;
  final bool downloadInProgress;
  final VoidCallback? onPlay;
  final bool isPlaying;
  final VoidCallback? onDownload;
  final VoidCallback onAddSongs;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PlaylistCover(name: playlistName, size: 88),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlistName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        color: colors.textHigh,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$songCount ${songCount == 1 ? 'song' : 'songs'} • '
                      '$downloadedCount downloaded',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.textMedium,
                      ),
                    ),
                    if (unavailableCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$unavailableCount unavailable offline',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _PlaylistHeaderAction(
                label: downloadInProgress
                    ? 'Working'
                    : unavailableCount == 0
                        ? 'Offline'
                        : 'Download',
                tooltip: unavailableCount == 0
                    ? 'Playlist available offline'
                    : 'Download all unavailable songs',
                icon: unavailableCount == 0
                    ? const OfflineStatusIcon.downloaded(size: 23)
                    : const OfflineStatusIcon.download(size: 23),
                isLoading: downloadInProgress,
                onPressed: onDownload,
              ),
              _PlaylistHeaderAction(
                label: 'Add',
                tooltip: 'Add songs',
                icon: const Icon(Icons.playlist_add_rounded, size: 23),
                onPressed: onAddSongs,
              ),
              _PlaylistHeaderAction(
                label: 'Reorder',
                tooltip: 'Edit song order',
                icon: const Icon(Icons.swap_vert_rounded, size: 23),
                onPressed: onReorder,
              ),
              const Spacer(),
              Tooltip(
                message:
                    isPlaying ? 'Pause playlist' : 'Play playlist in order',
                child: IconButton.filled(
                  key: const ValueKey('playlist-play-button'),
                  onPressed: onPlay,
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(56),
                    backgroundColor: colors.primaryPurple,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    disabledBackgroundColor: colors.card,
                    disabledForegroundColor: colors.textInactive,
                  ),
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
          if (songCount == 0) ...[
            const SizedBox(height: 12),
            Text(
              'Add songs to start this playlist.',
              style: textTheme.bodyMedium?.copyWith(color: colors.textMedium),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaylistHeaderAction extends StatelessWidget {
  const _PlaylistHeaderAction({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            onPressed: onPressed,
            tooltip: tooltip,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(48),
              foregroundColor: colors.primaryPurple,
              disabledForegroundColor: colors.textInactive,
              side: BorderSide(color: colors.divider),
            ),
            icon: isLoading
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primaryPurple,
                    ),
                  )
                : icon,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: onPressed == null
                      ? colors.textInactive
                      : colors.textMedium,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReorderInstructions extends StatelessWidget {
  const _ReorderInstructions({required this.songCount});

  final int songCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Icon(Icons.drag_handle_rounded, color: colors.primaryPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              songCount < 2
                  ? 'Add another song before reordering.'
                  : 'Drag songs into your preferred order.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textMedium,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSongsScreen extends ConsumerStatefulWidget {
  const _AddSongsScreen({required this.playlistId});
  final int playlistId;
  @override
  ConsumerState<_AddSongsScreen> createState() => _AddSongsScreenState();
}

class _AddSongsScreenState extends ConsumerState<_AddSongsScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final selected =
        ref.watch(playlistSongsProvider(widget.playlistId)).asData?.value;
    final ids = selected?.map((s) => s.id).toSet() ?? <int>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Add songs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search number or title',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: ref.watch(allSongsProvider).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      const Center(child: Text('Could not load songs.')),
                  data: (all) {
                    final songs = all
                        .where(
                          (s) =>
                              s.title.toLowerCase().contains(query) ||
                              s.paddedNumber.contains(query),
                        )
                        .toList();
                    return ListView.builder(
                      itemCount: songs.length,
                      itemBuilder: (context, i) {
                        final song = songs[i];
                        return ListTile(
                          leading: Text(song.paddedNumber),
                          title: Text(song.title),
                          trailing: Icon(
                            ids.contains(song.id)
                                ? Icons.check_circle
                                : Icons.add_circle_outline,
                          ),
                          onTap: selected == null || ids.contains(song.id)
                              ? null
                              : () => playlistAction(
                                    context,
                                    () => ref
                                        .read(playlistsRepositoryProvider)
                                        .add(widget.playlistId, song.id),
                                  ),
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
