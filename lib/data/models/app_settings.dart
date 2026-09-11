enum AppThemePreference {
  dark,
  light,
  system;

  static AppThemePreference fromStorageValue(Object? value) => switch (value) {
        'light' => AppThemePreference.light,
        'system' => AppThemePreference.system,
        _ => AppThemePreference.dark,
      };
}

class AppSettings {
  const AppSettings({
    this.congregationMode = false,
    this.fontScaleFactor = 1.0,
    this.autoScrollEnabled = true,
    this.themePreference = AppThemePreference.dark,
    this.floatingLyricsDiscoveryImpressions = 0,
    this.floatingLyricsDiscoveryCompleted = false,
  });

  static const schemaVersion = 3;
  static const maxFloatingLyricsDiscoveryImpressions = 2;

  final bool congregationMode;
  final double fontScaleFactor;
  final bool autoScrollEnabled;
  final AppThemePreference themePreference;
  final int floatingLyricsDiscoveryImpressions;
  final bool floatingLyricsDiscoveryCompleted;

  bool get canShowFloatingLyricsDiscovery =>
      !floatingLyricsDiscoveryCompleted &&
      floatingLyricsDiscoveryImpressions <
          maxFloatingLyricsDiscoveryImpressions;

  factory AppSettings.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const AppSettings();
    }

    final storedSchemaVersion = json['schemaVersion'];
    if (storedSchemaVersion != 1 &&
        storedSchemaVersion != 2 &&
        storedSchemaVersion != schemaVersion) {
      return const AppSettings();
    }

    final storedScale = json['fontScaleFactor'];
    final legacyDiscoveryShown = storedSchemaVersion == 2 &&
        json['floatingLyricsDiscoveryShown'] == true;
    final storedDiscoveryImpressions =
        json['floatingLyricsDiscoveryImpressions'];
    return AppSettings(
      congregationMode: json['congregationMode'] is bool
          ? json['congregationMode'] as bool
          : false,
      fontScaleFactor: storedScale is num
          ? storedScale.toDouble().clamp(0.8, 1.6).toDouble()
          : 1.0,
      autoScrollEnabled: json['autoScrollEnabled'] is bool
          ? json['autoScrollEnabled'] as bool
          : true,
      themePreference:
          AppThemePreference.fromStorageValue(json['themePreference']),
      floatingLyricsDiscoveryImpressions: legacyDiscoveryShown
          ? maxFloatingLyricsDiscoveryImpressions
          : storedDiscoveryImpressions is num
              ? storedDiscoveryImpressions
                  .toInt()
                  .clamp(0, maxFloatingLyricsDiscoveryImpressions)
                  .toInt()
              : 0,
      floatingLyricsDiscoveryCompleted: legacyDiscoveryShown ||
          (json['floatingLyricsDiscoveryCompleted'] is bool &&
              json['floatingLyricsDiscoveryCompleted'] as bool),
    );
  }

  AppSettings copyWith({
    bool? congregationMode,
    double? fontScaleFactor,
    bool? autoScrollEnabled,
    AppThemePreference? themePreference,
    int? floatingLyricsDiscoveryImpressions,
    bool? floatingLyricsDiscoveryCompleted,
  }) =>
      AppSettings(
        congregationMode: congregationMode ?? this.congregationMode,
        fontScaleFactor: fontScaleFactor ?? this.fontScaleFactor,
        autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
        themePreference: themePreference ?? this.themePreference,
        floatingLyricsDiscoveryImpressions:
            floatingLyricsDiscoveryImpressions ??
                this.floatingLyricsDiscoveryImpressions,
        floatingLyricsDiscoveryCompleted: floatingLyricsDiscoveryCompleted ??
            this.floatingLyricsDiscoveryCompleted,
      );

  Map<String, Object> toJson() => {
        'schemaVersion': schemaVersion,
        'congregationMode': congregationMode,
        'fontScaleFactor': fontScaleFactor,
        'autoScrollEnabled': autoScrollEnabled,
        'themePreference': themePreference.name,
        'floatingLyricsDiscoveryImpressions':
            floatingLyricsDiscoveryImpressions,
        'floatingLyricsDiscoveryCompleted': floatingLyricsDiscoveryCompleted,
      };
}
