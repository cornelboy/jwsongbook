import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:jwsongbook/core/constants/app_constants.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/data/repositories/songs_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'player_provider.g.dart';

// ── Audio player singleton ───────────────────────────────────────────────────

@Riverpod(keepAlive: true)
AudioPlayer audioPlayer(Ref ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
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
    this.isLoading = false,
    this.error,
  });

  final Song? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final ProcessingState processingState;
  final bool isLoading;
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
    bool? isLoading,
    String? error,
  }) =>
      PlayerState(
        currentSong: currentSong ?? this.currentSong,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        processingState: processingState ?? this.processingState,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

@Riverpod(keepAlive: true)
class PlayerNotifier extends _$PlayerNotifier {
  late AudioPlayer _player;
  late SongsRepository _repo;

  @override
  PlayerState build() {
    _player = ref.watch(audioPlayerProvider);
    _repo = ref.watch(songsRepositoryProvider);

    // Mirror just_audio streams into our state.
    final subscriptions = [
      _player.playingStream.listen((playing) {
        state = state.copyWith(isPlaying: playing);
      }),
      _player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
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
      }),
    ];

    ref.onDispose(() {
      for (final s in subscriptions) {
        s.cancel();
      }
    });

    return const PlayerState();
  }

  // ── Playback control ──────────────────────────────────────────────────────

  Future<void> playSong(Song song) async {
    if (state.currentSong?.id == song.id) {
      state = state.copyWith(error: null);
      return;
    }

    state = state.copyWith(isLoading: true, currentSong: song, error: null);

    try {
      final mediaItem = MediaItem(
        id: song.id.toString(),
        album: 'Kingdom Songs',
        title: song.title,
        artUri: null,
        extras: {'number': song.number},
      );
      final source = await _audioSourceForSong(song, mediaItem);

      await _player.setAudioSource(source);
      state = state.copyWith(isLoading: false);
      unawaited(_player.play());
      await _repo.markPlayed(song);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not play song ${song.number}: $e',
      );
    }
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

    return AudioSource.asset(
      AppConstants.audioFileName(song.number),
      tag: mediaItem,
    );
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying && !state.isCompleted) {
      await _player.pause();
    } else {
      if (state.isCompleted) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> seekMs(int ms) => seek(Duration(milliseconds: ms));

  Future<void> playNext() async {
    final current = state.currentSong;
    if (current == null) return;
    final all = await _repo.getAllSongs();
    final idx = all.indexWhere((s) => s.id == current.id);
    if (idx >= 0 && idx < all.length - 1) await playSong(all[idx + 1]);
  }

  Future<void> playPrevious() async {
    final current = state.currentSong;
    if (current == null) return;
    // If more than 3 s in, restart the current song instead of going back.
    if (state.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    final all = await _repo.getAllSongs();
    final idx = all.indexWhere((s) => s.id == current.id);
    if (idx > 0) await playSong(all[idx - 1]);
  }

  Future<void> stop() async {
    await _player.stop();
    state = const PlayerState();
  }
}

// ── Position stream (used by sync engine) ────────────────────────────────────

@riverpod
Stream<Duration> playerPosition(Ref ref) =>
    ref.watch(audioPlayerProvider).positionStream;
