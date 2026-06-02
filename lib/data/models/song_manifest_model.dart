import 'dart:convert';

class SongManifest {
  const SongManifest({required this.songs});

  factory SongManifest.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Manifest root must be a JSON object.');
    }
    return SongManifest.fromJson(decoded);
  }

  factory SongManifest.fromJson(Map<String, Object?> json) {
    final songsJson = json['songs'];
    if (songsJson is! List<Object?>) {
      throw const FormatException('Manifest songs must be a JSON array.');
    }

    return SongManifest(
      songs: songsJson.map((item) {
        if (item is! Map<String, Object?>) {
          throw const FormatException('Song manifest item is invalid.');
        }
        return RemoteSongAsset.fromJson(item);
      }).toList(),
    );
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
    required this.audioUrl,
    required this.version,
    this.lyricsUrl,
    this.audioSizeBytes,
    this.lyricsSizeBytes,
  });

  factory RemoteSongAsset.fromJson(Map<String, Object?> json) {
    return RemoteSongAsset(
      number: _requiredInt(json, 'number'),
      audioUrl: _requiredUri(json, 'audioUrl'),
      lyricsUrl: _optionalUri(json, 'lyricsUrl'),
      audioSizeBytes: _optionalInt(json, 'audioSize'),
      lyricsSizeBytes: _optionalInt(json, 'lyricsSize'),
      version: _optionalInt(json, 'version') ?? 1,
    );
  }

  final int number;
  final Uri audioUrl;
  final Uri? lyricsUrl;
  final int? audioSizeBytes;
  final int? lyricsSizeBytes;
  final int version;

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

  static Uri _requiredUri(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) return Uri.parse(value);
    throw FormatException('Manifest field "$key" must be a URL string.');
  }

  static Uri? _optionalUri(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return Uri.parse(value);
    throw FormatException('Manifest field "$key" must be a URL string.');
  }
}
