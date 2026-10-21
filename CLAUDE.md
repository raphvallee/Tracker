# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A cross-platform (iOS/Android/macOS/Windows/Linux) Flutter workout-tracking app. The Flutter app lives in `tracker/`; the repository root also contains a PowerShell script for running GitHub Actions locally. This is an early-stage work in progress - much of the UI is placeholder scaffolding.

## Architecture layout (Flutter app-architecture case study)

`tracker/lib/` follows the official Flutter [app architecture case study](https://docs.flutter.dev/app-architecture/case-study#package-structure) (MVVM + Repository, hybrid organization: data/domain by type, UI by feature):

- `lib/domain/models/` - Isar-annotated models (`Exercise`, `Gym`, `WorkoutSession` + embedded `WorkoutSet`, `WorkoutSplit` + embedded days/items, `Muscle`/`MuscleGroup`, split templates) plus pure value types (`graph_config.dart`, `weight_unit.dart`). Generated `*.g.dart` parts live next to their parents.
- `lib/domain/services/analytics.dart` - pure, DB-free analytics engine (`normalizedWeight`, `epley1rm`, `exerciseBest1rm`, `volumeTrend`, `estimateGymMultiplier`, ...). Imports only domain models.
- `lib/data/repositories/` - one file per repository (`ExerciseRepository`, `GymRepository`, `WorkoutSplitRepository`, `WorkoutSessionRepository`) plus the `TrackerRepository` facade. Pages/cubits never touch Isar directly.
- `lib/data/services/` - `db.dart` (single Isar instance, opened only by `main.dart`) and `seed.dart` (first-run exercise seeding).
- `lib/ui/core/ui/` - shared widgets/helpers used across features: `CustomAppBar`, `pushTo` (`custom_route.dart`), `MaxWidth`, `LineChart`, `weight_format.dart` (kg/lb UI conversion), `repository_scope.dart` (`RepositoryScope` InheritedWidget exposing `TrackerRepository` down the tree).
- `lib/ui/core/themes/material_theme_bridge.dart` - Forui `FThemeData` -> SDK `ThemeData` bridge + nav-label strengthening.
- `lib/ui/<feature>/widgets/` + `lib/ui/<feature>/view_models/` - features: `feed`, `history`, `workout` (incl. `view_models/workout_cubit.dart`), `exercises`, `settings` (incl. `view_models/settings_cubit.dart`), `analytics`.
- `lib/routing/` - `home_page.dart` (5-tab shell with nested `Navigator`s) and `tab_navigation.dart` (`TabName`, `HomePageSingleton`, `TabVisibilityScope`); features depend on `tab_navigation.dart`, never on the shell.
- `lib/utils/` - pure Dart helpers (`form_validators.dart`).
- `lib/main.dart` - composition root: HydratedBloc storage, Isar open + seed, `RepositoryProvider`/`RepositoryScope`/`MultiBlocProvider` wiring.

Layer direction: `ui` -> `data` + `domain`; `data` -> `domain` (+ Isar); `domain` depends on nothing UI/data. Intra-`lib` relative imports are lint-legal but package: imports are preferred for cross-folder references.

## Commands

The Dart/Flutter app is rooted in `tracker/`; run Flutter/Dart commands from that directory.

```bash
# Install dependencies
cd tracker && flutter pub get

# Static analysis (this is what CI runs)
cd tracker && flutter analyze

# Run tests (single: `flutter test test/app_test.dart`)
# Domain/unit tier (pure Dart, no Isar/DB): `flutter test test/domain`
cd tracker && flutter test

# Regenerate code from Isar/JsonSerializable annotations
cd tracker && dart run build_runner build
```

**Commit messages.** All commits (from agents and human contributors
alike) MUST follow [Conventional Commits](https://www.conventionalcommits.org/):
`type(scope): description`. Allowed types: `feat`, `fix`, `docs`, `style`,
`refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`; `scope` is
optional (e.g. `feat(workout): add warmup set toggle`, `fix: clamp chart
height`). Subject is lowercase, imperative, no trailing period.

**Git hooks.** Husky (Dart package on pub.dev, not npm) runs a `pre-commit`
hook that formats code with `dart fix --apply` then `dart format .`. The
hook lives at repo-root `.husky/pre-commit` (committed, so it's
project-specific); git runs it because `core.hooksPath` points at `.husky`
(already set here; a fresh clone needs the one-time
`git config core.hooksPath .husky`). Cross-platform: `husky` is pure Dart
and the plain-`sh` hook is LF-pinned via `.gitattributes`
(`.husky/** text eol=lf`) so Windows CRLF autoconversion can't break it on
any of Windows / macOS / Linux.

Tests live under `tracker/test/`, mirroring `lib/`: `test/domain/` (analytics, split templates), `test/utils/` (form validators), `test/data/` (Isar repositories/CRUD), `test/ui/<feature>/` (cubit state/flows, page widgets), plus `test/app_test.dart` (app shell). Shared test infrastructure lives in the top-level `tracker/testing/` directory (sibling of `test/`, imported via relative paths): `test_helpers.dart` (Isar core init, temp Isar open, `pumpApp`, watcher polling), `test_fixtures.dart` (seed data shared with the sweep tests), `test_fonts.dart` (loads Inter/Lucide/MaterialIcons/Roboto from the pub cache and Flutter SDK - the test env ships no real fonts), `screenshot_helpers.dart` (PNG capture + manifest), and `fakes/in_memory_storage.dart` (in-memory `HydratedBloc` `Storage` fake). CI (`dart.yml`) runs dependency installation, `flutter analyze`, generated-code verification, generated-file drift detection, and `flutter test` on `ubuntu-latest`.

## State management & persistence

- **Isar** for local persistence; **Bloc (flutter_bloc + HydratedBloc)** for state management. The case-study MVVM layout treats each `HydratedCubit` as its feature's view model (`ui/<feature>/view_models/`).
- `WorkoutCubit` (`lib/ui/workout/view_models/workout_cubit.dart`) is the sole workout cubit, a `HydratedCubit<WorkoutState>` - state is JSON-serialized via `HydratedStorage`, so the in-progress workout survives app restarts. `WorkoutState` is a hand-written plain class with manual `toJson`/`fromJson` holding `isInProgress`, `startTime`, gym id/name, optional plan (`planTitle` + `List<PlanExercise>`), and `List<ActiveSet> sets`; `ActiveSet.isWarmup` flags `SetType.warmup`. `startWorkout`/`startPlanWorkout` begin a session; `logSet`/`removeSet` mutate the set list; `endWorkout` (async) writes a real `WorkoutSession` to Isar via its optional `TrackerRepository` reference, then resets to idle. It also estimates gym multipliers (`estimateGymMultiplier`) at end-of-workout.
- `SettingsCubit` (`lib/ui/settings/view_models/settings_cubit.dart`) is a `HydratedCubit<SettingsState>` for unit/notification/privacy prefs + user graphs. Its pure value types (`GraphMetric`, `GraphTimeframe`, `GraphConfig`, `FreeStartPlacement`, `WeightUnit`) live in `lib/domain/models/{graph_config,weight_unit}.dart`.
- `WorkoutCubit` is provided app-wide in `main.dart` via `MultiBlocProvider` with `lazy: false`.
- The **`.g.dart` files are generated** - do not edit them by hand. After changing a `@collection`/`@embedded`/`@enumerated` annotation, run `dart run build_runner build` in `tracker/`. The analyzer excludes `*.g.dart`. (Isar 3.1 requires `@enumerated` enum fields to be non-nullable and models must not carry computed getters - the generator rejects both.)
- Host-side `flutter test` needs the Isar native lib: `libisar.dylib` is copied into `tracker/` (gitignored) so tests load it.
- **Isar schema is frozen pre-1.0**: additive changes only (no renames/deletes); the current schema and freeze rules live in `docs/ISAR_SCHEMA.md`, the isar_community stay/escape-hatch decision in `docs/adr/0001-isar-community.md`.
- **Hydrated payloads are versioned**: `WorkoutState`/`SettingsState` JSON carries a `'v'` field; `fromJson` dispatches to `_fromV1`-style parsers and unknown versions fall back to safe defaults. Extend per-version parsers on shape changes, never loosen casts.
- **AppLog** (`lib/data/services/app_log.dart`) is the local ring-buffer logger (mirrors to `tracker.log` in the documents dir); all app-level error channels in `main.dart` (run-zone, Flutter, platform dispatcher, build-error widget) route through it. `APP_ENV=prod` (dart-define, `lib/data/services/app_env.dart`) gates dev affordances and verbose logging.

## UI features (lib/ui/<feature>/)

- **feed** - `FeedPage` streams recent completed sessions (loading/empty/error states), hosts user-defined graph cards (`feed_page_graph_card.dart`) and links to `SessionDetailPage`; Settings is reached from the Feed app-bar action.
- **history** - `HistoryPage` lists persisted sessions via `repo.sessions.watchAll()`, toggling list <-> interactive month calendar (`history_calendar.dart`; layout/streak math in `calendar_grid.dart`). List tiles and calendar day lists open `SessionDetailPage` (header stats, working volume excluding warm-ups, per-set W/S markers).
- **workout** - `WorkoutPage` drives the active session from `WorkoutCubit` (idle -> Start with `promptGym` gym selection; in progress -> per-exercise cards with inline add-set form, W/S chips, confirm dialog calling `cubit.endWorkout`). `EditorPage` is the split-selection tab; `SplitDayPage` starts a plan workout; `SplitEditorPage` (`new_split_page.dart`) is the split CRUD editor with template picker; `SplitDayEditorPage` reorders exercises via `ReorderableListView` fed by `ExercisePickerPage`.
- **exercises** - `ExercisesPage` master library (browse by muscle group or movement pattern), `NewExercisePage` for custom exercises, `ExerciseDetailPage` for profile + performance history (best normalized 1RM over time).
- **settings** - `SettingsPage` (units, gyms, graphs) and `GymsPage` (create/edit gyms, primary baseline multiplier locked to 1.0, auto-estimate via `estimateGymMultiplier`).
- **analytics** - `ProgressionPage` plots overall strength + volume trends (`LineChart` in `ui/core/ui` is a dependency-free `CustomPainter`).
- Weights remain canonical kilograms in persisted data; `ui/core/ui/weight_format.dart` converts/formats at UI boundaries.

**Placeholder/known-incomplete code** (present in the scaffold, not implemented):

- `ExerciseDetailPage` shows best-1RM chart and summary stats; deeper performance-log detail is optional polish.
- Malformed hydration defaults, idle cubit behavior, Isar watcher updates, and settings persistence are covered across `test/`.
- Platform release builds require local signing/toolchains; CI does not claim store-ready artifacts.
- Hardware directories (`ios/`, `android/`, `macos/`, `windows/`, `linux/`) are stock Flutter platform runners; `tracker/ios/Podfile.lock` and `build/` are committed and may be stale.

## README (planning notes)

The README records intended refactors/features, not current behavior; several are now done: **Settings is a child page of Feed** (via the Feed app-bar action -> `pushTo(SettingsPage)`) and the **Current Workout** destination exists as tab 2. The intended bottom-bar layout (Home, History, CurrentWorkout, WorkoutsEditor, Exercices) is implemented.

## Writing tests (read first)

**Before writing any test that opens a real Isar database, read `docs/TESTING_ISAR_CI.md`.** Isar-backed cases must each get their own `*_test.dart` file, or they hang on the 4-vCPU CI runner while passing locally.

## Running GitHub Actions locally (repo root)

`run-github-actions-locally.ps1` is a cross-platform (Windows/macOS/Linux) PowerShell script that ensures an Internet connection, then installs (if needed) the `act` CLI (nektos/act) and Docker, starts Docker Desktop/systemctl, then runs the GitHub Actions workflow locally. It self-elevates via `sudo`/RunAs. macOS support is partial and untested. Run as: `pwsh run-github-actions-locally.ps1`.

## Capturing screenshots/videos of the app (fixed procedure)

**Never research capture methods** - follow `docs/CAPTURING_MEDIA.md`. Static
page screenshots: `pwsh run-visual-tests.ps1` (Tier 1). Screenshots of
interactive states and all videos: write an integration test that drives the
app and run `pwsh ./capture-app-media.ps1 -Mode video -Test ...` (Tier 2).
A working Tier 2 template lives at `tracker/integration_test/capture_smoke_test.dart`.

## Visual debugging screenshots (widget-test sweep)

`pwsh run-visual-tests.ps1` (repo root) renders every app page, dialog and sheet at 320x568, 800x600 and 1280x720 with real Inter text and Lucide/Material icon fonts, writing ~66 PNGs plus `manifest.json` to `tracker/build/test_screenshots/` (gitignored). Exit code = flutter test exit code. The sweep also runs on Linux CI via bare `flutter test`.

- **Vision-analysis loop** (for Claude Code, after UI changes): run the script -> read `manifest.json` (or glob `tracker/build/test_screenshots/*.png`) -> inspect the images with the Read tool for overflow, clipped text, misalignment or tofu glyphs -> fix -> re-run. Files suffixed `_FAIL` are auto-captures of the screen that threw a render exception; the test output's `SCREENSHOT-SWEEP:` / `SCREENSHOT:` lines map captures to pages.
- Under the hood: `test/ui/visual_screenshots_test.dart` (the sweep), `test/ui/overflow/layout_overflow_sweep.dart` + one `layout_overflow_<size>_test.dart` per window size (overflow assertions over the same pages; one file per size so each runs in its own process — libisar's native worker pool wedges multi-case sweeps on 4-CPU CI runners), and the shared infra in `testing/` (`screenshot_helpers.dart`, `test_fixtures.dart`, `test_fonts.dart`, `test_helpers.dart`). The output directory is disposable; `-NoClean` keeps previous captures.
