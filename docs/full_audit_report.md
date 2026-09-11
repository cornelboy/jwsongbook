# JW Songs Full Audit Report

**Date:** September 8, 2026
**Auditor:** Buffy (AI Agent)
**App Version:** 0.1.0+1 (Alpha)
**Flutter SDK:** 3.24+ with Dart 3.4+

---

## Executive Summary

The project is in **good shape for an alpha release**. Static analysis passes cleanly, all 123 tests pass, and the core architecture is solid. Key areas needing attention are test coverage gaps, outdated dependencies, and a few TODOs remaining in the codebase.

| Area | Status | Notes |
|------|--------|-------|
| Static Analysis | ✅ PASS | 0 issues found |
| Unit/Widget Tests | ✅ PASS | 123/123 tests passed |
| Test Coverage | ⚠️ 52.9% | Below 80% target; critical gaps in repositories |
| Code Quality | ✅ GOOD | No print statements, minimal TODOs |
| Dependencies | ⚠️ OUTDATED | 72 packages have newer versions |
| Security | ✅ GOOD | No hardcoded secrets; URL is public manifest |
| Asset Structure | ✅ GOOD | Properly organized |

---

## 1. Static Analysis (flutter analyze)

**Result:** ✅ No issues found

- Lint rules enforced: strict-casts, strict-inference, strict-raw-types
- All generated files (*.g.dart, *.freezed.dart) properly excluded
- No warnings, no errors, no info messages

---

## 2. Test Suite (flutter test)

**Result:** ✅ 123/123 tests passed (100% pass rate)

### Test Breakdown by Feature

| Feature | Tests | Status |
|---------|-------|--------|
| Lyrics Overlay Bubble | 8 | ✅ All pass |
| App Settings | 4 | ✅ All pass |
| Audio Interruption Handler | 5 | ✅ All pass |
| ELRC Parser | 16 | ✅ All pass |
| Playlists Repository | 5 | ✅ All pass |
| Songs Repository | 21 | ✅ All pass |
| Lyrics Repository | 8 | ✅ All pass |
| Song Manifest Model | 6 | ✅ All pass |
| Download Controller | 3 | ✅ All pass |
| Download Play Intent | 1 | ✅ All pass |
| Manage Downloads Screen | 10 | ✅ All pass |
| Lyrics Follow | 6 | ✅ All pass |
| Mini Player Motion | 6 | ✅ All pass |
| Player First Play | 2 | ✅ All pass |
| Playlists Flow | 8 | ✅ All pass |
| **Total** | **123** | **✅** |

---

## 3. Test Coverage Analysis

**Overall:** 3075/5810 lines covered (52.9%)

### Files with 0% Coverage (Critical Gaps)

| File | Lines | Priority | Status |
|------|-------|----------|--------|
| `lib/data/repositories/songs_repository.dart` | 205 | 🔴 HIGH | ✅ Tests added |
| `lib/core/platform/lyrics_overlay_bubble.dart` | 177 | 🔴 HIGH | ✅ Tests added |
| `lib/features/downloads/screens/manage_downloads_screen.dart` | 119 | 🟡 MEDIUM | ✅ Tests added |
| `lib/data/repositories/lyrics_repository.dart` | 53 | 🟡 MEDIUM | ✅ Tests added |
| `lib/data/database/tables/songs_table.dart` | 11 | 🟢 LOW | Table definition |
| `lib/data/models/song_model.dart` | 4 | 🟢 LOW | Simple model |

### Well-Covered Files (100%+)

- `lib/data/models/app_settings.dart` — 100%
- `lib/data/parsers/elrc_parser.dart` — 100%
- `lib/data/repositories/playlists_repository.dart` — 100%
- `lib/shared/widgets/empty_state.dart` — 100%
- `lib/shared/widgets/offline_download_icon.dart` — 100%
- `lib/features/player/providers/playback_queue.dart` — 100%
- `lib/features/playlists/widgets/playlist_cover.dart` — 100%

---

## 4. Code Quality Findings

### TODOs Found

| File | Line | TODO |
|------|------|------|
| `lib/packages/just_audio_background/lib/just_audio_background.dart` | 921 | `// TODO: This should combine indices of the children, like ConcatenatingAudioSource.` |

**Assessment:** Only 1 TODO remaining in the codebase (in a vendored package). This is acceptable.

### Debug Statements

- **print() calls:** 0 found ✅
- **debugPrint() calls:** None found ✅
- **developer.log() calls:** 1 found in `main.dart` (appropriate for startup error logging) ✅

### Hardcoded Values

- Manifest URL in `app_constants.dart` is properly externalized via `--dart-define` ✅
- All magic numbers centralized in `AppConstants` class ✅
- No hardcoded API keys, secrets, or credentials found ✅

---

## 5. Dependency Audit

### Outdated Direct Dependencies

