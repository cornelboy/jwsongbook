import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';

const _favoriteUndoDuration = Duration(seconds: 5);

Future<void> toggleFavoriteWithFeedback({
  required BuildContext context,
  required WidgetRef ref,
  required Song song,
}) async {
  final wasFavorited = song.isFavorited;
  final repository = ref.read(songsRepositoryProvider);
  await repository.setFavorite(song, value: !wasFavorited);

  if (!wasFavorited || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Removed from favorites'),
      duration: _favoriteUndoDuration,
      persist: false,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => unawaited(
          repository.setFavorite(song, value: true),
        ),
      ),
    ),
  );
}
