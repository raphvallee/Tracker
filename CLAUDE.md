# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A cross-platform (iOS/Android/macOS/Windows/Linux) Flutter workout-tracking app. The Flutter app lives in `tracker/`; the repository root also contains a PowerShell script for running GitHub Actions locally. This is an early-stage work in progress - much of the UI is placeholder scaffolding.

## Architecture layout (Flutter app-architecture case study)

`tracker/lib/` follows the official Flutter [app architecture case study](https://docs.flutter.dev/app-architecture/case-study#package-structure) (MVVM + Repository, hybrid organization: data/domain by type, UI by feature):

- `lib/domain/models/` - Isar-annotated models (`Exercise`, `Gym`, `WorkoutSession` + embedded `WorkoutSet`, `WorkoutSplit` + embedded days/items, `Muscle`/`MuscleGroup`, split templates) plus pure value types (`graph_config.dart`, `weight_unit.dart`, `number_entry.dart`, `effort_scale.dart` - RPE / RIR, sets store RPE and RIR reads as 10 minus it, `split_draft.dart` - the editable `SplitDraft`/`DayDraft`/`ExerciseDraft`/`SetTarget` copy of a split whose days and exercises remember their saved position, and whether they were dragged; a `SetTarget` is a working set or a warm-up). Generated `*.g.dart` parts live next to their parents.
- `lib/domain/services/analytics.dart` - pure, DB-free analytics engine (`normalizedWeight`, `epley1rm`, `exerciseBest1rm`, `volumeTrend`, `estimateGymMultiplier`, ...). Imports only domain models.
- `lib/domain/services/` also holds the pure workout planning helpers: `split_rotation.dart` (`upNext`, `currentSplitOf`: the day due next from `SplitDayVisit`s; `splitsByLastUsed`: the Splits tab order), `set_prefill.dart` (`PreviousPerformance`, `ghostForRow`: placeholder values for pending set rows) and `split_diff.dart` (`diffSplit`: every saved-vs-draft change, worded for the review sheet; a move names the item that was dragged, never the neighbour it passed).
- `lib/data/repositories/` - one file per repository (`ExerciseRepository`, `GymRepository`, `WorkoutSplitRepository`, `WorkoutSessionRepository`) plus the `TrackerRepository` facade. Pages/cubits never touch Isar directly.
- `lib/data/services/` - `db.dart` (single Isar instance, opened only by `main.dart`) and `seed.dart` (first-run exercise seeding).
- `lib/ui/core/ui/` - shared widgets/helpers used across features: `CustomAppBar`, `pushTo` (`custom_route.dart`), `MaxWidth`, `LineChart`, `weight_format.dart` (kg/lb UI conversion), `repository_scope.dart` (`RepositoryScope` InheritedWidget exposing `TrackerRepository` down the tree), `AccentButton`, `SheetSurface`, `EditSheet` (`edit_sheet.dart`, opened with `showEditSheet`: every value is edited in a bottom sheet with one Save-style button, swiping it away cancels; dialogs (`AppDialog`, `showConfirmDialog`) only ask to confirm), `SwipeToDelete` (raw-pointer, 2-step swipe for rows full of text fields: the first swipe opens the row on Delete, a second swipe or a tap on Delete removes it; `SwipeToDeleteChip` is the same for grid tiles: the first swipe arms a red trash tile, the second deletes; a chip inside a swipe row keeps the swipes that start on it), `Peek` (`peek.dart`: a card shown beside a row in its tab's overlay, below or above it, modal with the page dimmed around the row or pointer-transparent for hover), `SlidingColumn` (keyed children slide to their new places when the order changes), `AnimatedReveal` (a child that comes and goes with a state grows in and shrinks away, keeping its last content while it leaves), `keyboard_inset.dart` (`keyboardClearanceOf`: the bottom room a page's scrollable leaves for the keyboard; `KeyboardReveal`, wrapped around the app in `MyApp`, scrolls the focused field above the keyboard without rebuilding anything, so nothing may rebuild the app per keyboard frame, e.g. a theme derived from the inset; hidden tabs see the keyboard as down), `relative_dates.dart`, `effort_format.dart` (`effortScaleOf`, `effortLabel`: a stored RPE on the chosen scale). `lib/ui/core/themes/accents.dart` (`TrackerAccents`) adds the only two accents on top of the neutral Forui theme: blue = a live workout and the selected bottom-nav tab, amber = unsaved split edits.
- `lib/ui/core/themes/material_theme_bridge.dart` - Forui `FThemeData` -> SDK `ThemeData` bridge + nav-label strengthening (`strengthenNavLabels`: readable labels at rest, the selected tab in the blue accent).
- `lib/ui/<feature>/widgets/` + `lib/ui/<feature>/view_models/` - features: `feed`, `history`, `workout` (incl. `view_models/workout_cubit.dart`), `splits` (incl. `view_models/split_drafts_cubit.dart`), `exercises`, `settings` (incl. `view_models/settings_cubit.dart`), `analytics`.
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
- `WorkoutCubit` (`lib/ui/workout/view_models/workout_cubit.dart`) is the sole workout cubit, a `HydratedCubit<WorkoutState>` - state is JSON-serialized via `HydratedStorage`, so the in-progress workout survives app restarts. `WorkoutState` is a hand-written plain class with manual `toJson`/`fromJson` holding `isInProgress`, `startTime`, gym id/name, optional plan (`planTitle` = the day + `List<PlanExercise>`), the split link (`splitTitle`, `splitId`, `splitDayIndex`, written to the saved session for the Up next rotation), `lastGymId` (the gym the next workout starts at), and `List<ActiveSet> sets`; `ActiveSet.isWarmup` flags `SetType.warmup` and `ActiveSet.rpe` holds the set's rating. `startWorkout`/`startPlanWorkout` begin a session; a free workout (`planTitle == null`) builds its `plan` one card at a time via `addExercise`/`removeExercise`; `logSet`/`updateSet`/`removeSet`/`setRpe` mutate the set list; `reorderExercise` reorders the cards; `setGym`/`rememberGym` move the session or the next start; `endWorkout` (async) writes a real `WorkoutSession` to Isar via its optional `TrackerRepository` reference, then resets to idle. It also estimates gym multipliers (`estimateGymMultiplier`) at end-of-workout.
- `SettingsCubit` (`lib/ui/settings/view_models/settings_cubit.dart`) is a `HydratedCubit<SettingsState>` for the weight unit, the logging prefs (`prefillSets`, `numberEntry`: keypad / phone keyboard / steppers, `effortScale`: RPE / RIR, `showHeavyWeightWarning`), the rep target new planned sets start at (`defaultRepMode` + `defaultReps` / `defaultRepRange*`, set at once by `setDefaultSetTarget`), `currentSplitId` (the split Up next trains from; null follows the last trained), `splitsUsedAt` (when splits stopped being current; with training times it orders the Splits tab) + user graphs. Its pure value types (`GraphMetric`, `GraphTimeframe`, `GraphConfig`, `WeightUnit`, `NumberEntry`, `EffortScale`) live in `lib/domain/models/{graph_config,weight_unit,number_entry,effort_scale}.dart`.
- `SplitDraftsCubit` (`lib/ui/splits/view_models/split_drafts_cubit.dart`) is a `HydratedCubit<SplitDraftsState>`: every Splits tab edit lands at once in a per-split draft (`SplitDraftEntry`: the saved `base` editing started from + the edited `draft`) that survives app restarts; `save` writes it to Isar, `discard` drops it, and an edit that brings the draft back to its base drops the entry.
- `WorkoutCubit` is provided app-wide in `main.dart` via `MultiBlocProvider` with `lazy: false`.
- The **`.g.dart` files are generated** - do not edit them by hand. After changing a `@collection`/`@embedded`/`@enumerated` annotation, run `dart run build_runner build` in `tracker/`. The analyzer excludes `*.g.dart`. (Isar 3.1 requires `@enumerated` enum fields to be non-nullable and models must not carry computed getters - the generator rejects both.)
- Host-side `flutter test` needs the Isar native lib: `libisar.dylib` is copied into `tracker/` (gitignored) so tests load it.
- **Isar schema is frozen pre-1.0**: additive changes only (no renames/deletes); the current schema and freeze rules live in `docs/ISAR_SCHEMA.md`, the isar_community stay/escape-hatch decision in `docs/adr/0001-isar-community.md`.
- **Hydrated payloads are versioned**: `WorkoutState` (v3)/`SettingsState` (v2)/`SplitDraftsState` (v1) JSON carries a `'v'` field; `fromJson` dispatches to `_fromV1`-style parsers and unknown versions fall back to safe defaults. Extend per-version parsers on shape changes, never loosen casts.
- **AppLog** (`lib/data/services/app_log.dart`) is the local ring-buffer logger (mirrors to `tracker.log` in the documents dir); all app-level error channels in `main.dart` (run-zone, Flutter, platform dispatcher, build-error widget) route through it. `APP_ENV=prod` (dart-define, `lib/data/services/app_env.dart`) gates dev affordances and verbose logging.

## UI features (lib/ui/<feature>/)

- **feed** - `FeedPage` streams recent completed sessions (loading/empty/error states), hosts user-defined graph cards (`feed_page_graph_card.dart`) and links to `SessionDetailPage`; Settings is reached from the Feed app-bar action.
- **history** - `HistoryPage` reads sessions synchronously (start-time property query into a lazy, per-month `WorkoutDateIndex`; full sessions only for the List tab, a lazy `SliverList`) and reloads on `repo.sessions.watchChanges()` (deferred while its tab is hidden), toggling Calendar (first) <-> List (`history_calendar.dart`; layout/streak math in `calendar_grid.dart`). The tab shell prebuilds History offstage ~1 s after launch so its first open is instant. List tiles and calendar day lists open `SessionDetailPage` (header stats, working volume excluding warm-ups, per-set W/S markers). Shell-level perf harness: `tracker/benchmark/history_first_open_device_test.dart` (profile, `flutter drive`). The keyboard in a sheet has its own: `tracker/benchmark/keyboard_sheet_device_test.dart` (profile, on an Android device or emulator, the real keyboard; `BENCH_APP=perframe` replays the old per-frame theme rebuild).
- **workout** - the Workout tab starts and runs workouts, nothing else. `WorkoutPage` shows `StartView` when idle (the Up next day of the current split with one big Start at the remembered gym, the split's other days: tap starts at once, hold opens `showDayPreview`; an empty workout; restore last workout) and `WorkoutOverview` during a workout (live timer, Finish, menu with Change gym / Cancel workout, the exercises in order: done ones shrink to their best set, the current one has Continue, hold reorders, swipe removes). Each exercise opens `ExercisePage`: weight x reps rows prefilled in grey (`ghostForRow`; planned warm-ups open as warm-up rows), an RPE / RIR column rated 0-10 in `showEffortSheet`, logged rows tinted, the current row opened up with -/+ steppers, the Log button docked at the bottom, save on leaving a row, badge tap = warm-up, two swipes = delete. Number entry follows Settings: `NumberKeypad` overlay (default), the phone's decimal pad + `KeyboardToolbar`, or steppers (drag to scrub, hold to type). `start_workout.dart` holds the start helpers (`startSplitDay`, `startEmptyWorkout`, `planOf`).
- **exercises** - `ExercisesPage` master library (browse by muscle group or movement pattern), `NewExercisePage` for custom exercises, `ExerciseDetailPage` for profile + performance history (best normalized 1RM over time).
- **splits** - the Splits tab plans only (no start buttons). `SplitsPage` lists splits current first, then by last use (Make current slides the split to the top and the old current right below it, in a `SlidingColumn`; Current badge, menu: Rename (the name turns into a field in place, keyboard up, Done saves) / Make current / Duplicate / Delete; days reorder by grip, peek on hold or mouse hover, go in two swipes; unsaved-changes strip that opens and closes with the draft; New/Edited tags; removed days struck through with Restore); `showNewSplitSheet` creates a blank or template split straight away. `SplitDayEditorPage` edits a day (name, exercises reordered by grip and removed in two swipes, planned sets as equal chips in a grid edited in `showSetTargetSheet`: reps and warm-up or working, deleted in two swipes, removed exercises restorable) with a save bar that slides up while there are unsaved changes; `showReviewChangesSheet` lists every change (old struck through, new bold) before Save / Discard.
- **settings** - `SettingsPage` is a hub: one row per part of the app with settings, named and iconed like its tab and summing up what is set inside (`WorkoutSettingsPage`: number entry, prefill, effort rating, heavy weight check; `SplitsSettingsPage`: the rep target new exercises start at, edited in `showSetTargetSheet` without the warm-up switch, kept on close (`saveOnClose`) as well as on Done; `GymsPage`), then General (weight unit). Every page is built from `settings_list.dart`: `SettingsScaffold` > `SettingsSection` (heading, outlined card, note) > `SettingsLinkItem` / `SettingsSwitchItem` / `SettingsChoiceItem` (opens `showChoiceSheet`: each option with what it does, one tap picks and closes) / `SettingsValueItem`. Card rows are inset 4 px on every side, so a pressed or selected highlight never touches a divider. A new setting is one row; a section that outgrows its page moves behind a link row. Only settings that change something are shown (`notificationsEnabled` / `analyticsEnabled` stay in the payload with no UI). `GymsPage`: create/edit gyms in `editGymSheet`, primary baseline multiplier locked to 1.0, auto-estimate via `estimateGymMultiplier`.
- **analytics** - `ProgressionPage` plots overall strength + volume trends (`LineChart` in `ui/core/ui` is a dependency-free `CustomPainter`).
- Weights remain canonical kilograms in persisted data; `ui/core/ui/weight_format.dart` converts/formats at UI boundaries.

**Placeholder/known-incomplete code** (present in the scaffold, not implemented):

- `ExerciseDetailPage` shows best-1RM chart and summary stats; deeper performance-log detail is optional polish.
- Malformed hydration defaults, idle cubit behavior, Isar watcher updates, and settings persistence are covered across `test/`.
- Platform release builds require local signing/toolchains; CI does not claim store-ready artifacts.
- Hardware directories (`ios/`, `android/`, `macos/`, `windows/`, `linux/`) are stock Flutter platform runners; `tracker/ios/Podfile.lock` and `build/` are committed and may be stale.

## README (planning notes)

The README records intended refactors/features, not current behavior; several are now done: **Settings is a child page of Feed** (via the Feed app-bar action -> `pushTo(SettingsPage)`) and the **Current Workout** destination exists as tab 2. The intended bottom-bar layout is implemented as Feed, History, Workout, Splits, Exercises (the Workout tab label shows the live time while a workout runs; only the selected tab is colored).

## Writing tests (read first)

**Before writing any test that opens a real Isar database, read `docs/TESTING_ISAR_CI.md`.** Isar-backed cases must each get their own `*_test.dart` file, or they hang on the 4-vCPU CI runner while passing locally. Every Isar-backed file in `test/` follows this today (e.g. `test/data/*_test.dart`, `test/ui/workout/workout_*_test.dart`); keep it that way.

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
- Under the hood: `test/ui/visual_screenshots/visual_screenshot_sweep.dart` (the sweep body) + one `visual_screenshots_<size>_test.dart` per size, `test/ui/overflow/layout_overflow_sweep.dart` + one `layout_overflow_<size>_test.dart` per extra window size (480x800, 640x720, 1920x1080 - the sweep's own 320x568/800x600/1280x720 already fail on render exceptions, so they have no overflow file; overflow assertions over the same pages; one file per size so each runs in its own process — libisar's native worker pool wedges multi-case sweeps on 4-CPU CI runners), and the shared infra in `testing/` (`screenshot_helpers.dart`, `test_fixtures.dart`, `test_fonts.dart`, `test_helpers.dart`). The output directory is disposable; `-NoClean` keeps previous captures.
