import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/core/theme/app_typography.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/data/services/song_download_service.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';

final downloadedSongsInfoProvider =
    StreamProvider<List<DownloadedSongInfo>>((ref) async* {
  final service = ref.watch(songDownloadServiceProvider);

  await for (final songs
      in ref.watch(songsRepositoryProvider).watchDownloaded()) {
    final info = <DownloadedSongInfo>[];
    for (final song in songs) {
      info.add(
        DownloadedSongInfo(
          song: song,
          sizeBytes: await service.downloadedSizeBytes(song),
        ),
      );
    }
    yield info;
  }
});

final downloadedSongsSummaryProvider =
    StreamProvider<DownloadedSongsSummary>((ref) async* {
  final service = ref.watch(songDownloadServiceProvider);

  await for (final songs
      in ref.watch(songsRepositoryProvider).watchDownloaded()) {
    var totalBytes = 0;
    for (final song in songs) {
      totalBytes += await service.downloadedSizeBytes(song);
    }
    yield DownloadedSongsSummary(
      count: songs.length,
      totalBytes: totalBytes,
    );
  }
});

class DownloadedSongInfo {
  const DownloadedSongInfo({
    required this.song,
    required this.sizeBytes,
  });

  final Song song;
  final int sizeBytes;
}

class DownloadedSongsSummary {
  const DownloadedSongsSummary({
    required this.count,
    required this.totalBytes,
  });

  final int count;
  final int totalBytes;
}

class ManageDownloadsScreen extends ConsumerWidget {
  const ManageDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final infoAsync = ref.watch(downloadedSongsInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Downloads')),
      body: infoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load downloads',
          subtitle: error.toString(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.download_done_outlined,
              title: 'No downloaded songs',
              subtitle: 'Downloaded songs will appear here.',
            );
          }

          final totalBytes = items.fold<int>(
            0,
            (sum, item) => sum + item.sizeBytes,
          );

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _SummaryHeader(
                count: items.length,
                totalBytes: totalBytes,
                onRemoveAll: () => _confirmRemoveAll(context, ref, items),
              ),
              Divider(height: 1, color: colors.divider),
              ...items.map(
                (item) => _DownloadedSongTile(
                  info: item,
                  onRemove: () => _confirmRemoveSong(context, ref, item.song),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmRemoveSong(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove download?'),
        content: Text('Remove "${song.title}" from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await _removeSongs(context, ref, [song]);
  }

  Future<void> _confirmRemoveAll(
    BuildContext context,
    WidgetRef ref,
    List<DownloadedSongInfo> items,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove all downloads?'),
        content: const Text(
          'Downloaded songs will be removed from this device. Bundled starter songs remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove all'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await _removeSongs(
      context,
      ref,
      items.map((item) => item.song).toList(),
    );
  }

  Future<void> _removeSongs(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
  ) async {
    final playerState = ref.read(playerNotifierProvider);
    final currentSong = playerState.currentSong;
    if (currentSong != null && songs.any((song) => song.id == currentSong.id)) {
      await ref.read(playerNotifierProvider.notifier).stop();
    }

    final service = ref.read(songDownloadServiceProvider);
    await service.removeAllDownloads(songs);
    ref
        .read(downloadControllerProvider.notifier)
        .clearSongStatuses(songs.map((song) => song.number));
    ref.invalidate(downloadedSongsInfoProvider);
    ref.invalidate(downloadedSongsSummaryProvider);

    if (context.mounted) {
      final label = songs.length == 1
          ? 'Song ${songs.single.paddedNumber} removed.'
          : '${songs.length} songs removed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(label)),
      );
    }
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.count,
    required this.totalBytes,
    required this.onRemoveAll,
  });

  final int count;
  final int totalBytes;
  final VoidCallback onRemoveAll;

  @override
  Widget build(BuildContext context) {
    final songLabel = count == 1 ? 'song' : 'songs';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Downloaded songs', style: context.appText.displayTitle),
          const SizedBox(height: 6),
          Text(
            '$count $songLabel - ${formatDownloadBytes(totalBytes)}',
            style: context.appText.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRemoveAll,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove all downloads'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appColors.error,
              side: BorderSide(color: context.appColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadedSongTile extends StatelessWidget {
  const _DownloadedSongTile({
    required this.info,
    required this.onRemove,
  });

  final DownloadedSongInfo info;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final song = info.song;
    final colors = context.appColors;

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.divider),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Text(song.paddedNumber, style: context.appText.songNumber),
      ),
      title: Text(
        song.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(formatDownloadBytes(info.sizeBytes)),
      trailing: IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.delete_outline),
        color: colors.textMedium,
        tooltip: 'Remove download',
      ),
    );
  }
}

String formatDownloadBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  const kb = 1024;
  const mb = kb * 1024;

  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
  return '${(bytes / kb).ceil()} KB';
}
