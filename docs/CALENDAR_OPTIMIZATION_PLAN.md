# Calendar optimization implementation plan

## Context

The calendar already uses `WorkoutDateIndex` for constant-time date lookups and precomputed month counts. The audit identifies avoidable full-history session loading, index reconstruction on subtab remount, hidden subscriptions, and eager session-row layout. Preserve the existing lookup strategy while reducing data allocation and repeated work, retaining navigation state, and fixing date-dependent cache correctness.

This is a saved implementation plan only. No application changes or commits are made during planning. During implementation, every optimization gets its own commit, with its tests. The user explicitly authorizes committing immediately when tests pass and code quality is satisfactory, without asking between commits. Do not push.

## Evidence and corrections to earlier discussion

- `tracker/lib/ui/history/widgets/calendar/history_calendar.dart:40–58` owns and rebuilds the index; `history_page.dart:90–104` places it in a disposable subtab body.
- `history_page.dart:35` attaches `watchAll()` regardless of the selected subtab. A narrower calendar query does not help if this full-history subscription/cache remains alive.
- Installed `isar_community` 3.3.2 supports single-property queries, including `startTimeProperty()`. It does not supply arbitrary summary tuples or a stored set-count property. `setsProperty()` still decodes embedded sets.
- Full-object deserialization includes Dart-side work. A date projection reduces Dart object decoding/allocation; it does not prove proportional reductions in native buffers or disk reads.
- Repository collection notifications identify that something changed, not which IDs changed. A generic write revision still changes on weight-only edits and does not solve semantic invalidation.
- `WorkoutCubit.logSet` and `removeSet` only update hydrated state. The located production session write happens in `endWorkout`, not on every logged set.
- Keeping navigation state is an intentional behavior improvement. DST/local-date normalization fixes are deliberate correctness changes, not a claim of zero behavior change.

## Implementation and commit contract

1. Recheck `git status`, staged changes, and existing diffs; create a feature branch from the current checkout before implementation. Do not create a worktree or change branches under another session.
2. Preserve the user's existing calendar edits, three macOS files, untracked audit documents, and `tracker/test/perf_tmp_test.dart`. Save a baseline diff outside the repository before editing overlapping files. Do not delete, reset, stash, or include unrelated changes in commits.
3. Copy this finalized plan to `docs/CALENDAR_OPTIMIZATION_PLAN.md` when implementation begins, after checking that the destination does not already contain different work. Keep its checklist and evidence current. Include the initial plan copy in the first implementation commit; do not add the user's untracked audits automatically.
4. Each numbered optimization below is a separate commit. Include its regression tests and acceptance evidence in that commit. Shared fixtures needed for one optimization belong in that commit, not a separate failing-test commit.
5. Review scoped diffs, run formatting and analysis, and pass targeted tests plus the complete test suite before each commit. Validate the staged snapshot independently when the dirty working tree differs from the proposed commit; working-tree success alone does not prove that the commit builds.
6. **Hook safety:** `.husky/pre-commit:26–34` runs package-wide fixes/formatting and `git add tracker`. Normal commits would sweep in unrelated user work. It does not honor `HUSKY=0`. For this dirty-tree implementation only, perform the relevant formatting/fix review manually on owned files, stage only owned patches, and use the command-local `git -c core.hooksPath=/dev/null commit ...`. This bypass is solely to avoid the hook's broad edits/staging; do not change persistent hook configuration or skip tests/analysis. Record its use in the final receipt.
7. For files with pre-existing edits, stage only the implementation delta against HEAD, preserving the user's original edits unstaged. If changes overlap too closely to separate safely, do not guess: restructure the patch or surface that specific blocker. Test an exported copy of the index when necessary; this is not a Git worktree.
8. After each commit, inspect committed paths, staged state, and remaining diffs. Confirm unrelated user work remains unchanged. Stop progression on failed gates, unexpected hook effects, or unsafe patch separation.
9. Commit without additional permission once the above conditions pass. End messages with `Co-Authored-By: Claude Code <noreply@anthropic.com>`.

## Baseline before the first code change

