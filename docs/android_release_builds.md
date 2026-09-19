# Android Release Builds

Use a release build when checking app size on a phone. Debug builds are much
larger because they include development tooling and unoptimized native code.

## Configure Release Signing

Release builds deliberately do not fall back to Flutter's debug key. Generate
and protect a dedicated upload keystore before building a release. Do not
commit the keystore or its passwords; `android/.gitignore` excludes
`key.properties`, `*.jks`, and `*.keystore`.

One way to generate an upload keystore is:

```powershell
keytool -genkeypair -v -keystore "$env:USERPROFILE\upload-keystore.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties` locally with these four values:

```properties
storePassword=replace-with-keystore-password
keyPassword=replace-with-key-password
keyAlias=upload
storeFile=C:/Users/you/upload-keystore.jks
```

Use forward slashes or escaped backslashes in the Windows path. Keep an
encrypted backup of the keystore and credentials outside the repository. Losing
the upload key can prevent direct APK updates and requires the Google Play key
reset process for Play-distributed apps.

If `key.properties`, a required property, or the referenced keystore is missing,
a release task stops with a clear error. Debug builds remain signed with the
normal local debug certificate and require no release-signing setup.

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

## Verify the APK Signature

After building, verify that the APK is signed and inspect its certificate:

```powershell
apksigner verify --verbose --print-certs build\app\outputs\flutter-apk\app-release.apk
```

Record the release certificate SHA-256 fingerprint somewhere secure before
sharing the first build. Future versions must use the same signing identity for
Android to accept them as updates.

## Backup Policy

Android backup and device-to-device transfer are disabled for this app. The
local database, preferences, downloaded audio, and lyrics can be recreated or
downloaded again, while excluding them avoids copying private app state to cloud
backup or another device. The manifest disables backup and the XML extraction
rules exclude every app-private storage domain as defense in depth across
Android versions.
