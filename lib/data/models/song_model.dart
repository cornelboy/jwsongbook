import 'package:jwsongbook/data/database/app_database.dart';

/// Rich domain model wrapping the Drift [Song] row.
/// Add computed properties here — keep Drift rows as pure data.
extension SongX on Song {
  /// Zero-padded song number string — e.g. song 7 → "007".
  String get paddedNumber => number.toString().padLeft(3, '0');

  /// True if the elapsed [positionMs] is within this song's duration.
  bool isPositionValid(int positionMs) =>
      durationMs == null || positionMs <= durationMs!;
}