Record current analysis/test results and reproduce the audit's deterministic cases using owned fixtures, not the user's `perf_tmp_test.dart`. Capture first index construction, unchanged subtab remount, 200 same-day mounted rows, query/subscription counts, and representative payload allocations. Keep benchmark-only helpers outside normal timing assertions. Where device tooling exists, record the same profile scenarios before and after the changes; debug host timings are not a device baseline. A baseline defect can have a passing characterization test first, then become a regression assertion in its fixing commit; do not commit intentionally failing tests.

## Target design

Use a small history-owned view model under `tracker/lib/ui/history/view_models/`. Follow the repository's MVVM direction; no new global singleton, hydration format, dependency, or generic caching framework. The history page owns the model's lifetime.

Separate:

- **Navigation:** selected subtab, displayed year/month, selected local date, and appropriate per-subtab scroll position.
- **Calendar date data:** immutable local-date counts, occupied dates, and month workout-day counts. Evolve `WorkoutDateIndex`; do not maintain a redundant second index.
- **Selected-day rows:** immutable summaries with ID, title, start time, set count, and optional gym reference. Full sets belong only to scoped reads and detail pages.
- **Clock state:** today's local date and streak, independently invalidated.
- **Load state:** distinguish initial load, refresh, empty, and error. Retain valid compact data during refresh without presenting stale data as confirmed current data after a failure.

The view model must preserve navigation through loading/error/empty transitions. Repository replacement clears repository-specific caches, while ordinary subtab changes do not reset navigation.

## Commit 1 — Retain calendar state across subtab remounts

Suggested subject: `perf(history): retain calendar presentation state`

- Lift the lazily initialized index, displayed month, and selected day out of `_HistoryCalendarState` into history-owned state.
- Keep initial List behavior: do not build the calendar index until Calendar is first used.
- Make `HistoryCalendar` consume presentation data and callbacks. Retain month/grid caches without keeping both complete List and Calendar widget trees mounted.
- Control subtab selection using installed `FTabControl.lifted(index:, onChange:)`. Preserve the Forui appearance, labels, keyboard behavior, and accessibility.
- Initially preserve current data delivery. Later commits replace the input shape without duplicating ownership.

Files: `history_page.dart`, `calendar/history_calendar.dart`, new history view model, `test/ui/history/history_test.dart`, and focused view-model tests.

Acceptance:
- [x] First Calendar activation reads N sessions; month/day navigation reads no additional source sessions.
- [x] An unchanged List/Calendar round trip preserves the same index, displayed month, and selected date without reindexing.
- [x] Loading/error/empty transitions do not accidentally reset navigation.
- [x] User's existing `_WeekdayLabels` extraction and other calendar edits remain intact.

Commit 1 evidence (2026-09-16, working tree on `feature/optimization-1`; no staging or commit, per the latest instruction):

- `calendar_view_model_test.dart`: counted immutable list of 1,000 sessions has zero reads on delivery, exactly 1,000 on first index access, and no further reads on month/day navigation or unchanged delivery. Replacement/empty snapshots invalidate lazily without clearing navigation; only the latest pre-activation snapshot is indexed.
- `history_test.dart`: actual `HistoryPage` taps activate Calendar, navigate/select a day, then perform three List/Calendar round trips. The calendar widget is unmounted each time, but its model, date index, grid, occupied-day cache and selected date retain identity/value, with zero additional calendar source reads. Initial activation adds exactly N reads above existing List rendering; `watchAll()` is requested once.
- Actual page stream error/recovery and empty/recovery retain Calendar selection, displayed month and selected day. Repository replacement exercises a real loading transition, drops old repository data/listener, and preserves navigation when new data arrives. Standalone calendar external → internal → external and external → external model switching passes without disposing caller-owned models.
- Scoped `dart format` completed on the six owned Dart files. `dart analyze lib/ui/history test/ui/history`: **No issues found**. `flutter test test/ui/history`: **17 tests passed** (11 existing, 6 new). No other suites ran concurrently.
- `_WeekdayLabels` remains intact. Later optimizations, full-suite/global analysis, visual sweep and profiling are not claimed by this scoped gate; the supplied prior baseline was 90 passing tests with the pre-existing `perf_tmp_test.dart` global-analysis warning.

