import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/services/audio_interruption_handler.dart';

void main() {
  group('AudioInterruptionCoordinator', () {
    test('VoIP focus transitions pause once and never auto-resume', () async {
      final player = _FakeInterruptionPlayer(playing: true);
      final coordinator = AudioInterruptionCoordinator(player);

      await coordinator.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await coordinator.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      await coordinator.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await coordinator.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );

      expect(player.pauseCalls, 1);
      expect(player.playing, isFalse);
    });

    test('an interruption does nothing when playback was already paused',
        () async {
      final player = _FakeInterruptionPlayer(playing: false);
      final coordinator = AudioInterruptionCoordinator(player);

      await coordinator.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await coordinator.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );

      expect(player.pauseCalls, 0);
      expect(player.playing, isFalse);
    });

    test('ducking is stable and restores the original volume', () async {
      final player = _FakeInterruptionPlayer(playing: true, volume: 0.8);
      final coordinator = AudioInterruptionCoordinator(player);

      await coordinator.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      await coordinator.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      expect(player.volume, 0.4);

      await coordinator.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.duck),
      );
      expect(player.volume, 0.8);
    });

    test('headphone disconnect restores volume and pauses', () async {
      final player = _FakeInterruptionPlayer(playing: true, volume: 0.6);
      final coordinator = AudioInterruptionCoordinator(player);

      await coordinator.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      await coordinator.handleBecomingNoisy();

      expect(player.volume, 0.6);
      expect(player.playing, isFalse);
      expect(player.pauseCalls, 1);
    });

    test('unknown focus loss restores volume and pauses', () async {
      final player = _FakeInterruptionPlayer(playing: true, volume: 1);
      final coordinator = AudioInterruptionCoordinator(player);

      await coordinator.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      await coordinator.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.unknown),
      );

      expect(player.volume, 1);
      expect(player.playing, isFalse);
    });
  });
}

class _FakeInterruptionPlayer implements InterruptionPlayer {
  _FakeInterruptionPlayer({required this.playing, this.volume = 1});

  @override
  bool playing;

  @override
  double volume;

  int pauseCalls = 0;

  @override
  Future<void> pause() async {
    pauseCalls++;
    playing = false;
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }
}
