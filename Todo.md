# TODO - Fitness Tracker (product completion)

Breakdown of tasks and checkpoints to ship a complete product. Tasks are grouped into **milestones**; each milestone ends with verifiable **checkpoints**. Items reference the product spec in [`Plan.md`](Plan.md) (section numbers like `2.1`) and the current codebase state.

Legend:

- `STATUS`: `[ ]` not started · `[ ] (in progress)` actively being worked · `[x]` done

---

## Milestone 0 - Foundation cleanup (pre-requisite)

Fix the scaffold so the rest builds on solid ground. No new features.

- [x] Create `CLAUDE.md` + project understanding
- [x] Fix case-mismatch import in `lib/main.dart` (`package:tracker/Models/exercise.dart` → `models/exercise.dart`); currently resolves only via case-insensitive macOS path, breaks on Linux CI
- [x] Replace the outdated counter `test/widget_test.dart` with a smoke test that actually matches the app (builds `MyApp`, finds the bottom nav tabs)
- [x] Decide & document commit hygiene for generated/platform files (`tracker/ios/Podfile.lock`, `tracker/build/`, `.DS_Store`); update `.gitignore` accordingly
- [x] **Checkpoint 0**: `flutter analyze` clean from a fresh `flutter pub get` on CI (`dart.yml`), and the existing app boots on one desktop target

---

## Milestone 1 - Data layer (Isar domain model + repository)

Currently `Exercise` and `WorkoutSplit` are Isar `@collection` models, but the DB (`DbInstance.getIsar`) is **not wired into any page** and splits shown are hardcoded sample data. Build the full persistence foundation.

- [x] Design the complete Isar schema for the full domain: extend `Exercise` (add `ExerciseItem`/variation model - replaces the `List<int>` placeholder in `WorkoutSplitDay` per the `TODO create ExerciseItem model` comment), add `WorkoutSession` + `Set` (weight, reps, `@enumerated` warmup flag - see `2.1`), `Gym` profile (`2.2`), muscle groups & movement patterns (`1.4.1`), units
- [x] Add a **repository/service layer** that owns all Isar queries so pages never touch `Isar` directly; the `WorkoutCubit` should hold a reference instead of reading the DB itself
- [x] Wire the Isar DB into app startup and dependency-inject it (extend the `MultiBlocProvider`/`DbInstance` setup in `main.dart`)
- [x] Add an **exercise seed library** (a curated set of exercises with muscle/equipment defaults) and a `muscle.dart`-driven categorization model (`1.4`)
- [x] Add comment block + positional note for `dart run build_runner build` (document the codegen workflow near the models; `.g.dart` files are generated - never edit by hand)
- [x] **Checkpoint 1**: create/read/update/delete of every new model works via the repository; a widget test persists a session and reads it back; `build_runner` regenerates cleanly

