import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/data/models/playback_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final playbackPreferencesRepositoryProvider =
    Provider<PlaybackPreferencesRepository>(
  (ref) => PlaybackPreferencesRepository(),
);

class PlaybackPreferencesRepository {
  static const _fileName = 'playback_preferences.json';

  PlaybackPreferences _current = const PlaybackPreferences();
  File? _file;
  Future<void> _writeQueue = Future<void>.value();

  PlaybackPreferences get current => _current;

  Future<void> load() async {
    try {
      final file = await _resolveFile();
      _file = file;
      if (!await file.exists()) return;

      final decoded = jsonDecode(await file.readAsString());
      _current = PlaybackPreferences.fromJson(decoded);
    } on Object {
      _current = const PlaybackPreferences();
    }
  }

  Future<void> save(PlaybackPreferences preferences) {
    // Make consecutive updates compose against the newest in-memory value even
    // while an earlier disk write is still queued.
    _current = preferences;
    final operation = _writeQueue.then<void>((_) async {
      final file = _file ??= await _resolveFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(preferences.toJson()),
        flush: true,
      );
    });

    // A failed write must not prevent later preference changes from saving.
    _writeQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<File> _resolveFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, _fileName));
  }
}