## Commit 2 — Make date caches correct across midnight and DST

Suggested subject: `fix(history): invalidate calendar state by local date`

- Normalize session instants with `toLocal()` before deriving local day keys. Use the same policy for grouping, selected-day queries, and labels.
- Replace 24-hour date stepping with calendar arithmetic, such as `DateTime(year, month, day - 1)`.
- Fix `getForDate()` to use `[local midnight, next local midnight)`; leave `getBetween()`'s existing inclusive contract unchanged.
- Make streak computation accept an injected current date. Preserve the rule: a streak ends today, or yesterday if today is empty; an older isolated workout does not count.
- Remove time-dependent streak caching from immutable data-index construction. Recompute streak when the date changes without rescanning sessions.
- Schedule one next-local-midnight timer while the calendar is active; cancel it on disposal/inactivity. Refresh the clock and reschedule on app resume and tab activation. If the device timezone changes while suspended, reload/regroup source timestamps before treating cached local-date keys as current.

Files: `calendar/calendar_grid.dart`, history view model, `workout_session_repository.dart`, calendar/date repository tests.

Acceptance:
- [x] Deterministic today/yesterday/gap, leap-day, month/year-boundary tests.
- [x] Spring-forward and fall-back tests run in an actual DST-observing process timezone; UTC-only tests cannot substitute.
- [x] UTC timestamps crossing local midnight group and query consistently.
- [x] Active midnight and resumed-after-midnight refresh streak without a workout write or full index rebuild.
- [x] Timer/lifecycle listeners dispose cleanly and do not duplicate after repeated activation.

Commit 2 evidence (2026-09-16, working tree on `feature/optimization-1`; no staging or commit):

- `calendar_grid.dart` normalizes `startTime.toLocal()` before day-key grouping; `currentStreak(workoutDays, today)` steps `DateTime(year, month, day - 1)` and takes an explicit today, so index construction no longer caches a streak; `CalendarViewModel.streak` derives it from `workoutDays` + the model's `today`. `getForDate` uses `DateTime(y, m, d + 1)` as the exclusive upper bound (correct across 23h/25h days); `getBetween` untouched.
- DST gates ran in a real DST-observing process: `TZ=America/New_York flutter test --reporter expanded test/ui/history test/data` → **41 tests passed** (29 history tests across calendar math/model/widgets, 12 data tests including the new half-open DST boundary test). `calendar_test.dart` documents the `TZ=America/New_York` invocation and asserts real DST offsets when that zone is present; pure date-math tests stay valid on non-DST hosts.
- Midnight/lifecycle tests inject `now` and use fake-async `tester.pump` (no real timers): active midnight alarm updates today + streak with **zero additional source reads** and no index rebuild; paused model skips the alarm; resume refreshes; dispose cancels timers; a normal DST transition does not regroup (index identity retained). `history_test.dart` also proves the clock rebuilds the streak metric only while the calendar tab is visible.
- Timezone-change-while-suspended: activation/resume validates the cached UTC instant-to-local-midnight mappings, not an ambiguous zone abbreviation/offset. This costs O(N) timestamp validation on activation/resume but no source-session reads or reindex when unchanged. Midnight skips this validation. Grouping uses `toUtc().toLocal()` to avoid cached old-zone fields on retained local DateTime objects. The actual process-timezone Denver/Phoenix collision regression in `timezone_change_test.dart` failed before the fix and passes afterward; host timezone settings are not changed. New York history/data gates also pass after the fix.
- Timer/lifecycle wiring lives on the view model (`setActive` + `AppLifecycleListener`), driven from `HistoryCalendar.didChangeDependencies`/`didUpdateWidget`/`dispose` with `TabVisibilityScope`; model listener rebuilds the widget on clock ticks. The later top-tab suspension (Commit 5) will reuse the same `setActive` surface.
- `dart format` on the eight owned files; `dart analyze lib/ test/` → only the pre-existing `test/perf_tmp_test.dart:2:8 unused_import` warning, unchanged.

## Commit 3 — Replace calendar full-history payloads with dates and scoped rows

Suggested subject: `perf(history): scope calendar session loading`

