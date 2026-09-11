import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class AudioInterruptionHandler {
  AudioInterruptionHandler(AudioPlayer player)
      : _coordinator = AudioInterruptionCoordinator(
          _JustAudioInterruptionPlayer(player),
        );

  final AudioInterruptionCoordinator _coordinator;

  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;
  Future<void> _operationQueue = Future<void>.value();
  bool _disposed = false;

  Future<void> initialize() async {
    try {
      final session = await AudioSession.instance;
      if (_disposed) return;

      await session.configure(const AudioSessionConfiguration.music());
      if (_disposed) return;

      _interruptionSubscription = session.interruptionEventStream.listen(
        (event) => _enqueue(() => _coordinator.handleInterruption(event)),
      );
      _becomingNoisySubscription = session.becomingNoisyEventStream.listen(
        (_) => _enqueue(_coordinator.handleBecomingNoisy),
      );
    } on Object catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  void _enqueue(Future<void> Function() operation) {
    final previous = _operationQueue;
    _operationQueue = () async {
      try {
        await previous;
        if (!_disposed) await operation();
      } on Object catch (error, stackTrace) {
        _reportError(error, stackTrace);
      }
    }();
  }

  Future<void> dispose() async {
    _disposed = true;
    await _interruptionSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();
  }

  void _reportError(Object error, StackTrace stackTrace) {
    developer.log(
      'Audio interruption handling failed.',
      name: 'AudioInterruptionHandler',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

abstract interface class InterruptionPlayer {
  bool get playing;

  double get volume;

  Future<void> pause();

  Future<void> setVolume(double volume);
}

class AudioInterruptionCoordinator {
  AudioInterruptionCoordinator(this._player);

  final InterruptionPlayer _player;

  bool _pauseInterruptionActive = false;
  double? _volumeBeforeDucking;

  Future<void> handleInterruption(AudioInterruptionEvent event) async {
    switch (event.type) {
      case AudioInterruptionType.pause:
        if (event.begin) {
          await _beginPauseInterruption();
        } else {
          await _endPauseInterruption();
        }
        break;
      case AudioInterruptionType.duck:
        if (event.begin) {
          await _beginDucking();
        } else {
          await _endDucking();
        }
        break;
      case AudioInterruptionType.unknown:
        if (event.begin) {
          _pauseInterruptionActive = false;
          await _endDucking();
          if (_player.playing) await _player.pause();
        }
        break;
    }
  }

  Future<void> _beginPauseInterruption() async {
    _pauseInterruptionActive = true;

    await _endDucking();
    if (_player.playing) await _player.pause();
  }

  Future<void> _endPauseInterruption() async {
    if (!_pauseInterruptionActive) return;

    _pauseInterruptionActive = false;
    // Some VoIP apps briefly release audio focus while a call transitions from
    // ringing to connected. Treat focus gain as permission to remain paused,
    // not as a user request to restart playback during the call.
  }

  Future<void> _beginDucking() async {
    _volumeBeforeDucking ??= _player.volume;
    await _player.setVolume(_volumeBeforeDucking! * 0.5);
  }

  Future<void> _endDucking() async {
    final previousVolume = _volumeBeforeDucking;
    if (previousVolume == null) return;

    _volumeBeforeDucking = null;
    await _player.setVolume(previousVolume);
  }

  Future<void> _handleBecomingNoisy() async {
    _pauseInterruptionActive = false;
    await _endDucking();
    if (_player.playing) await _player.pause();
  }

  Future<void> handleBecomingNoisy() => _handleBecomingNoisy();
}

class _JustAudioInterruptionPlayer implements InterruptionPlayer {
  const _JustAudioInterruptionPlayer(this._player);

  final AudioPlayer _player;

  @override
  bool get playing => _player.playing;

  @override
  double get volume => _player.volume;

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
}
