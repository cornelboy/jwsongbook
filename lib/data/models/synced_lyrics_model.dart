/// In-memory representation of an entire song's synced lyrics.
///
/// After the DB rows are loaded (or the .elrc file is parsed), everything
/// is converted to this pure-Dart model so the sync engine never touches
/// the database during playback.
class SyncedLyrics {
  const SyncedLyrics({required this.lines, this.sections = const []});

  factory SyncedLyrics.fromLines(List<SyncedLine> lines) {
    if (lines.isEmpty) return const SyncedLyrics(lines: []);

    final hasExplicitSections =
        lines.any((line) => line.sectionIndex != lines.first.sectionIndex);
    final sections = <SyncedSection>[];
    var lastSectionIndex = -1;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final startsFallbackSection = !hasExplicitSections &&
          i > 0 &&
          line.startMs - lines[i - 1].endMs >= 3000;
      final startsExplicitSection =
          hasExplicitSections && line.sectionIndex != lastSectionIndex;

      if (i == 0 || startsExplicitSection || startsFallbackSection) {
        sections.add(
          SyncedSection(
            index: sections.length,
            // The instrumental introduction belongs to Part 1. Only later
            // sections begin at their first lyric line.
            startMs: i == 0 ? 0 : line.startMs,
            firstLineIndex: i,
          ),
        );
      }
      lastSectionIndex = line.sectionIndex;
    }

    return SyncedLyrics(lines: lines, sections: sections);
  }

  final List<SyncedLine> lines;
  final List<SyncedSection> sections;

  bool get isEmpty => lines.isEmpty;

  /// Returns the section containing [positionMs]. During an instrumental
  /// introduction, the first section is returned so the player remains stable.
  SyncedSection? sectionAt(int positionMs) {
    if (sections.isEmpty) return null;
    for (var i = sections.length - 1; i >= 0; i--) {
      if (positionMs >= sections[i].startMs) return sections[i];
    }
    return sections.first;
  }

  /// Returns the index of the line active at [positionMs], or -1 outside the
  /// synced lyric range.
  int activeLineIndexAt(int positionMs) {
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (positionMs >= line.startMs && positionMs < line.endMs) return i;
    }
    return -1;
  }

  /// Returns the first lyric line that starts after [positionMs], or -1 if
  /// playback is beyond the final lyric line.
  int nextLineIndexAfter(int positionMs) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].startMs > positionMs) return i;
    }
    return -1;
  }

  /// Returns true only when [positionMs] is inside a non-lyric gap long enough
  /// to deserve an instrumental indicator.
  bool hasInstrumentalGapAt(
    int positionMs, {
    int minGapMs = 2000,
    int? songEndMs,
  }) {
    if (lines.isEmpty || activeLineIndexAt(positionMs) >= 0) return false;

    final first = lines.first;
    if (positionMs < first.startMs) {
      return first.startMs >= minGapMs;
    }

    for (var i = 0; i < lines.length - 1; i++) {
      final current = lines[i];
      final next = lines[i + 1];
      if (positionMs >= current.endMs && positionMs < next.startMs) {
        return next.startMs - current.endMs >= minGapMs;
      }
    }

    final last = lines.last;
    if (songEndMs != null &&
        positionMs >= last.endMs &&
        positionMs < songEndMs) {
      return songEndMs - last.endMs >= minGapMs;
    }

    return false;
  }
}

class SyncedLine {
  const SyncedLine({
    required this.index,
    required this.sectionIndex,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.words,
  });

  final int index;
  final int sectionIndex;
  final int startMs;
  final int endMs;
  final String text;
  final List<SyncedWord> words;

  /// Returns the index of the word active at [positionMs], or -1.
  int activeWordIndexAt(int positionMs) {
    for (var i = words.length - 1; i >= 0; i--) {
      if (positionMs >= words[i].startMs) return i;
    }
    return -1;
  }

  /// Progress fraction (0.0–1.0) for the word highlight fill animation.
  /// Returns 0 if the line hasn't started; 1 if it has ended.
  double fillProgressAt(int positionMs, int wordIndex) {
    if (wordIndex < 0 || wordIndex >= words.length) return 0;
    final word = words[wordIndex];
    final elapsed = positionMs - word.startMs;
    final duration = word.endMs - word.startMs;
    if (duration <= 0) return 1;
    return (elapsed / duration).clamp(0.0, 1.0);
  }
}

class SyncedSection {
  const SyncedSection({
    required this.index,
    required this.startMs,
    required this.firstLineIndex,
  });

  final int index;
  final int startMs;
  final int firstLineIndex;
}

class SyncedWord {
  const SyncedWord({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int index;
  final int startMs;
  final int endMs;
  final String text;

  bool isActiveAt(int positionMs) =>
      positionMs >= startMs && positionMs < endMs;
}