- Add a repository-owned date stream based on collection `watchLazy` notifications and a `startTimeProperty().findAll()` projection. Subscribe before initial refresh so writes during startup cannot be missed. Serialize/coalesce refreshes with a dirty flag so bursts cause bounded refresh work and the final state is never dropped.
- Evolve `WorkoutDateIndex` to build occupied-day/count state from timestamp values, without retaining lifetime `WorkoutSession` references. Keep one date index and O(1) date/month lookup behavior.
- Add a selected-day watch/read path using the half-open boundary from Commit 2. Map only that day's full sessions into immutable summaries; release full model references afterward. This still decodes that day's embedded sets to obtain `sets.length`; document this residual cost honestly.
- While Calendar is selected, detach the List full-history watcher and release its full-object cache. While List is selected, use its current full list path and cancel calendar-specific scoped queries. Retain the compact calendar index, mark it for refresh after absence, and compare new date values before rebuilding in Commit 4.
- Resolve full details by `getById()` when a summary row opens. Preserve the existing detail UI and gym labeling. Handle deletion-before-open, lookup failures, repeated taps, and widget disposal during lookup.
- Handle rapid day selection, subtab changes, repository replacement, and late asynchronous completion with generation tokens. Only the current request may update state. Keep a usable retry path after stream/query failures.
- Calendar month navigation remains an in-memory operation. Selecting a different day may now perform a scoped query; tests must distinguish this intentional change from forbidden full-history reads.

Files: `workout_session_repository.dart`, new immutable summary value type under `domain/models/`, existing date index, history view model/page/calendar widgets, `test/data/data_test.dart`, and history tests. Reuse `getById`, `RepositoryScope`, and `pushTo`; never open Isar in widgets.

Acceptance:
- [x] Real-Isar tests cover initial date projection, insert/delete, count-preserving date edits, and committed updates.
- [x] Calendar mode performs no `watchAll()` load and retains no full-history model cache.
- [x] Date projection does not decode embedded sets; selected-day rows match existing title/count semantics.
- [x] Month navigation performs no repository read; day selection reads only the selected range.
- [x] Detail lookup shows current full data or a clear missing/error state.
- [x] Slow obsolete requests cannot overwrite newer selection or repository state.

Commit 3 evidence (2026-09-16, working tree on `feature/optimization-1`, based on `c288cd4`; no staging or commit):

- Repository `getStartTimes` uses the generated native `startTimeProperty().findAll()` single-property path, not `WorkoutSession` decoding or `setsProperty`. `watchStartTimes` and scoped `watchSummariesForDate` share a repository-private subscribe-before-read, serialized dirty-flag refresh loop with error delivery and cancellation guards. Selected-day summaries are immutable ID/title/startTime/setCount/gymId values; counting still decodes that day's full embedded sets and no native-buffer/disk-read reduction is claimed.
- `calendar_repository_test.dart` uses one shared real Isar instance, a 1,000-set fixture, raw collection writes, insert/delete/count-preserving date moves, rollback, half-open selected-day boundaries, ordering and row edits. A held real projection plus five committed writes proves one initial + one coalesced refresh, maximum concurrency 1, final state retained; failure/write recovery, resubscription and cancellation are also covered.
- `WorkoutDateIndex` now contains date counts and timestamp-to-local-date mappings only. `CalendarViewModel` retains compact timestamps/index/navigation, not full sessions; the optional standalone widget adapter immediately converts supplied sessions into compact summaries. The History page explicitly cancels its List watcher and clears its full-list reference on Calendar entry. Returning to List cancels date/day subscriptions and clears scoped rows; Calendar reentry refreshes compact data (identity equality suppression remains Commit 4).
- Page tests prove scoped subscription ownership, no additional full-list source reads in Calendar, month navigation with no new scoped request, cancellation of the old day, state retention through empty/error/retry/repository replacement, and zero `watchAll` requests for a repository installed while Calendar is selected. Model tests deliberately deliver late data/errors even after cancellation to verify generation + repository guards.
- `SessionLookupPage` fetches current full data by ID with FutureBuilder request identity, loading, missing and retry/error UI. Tests cover current full sets/gym label, missing/deleted result, retry, repository/ID replacement, disposal and double tap (one lookup/route).
- Scoped formatting of 14 owned Dart files completed; scoped `dart analyze` reports **No issues found**. `TZ=America/New_York flutter test test/ui/history test/data --concurrency=1 --reporter expanded`: **51 tests passed**, including the original process-timezone collision regression. Full analysis before final formatting reported only the pre-existing `test/perf_tmp_test.dart` unused-import warning. Full-suite/visual/profile acceptance is reserved for coordinator gates, not claimed here.
- User `_WeekdayLabels` extraction preserved; macOS files, audit documents, temporary perf test and `.claude` untouched. No equality optimization, top-tab subscription suspension, sliver redesign, schema change or revision bus introduced.

