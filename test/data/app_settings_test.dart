import 'package:flutter_test/flutter_test.dart';
import 'package:jwsongbook/data/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('migrates version 1 settings without losing preferences', () {
      final settings = AppSettings.fromJson({
        'schemaVersion': 1,
        'congregationMode': true,
        'fontScaleFactor': 1.4,
        'autoScrollEnabled': false,
        'themePreference': 'light',
      });

      expect(settings.congregationMode, isTrue);
      expect(settings.fontScaleFactor, 1.4);
      expect(settings.autoScrollEnabled, isFalse);
      expect(settings.themePreference, AppThemePreference.light);
      expect(settings.floatingLyricsDiscoveryImpressions, 0);
      expect(settings.floatingLyricsDiscoveryCompleted, isFalse);
      expect(settings.canShowFloatingLyricsDiscovery, isTrue);
    });

    test('persists floating lyrics discovery progress', () {
      final stored = const AppSettings(
        floatingLyricsDiscoveryImpressions: 1,
        floatingLyricsDiscoveryCompleted: true,
      ).toJson();
      final restored = AppSettings.fromJson(stored);

      expect(stored['schemaVersion'], AppSettings.schemaVersion);
      expect(restored.floatingLyricsDiscoveryImpressions, 1);
      expect(restored.floatingLyricsDiscoveryCompleted, isTrue);
      expect(restored.canShowFloatingLyricsDiscovery, isFalse);
    });

    test('migrates the old shown flag as completed discovery', () {
      final settings = AppSettings.fromJson({
        'schemaVersion': 2,
        'floatingLyricsDiscoveryShown': true,
      });

      expect(
        settings.floatingLyricsDiscoveryImpressions,
        AppSettings.maxFloatingLyricsDiscoveryImpressions,
      );
      expect(settings.floatingLyricsDiscoveryCompleted, isTrue);
      expect(settings.canShowFloatingLyricsDiscovery, isFalse);
    });

    test('caps malformed discovery impression counts', () {
      final settings = AppSettings.fromJson({
        'schemaVersion': AppSettings.schemaVersion,
        'floatingLyricsDiscoveryImpressions': 99,
        'floatingLyricsDiscoveryCompleted': false,
      });

      expect(
        settings.floatingLyricsDiscoveryImpressions,
        AppSettings.maxFloatingLyricsDiscoveryImpressions,
      );
      expect(settings.canShowFloatingLyricsDiscovery, isFalse);
    });
  });
}
