# Production Readiness Roadmap - Tracker

**Prepared:** 2026-09-02 - **Target release:** v1.0.0+1 - **Status: Phase 1 executed 2026-09-03; Phases 2-6 pending**

Platforms: iOS, Android, macOS, Windows, Linux. Product promise: **offline first, no account, no data collection** - this promise reshapes the standard Flutter launch checklist (see Phase 0). Items marked **N/A (offline)** are documented as intentionally skipped so nobody re-adds them later.

**Execution order = document order.** Phases are numbered in the intended execution sequence - work
top to bottom, no reordering needed

---

## Phase 0 - Scope notes that reshape the standard checklist

- **No backend, no API keys, no SSL pinning, no ATT, no analytics SDKs.** The standard "secure your API" phase collapses into "keep the app offline and prove it."
- **User data is the product and there is no cloud.** Durability, backup/export, and Isar schema discipline move from "nice-to-have" to **Critical**: an uninstall or lost phone erases everything unless the app provides an escape hatch.
- **`isar_community` fork risk.** The app depends on a community-maintained fork (`isar_community ^3.3.2`) of a stalled upstream project. This is a long-term maintenance liability to manage explicitly.
- **Five platforms = five packaging/signing pipelines.** Android and iOS are the established paths; macOS notarization, Windows code signing, and Linux packaging each have their own prerequisites.
- **Known current-state gates** (from CLAUDE.md / memory): batch 3 UI fixes remain; some features incomplete or absent; `tracker/ios/Podfile.lock` possibly stale; test-only `libisar.dylib` copy in `tracker/` (gitignored, fine, but keep it out of release tooling).
- **Dependency pin is load-bearing:** `dependency_overrides: path_provider_android <2.3.0` works around a `jni` 1.0.x compile break. Re-verify when `path_provider_android` 2.3.x+ ships a fixed `jni`.

### Decisions (2026-09-02)

- **Platform scope: mobile-first.** v1.0 ships **iOS (App Store) + Android (Play) only**.
  macOS / Windows / Linux are deferred to v1.1+ and would distribute via unsigned GitHub
  Releases at that point. Postponed until then: macOS MAS-vs-notarization choice, Windows
  cert-vs-MS-Store choice. Phase 5 signing inventory shrinks to **Android keystore + Apple
  distribution cert**; desktop CI build jobs stay only as unsigned compile canaries (Phase 3).
- **isar_community strategy: stay + document escape hatch.** No migration before 1.0. Phase 1
  writes the one-paragraph drift/SQLite migration note as a decision record; CI pins exact
  versions; dependabot watches the fork for releases/security fixes.

*Phase 0 assumption checks passed 2026-09-02: override + fork pins present in `pubspec.yaml`;
zero TODO/FIXME in `lib/`; `libisar.dylib` gitignored and out of release tooling.*

---

## Phase 1 - Codebase & Architecture Hardening

### Critical / Blocker

