# TODO - Fitness Tracker (remaining work)

Verified against the codebase, `flutter analyze`, and `flutter test` on 2026-10-22. Milestones 0-6 are complete and have been removed; only unfinished items from Milestones 7 and 8 remain.

Legend:

- `STATUS`: `[ ]` not started · `[ ] (in progress)` actively being worked · `[x]` done

---

## Milestone 7 - Feed, settings & app polish (`1.1`, `1.5`)

- [ ] (in progress) Units & formatting: kg/lbs conversion is centralized in `ui/core/ui/weight_format.dart` and used consistently across workout, history, feed, progression, and exercise surfaces. No plate math (plate-loading/weight-distribution calculation) exists anywhere in the codebase, so that part is untouched. The user profile was intentionally removed (see `Refine.md`), so it is no longer tracked here despite Plan.md `1.5`.

> Completed under this milestone: Feed activity stream, real Settings controls, empty/loading/error states, theme/animation consistency, and the desktop walkthrough (covered by the automated screenshot/overflow sweep).

---

## Milestone 8 - QA, testing & release

- [ ] Manual test matrix on all supported platforms (iOS/Android/macOS/Windows/Linux present in repo) incl. the fix from Milestone 0 for case-insensitive imports. **Progress: not started** - no per-platform manual checklist or results are recorded; only automated CI build jobs (Android/iOS/Windows) and the widget/overflow sweeps exist. macOS and Linux have no CI build job.
- [ ] (in progress) Configure app metadata, icons, and app display names for each platform; prepare store listing. **Progress: metadata, display names, and icons are configured** (`Tracker`; Android application ID `me.raph.tracker`; icons present for Android, iOS, macOS, and Windows; window titles set for Linux). **Store listing is not started** - no fastlane/store metadata, descriptions, keywords, screenshots, or store URLs exist in the repo.

> Completed under this milestone: expanded unit/widget coverage, CI review (`dart.yml` runs analyze, generated-code regeneration/drift check, tests, dependency validation), and Checkpoint 8 (local analyze + generated-code + test gates green; both verified again on 2026-10-22).

---

## Reference notes (not tasks)

### Commit hygiene (decided in Milestone 0)

- `tracker/ios/Podfile.lock` is **kept committed** - CocoaPods app best practice keeps the lockfile for reproducible iOS builds.
- `tracker/build/` is gitignored (root `build/` pattern + `tracker/.gitignore` `/build/`); never commit build artifacts.
- `.DS_Store` / macOS junk are in the root `.gitignore` (already present in `tracker/.gitignore`).
- `linux/` + `windows/` `generated_plugin_registrant.*` and `generated_plugins.cmake` are regenerated on `flutter pub get` and **are meant to be committed** - expect them to show as modified after dependency changes.

### Other decisions

- Codegen: after any change to `@collection`/`@embedded`/`@enumerated` annotations, run `cd tracker && dart run build_runner build`. Generated `*.g.dart` files are excluded from the analyzer and must not be hand-edited.
- State caching is reconciled (Milestone 3): `HydratedBloc` caches only the **in-progress** session (plan + sets) so a workout survives a restart; completed workouts are finalized as `WorkoutSession` records in Isar on `endWorkout`, and the hydrated state resets to idle.