## Commit 4 — Suppress irrelevant date-index and row rebuilds

Suggested subject: `perf(history): skip unchanged calendar derivations`

- Compare immutable local-date count maps derived from incoming projected timestamps. Reuse existing index and month data when counts are unchanged, regardless of list identity or source order.
- Recompute occupied-day/month state only for meaningful date-count changes. Month workout-day count changes only when a date transitions between zero and nonzero sessions.
- Keep selected-day summary equality independent of date equality. Title, set count, gym, and meaningful ordering/time changes update rows even when the date index is unchanged. Weight-only changes with unchanged row fields do not rebuild calendar rows.
- Do not introduce a fake global repository revision or promise O(1) updates. Comparing all incoming date values remains O(N), but avoids full-session decoding and redundant downstream allocation/rebuilds.

Files: date index, history view model, immutable summary value type, relevant tests.

Acceptance:
- [x] Fresh equal snapshots and reordered equivalent date projections preserve the date-index identity.
- [x] Weight-only changes cause no date-index reconstruction; title/count/gym edits update rows appropriately.
- [x] Date moves and last-session deletion update both affected day/month counts.
- [x] Equal session counts with different contents do not bypass invalidation.

Commit 4 evidence (2026-09-16, working tree on `feature/optimization-1`, based on `7b84657`; no staging or commit):

- `WorkoutDateProjection` normalizes incoming compact timestamps into immutable local-date counts and UTC-instant/local-midnight mappings. `CalendarViewModel.updateDates` compares count maps before invalidating the existing lazy `WorkoutDateIndex` and occupied-day cache; equal, reordered, and same-day time edits retain index/grid/month data identity. Comparison remains O(N), without a revision bus or claims of incremental updates.
- Timezone validation is separate from the reusable semantic index: every projection replaces the raw instant mappings even when counts are equal. The Denver/Phoenix process-timezone regression now first moves a timestamp within the same Denver date (08:00 UTC → 06:30 UTC), asserts index/cache identity, then verifies resume regroups it to June 30 in Phoenix. Old mappings would miss this change.
- Immutable `WorkoutSessionSummary` equality/hash includes ID, title, startTime, setCount and gymId. Ordered row comparison independently suppresses equal row snapshots while title/count/gym/time/ID/order and equal-length different-content changes notify. Loading completion and error recovery still notify for equal payloads.
- Before implementation, the new focused regressions failed with four date notifications instead of one, replaced equal row identity, and replaced index identity on a same-date time edit. After implementation, scoped history/data tests pass. `calendar_scoping_test.dart` asserts exact notifications, retained index/grid/occupied-day identities, date-count redistribution, last-day removal, month-boundary moves and recovery. The shared real-Isar test awaits both actual projected and row deliveries after a raw committed weight-only edit and proves zero model notifications with index/row/cache identity retained; a subsequent title edit publishes once.
- Scoped formatting covered seven owned Dart files. Scoped `dart analyze` reports **No issues found**. `TZ=America/New_York flutter test test/ui/history test/data --concurrency=1 --reporter expanded`: **54 tests passed**, including actual DST/process-timezone coverage. Full-suite, visual and profile gates were not run or claimed for this scoped implementation.
- `history_calendar.dart` and the user's `_WeekdayLabels` extraction were not edited. Unrelated macOS files, audits, `.claude`, and temporary performance test remain untouched. No later optimization, schema change, external agent, staging or commit introduced.

