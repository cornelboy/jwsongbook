import 'dart:convert';

class SongManifest {
  const SongManifest({required this.songs});

  static const int maxEncodedBytes = 2 * 1024 * 1024;

  static void validateManifestUri(Uri uri) {
    RemoteSongAsset._validateSecureUri(uri, field: 'manifest URL');
  }

  static void validateAssetUri(Uri uri, {required Uri manifestUri}) {
    RemoteSongAsset._validateSecureUri(uri, field: 'asset URL');
    if (!RemoteSongAsset._hasSameOrigin(uri, manifestUri)) {
      throw const FormatException(
        'Manifest asset URLs must use the manifest origin.',
      );
    }
  }

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
    this.audioSha256,
    this.lyricsSha256,
  });

  static const int maxAudioSizeBytes = 100 * 1024 * 1024;
  static const int maxLyricsSizeBytes = 2 * 1024 * 1024;
  static const bool _allowInsecureDownloads = bool.fromEnvironment(
    'ALLOW_INSECURE_SONG_DOWNLOADS',
  );

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

    final audioUrl = _optionalUri(json, 'audioUrl', baseUri: baseUri);
    final lyricsUrl = _optionalUri(json, 'lyricsUrl', baseUri: baseUri);
    final audioSizeBytes = _validatedAssetSize(
      json,
      'audioSize',
      maximum: maxAudioSizeBytes,
    );
    final lyricsSizeBytes = _validatedAssetSize(
      json,
      'lyricsSize',
      maximum: maxLyricsSizeBytes,
    );
    final audioSha256 = _optionalSha256(json, 'audioSha256');
    final lyricsSha256 = _optionalSha256(json, 'lyricsSha256');

    _requireIntegrityMetadata(
      url: audioUrl,
      size: audioSizeBytes,
      sha256: audioSha256,
      kind: 'audio',
    );
    _requireIntegrityMetadata(
      url: lyricsUrl,
      size: lyricsSizeBytes,
      sha256: lyricsSha256,
      kind: 'lyrics',
    );

    return RemoteSongAsset(
      number: number,
      title: title?.trim(),
      durationMs: durationMs,
      audioUrl: audioUrl,
      lyricsUrl: lyricsUrl,
      audioSizeBytes: audioSizeBytes,
      lyricsSizeBytes: lyricsSizeBytes,
      audioSha256: audioSha256,
      lyricsSha256: lyricsSha256,
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
  final String? audioSha256;
  final String? lyricsSha256;
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
    if (baseUri != null) {
      _validateSecureUri(baseUri, field: 'manifest URL');
    }
    final uri = baseUri?.resolve(value) ?? Uri.parse(value);
    _validateSecureUri(uri, field: 'asset URL');
    if (baseUri != null && !_hasSameOrigin(uri, baseUri)) {
      throw const FormatException(
        'Manifest asset URLs must use the manifest origin.',
      );
    }
    return uri;
  }

  static void _validateSecureUri(Uri uri, {required String field}) {
    final permittedScheme = uri.scheme == 'https' ||
        (_allowInsecureDownloads && uri.scheme == 'http');
    if (!permittedScheme ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw FormatException(
        '$field must be an HTTPS URL without credentials or a fragment.',
      );
    }
  }

  static bool _hasSameOrigin(Uri first, Uri second) =>
      first.scheme == second.scheme &&
      first.host.toLowerCase() == second.host.toLowerCase() &&
      first.port == second.port;

  static int? _validatedAssetSize(
    Map<String, Object?> json,
    String key, {
    required int maximum,
  }) {
    final size = _optionalInt(json, key);
    if (size != null && (size <= 0 || size > maximum)) {
      throw FormatException(
        'Manifest field "$key" must be between 1 and $maximum bytes.',
      );
    }
    return size;
  }

  static String? _optionalSha256(Map<String, Object?> json, String key) {
    final value = _optionalString(json, key);
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
      throw FormatException(
        'Manifest field "$key" must be a 64-character SHA-256 digest.',
      );
    }
    return normalized;
  }

  static void _requireIntegrityMetadata({
    required Uri? url,
    required int? size,
    required String? sha256,
    required String kind,
  }) {
    // Older published manifests do not yet contain hashes. Their declared
    // sizes remain mandatory; whenever a hash is published it is enforced by
    // the downloader. New manifests should always publish both fields.
    if (url != null && size == null) {
      throw FormatException(
        'Downloadable $kind requires a declared size.',
      );
    }
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Manifest field "$key" must be a string.');
  }
}
