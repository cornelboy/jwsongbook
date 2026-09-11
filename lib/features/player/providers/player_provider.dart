import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/models/playback_preferences.dart';
import 'package:jwsongbook/data/models/song_model.dart';
import 'package:jwsongbook/data/repositories/playback_preferences_repository.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:jwsongbook/data/services/audio_interruption_handler.dart';
import 'package:jwsongbook/features/player/providers/playback_queue.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'player_provider.g.dart';

// ── Audio player singleton ───────────────────────────────────────────────────

@Riverpod(keepAlive: true)
AudioPlayer audioPlayer(Ref ref) {
  final player = AudioPlayer(handleInterruptions: false);
  final interruptionHandler = AudioInterruptionHandler(player);
  unawaited(interruptionHandler.initialize());
  ref.onDispose(() {
    unawaited(interruptionHandler.dispose());
    unawaited(player.dispose());
  });
  return player;
}

// ── Player state ─────────────────────────────────────────────────────────────

class PlayerState {
  const PlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.processingState = ProcessingState.idle,
    this.repeatMode = PlaybackRepeatMode.off,
    this.isShuffleEnabled = false,
    this.isLoading = false,
    this.seekRevision = 0,
    this.error,
  });

  final Song? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final ProcessingState processingState;
  final PlaybackRepeatMode repeatMode;
  final bool isShuffleEnabled;
  final bool isLoading;
  final int seekRevision;
  final String? error;

  bool get hasSong => currentSong != null;
  int get positionMs => position.inMilliseconds;
  bool get isCompleted =>
      processingState == ProcessingState.completed ||
      (duration > Duration.zero && position >= duration);

  PlayerState copyWith({
    Song? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    ProcessingState? processingState,
    PlaybackRepeatMode? repeatMode,
    bool? isShuffleEnabled,
    bool? isLoading,
    int? seekRevision,
    String? error,
  }) =>
      PlayerState(
        currentSong: currentSong ?? this.currentSong,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        processingState: processingState ?? this.processingState,
        repeatMode: repeatMode ?? this.repeatMode,
        isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
        isLoading: isLoading ?? this.isLoading,
        seekRevision: seekRevision ?? this.seekRevision,
        error: error,
      );
}

@Riverpod(keepAlive: true)
class PlayerNotifier extends _$PlayerNotifier {
  static const _checkpointInterval = Duration(seconds: 2);
  static const _restartThreshold = Duration(seconds: 5);

  late AudioPlayer _player;
  late SongsRepository _repo;
  late PlaybackPreferencesRepository _preferencesRepository;
  final _random = Random();
  bool _isHandlingCompletion = false;
  bool _hasPlaybackRequest = false;
  Timer? _checkpointTimer;
  Future<void>? _restoreFuture;
  List<int>? _playlistSongIds;

