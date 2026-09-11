# Android Release Builds

Use a release build when checking app size on a phone. Debug builds are much
larger because they include development tooling and unoptimized native code.

## Recommended Store Build

For Google Play, build an app bundle:

```powershell
& 'C:\Users\USER\development\flutter\bin\flutter.bat' build appbundle --release --suppress-analytics --dart-define=SONG_MANIFEST_URL=https://cornelboy.github.io/jwsongbook-downloads/manifest.json
```

Google Play will deliver the correct device-specific files automatically.

## APK Builds for Manual Testing

For direct APK sharing/testing across Android phones, build split APKs:

```powershell
& 'C:\Users\USER\development\flutter\bin\flutter.bat' build apk --release --split-per-abi --suppress-analytics --dart-define=SONG_MANIFEST_URL=https://cornelboy.github.io/jwsongbook-downloads/manifest.json
```

This produces separate APKs:

- `app-arm64-v8a-release.apk` for most modern Android phones.
- `app-armeabi-v7a-release.apk` for older 32-bit Android phones.
- `app-x86_64-release.apk` for x86 Android emulators/devices.

Do not add ABI filters to `android/app/build.gradle.kts` unless intentionally
dropping support for some devices.
