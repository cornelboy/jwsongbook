import 'dart:convert';

class SongManifest {
  const SongManifest({required this.songs});

  factory SongManifest.fromJsonString(String source, {Uri? baseUri}) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Manifest root must be a JSON object.');
    }
    return SongManifest.fromJson(decoded, baseUri: baseUri);
  }

  factory SongManifest.fromJson(Map<String, Object?> json, {Uri? baseUri}) {
    final songsJson = json['songs'];
    if (songsJson is! List<Object?>) {
      throw const FormatException('Manifest songs must be a JSON array.');
    }

    final songs = songsJson.map((item) {
      if (item is! Map<String, Object?>) {
        throw const FormatException('Song manifest item is invalid.');
      }
      return RemoteSongAsset.fromJson(item, baseUri: baseUri);
    }).toList();

    final numbers = <int>{};
    for (final song in songs) {
      if (!numbers.add(song.number)) {
        throw FormatException(
          'Manifest contains duplicate song number ${song.number}.',
        );
      }
    }

    return SongManifest(songs: songs);
  }

  final List<RemoteSongAsset> songs;

  RemoteSongAsset? assetFor(int songNumber) {
    for (final song in songs) {
      if (song.number == songNumber) return song;
    }
    return null;
  }
}

class RemoteSongAsset {
  const RemoteSongAsset({
    required this.number,
    required this.version,
    this.title,
    this.durationMs,
    this.audioUrl,
    this.lyricsUrl,
    this.audioSizeBytes,
    this.lyricsSizeBytes,
  });

  factory RemoteSongAsset.fromJson(Map<String, Object?> json, {Uri? baseUri}) {
    final number = _requiredInt(json, 'number');
    if (number <= 0) {
      throw const FormatException('Manifest song number must be positive.');
    }

    final title = _optionalString(json, 'title');
    if (title != null && title.trim().isEmpty) {
      throw const FormatException('Manifest song title cannot be empty.');
    }

    final durationMs = _optionalInt(json, 'durationMs');
    if (durationMs != null && durationMs < 0) {
      throw const FormatException('Manifest durationMs cannot be negative.');
    }

    return RemoteSongAsset(
      number: number,
      title: title?.trim(),
      durationMs: durationMs,
      audioUrl: _optionalUri(json, 'audioUrl', baseUri: baseUri),
      lyricsUrl: _optionalUri(json, 'lyricsUrl', baseUri: baseUri),
      audioSizeBytes: _optionalInt(json, 'audioSize'),
      lyricsSizeBytes: _optionalInt(json, 'lyricsSize'),
      version: _optionalInt(json, 'version') ?? 1,
    );
  }

  final int number;
  final String? title;
  final int? durationMs;
  final Uri? audioUrl;
  final Uri? lyricsUrl;
  final int? audioSizeBytes;
  final int? lyricsSizeBytes;
  final int version;

  bool get hasAudio => audioUrl != null;

  bool get hasCatalogMetadata => title != null;

  static int _requiredInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw FormatException('Manifest field "$key" must be an integer.');
  }

  static int? _optionalInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is int) return value;
    throw FormatException('Manifest field "$key" must be an integer.');
  }

  static Uri? _optionalUri(
    Map<String, Object?> json,
    String key, {
    Uri? baseUri,
  }) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return _parseUri(value, baseUri: baseUri);
    throw FormatException('Manifest field "$key" must be a URL string.');
  }

  static Uri _parseUri(String value, {Uri? baseUri}) {
    if (value.trim().isEmpty) {
      throw const FormatException('Manifest URL cannot be empty.');
    }
    return baseUri?.resolve(value) ?? Uri.parse(value);
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Manifest field "$key" must be a string.');
  }
}