## Commit 5 — Stop hidden history subscriptions

Suggested subject: `perf(history): suspend inactive history queries`

- Read `TabVisibilityScope.isActiveOf(context)` in `didChangeDependencies`; no scope means active, matching standalone test behavior.
- Cancel history data subscriptions and midnight timers while the top-level History tab is inactive. Drop/reject already in-flight results; cancellation cannot undo native work that already started.
- Retain compact calendar presentation state and navigation, not lifetime full-session payloads. On activation, attach only the selected subtab's subscriptions and do one initial refresh per required data source, not `getAll()` plus an immediate watcher load.
- Also suspend while the app is paused/hidden; resume only when both app and History are active. Do not churn subscriptions for a brief inactive focus transition alone.
- Keep updates while a detail route covers History for now. Route-level suspension adds lifecycle complexity without evidence that it is needed.
- Dispose all subscriptions/queries, timers, and lifecycle listeners. Handle repository replacement even if it happens while hidden.

Files: history page/view model; reuse `routing/tab_navigation.dart` without altering the shell's navigation contract.

Acceptance:
- [ ] Hidden History starts no new history queries or index rebuilds when workouts are completed elsewhere.
- [ ] Returning to Calendar refreshes dates and the selected day exactly once per source; returning to List refreshes only its required sources.
- [ ] Repeated hide/show and repository replacement create no duplicate listeners or stale updates.
- [ ] Month and selection survive inactivity while data catches up correctly.

## Commit 6 — Use one lazy scrolling viewport

Suggested subject: `perf(history): render session rows as lazy slivers`

- Keep the page's outer `CustomScrollView` as the only scroll owner.
- Render controlled `FTabs` as the header with empty entry bodies and place selected content in sibling slivers. Verify Forui semantics and spacing; do not invent an unsupported standalone tab-bar API or enable `expands` under unbounded constraints.
- Put month header, weekdays, bounded grid, metrics, and selected-day heading in box-adapter slivers. Render selected-day rows with `SliverList.builder`.
- Convert the List subtab's eager shrink-wrapped list to a lazy sliver list in the same viewport optimization. Do not retain a second unbounded scrolling arrangement.
- Preserve sensible subtab scroll positions, allow the selected-day list to remain reachable, and keep 320px layouts usable. Do not assume a fixed mounted-row count across all viewport sizes.

Files: history page, calendar widgets, history tests, visual/overflow fixtures where necessary.

Acceptance:
- [ ] With 200 same-day sessions in a controlled finite viewport, only viewport/cache rows mount; the last row becomes reachable by scrolling.
- [ ] A long List history also mounts only viewport/cache rows.
- [ ] Navigation, empty messages, detail opening, focus/semantics, and scrolling still work.
- [ ] Visual and overflow checks pass at 320×568, 800×600, and 1280×720.

## Commit 7 — Isolate selection-dependent rebuilding

Suggested subject: `perf(history): isolate calendar selection rebuilds`

- Move month workout-day and streak metrics outside the day-selection listener, or reuse invariant builder children where composition requires it.
- Keep selection listeners focused on the grid's selection styling, selected-day heading, and rows. Month/date-data/clock changes still update their own dependent sections.
- Retain the simple bounded grid. Do not add 42 per-cell notifiers without profiling evidence.

Acceptance:
- [ ] Selecting a different day does not rebuild metrics or reconstruct the index.
- [ ] Selecting the same day starts no duplicate request or state notification.
- [ ] Month changes, date updates, and midnight still refresh the correct metrics.

## Measurement-gated follow-ups: separate commits only when justified

Cover these possibilities in the final evidence; they are not mandatory complexity. A skipped optimization requires a recorded reason, not a false completed checkbox.

### A. Index the now-scoped date queries

Profile the actual selected-day query after Commit 3 with realistic N and embedded-set counts. If full collection filtering materially dominates, add a nonunique `startTime` index and change the new scoped query to generated indexed range clauses. An annotation alone is not sufficient. Preserve half-open boundaries, regenerate code, update `docs/ISAR_SCHEMA.md`, test opening an existing database, and compare read speed/write cost/size. Commit separately as `perf(history): index scoped session date queries` only if measurements support it.

