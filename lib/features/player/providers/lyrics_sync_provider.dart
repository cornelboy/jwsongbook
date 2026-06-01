import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/data/models/synced_lyrics_model.dart';
import 'package:jwsongbook/data/repositories/lyrics_repository.dart';
import 'package:jwsongbook/features/player/providers/player_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lyrics_sync_provider.g.dart';

// Lead visual lyrics slightly ahead of the audio so the next line appears
// before it is sung instead of feeling late.
const int _lyricLeadMs = 300;

/// Sync cursor — the currently active line + word indices.
class SyncCursor {
  const SyncCursor({
    required this.lineIndex,
    required this.wordIndex,
    required this.wordFillProgress,
    required this.showInstrumentalGap,
  });

  /// Index into [SyncedLyrics.lines], or -1 before song starts.
  final int lineIndex;

  /// Index into [SyncedLine.words], or -1.
  final int wordIndex;

  /// 0.0–1.0 fill progress for the karaoke left-to-right highlight animation.
  final double wordFillProgress;

  /// True when playback is inside a meaningful non-lyric instrumental gap.
  final bool showInstrumentalGap;

  static const SyncCursor empty = SyncCursor(
    lineIndex: -1,
    wordIndex: -1,
    wordFillProgress: 0,
    showInstrumentalGap: false,
  );
}

/// Loads the [SyncedLyrics] for the currently playing song.
@riverpod
Future<SyncedLyrics> currentSongLyrics(Ref ref) async {
  final song = ref.watch(playerNotifierProvider.select((s) => s.currentSong));
  if (song == null) return const SyncedLyrics(lines: []);
  return ref.watch(lyricsRepositoryProvider).loadForSong(song);
}

/// Derives the active [SyncCursor] from the playback position and the loaded
/// lyrics.  Rebuilds on every position tick (~60 fps via the Ticker in the
/// lyrics widget).
@riverpod
SyncCursor syncCursor(Ref ref) {
  final lyricsAsync = ref.watch(currentSongLyricsProvider);
  final lyrics = lyricsAsync.valueOrNull;
  if (lyrics == null || lyrics.isEmpty) return SyncCursor.empty;

  final playerState = ref.watch(playerNotifierProvider);
  final playbackPositionMs = playerState.positionMs;
  final positionMs = playbackPositionMs + _lyricLeadMs;

  final lineIndex = lyrics.activeLineIndexAt(positionMs);
  if (lineIndex < 0) {
    final durationMs = playerState.duration.inMilliseconds;
    return SyncCursor(
      lineIndex: -1,
      wordIndex: -1,
      wordFillProgress: 0,
      showInstrumentalGap: lyrics.hasInstrumentalGapAt(
        positionMs,
        minGapMs: 2000,
        songEndMs: durationMs > 0 ? durationMs : null,
      ),
    );
  }

  final line = lyrics.lines[lineIndex];
  final wordIndex = line.activeWordIndexAt(positionMs);
  final fillProgress =
      wordIndex >= 0 ? line.fillProgressAt(positionMs, wordIndex) : 0.0;

  return SyncCursor(
    lineIndex: lineIndex,
    wordIndex: wordIndex,
    wordFillProgress: fillProgress,
    showInstrumentalGap: false,
  );
}
