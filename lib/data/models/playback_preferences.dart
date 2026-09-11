enum PlaybackRepeatMode {
  off,
  one,
  all;

  PlaybackRepeatMode get next => switch (this) {
        PlaybackRepeatMode.off => PlaybackRepeatMode.one,
        PlaybackRepeatMode.one => PlaybackRepeatMode.all,
        PlaybackRepeatMode.all => PlaybackRepeatMode.off,
      };

  static PlaybackRepeatMode fromStorageValue(Object? value) => switch (value) {
        'one' => PlaybackRepeatMode.one,
        'all' => PlaybackRepeatMode.all,
        _ => PlaybackRepeatMode.off,
      };
}

class PlaybackPreferences {
  const PlaybackPreferences({
    this.repeatMode = PlaybackRepeatMode.off,
    this.isShuffleEnabled = false,
    this.lastSongNumber,
    this.lastPositionMs = 0,
    this.playlistSongIds,
  });

  static const schemaVersion = 1;

  final PlaybackRepeatMode repeatMode;
  final bool isShuffleEnabled;
  final int? lastSongNumber;
  final int lastPositionMs;
  final List<int>? playlistSongIds;

  factory PlaybackPreferences.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['schemaVersion'] != schemaVersion) {
      return const PlaybackPreferences();
    }

    return PlaybackPreferences(
      repeatMode: PlaybackRepeatMode.fromStorageValue(json['repeatMode']),
      isShuffleEnabled: json['isShuffleEnabled'] is bool
          ? json['isShuffleEnabled'] as bool
          : false,
      lastSongNumber:
          json['lastSongNumber'] is int ? json['lastSongNumber'] as int : null,
      lastPositionMs: json['lastPositionMs'] is int
          ? (json['lastPositionMs'] as int).clamp(0, 1 << 31).toInt()
          : 0,
      playlistSongIds: json['playlistSongIds'] is List
          ? List<int>.unmodifiable(
              (json['playlistSongIds'] as List)
                  .whereType<int>()
                  .where((id) => id > 0)
                  .toSet(),
            )
          : null,
    );
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'repeatMode': repeatMode.name,
        'isShuffleEnabled': isShuffleEnabled,
        'lastSongNumber': lastSongNumber,
        'lastPositionMs': lastPositionMs,
        'playlistSongIds': playlistSongIds,
      };
}
