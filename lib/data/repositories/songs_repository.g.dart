// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'songs_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$songsDaoHash() => r'cf9201f3329ef406281a18b2db2c49f1217d9853';

/// See also [songsDao].
@ProviderFor(songsDao)
final songsDaoProvider = Provider<SongsDao>.internal(
  songsDao,
  name: r'songsDaoProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$songsDaoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SongsDaoRef = ProviderRef<SongsDao>;
String _$appDatabaseHash() => r'98a09c6cfd43966155dfbdb0787fa18c85438e13';

/// See also [appDatabase].
@ProviderFor(appDatabase)
final appDatabaseProvider = Provider<AppDatabase>.internal(
  appDatabase,
  name: r'appDatabaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appDatabaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppDatabaseRef = ProviderRef<AppDatabase>;
String _$songsRepositoryHash() => r'fe2e6987f94f87fdcb8d5b8834488ae48859f13b';

/// See also [songsRepository].
@ProviderFor(songsRepository)
final songsRepositoryProvider = AutoDisposeProvider<SongsRepository>.internal(
  songsRepository,
  name: r'songsRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$songsRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SongsRepositoryRef = AutoDisposeProviderRef<SongsRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
