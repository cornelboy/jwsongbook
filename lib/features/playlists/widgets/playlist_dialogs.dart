import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/core/theme/app_colors.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/repositories/playlists_repository.dart';

Future<String?> askPlaylistName(BuildContext context, {String? initial}) =>
    showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.appColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PlaylistNameSheet(initial: initial),
    );

class _PlaylistNameSheet extends StatefulWidget {
  const _PlaylistNameSheet({this.initial});

  final String? initial;

  @override
  State<_PlaylistNameSheet> createState() => _PlaylistNameSheetState();
}

class _PlaylistNameSheetState extends State<_PlaylistNameSheet> {
  late final controller = TextEditingController(text: widget.initial);

  bool get isCreating => widget.initial == null;
  bool get canSubmit => controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    if (canSubmit) {
      Navigator.pop(context, controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCreating ? 'Create playlist' : 'Rename playlist',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: context.appColors.textHigh,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Playlist name',
                hintText: 'e.g. Meeting songs',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: canSubmit ? submit : null,
                child: Text(isCreating ? 'Create playlist' : 'Save changes'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmPlaylistAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<void> playlistAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your change. Please try again.'),
        ),
      );
    }
  }
}

Future<void> showAddToPlaylist(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  final repository = ref.read(playlistsRepositoryProvider);
  final selected = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const _PlaylistPicker(),
  );
  if (selected == null || !context.mounted) return;
  await playlistAction(context, () async {
    var id = selected;
    if (id == -1) {
      final name = await askPlaylistName(context);
      if (name == null) return;
      id = await repository.create(name);
    }
    await repository.add(id, song.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song saved to playlist.')),
      );
    }
  });
}

class _PlaylistPicker extends ConsumerWidget {
  const _PlaylistPicker();
  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          children: [
            const ListTile(title: Text('Add to playlist')),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New playlist'),
              onTap: () => Navigator.pop(context, -1),
            ),
            Expanded(
              child: ref.watch(playlistsProvider).when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) =>
                        const Center(child: Text('Could not load playlists.')),
                    data: (items) => ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(items[i].name),
                        onTap: () => Navigator.pop(context, items[i].id),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      );
}