  /// A playback snapshot; edits to a saved playlist apply on its next play.
  Future<void> playPlaylist(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) return;
    final playable = songs.where((s) => s.hasLocalAudio).toList();
    if (!songs[startIndex].hasLocalAudio || playable.isEmpty) return;
    _playlistSongIds = playable.map((s) => s.id).toList();
    state = state.copyWith(isShuffleEnabled: false);
    await playSong(songs[startIndex], keepQueue: true);
  }

  @override
  PlayerState build() {
    _player = ref.watch(audioPlayerProvider);
    _repo = ref.watch(songsRepositoryProvider);
    _preferencesRepository = ref.watch(playbackPreferencesRepositoryProvider);
    final preferences = _preferencesRepository.current;
    _playlistSongIds = preferences.playlistSongIds;

    // Mirror just_audio streams into our state.
    final subscriptions = [
      _player.playingStream.listen((playing) {
        state = state.copyWith(isPlaying: playing);
        if (!playing) {
          unawaited(_savePlaybackPreferences());
        }
      }),
      _player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
        _schedulePlaybackCheckpoint();
      }),
      _player.durationStream.listen((dur) {
        if (dur != null) state = state.copyWith(duration: dur);
      }),
      _player.processingStateStream.listen((processingState) {
        state = state.copyWith(
          processingState: processingState,
          isLoading: processingState == ProcessingState.loading ||
              processingState == ProcessingState.buffering,
        );
        if (processingState == ProcessingState.completed) {
          unawaited(_savePlaybackPreferences());
          unawaited(_handlePlaybackCompleted());
        }
      }),
      JustAudioBackground.remotePreviousStream.listen((_) {
        unawaited(playPrevious());
      }),
      JustAudioBackground.remoteNextStream.listen((_) {
        unawaited(playNext());
      }),
    ];

    ref.onDispose(() {
      _checkpointTimer?.cancel();
      if (state.currentSong != null) {
        unawaited(_savePlaybackPreferences());
      }
      for (final s in subscriptions) {
        s.cancel();
      }
    });

    final initialState = PlayerState(
      repeatMode: preferences.repeatMode,
      isShuffleEnabled: preferences.isShuffleEnabled,
    );
    final restoreFuture = Future<void>.delayed(
      Duration.zero,
      _restorePlaybackSession,
    );
    _restoreFuture = restoreFuture;
    unawaited(restoreFuture);
    return initialState;
  }

  // ── Playback control ──────────────────────────────────────────────────────

  Future<void> playSong(Song song, {bool keepQueue = false}) async {
    if (!keepQueue) _playlistSongIds = null;
    _hasPlaybackRequest = true;
    final restoreFuture = _restoreFuture;
    if (restoreFuture != null) {
      await restoreFuture;
    }

    if (state.currentSong?.id == song.id) {
      state = state.copyWith(error: null);
      if (state.isCompleted) {
        await seek(Duration.zero);
      }
      if (!state.isPlaying || state.isCompleted) {
        unawaited(_player.play());
      }
      await _savePlaybackPreferences();
      return;
    }

    state = state.copyWith(isLoading: true, currentSong: song, error: null);

    try {
      final artUri = await _notificationArtUri();
      final mediaItem = MediaItem(
        id: song.id.toString(),
        album: 'JW Songs',
        title: song.title,
        artUri: artUri,
        extras: {'number': song.number},
      );
      final source = await _audioSourceForSong(song, mediaItem);

      await _player.setAudioSource(source);
      state = state.copyWith(
        isLoading: false,
        currentSong: song,
        position: Duration.zero,
        seekRevision: state.seekRevision + 1,
      );
      await _savePlaybackPreferences();
      unawaited(_player.play());
      await _repo.markPlayed(song);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not play song ${song.number}: $e',
      );
    }
  }

  Future<Uri?> _notificationArtUri() async {
    const assetPath = 'assets/branding/jw_songs_logo.jpeg';
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/jw_songs_notification_art.jpeg');

    if (!await file.exists()) {
      final bytes = await rootBundle.load(assetPath);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }

    return Uri.file(file.path);
  }

  Future<AudioSource> _audioSourceForSong(
    Song song,
    MediaItem mediaItem,
  ) async {
    final audioFilePath = song.audioFilePath;
    if (song.isDownloaded && audioFilePath != null) {
      final audioFile = File(audioFilePath);
      if (await audioFile.exists()) {
        return AudioSource.uri(Uri.file(audioFile.path), tag: mediaItem);
      }
    }

    throw StateError(
      'Song ${song.paddedNumber} is not downloaded on this device.',
    );
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying && !state.isCompleted) {
      state = state.copyWith(isPlaying: false);
      await _player.pause();
    } else {
      if (state.isCompleted) {
        await seek(Duration.zero);
      }
      state = state.copyWith(isPlaying: true);
      await _player.play();
    }
    await _savePlaybackPreferences();
  }

  Future<void> seek(Duration position) async {
    final target = _clampSeekPosition(position);
    state = state.copyWith(
      position: target,
      processingState: ProcessingState.ready,
      seekRevision: state.seekRevision + 1,
      error: null,
    );
    await _player.seek(target);
    await _savePlaybackPreferences();
  }

  Future<void> seekMs(int ms) => seek(Duration(milliseconds: ms));

  Future<void> playNext() async {
    final current = state.currentSong;
    if (current == null) return;
    final all = await _getPlayableSongs();

    if (state.isShuffleEnabled) {
      await _playRandomSong(current, all);
      return;
    }

    final nextSong = nextSongInQueue(
      all,
      current,
      wrap: state.repeatMode == PlaybackRepeatMode.all,
    );
    if (nextSong != null) {
      if (nextSong.id == current.id) {
        await seek(Duration.zero);
        await _player.play();
      } else {
        await playSong(nextSong, keepQueue: true);
      }
    }
  }

  Future<void> playPrevious() async {
    final current = state.currentSong;
    if (current == null) return;
    // If more than 3 s in, restart the current song instead of going back.
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    final all = await _getPlayableSongs();
    final previousSong = previousSongInQueue(
      all,
      current,
      wrap: state.repeatMode == PlaybackRepeatMode.all,
    );
    if (previousSong != null) {
      await playSong(previousSong, keepQueue: true);
    }
  }

  Future<void> toggleRepeatMode() async {
    state = state.copyWith(repeatMode: state.repeatMode.next);
    await _savePlaybackPreferences();
  }

  Future<void> toggleShuffle() async {
    state = state.copyWith(isShuffleEnabled: !state.isShuffleEnabled);
    await _savePlaybackPreferences();
  }

  void _schedulePlaybackCheckpoint() {
    if (state.currentSong == null || _checkpointTimer != null) return;

    _checkpointTimer = Timer(_checkpointInterval, () {
      _checkpointTimer = null;
      unawaited(_savePlaybackPreferences());
    });
  }

  Future<void> _savePlaybackPreferences({bool clearSession = false}) async {
    final currentPreferences = _preferencesRepository.current;
    final currentSong = state.currentSong;
    final preferences = PlaybackPreferences(
      playlistSongIds: clearSession ? null : _playlistSongIds,
      repeatMode: state.repeatMode,
      isShuffleEnabled: state.isShuffleEnabled,
      lastSongNumber: clearSession
          ? null
          : currentSong?.number ?? currentPreferences.lastSongNumber,
      lastPositionMs: clearSession
          ? 0
          : currentSong?.number != null
              ? state.positionMs
              : currentPreferences.lastPositionMs,
    );

    try {
      await _preferencesRepository.save(preferences);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Could not save playback preferences.',
        name: 'PlayerNotifier',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _restorePlaybackSession() async {
    try {
      await _restorePlaybackSessionInternal();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Could not restore the previous playback session.',
        name: 'PlayerNotifier',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(isLoading: false);
      await _savePlaybackPreferences(clearSession: true);
    }
  }

  Future<void> _restorePlaybackSessionInternal() async {
    final saved = _preferencesRepository.current;
    final songNumber = saved.lastSongNumber;
    if (songNumber == null ||
        _hasPlaybackRequest ||
        state.currentSong != null ||
        _player.audioSource != null) {
      return;
    }

    final song = await _repo.getByNumber(songNumber);
    if (_hasPlaybackRequest) return;

    if (song == null || !await _hasPlayableAudio(song)) {
      await _savePlaybackPreferences(clearSession: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final artUri = await _notificationArtUri();
      if (_hasPlaybackRequest) return;

      final mediaItem = MediaItem(
        id: song.id.toString(),
        album: 'JW Songs',
        title: song.title,
        artUri: artUri,
        extras: {'number': song.number},
      );
      final source = await _audioSourceForSong(song, mediaItem);
      if (_hasPlaybackRequest) return;

      final loadedDuration = await _player.setAudioSource(source);
      if (_hasPlaybackRequest) return;

      final duration = loadedDuration ??
          (song.durationMs == null
              ? Duration.zero
              : Duration(milliseconds: song.durationMs!));
      var restoredPosition = Duration(milliseconds: saved.lastPositionMs);
      if (duration > Duration.zero) {
        final remaining = duration - restoredPosition;
        if (remaining <= _restartThreshold) {
          restoredPosition = Duration.zero;
        } else if (restoredPosition > duration) {
          restoredPosition = duration;
        }
      }

      if (restoredPosition > Duration.zero) {
        await _player.seek(restoredPosition);
      }
      _playlistSongIds = saved.playlistSongIds?.contains(song.id) == true
          ? saved.playlistSongIds
          : null;
      state = state.copyWith(
        currentSong: song,
        isPlaying: false,
        isLoading: false,
        position: restoredPosition,
        duration: duration,
        processingState: _player.processingState,
        seekRevision: state.seekRevision + 1,
      );
      await _savePlaybackPreferences();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Could not restore the previous playback session.',
        name: 'PlayerNotifier',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(isLoading: false);
      await _savePlaybackPreferences(clearSession: true);
    }
  }

  Future<bool> _hasPlayableAudio(Song song) async {
    final audioFilePath = song.audioFilePath;
    return song.isDownloaded &&
        audioFilePath != null &&
        await File(audioFilePath).exists();
  }

  Future<List<Song>> _getPlayableSongs() async {
    final all = await _repo.getAllSongs();
    final ids = _playlistSongIds;
    if (ids != null) {
      final byId = {for (final song in all) song.id: song};
      return ids
          .map((id) => byId[id])
          .whereType<Song>()
          .where((song) => song.hasLocalAudio)
          .toList();
    }
    return all.where((song) => song.hasLocalAudio).toList();
  }

  Future<void> _playRandomSong(Song current, List<Song> all) async {
    if (all.isEmpty) return;

    final candidates = all.where((song) => song.id != current.id).toList();
    if (candidates.isEmpty) {
      if (state.repeatMode != PlaybackRepeatMode.off) {
        await seek(Duration.zero);
        await _player.play();
      }
      return;
    }

    await playSong(
      candidates[_random.nextInt(candidates.length)],
      keepQueue: true,
    );
  }

  Future<void> _handlePlaybackCompleted() async {
    if (_isHandlingCompletion) return;
    _isHandlingCompletion = true;

    try {
      switch (state.repeatMode) {
        case PlaybackRepeatMode.off:
          if (_playlistSongIds != null) await playNext();
          break;
        case PlaybackRepeatMode.one:
          await seek(Duration.zero);
          await _player.play();
          break;
        case PlaybackRepeatMode.all:
          await playNext();
          break;
      }
    } finally {
      _isHandlingCompletion = false;
    }
  }

  Future<void> stop() async {
    _playlistSongIds = null;
    await _savePlaybackPreferences();
    await _player.stop();
    state = PlayerState(
      repeatMode: state.repeatMode,
      isShuffleEnabled: state.isShuffleEnabled,
    );
  }

  Duration _clampSeekPosition(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    final duration = state.duration;
    if (duration > Duration.zero && position > duration) return duration;
    return position;
  }
}

// ── Position stream (used by sync engine) ────────────────────────────────────

@riverpod
Stream<Duration> playerPosition(Ref ref) =>
    ref.watch(audioPlayerProvider).positionStream;
