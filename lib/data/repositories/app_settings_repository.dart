import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/data/models/app_settings.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => AppSettingsRepository(),
);

class AppSettingsRepository {
  static const _fileName = 'app_settings.json';

  AppSettings _current = const AppSettings();
  File? _file;
  Future<void> _writeQueue = Future<void>.value();

  AppSettings get current => _current;

  Future<void> load() async {
    try {
      final file = await _resolveFile();
      _file = file;
      if (!await file.exists()) return;

      _current = AppSettings.fromJson(jsonDecode(await file.readAsString()));
    } on Object {
      _current = const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) {
    _current = settings;
    final operation = _writeQueue.then<void>((_) async {
      final file = _file ??= await _resolveFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
    });

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
