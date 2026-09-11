import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/playlists_repository.dart';
import 'package:jwsongbook/data/services/song_download_service.dart';
import 'package:jwsongbook/features/downloads/actions/song_download_actions.dart';
import 'package:jwsongbook/features/downloads/providers/download_controller.dart';
import 'package:jwsongbook/features/favorites/actions/favorite_actions.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:jwsongbook/features/playlists/widgets/playlist_dialogs.dart';
import 'package:jwsongbook/shared/widgets/offline_download_icon.dart';

Future<void> showSongOptions(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  int? playlistId,
}) async {
  final status = ref.read(downloadControllerProvider).statusFor(song.number);
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.appColors.primaryPurple.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                song.paddedNumber,
                style: TextStyle(color: context.appColors.primaryPurple),
              ),
            ),
            title: Text(song.title),
            subtitle: Text(
              song.hasLocalAudio ? 'Available offline' : 'Not downloaded',
            ),
          ),
          const Divider(),
          for (final item in [
            (
              'favorite',
              song.isFavorited ? 'Remove from favorites' : 'Add to favorites',
              song.isFavorited ? Icons.favorite : Icons.favorite_border
            ),
            ('playlist', 'Add to playlist', Icons.playlist_add),
            if (playlistId != null)
              (
                'removeFromPlaylist',
                'Remove from this playlist',
                Icons.playlist_remove
              ),
            if (song.hasLocalAudio)
              ('removeDownload', 'Remove download', Icons.delete_outline)
            else
              (
                'download',
                status.isDownloading
                    ? 'Pause download'
                    : status.isPaused
                        ? 'Resume download'
                        : 'Download',
                Icons.arrow_downward_rounded
              ),
          ])
            ListTile(
              leading: item.$1 == 'download'
                  ? const OfflineStatusIcon.download(size: 24)
                  : Icon(item.$3),
              title: Text(item.$2),
              onTap: () => Navigator.pop(sheetContext, item.$1),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  await playlistAction(context, () async {
    switch (action) {
      case 'favorite':
        await toggleFavoriteWithFeedback(
          context: context,
          ref: ref,
          song: song,
        );
      case 'playlist':
        await showAddToPlaylist(context, ref, song);
      case 'removeFromPlaylist':
        await ref
            .read(playlistsRepositoryProvider)
            .remove(playlistId!, song.id);
      case 'download':
        if (status.isDownloading) {
          ref.read(downloadControllerProvider.notifier).pauseSong(song.number);
        } else {
          await downloadSongAndMaybePlay(
            context: context,
            ref: ref,
            song: song,
            playAfterDownload: false,
          );
        }
      case 'removeDownload':
        final confirmed = await confirmPlaylistAction(
          context,
          title: 'Remove download?',
          message: 'Remove the offline copy of song ${song.paddedNumber}? '
              'It stays in your library, favorites and playlists. '
              'If it is playing, playback will stop.',
          action: 'Remove',
        );
        if (!confirmed || !context.mounted) return;
        final service = ref.read(songDownloadServiceProvider);
        final downloads = ref.read(downloadControllerProvider.notifier);
        if (ref.read(playerNotifierProvider).currentSong?.id == song.id) {
          await ref.read(playerNotifierProvider.notifier).stop();
        }
        await service.removeDownload(song);
        downloads.clearSongStatuses([song.number]);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Song ${song.paddedNumber} removed.')),
          );
        }
    }
  });
}
