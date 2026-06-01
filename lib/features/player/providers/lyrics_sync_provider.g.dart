// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lyrics_sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentSongLyricsHash() => r'93751274dcf23da720de51d240ae49463fc7fc12';

/// Loads the [SyncedLyrics] for the currently playing song.
///
/// Copied from [currentSongLyrics].
@ProviderFor(currentSongLyrics)
final currentSongLyricsProvider =
    AutoDisposeFutureProvider<SyncedLyrics>.internal(
  currentSongLyrics,
  name: r'currentSongLyricsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentSongLyricsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentSongLyricsRef = AutoDisposeFutureProviderRef<SyncedLyrics>;
String _$syncCursorHash() => r'1ce4d7874ee3af70a8adb35653e647497d793a04';

/// Derives the active [SyncCursor] from the playback position and the loaded
/// lyrics.  Rebuilds on every position tick (~60 fps via the Ticker in the
/// lyrics widget).
///
/// Copied from [syncCursor].
@ProviderFor(syncCursor)
final syncCursorProvider = AutoDisposeProvider<SyncCursor>.internal(
  syncCursor,
  name: r'syncCursorProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$syncCursorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncCursorRef = AutoDisposeProviderRef<SyncCursor>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
