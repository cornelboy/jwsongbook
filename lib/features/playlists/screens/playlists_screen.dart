import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jwsongbook/core/router/app_router.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/repositories/playlists_repository.dart';
import 'package:jwsongbook/features/playlists/widgets/playlist_cover.dart';
import 'package:jwsongbook/features/playlists/widgets/playlist_dialogs.dart';
import 'package:jwsongbook/shared/widgets/empty_state.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    Future<void> create() async {
      final repository = ref.read(playlistsRepositoryProvider);
      final name = await askPlaylistName(context);
      if (name == null || !context.mounted) return;
      await playlistAction(context, () async {
        final id = await repository.create(name);
        if (context.mounted) {
          unawaited(context.push(AppRoutes.playlistPath(id)));
        }
      });
    }

    Future<void> managePlaylist(Playlist playlist, String action) async {
      final repository = ref.read(playlistsRepositoryProvider);
      if (action == 'rename') {
        final name = await askPlaylistName(context, initial: playlist.name);
        if (name == null || !context.mounted) return;
        await playlistAction(
          context,
          () => repository.rename(playlist.id, name),
        );
        return;
      }

      final confirmed = await confirmPlaylistAction(
        context,
        title: 'Delete playlist?',
        message: 'Delete “${playlist.name}”? '
            'Your songs, downloads and favorites will not be removed.',
        action: 'Delete',
      );
      if (!confirmed || !context.mounted) return;
      await playlistAction(context, () => repository.delete(playlist.id));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            onPressed: create,
            tooltip: 'New playlist',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ref.watch(playlistsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load playlists',
              subtitle: 'Please try again.',
            ),
            data: (items) => items.isEmpty
                ? EmptyState(
                    icon: Icons.playlist_play,
                    title: 'Your songs, your order',
                    subtitle:
                        'Create a playlist for personal listening or song practice.',
                    action: FilledButton.icon(
                      onPressed: create,
                      icon: const Icon(Icons.add),
                      label: const Text('New playlist'),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final count = ref
                          .watch(playlistSongsProvider(item.id))
                          .asData
                          ?.value
                          .length;
                      return Material(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          minTileHeight: 72,
                          contentPadding: const EdgeInsets.only(left: 12),
                          leading: PlaylistCover(name: item.name),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            count == null
                                ? 'Loading…'
                                : '$count ${count == 1 ? 'song' : 'songs'}',
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Options for ${item.name}',
                            onSelected: (action) =>
                                managePlaylist(item, action),
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
                          onTap: () =>
                              context.push(AppRoutes.playlistPath(item.id)),
                        ),
                      );
                    },
                  ),
          ),
    );
  }
}