- [x] **Centralized error handling.** Add app-level handlers in `main.dart`: `runZonedGuarded`,
  `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and a custom `ErrorWidget.builder`.
  Route everything into a tiny file-based ring-buffer logger (local-only; feeds the offline
  bug-report flow, see Phase 6).

  ```dart
  void main() {
    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (d) => AppLog.error('flutter', d.exception, d.stack);
      PlatformDispatcher.instance.onError = (e, s) { AppLog.error('platform', e, s); return true; };
      await bootstrap(); // Isar open + seed, HydratedBloc storage, runApp
    }, (e, s) => AppLog.error('zone', e, s));
  }
  ```

- [x] **Hydrated state versioning.** `WorkoutState`/`SettingsState` `fromJson` must tolerate shape changes across releases. Add a `schemaVersion` int to each JSON payload; write migration functions instead of relying on null-forgiving casts. Keep/extend the malformed-hydration tests as the contract. *(Done 2026-09-03: `'v'` field + `_fromV1` parsers + unknown-version fallback + tests.)*

  ```dart
  factory WorkoutState.fromJson(Map<String, dynamic> json) {
    switch (json['v'] as int? ?? 1) {
      case 1: return _fromV1(json);
      // case 2: return _fromV2(json);
      default: return WorkoutState.idle(); // never crash on unknown future version
    }
  }
  ```

- [x] **Isar schema discipline (pre-1.0 freeze rules).** No field renames or deletions until after 1.0 - additive changes only (Isar auto-migrates added fields; renames lose data). Document the current schema once in `CLAUDE.md`. *(Done 2026-09-03: `docs/ISAR_SCHEMA.md` + CLAUDE.md pointer.)*
- [x] **isar_community dependency risk plan.** Pin exact versions in CI, watch the fork for releases/security fixes, and write a one-paragraph escape-hatch note (migration path to `drift`/SQLite if the fork dies). This is a decision record, not code. *(Done 2026-09-03: `docs/adr/0001-isar-community.md`; committed `pubspec.lock` pins CI versions; automated watch deferred.)*
- [x] **Debug artifact sweep.**

  ```powershell
  # from tracker/
  rg -n "print\(|debugPrint|TODO|FIXME|XXX" lib/ --glob '!*.g.dart'
  ```

  Wrap any intentional verbose logging in `if (kDebugMode)`. Resolve or ticket every TODO before submission. *(Done 2026-09-03: zero TODO/FIXME; one `debugPrint` moved to AppLog.)*
- [x] **Unused dependency / asset audit.** Dependency list is already lean (isar_community, path_provider, quiver, hydrated_bloc, flutter_bloc, window_size, forui, forui_lucide). Verify `quiver` usage specifically (likely replaceable with core Dart). Add `dependency_validator` to CI to keep it that way. Audit `pubspec.yaml` asset/font entries against actual files. *(Done 2026-09-03: quiver dropped (BiMap hand-rolled), `dependency_validator` in CI with allow-list in `tracker/dependency_validator.yaml`; pubspec declares no assets/fonts.)*

### High Priority

- [x] **Error-surfacing contract for writes.** Feed already models loading/empty/error. Extend the pattern to mutations, especially `WorkoutCubit.endWorkout`: if the Isar write fails, the in-progress workout must NOT be discarded from HydratedStorage. Add a test for that exact failure path. *(Done 2026-09-03: transient `saveError` state + FToaster toast + failing-write test.)*
- [x] **Environment configuration via `--dart-define`** (full flavors are overkill for an offline v1):

  ```bash
  flutter build appbundle --release --dart-define=APP_ENV=prod
  ```

  Read via `const String.fromEnvironment('APP_ENV', defaultValue: 'dev')`. Use it to force dev seed data, verbose logging, and debug-only affordances off in prod. *(Done 2026-09-03: `lib/data/services/app_env.dart`; wired to AppLog verbosity + prod ErrorWidget fallback.)*
- [x] **Toolchain pinning.** `pubspec.yaml` already pins Flutter 3.47.2; ensure CI and local docs match, and record intended Dart SDK upper bound. *(Verified 2026-09-03: CI reads `flutter-version-file: tracker/pubspec.yaml`; SDK bound `>=3.13.2 <4.0.0`.)*
- [x] **Re-verify `path_provider_android` override** each minor bump (`jni` issue #3235 may get a fixed release; the comment in `pubspec.yaml` documents it). *(Verified 2026-09-03: `path_provider_android` 2.3.1 still pulls `jni ^1.0.0`, latest `jni 1.0.3` still broken - override `<2.3.0` stays, lockfile holds 2.2.23.)*

---

## Phase 2 - Security & Compliance

### Critical / Blocker

- [ ] **Data durability: export + auto-backup.** The flagship offline-app risk. Ship (a) user-facing export/import (canonical JSON of all collections), (b) automatic rotating local backup on app start (e.g., keep last 3 DB copies in app-support dir). Test the *restore* path, not just export.
- [ ] **Explicit encryption decision.** Isar supports `Isar.open(..., encryptionKey: ...)`. Decide and document one of: (a) device-level encryption is sufficient for v1 (defensible default; document the decision), or (b) app-level DB encryption - then keys need `flutter_secure_storage` (note: Linux desktop backend requires `libsecret` at runtime).
- [ ] **Privacy policy URL.** Both stores require one even with zero collection. One static page stating: all data stays on device, no analytics, no network use.
- [ ] **Google Play Data Safety form.** Declare "no data collected, no data shared." Justified only
  if verified: run a full functional pass in airplane mode (see Phase 3, airplane-mode release gate)
  and confirm no dependency makes network calls (flutter_bloc, forui, path_provider, window_size,
  isar_community - none do; the Flutter *runtime* does not phone home, only the Flutter *tool* sends
  dev-side analytics).
- [ ] **Android 16 KB page-size compliance.** Play requires 16 KB support for new apps targeting recent Android. Verify the fork's native binaries are 16 KB-aligned before trusting `isar_community 3.3.2`:

  ```bash
  unzip -o app-release.apk lib/arm64-v8a/libisar.so -d /tmp/apkcheck
  llvm-readelf -lW /tmp/apkcheck/lib/arm64-v8a/libisar.so | grep LOAD
  # every LOAD segment "Align" column must read 0x4000 (16384)
  ```

  If misaligned: bump the fork / rebuild its native core / plan migration. Repeat for `libisar.so` in each ABI.
- [ ] **Target SDK current.** Use the newest `targetSdkVersion` Play requires this year (check Play Console's current deadline - it advances annually). Flutter 3.47.2 sets this per build config.

### High Priority

- [ ] **Release hardening flags on every store build** (v1.0 = mobile only; desktop lines
  deferred to v1.1+ per Phase 0 decision):

  ```bash
  flutter build appbundle --release \
    --obfuscate --split-debug-info=build/symbols/android
  flutter build ipa --release \
    --obfuscate --split-debug-info=build/symbols/ios
  # v1.1+: flutter build windows --release --obfuscate --split-debug-info=build/symbols/windows
  # v1.1+: flutter build macos --release --obfuscate --split-debug-info=build/symbols/macos
  # v1.1+: flutter build linux --release --obfuscate --split-debug-info=build/symbols/linux
  ```

  Archive `build/symbols/*` per release for symbolication. Obfuscation is safe with Isar/build_runner codegen (no reflection).
- [ ] **Permissions audit.** AndroidManifest should declare nothing beyond what features use (add `POST_NOTIFICATIONS` + runtime request only when the notification feature lands). iOS `Info.plist` usage strings: none needed today; add any only when a feature demands it. Fewer permissions = better review and better Play listing trust.
- [ ] **Documented as N/A (offline):** SSL/TLS pinning, network security config, App Tracking Transparency, advertising ID. Revisit only if any network feature is ever added.
- [ ] **Local notifications compliance** (SettingsCubit already has notification prefs): Android 13+ runtime permission flow, exact-alarm restrictions if scheduling is used.

### Nice-to-Have

- [ ] `flutter_secure_storage` if and only if app-level DB encryption is chosen.
- [ ] Play "Independent security review" / integrity features - unnecessary for an offline app; skip.

---

## Phase 3 - Testing & QA

**Current base (strong):** domain unit tests, Isar CRUD tests, cubit/widget tests, overflow assertions, 66-screenshot visual sweep, `flutter analyze` + generated-code checks on CI (ubuntu).

### Critical / Blocker

- [ ] **Coverage floors enforced in CI:** `flutter test --coverage` + a summary gate. Suggested floors: `domain/` + `data/` >= 80% lines, `ui/view_models/` >= 70%. UI widget coverage is tracked, not gated.
- [ ] **Integration tests** (`integration_test` package) for the money paths, run on an Android emulator + iOS simulator in CI or pre-release locally: start plan workout -> log sets/warmups -> end workout -> session appears in History and analytics; settings unit switch reflects everywhere; split CRUD round-trip.
- [ ] **Airplane-mode full pass as a release gate.** Entire smoke checklist on a device with radios
  off - this *is* the proof of the 100%-offline claim backing the Data Safety form (Phase 2).
- [ ] **Manual per-platform smoke checklist** (one page, ~15 items): first-run seed, create workout, end workout, history, analytics graph CRUD, settings, export/import, backup restore. Execute on both mobile platforms before every store submission (desktop joins at v1.1+).

### High Priority

- [ ] **Crash/error reporting - the offline answer.** No Crashlytics/Sentry (Phase 0: no backend, no
  analytics SDKs - the standard crash-reporting item of an online app is intentionally dropped). The
  offline replacement: the Phase 1 ring-buffer logger plus a user-facing "export data + logs" action
  built on the Phase 2 export feature, doubling as the bug-report mechanism (see Phase 6 support
  loop).
- [ ] **Cross-platform CI expansion.** Today: ubuntu (analyze, tests, sweep). Add: `macos-latest` job that builds iOS + macOS (unsigned) and a `windows-latest` job that builds Windows - build-passing gates catch platform breaks early; signing stays local/late.
- [ ] **Accessibility pass.** TalkBack/VoiceOver over main flows; 200% text scale (the sweep covers 320x568 smallness - add largest-scale variants); contrast on the Forui theme; every tappable >= 44x44 pt.
- [ ] **Real-device soak of the release build** (not just debug): one full workout logged on each mobile platform from the store-build artifact.

### Nice-to-Have

- [ ] Golden tests for core screens derived from the existing sweep infra.
- [ ] Beta rings: TestFlight internal (<= 5 testers) -> Play internal -> closed testing; desktop builds distributed via GitHub Releases to a friends ring.

---

## Phase 4 - Performance & Resource Optimization

### Critical / Blocker

- [ ] **Profile release builds on real hardware** - at minimum one Android phone, one iPhone, one
  desktop. Debug builds lie.

  ```bash
  cd tracker
  flutter run --profile          # DevTools -> Timeline / Frame Analysis
  flutter build apk --release --analyze-size   # size audit
  ```

- [ ] **Isar query audit.** Add indexes for every queried/watched field (session dates,
  `exerciseId`, gym id). Confirm `watchAll()` and history/analytics paths never deserialize whole
  collections into memory; paginate or window the History list as session count grows.
- [ ] **120 Hz check.** Test on a ProMotion iPhone / 120 Hz Android. Modern Flutter uses Impeller -
  watch the custom `LineChart` `CustomPainter` for shader/first-draw jank and recompute cost per
  frame; cache paths outside `paint()`.

### High Priority

- [ ] **Rebuild reduction.** `BlocBuilder` with `buildWhen` (or `context.select`) on the workout
  tab - the per-exercise cards must not all rebuild per logged set. `const` constructors on static
  subtrees; `ListView.builder` for any list that grows.
- [ ] **Memory soak.** 30-minute simulated workout session with DevTools memory view: confirm Isar
  watchers, chart/controllers, and `ReorderableListView` state are disposed; single Isar instance (
  already true via `db.dart`).
- [ ] **Bundle size.** AAB for Play; `--split-per-abi` only if distributing APKs directly. Subset
  Inter/Lucide fonts to used glyphs if fonts dominate size. Note `libisar` native libs are multi-MB
  on every desktop target - acceptable offline cost, but measure.
- [ ] **Cold start budget.** Target < 2.5 s to interactive on a mid-range Android; defer seeding
  only if measured as a cost.

### Nice-to-Have

- [ ] Timeline events around `endWorkout` (Isar write + multiplier estimation) for future profiling.
- [ ] Frame-budget regression tracking in the existing visual sweep.

---

## Phase 5 - CI/CD & Release Management

### Critical / Blocker

- [ ] **Signing inventory - create and back up before anything else.**

  | Platform | Needs | Notes |
  | --- | --- | --- |
  | Android | Upload keystore + passwords | **Back up offline twice.** Enroll Play App Signing so a lost key is survivable. |
  | iOS | Distribution cert + App Store profile | App Store Connect -> Certificates; match bundle ID. |
  | macOS | *Deferred v1.1+* | Ships via unsigned GitHub Releases then; MAS/Developer-ID decision postponed (Phase 0). |
  | Windows | *Deferred v1.1+* | Unsigned GitHub Releases then; SmartScreen warning accepted at first; cert-vs-MS-Store decision postponed (Phase 0). |
  | Linux | *Deferred v1.1+* | AppImage/deb/flatpak unsigned is normal when it ships. |

  Secrets go in GitHub Actions secrets; raw keys never in repo.

- [ ] **Tag-driven release workflow** on GitHub Actions (extend existing `dart.yml`) — v1.0
  ships the two store jobs only; desktop jobs return at v1.1+ (Phase 0):

  ```yaml
  on: { push: { tags: ["v*"] } }
  jobs:
    android: { runs-on: ubuntu-latest,  steps: [checkout, java, flutter, build appbundle, upload artifact] }
    ios:     { runs-on: macos-latest,   steps: [checkout, flutter, build ipa, upload artifact] }
    # v1.1+: macos   { runs-on: macos-latest,   steps: [checkout, flutter, build macos, zip, upload] }
    # v1.1+: windows { runs-on: windows-latest, steps: [checkout, flutter, build windows, msix, upload] }
    # v1.1+: linux   { runs-on: ubuntu-latest,  steps: [checkout, flutter, build linux, appimage/deb, upload] }
  ```

  First milestone: unsigned artifacts + drafted GitHub Release per tag. Then layer signing, then store uploads.
- [ ] **Versioning scheme.** `pubspec.yaml` `version: 1.0.0+1` is the single source: `X.Y.Z` for humans, `+N` build number increments every upload (Play and App Store both reject reused build numbers). Document the bump rule (e.g., CI or release script rewrites pubspec per tag).

### High Priority

- [ ] **Store upload pipelines.** Play: fastlane `supply` or a GitHub action -> internal track. iOS: `xcrun altool`/`notarytool` or fastlane `pilot` -> TestFlight. macOS: **decide channel** - Mac App Store (simpler review, sandboxing) vs Developer-ID + notarized direct download (`codesign --deep --force --options runtime` -> `xcrun notarytool submit` -> `stapler staple`). Windows: `msix` package, signed; distribute via MS Store or own site. Linux: GitHub Releases (AppImage + deb, optionally flatpak/snap).
- [ ] **Key/secret management.** Keystore + cert `.p12` files in password manager AND one offline copy. Losing the Android keystore without Play App Signing is unrecoverable.
- [ ] **Release gate pipeline order:** analyze -> tests -> sweep -> integration tests -> unsigned builds -> signed builds -> store upload -> tag GitHub release. Every step skippable only manually.

### Nice-to-Have

- [ ] Fastlane `match` for iOS cert/profile sync across machines.
- [ ] Keep using the existing `act` local-runner script for iterating on the workflow without burning CI minutes.
- [ ] Changelog generation from the existing conventional-commit history.

---

## Phase 6 - Go-Live Pre-Flight Checklist

### Critical / Blocker

- [ ] **Feature completeness gate.** Batch 3 UI fixes done; no placeholder screens reachable in prod; every visible control does something; the "features completely absent" list is either built or gated out (Phase 1).
- [ ] **Store listings.** App Store Connect record + Play Console app created. Per store: final name, subtitle/short description, keyword field (iOS), category (Health & Fitness), content-rating questionnaires, health/fitness data declaration (**"data stored only on device"**), support URL, privacy policy URL, support email.
- [ ] **Screenshots.** Required sizes: iOS 6.9" phone + 13" iPad; Play: phone 7"/tablet 10". The visual sweep's renders are a starting base, but re-capture on real devices/simulators - stores accept synthetic frames only if they look real. 3-5 shots each telling the story: plan split -> log workout -> progression graphs.
- [ ] **App identity.** Final display name everywhere; bundle IDs (`com.<you>.tracker`) reserved on both stores; app icons for all five platforms (`flutter_launcher_icons`, Android adaptive icons, macOS `.icns`); native splash screens; sensible desktop min-window sizes (already via `window_size`).
- [ ] **Export compliance (iOS).** No custom cryptography -> `ITSAppUsesNonExemptEncryption = false` in Info.plist to skip the per-build export question.
- [ ] **OSS license page.** Add `LicensePage` (or `showLicensePage`) reachable from Settings - Flutter auto-collects pub dependency licenses; required by most licenses and trivially cheap.

### High Priority

- [ ] **Localization.** `flutter_localizations` is already a dependency. Wire `intl`/`gen_l10n` with English-only `.arb` files for v1 so strings are extracted once and future translations are data, not refactor. Localize store metadata only for languages actually supported.
- [ ] **Staged rollout.** Play: internal -> closed -> production at 10% -> 50% -> 100% with halt criteria (rating drop, review complaints, GitHub issue spike). App Store: 7-day phased release (can pause). Desktop: manual control by channel.
- [ ] **Reviewer notes.** Both stores: state plainly "offline app, no account required, all data stored on device" - this preempts the top review questions for fitness apps. Avoid medical claims ("builds muscle") - health claims trigger stricter review.
- [ ] **Support & feedback loop.** Support email monitored; in-app "export data + logs" flow doubles
  as the bug-report mechanism (offline answer to crash reporting, see Phase 3).

### Nice-to-Have

- [ ] Launch marketing: Play feature graphic, promotional video, landing page or polished GitHub README.
- [ ] In-app changelog card ("what's new in 1.0").
- [ ] Feature-flag system for post-1.0 experimentation (trivial offline variant: settings-backed flags).

---

## Appendix - Release build command reference

```bash
# Android
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/android
# iOS
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios
# macOS (direct distribution)
flutter build macos --release --obfuscate --split-debug-info=build/symbols/macos
codesign --deep --force --options runtime --sign "Developer ID Application: ..." Build/Products/Release/tracker.app
xcrun notarytool submit Tracker.zip --keychain-profile ac --wait && xcrun stapler staple Tracker.app
# Windows (deferred v1.1+)
flutter build windows --release --obfuscate --split-debug-info=build/symbols/windows
# then package msix (msix pub package) and sign with signtool
# Linux (deferred v1.1+)
flutter build linux --release --obfuscate --split-debug-info=build/symbols/linux
# then AppImage/deb packaging
```

**Execution order:** document order (Phase 1 -> 6, top to bottom). No reordering needed - the
2026-09-02 reorder already put durability + 16 KB verification early (Phase 2, they can force
architecture decisions) and performance tuning after tests exist (Phase 4).