| Package | Current | Latest | Severity |
|---------|---------|--------|----------|
| `flutter_riverpod` | 2.6.1 | 3.4.3 | 🔴 Major version behind |
| `riverpod_annotation` | 2.6.1 | 4.0.7 | 🔴 Major version behind |
| `riverpod_generator` | 2.6.4 | 4.0.9 | 🔴 Major version behind |
| `go_router` | 14.8.1 | 18.0.1 | 🔴 Major version behind |
| `freezed` | 2.5.8 | 4.0.1 | 🔴 Major version behind |
| `freezed_annotation` | 2.4.4 | 3.1.0 | 🔴 Major version behind |
| `drift` | 2.28.2 | 2.34.4 | 🟡 Minor behind |
| `just_audio` | 0.9.46 | 0.10.6 | 🟡 Minor behind |
| `flutter_lints` | 4.0.0 | 6.0.0 | 🟡 Minor behind |

**Recommendation:** Riverpod, go_router, and freezed upgrades are major version bumps with breaking changes. Plan a dedicated upgrade sprint. Drift and just_audio can be upgraded with less risk.

### Vulnerable/Discontinued Packages

- `build_resolvers` — marked as discontinued
- `build_runner_core` — marked as discontinued
- `sqlite3_flutter_libs` 0.6.0+eol — end-of-life marker

---

## 6. Security Review

| Check | Status | Notes |
|-------|--------|-------|
| No hardcoded secrets | ✅ | Only public manifest URL |
| No API keys in code | ✅ | App is offline-first |
| Permissions justified | ✅ | INTERNET, FOREGROUND_SERVICE, WAKE_LOCK, SYSTEM_ALERT_WINDOW all needed |
| Manifest URL externalized | ✅ | Overridable via `--dart-define` |
| No sensitive data logging | ✅ | Error logging uses `developer.log` |

### Android Permissions

- `WAKE_LOCK` — Needed for background audio
- `INTERNET` — Needed for song downloads
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` — Background audio
- `SYSTEM_ALERT_WINDOW` — Floating lyrics bubble overlay

All permissions are justified for the app's functionality.

---

## 7. Architecture Review

### Strengths
- Clean feature-based folder structure under `lib/features/`
- Proper separation: data/models, data/repositories, data/services
- Constants centralized in `AppConstants`
- Riverpod providers for state management
- Generated code properly excluded from analysis

### Areas for Improvement
- `songs_repository.dart` (205 lines) has 0% test coverage — this is the most critical data layer
- `lyrics_overlay_bubble.dart` (177 lines) has 0% test coverage — FLB is a key feature
- Consider adding integration tests for the full playback flow

---

## 8. Launch Readiness Assessment

Referencing `launch_readiness/launch_phases.md`:

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Core Playback | ✅ Ready | Tests pass, no known issues |
| Phase 2: Lyrics Sync | ✅ Ready | 16 ELRC parser tests, sync provider tested |
| Phase 3: FLB | ⚠️ Partial | Tests exist but 0% coverage on bubble widget |
| Phase 4: Downloads | ⚠️ Partial | Controller tested, UI untested |
| Phase 5: Content | ✅ Ready | Manifest system works |
| Phase 6: Performance | 🔴 Not Tested | No benchmarks run |
| Phase 7: Cross-Device | 🔴 Not Tested | No device matrix results |
| Phase 8: Release Packaging | ⚠️ Partial | Build works, no signed release yet |
| Phase 9: Private Beta | 🔴 Not Started | |
| Phase 10: Public Launch | 🔴 Not Started | |

---

## 9. Recommendations

### Immediate (Before Beta)

1. ~~**Add tests for `songs_repository.dart`**~~ ✅ Done — 21 tests added
2. ~~**Add tests for `lyrics_overlay_bubble.dart`**~~ ✅ Done — 8 tests added
3. **Run performance benchmarks** — Verify 60fps lyrics animation, <3s startup, <500MB install

### Short-term (Next Sprint)

4. **Upgrade Riverpod ecosystem** — Currently 2 major versions behind (2.x → 4.x)
5. **Upgrade go_router** — Currently 4 major versions behind (14.x → 18.x)
6. **Add integration tests** — Full playback flow test (select → play → lyrics → next)

### Medium-term

7. **Increase test coverage to 80%** — Currently at 52.9% (up from 47.2%)
8. **Replace discontinued build packages** — `build_resolvers`, `build_runner_core`
9. **Device matrix testing** — Test on 3+ Android versions

---

## 10. Summary

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Static analysis issues | 0 | 0 | ✅ |
| Test pass rate | 100% | 100% | ✅ |
| Test count | 123 | 50+ | ✅ |
| Test coverage | 52.9% | 80% | ❌ |
| TODOs in code | 1 | 0 | ⚠️ |
| Critical security issues | 0 | 0 | ✅ |
| Outdated major deps | 6 | 0 | ⚠️ |

**Overall Assessment:** The project is solid for an alpha release but needs test coverage improvements and dependency upgrades before a public launch.

---

*Report generated by automated audit on September 8, 2026*
*Updated: September 8, 2026 — 50 new tests added, coverage improved to 52.9%*
