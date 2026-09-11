# Critical Risk Remediation Plan

**Source:** [full_audit_report.md](./full_audit_report.md)
**Created:** September 8, 2026
**Auditor:** Buffy (AI Agent)

---

## Risk 1: Test Coverage (47.2% → 80%)

**Status:** ✅ In Progress — Coverage improved from 47.2% → **52.9%** (3075/5810 lines)

**Current state:** 123 tests pass, coverage is 52.9% against an 80% target. Four critical files now have tests.

### 1A. `songs_repository.dart` (205 lines) ✅ DONE

**21 tests added** covering all CRUD methods, catalog sync, search, favorites, downloads, and migrations.

### 1B. `lyrics_overlay_bubble.dart` (177 lines) ✅ DONE

**8 tests added** covering route suppression edge cases, state serialization, type safety for platform channel.

### 1C. `lyrics_repository.dart` (53 lines) ✅ DONE

**8 tests added** covering loadForSong, importElrcForSong, section breaks, empty state.

### 1D. `manage_downloads_screen.dart` (119 lines) ✅ DONE

**10 tests added** covering `formatDownloadBytes`, `DownloadedSongInfo`, `DownloadedSongsSummary`.

### 1E. Remaining gap to hit 80%

**Coverage: 52.9% (3075/5810 lines)**. To close the remaining ~27% gap, widget tests for screens with full provider mocking are needed. Better suited for integration tests on a real device.

---

## Risk 2: Outdated Dependencies

The pubspec shows 6 major-version-behind packages:

| Package | Current | Latest | Effort |
|---------|---------|--------|--------|
| `flutter_riverpod` | ^2.5.1 | 3.4.3 | 🔴 High — breaking API changes |
| `riverpod_annotation` | ^2.3.5 | 4.0.7 | 🔴 High — paired with riverpod |
| `riverpod_generator` | ^2.4.3 | 4.0.9 | 🔴 High — paired with riverpod |
| `go_router` | ^14.3.0 | 18.0.1 | 🔴 High — 4 major versions |
| `freezed` | ^2.5.2 | 4.0.1 | 🔴 High — breaking changes |
| `freezed_annotation` | ^2.4.4 | 3.1.0 | 🔴 High — paired with freezed |

### Recommended upgrade phases (separate PRs):

**Phase A — Low-risk upgrades first (safe, no breaking changes)**
- `drift` ^2.20 → 2.34
- `just_audio` ^0.9.40 → 0.10.6
- `flutter_lints` ^4.0 → 6.0

**Phase B — Freezed upgrade (do before Riverpod since Riverpod depends on it)**
1. Upgrade `freezed_annotation` → `freezed`
2. Run `build_runner` to regenerate
3. Fix any generated code changes
4. Verify all tests pass

**Phase C — Riverpod + go_router upgrade (biggest effort)**
1. Upgrade `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` together
2. Upgrade `go_router`
3. Run `build_runner` to regenerate all `.g.dart` files
4. Fix all provider annotations and router configuration
5. Verify all tests pass

Each phase should be a separate PR with tests passing before merging.

---

## Risk 3: Performance Not Tested

No benchmarks have been run. Key targets from the audit:

| Metric | Target | How to measure |
|--------|--------|----------------|
| Cold start | <3s | `flutter run --profile --trace-startup` |
| Song start | <500ms | Stopwatch from tap to first audio heard |
| Lyrics animation | 60fps | DevTools → Performance overlay |
| Memory usage | <150MB | DevTools → Memory tab (heap snapshot during playback) |
| Sync calculation | <2ms/frame | Custom Stopwatch in sync loop |
| App size (installed) | <500MB | Build APK/IPA and check file size |

### Steps

```bash
# 1. Startup time
flutter run --profile --trace-startup

# 2. Memory usage
flutter run --profile
# Open DevTools → Memory → take heap snapshot during lyrics playback

# 3. Frame rate
# DevTools → Performance → enable overlay
# Play a song with synced lyrics — verify 60fps (no dropped frames)

# 4. Install size
flutter build apk --release
flutter build ios --release --no-codesign
```

---

## Risk 4: Cross-Device Testing

No device matrix results exist yet. Minimum matrix:

| Device | OS | Purpose |
|--------|-----|---------|
| Budget Android (2GB RAM) | Android 9+ | Baseline performance |
| Mid-range Android | Android 12 | Main user base |
| iPhone SE (2nd gen) | iOS 15+ | Smallest screen, oldest supported iOS |
| iPhone 12/13 | iOS 16+ | Common device |
| iPad (if supporting projection) | iPadOS | Congregation mode |

### Per-device test checklist

- [ ] App launches and loads song list
- [ ] Play a song → lyrics sync correctly
- [ ] Background playback works
- [ ] Lock screen controls work
- [ ] Offline mode (airplane mode) works
- [ ] FLB overlay permissions flow works (Android)

---

## Priority Order

1. **Risk 1 (Tests)** — Highest impact, no risk of breaking existing code. Do first.
2. **Risk 2 (Dependencies)** — High effort but necessary. Phase A can be done anytime; Phase B+C need dedicated sprints.
3. **Risk 3 (Performance)** — Quick to measure, but fixes may overlap with dependency upgrades.
4. **Risk 4 (Cross-Device)** — Requires physical devices. Can run in parallel with other work.

---

*Plan generated alongside the full audit report on September 8, 2026*
*Updated: September 8, 2026 — Risk 1 tasks 1A–1D complete. Coverage improved 47.2% → 52.9%.*