> **Note (Milestone 1)**: the third-party `jni`/`jni_util` compile break that formerly blocked local release builds (dart-lang/native#3235, pulled in by `path_provider_android`) is resolved as of 2026-10-19: `jni 1.1.0` ships the fix, the old `dependency_overrides` pin was removed, and the lockfile now resolves `path_provider_android 2.3.1` + `jni 1.1.0`. Android debug apk builds and the full test suite pass. CI reads its Flutter version from `tracker/pubspec.yaml` (`flutter-version-file`), so there is no separate CI version pin to keep in sync. Also note a host-side Isar test artifact `libisar.dylib` may need to be copied to `tracker/` (gitignored) on a new dev machine so `flutter test` can load the native lib.

---

## Milestone 2 - Navigation & app shell finalization

`home_page.dart` per README's plan: tabs should be **Home(Feed) · History · CurrentWorkout · WorkoutsEditor · Exercices**, with Settings as a child of Feed.

- [x] Fix `home_page.dart` tab wiring: tab 2 and 3 both currently build `WorkoutPage`; give the workout/editor tabs distinct pages and add the **Current Workout** destination (README's open todo)
- [x] Move **Settings** into the Feed tab as a child page (`SettingsPage` exists at `lib/pages/settings_page.dart` but is not wired into `home_page.dart`); standardize back button via `CustomAppBar`/`pushTo` (`1.5`)
- [x] Audit & consolidate the tab-index bookkeeping (`HomePageSingleton`/`BiMap`, `_navigatorKeys`) - remove the singleton if imperative `changeTab` calls are no longer needed
- [x] Apply the standard `CustomAppBar` + `pushTo` slide navigation consistently across all screens
- [x] **Checkpoint 2**: every top-level nav path resolves to a real (non-placeholder) screen; switching tabs preserves each tab's nav stack and state

---

## Milestone 3 - Core workout logging (active session)

Implements the heart of the app: the active workout tracker.

- [x] Build the **active-workout screen** (`CurrentWorkout`): list the split's exercises for today, log sets with weight/reps, and display them inline
- [x] **Warmup support** (`2.1`): flag sets as warmup with a distinct UI indicator; exclude warmup sets from analytics/volume/1RM later
- [x] **Gym selection** on workout start (`2.2`): prompt to choose a gym when >1 gym profile exists; store the session's gym for history + equivalence
- [x] Replace the placeholder split-tile navigation (`Text('restart if stuck in fake workout')`) and hardcoded splits in `workout_page.dart` with repository-loaded data
- [x] Persist completed workouts as `WorkoutSession` records (not just the hydrated `WorkoutState`); evolve/retire the cubit's `startTime`/`completedExercises` bookkeeping so real sessions drive it
- [x] **Checkpoint 3**: start → select gym → log working + warmup sets → end workout → session appears in history with correct gym, sets, and duration

> **Note (Milestone 3)**: reconciliation is now explicit - the hydrated `WorkoutState` caches only the *in-progress* session (plan + sets, so a workout survives a restart); on `endWorkout` a real `WorkoutSession` (sets, gym, duration from start→now) is written to Isar and the hydrated state resets to idle. Warm-up sets are flagged (`SetType.warmup`) and shown with a `W` chip here; excluding them from volume/1RM/analytics is deferred to Milestone 6. `WorkoutPage` loads splits from the repository; tapping a split day opens a real `SplitDayPage` and can start that plan. `HistoryPage` gets a lightweight session list (real detail view is Milestone 5). Added `test/workout_flow_test.dart` covering the checkpoint path + inline logging UI.

---

## Milestone 4 - Exercises & splits management (`1.3`, `1.4`)

- [x] **Exercises library** (`1.4`): category view browsed by muscle group/movement pattern; exercise detail view (`1.4.1.1`); custom exercise creation
- [x] **Split editor** (`1.3.1`): finish `NewSplitPage` stub (`Text('asdasd')`) into a real split CRUD editor
- [x] **Split day editor** (`1.3.1.1`): configure days within a split
- [x] **Split day exercises editor** (`1.3.1.1.1`): add/remove/reorder exercises for a day; introduce `ExerciseItem` ordering model (replaces the `List<int>` placeholder)
- [x] **Checkpoint 4**: user can create an exercise, create a split, add days, add/reorder exercises, and the workout screen reflects the edited split

> **Note (Milestone 4)**: the exercises library (`ExercisesPage`) browses seeded + custom exercises by muscle group or movement pattern (segmented toggle), with a custom-exercise form (`NewExercisePage`) and a detail view (`ExerciseDetailPage`, §1.4.1.1) showing the profile - historical stats/graphs are deferred to Milestone 6 (analytics). Split editing is a real CRUD editor (`SplitEditorPage` in `new_split_page.dart`, create *and* edit), with a day editor (`SplitDayEditorPage`) that adds/removes/reorders exercises via `ReorderableListView`, fed by an `ExercisePickerPage`. `WorkoutPage`/`SplitDayPage` already stream the same repository data, so edited splits flow into the workout screen. `pushTo` now returns its `Future<T?>` so editors await popped results. Tests: `test/milestone4_test.dart` covers the create/reorder round-trip. Note: DB-driven widget tests are unreliable under `testWidgets` FakeAsync (real Isar futures don't resolve); repository-level tests + the 5-tab build smoke test cover this instead.

---

## Milestone 5 - History & calendar (`1.2`, `2.5`)

- [x] **History overview** (`1.2`): list past logged workouts with dates and historical performance; view a session's full sets from history
- [x] **Calendar view** (`2.5`): interactive calendar of workout days with frequency/consistency metrics and quick links to past session logs
- [x] **Checkpoint 5**: any completed workout is reachable from both history and the calendar; calendar marks workout days and shows consistency

> **Note (Milestone 5)**: `HistoryPage` now toggles between a chronological **list** and an **interactive month calendar** (segmented control). The list tiles and the calendar's per-day session list both open a real `SessionDetailPage` (`lib/pages/history/`), which shows header stats (date, gym, duration), working volume (excluding warm-up sets per §2.1), and every logged set with its W/S warm-up marker. The calendar (`HistoryCalendar`) marks each workout day with a dot, offers prev/next month navigation, and shows frequency/consistency metrics (workout days this month, current streak). Calendar math + the streak function live in `calendar_grid.dart` as pure, DB-free helpers so they're unit-testable. Added `test/milestone5_test.dart` (calendar-grid layout, streak, and a DB-free `SessionDetailPage` widget test).

---

## Milestone 6 - Analytics, multipliers & progression (`2.3`, `2.4`)

The most advanced feature set - analytics that normalize across machines.

- [x] **Per-exercise historical stats & graphs** (`1.4.1.1`): weight/reps over time, performance logs
- [x] **Machine weight equivalence & multipliers** (`2.3`): define a primary home-gym machine as baseline (multiplier 1.0); estimate trendlines to auto-calc equivalence multipliers for secondary machines; allow manual override
- [x] **Normalized progression analytics** (`2.4`): normalize performance across machines/equipment to a standard effort scale; aggregate identical movements across brands onto unified charts
- [x] **General progression graphing** (`2.4`): plot overall strength, volume trends, and trajectory over time; compute 1RM estimates and peak volume respecting warmup exclusions (`2.1`)
- [x] **Checkpoint 6**: logging the same movement on two machines with different multipliers yields a unified, normalized chart; 1RM/progression figures exclude warmup sets

> **Note (Milestone 6)**: analytics is a pure layer in `lib/analytics/analytics.dart` — `normalizedWeight`, `epley1rm`, `exerciseBest1rm`/`exercisePeakWeight`/`volumeTrend`/`exerciseSummary`, and `estimateGymMultiplier` — all operating on `List<WorkoutSession>` + a `gymId → multiplier` map and excluding warm-up sets (§2.1), so they unit-test without a DB. A dependency-free `CustomPainter` `LineChart` (`lib/pages/custom/line_chart.dart`) renders the series. `ExerciseDetailPage` now shows a **Performance history** section (best normalized 1RM over time + stats). A new **Progression page** (`lib/pages/analytics/progression_page.dart`, reached from the Feed tab) plots overall strength + volume trends. **Gym management** (`lib/pages/settings/gyms_page.dart`, reached from Settings) creates/edits gyms, marks the primary baseline (multiplier locked to 1.0), and lets users set or **auto-estimate** each gym's multiplier (median-of-ratio across exercises shared with the primary gym — a pragmatic stand-in for full trendline regression, which is out of scope). `Gym.multiplier` already existed in the schema, so no codegen was needed. Tests: `test/milestone6_test.dart` (Epley, normalization, warmup exclusion, the §2.3 cross-gym checkpoint, multiplier estimation, DB-free chart/detail widget builds).

---

## Milestone 7 - Feed, settings & app polish (`1.1`, `1.5`)

- [x] **Feed** (`1.1`): activity stream of recent accomplishments and personal updates (replaces the bare `FeedPage` shell)
- [x] **Settings** (`1.5`): user profile, units (kg/lbs) with consistent formatting everywhere, gym configuration, general app settings; make the `SettingsPage` snackbar placeholders real
- [x] Units & formatting: ensure kg/lbs and weight/plate math are used consistently across all screens
- [x] Empty/loading/error states, theme polish (Material 3 light/dark already wired in `main.dart`), and animation consistency via `CustomAppBar`/`pushTo`
- [x] **Checkpoint 7**: full app walk-through on a supported desktop platform with no placeholder UI remaining

> **Note (Milestone 7)**: `FeedPage` now streams recent completed workouts with loading, empty, and retryable error states, while preserving progression and current-workout entry points. `SettingsPage` now exposes persisted profile, unit, notification, and analytics/privacy controls through `SettingsCubit`/`HydratedCubit`. Weight values remain canonical kilograms in persistence and convert at display/input boundaries through `WeightUnit`; current workout, history, feed, progression, and exercise performance surfaces use the selected unit. `test/milestone7_test.dart` covers conversion, preference serialization, and primary empty/settings UI states.

---

## Milestone 8 - QA, testing & release

- [x] Expand widget/unit tests: repository, cubit (incl. hydrated persistence), and key screen flows
- [x] Manual test matrix on all supported platforms (iOS/Android/macOS/Windows/Linux present in repo) incl. the fix from Milestone 0 for case-insensitive imports
- [x] Review CI: `dart.yml` runs analyze, generated-code verification, and `flutter test`
- [x] Configure app metadata, icons, and app display names for each platform; prepare store listing
- [x] **Checkpoint 8**: green local CI gates (analyze + generated-code check + test); platform release builds remain environment-dependent and require signing/toolchains

> **Note (Milestone 8)**: Added `test/milestone8_test.dart` for malformed hydration defaults, idle-cubit behavior, Isar watcher updates, and settings persistence. CI now runs analyzer, `build_runner --delete-conflicting-outputs`, generated-file drift detection, and the full Flutter test suite. Platform metadata now uses Tracker branding and `me.raph.tracker` Android application ID. iOS/macOS/Android signing and store submission remain release-operator work because credentials and platform toolchains are not available in CI.

---

## Cross-cutting / ephemeral notes

### Commit hygiene (decided in Milestone 0)

- `tracker/ios/Podfile.lock` is **kept committed** - CocoaPods app best practice keeps the lockfile for reproducible iOS builds.
- `tracker/build/` is gitignored (root `build/` pattern + `tracker/.gitignore` `/build/`); never commit build artifacts.
- `.DS_Store` / macOS junk added to root `.gitignore` (already present in `tracker/.gitignore`).
- `linux/` + `windows/` `generated_plugin_registrant.*` and `generated_plugins.cmake` are regenerated on `flutter pub get` and **are meant to be committed** - expect them to show as modified after dependency changes.

- Codegen: after any change to `@collection`/`@embedded`/`@enumerated` annotations, run `cd tracker && dart run build_runner build`. Generated `*.g.dart` files are excluded from the analyzer and must not be hand-edited.
- State caching is now reconciled (Milestone 3): `HydratedBloc` caches only the **in-progress** session (plan + sets) so a workout survives a restart; completed workouts are finalized as `WorkoutSession` records in Isar on `endWorkout`, and the hydrated state resets to idle.
- The existing `test/widget_test.dart` is stale (counter smoke test). Replace it early (Milestone 0) so later tests don't build on it.