### B. Persist compact summaries only if scoped set decoding remains costly

If selected-day reads or retained memory still dominate, first verify whether native property queries can provide the needed fields coherently. Do not fetch independent arrays and zip them without deterministic ordering and a shared read transaction. There is currently no stored set-count property.

Only if evidence warrants storage changes, add the minimum additive summary storage, with an explicit old-record backfill/completeness policy, atomic session+summary writes/deletes, failed-transaction tests, duplicate/stale-summary recovery, and existing-database verification. Do not treat default zero as a valid migrated set count. Keep the original session schema/data authoritative. This follow-up needs its own detailed subplan and commit; if not justified, record it as deferred rather than inventing a migration.

### C. ID-based incremental updates only after projected O(N) comparison is measured costly

Collection `watchLazy` has no changed-ID feed. Do not add a repository-local revision and pretend external/raw/multi-instance writes are covered. Any justified delta design must handle committed IDs, insert/update/delete, failed/no-op writes, coherent initial snapshot, cancellation/restart gaps, and a trustworthy resnapshot fallback. Apply day/month changes only on proper zero/nonzero transitions. Give this its own detailed subplan and commit only if it beats compact snapshot comparison enough to justify the additional failure modes.

## Verification protocol

Run commands from `tracker/` unless stated otherwise. Record actual results; no tests have been rerun while preparing this plan.

For every optimization commit:

1. Run focused unit/widget/repository tests introduced or affected by that optimization. Reuse `testing/test_helpers.dart` (`initIsarCore`, `openTestIsar`, `pumpAppPage`, `waitFor`) and existing fixtures.
2. Format only owned Dart changes, review any suggested `dart fix` changes, then run `flutter analyze` and `flutter test`. If pre-existing temporary tests or unrelated code fail, report the baseline failure; do not delete or silently exclude them to claim success.
3. For UI changes, run `pwsh run-visual-tests.ps1` from the repository root. Read `tracker/build/test_screenshots/manifest.json` and relevant PNGs, including any `_FAIL` capture. Preserve separate process execution for overflow sizes to avoid the documented Isar worker-pool stall.
4. If model annotations change, run `dart run build_runner build`, review generated diffs, then rerun generation to prove no drift. Never hand-edit `.g.dart` files.
5. Review and validate the staged snapshot separately if unrelated working changes can affect it. Then commit using the safe commit procedure above.

Before final closure:

- [ ] All seven optimization commits have passing gates and recorded commit hashes.
- [ ] Full `flutter analyze`, `flutter test`, and `dart run dependency_validator` pass.
- [ ] Generated files match regeneration; unrelated platform/user files remain untouched and uncommitted.
- [ ] Clock/DST tests run with their required timezone, not merely UTC.
- [ ] Visual sweep and manual image inspection pass all three sizes.
- [ ] A profile-mode run on an available device measures first Calendar entry, repeated subtab switches, month/day selection, hidden-tab writes, and a 200-session day. Use realistic 1k/10k histories and a larger stress fixture when feasible. Record device/build/dataset and frame/heap/query observations. If no device is available, report device profiling as blocked and do not claim frame-budget success.
- [ ] Record each optional follow-up as implemented with its own commit, deferred with evidence, or blocked. Do not add migrations/delta machinery solely to fill a checklist.
- [ ] Update this plan's checked items from evidence, and inspect any related `RefinementPlan.md`/production-readiness checklist before declaring a linked milestone complete. Do not mark unrelated milestones complete.

## Documentation references

- Audit: `docs/CALENDAR_OPTIMIZATION_AUDIT.md`.
- Schema and persistence constraints: `docs/ISAR_SCHEMA.md`, `docs/adr/0001-isar-community.md`.
- Current Isar property query documentation: https://github.com/isar-community/isar-community/blob/v3/docs/docs/queries.md
- Current watcher documentation: https://github.com/isar-community/isar-community/blob/v3/docs/docs/watchers.md
- Flutter lazy sliver guidance: https://docs.flutter.dev/cookbook/lists/floating-app-bar
- Installed Forui API/source is authoritative for version 0.26.0 during implementation.
