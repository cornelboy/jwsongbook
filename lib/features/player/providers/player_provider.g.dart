// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioPlayerHash() => r'da4907d740d3974621d680b1ce2ac2a61956bb40';

/// See also [audioPlayer].
@ProviderFor(audioPlayer)
final audioPlayerProvider = Provider<AudioPlayer>.internal(
  audioPlayer,
  name: r'audioPlayerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$audioPlayerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AudioPlayerRef = ProviderRef<AudioPlayer>;
String _$playerPositionHash() => r'3291d0312ab0920e9bca023ce80e485678cc3829';

/// See also [playerPosition].
@ProviderFor(playerPosition)
final playerPositionProvider = AutoDisposeStreamProvider<Duration>.internal(
  playerPosition,
  name: r'playerPositionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$playerPositionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlayerPositionRef = AutoDisposeStreamProviderRef<Duration>;
String _$playerNotifierHash() => r'7843879a8e6a0c477678a0c30f6f8e150cc1d719';

/// See also [PlayerNotifier].
@ProviderFor(PlayerNotifier)
final playerNotifierProvider =
    NotifierProvider<PlayerNotifier, PlayerState>.internal(
  PlayerNotifier.new,
  name: r'playerNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$playerNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PlayerNotifier = Notifier<PlayerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
