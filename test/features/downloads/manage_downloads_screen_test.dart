import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:jwsongbook/features/downloads/screens/manage_downloads_screen.dart';

void main() {
  // ── formatDownloadBytes ─────────────────────────────────────────────────

  group('formatDownloadBytes', () {
    test('returns "0 KB" for zero bytes', () {
      expect(formatDownloadBytes(0), '0 KB');
    });

    test('returns "0 KB" for negative bytes', () {
      expect(formatDownloadBytes(-100), '0 KB');
    });

    test('formats bytes to KB (rounded up)', () {
      expect(formatDownloadBytes(1), '1 KB');
      expect(formatDownloadBytes(500), '1 KB');
      expect(formatDownloadBytes(1023), '1 KB');
      expect(formatDownloadBytes(1024), '1 KB');
      expect(formatDownloadBytes(1536), '2 KB');
    });

    test('formats bytes to MB (one decimal place)', () {
      const mb = 1024 * 1024;
      expect(formatDownloadBytes(mb), '1.0 MB');
      expect(formatDownloadBytes(mb + mb ~/ 2), '1.5 MB');
      expect(formatDownloadBytes(5 * mb), '5.0 MB');
    });

    test('formats large values correctly', () {
      const gb = 1024 * 1024 * 1024;
      expect(formatDownloadBytes(gb), '1024.0 MB');
    });

    test('boundary: exactly 1024 bytes is 1 KB', () {
      expect(formatDownloadBytes(1024), '1 KB');
    });

    test('boundary: 1025 bytes is 2 KB', () {
      expect(formatDownloadBytes(1025), '2 KB');
    });
  });

  // ── DownloadedSongInfo ──────────────────────────────────────────────────

  group('DownloadedSongInfo', () {
    test('constructs with required fields', () {
      const song = Song(
        id: 1,
        number: 1,
        title: 'Test Song',
        isDownloaded: true,
        isFavorited: false,
        hasSyncedLyrics: false,
      );

      const info = DownloadedSongInfo(song: song, sizeBytes: 5000);

      expect(info.song.number, 1);
      expect(info.song.title, 'Test Song');
      expect(info.sizeBytes, 5000);
    });
  });

  // ── DownloadedSongsSummary ──────────────────────────────────────────────

  group('DownloadedSongsSummary', () {
    test('constructs with count and totalBytes', () {
      const summary = DownloadedSongsSummary(count: 5, totalBytes: 50000);
      expect(summary.count, 5);
      expect(summary.totalBytes, 50000);
    });

    test('handles zero counts', () {
      const summary = DownloadedSongsSummary(count: 0, totalBytes: 0);
      expect(summary.count, 0);
      expect(summary.totalBytes, 0);
    });
  });
}
