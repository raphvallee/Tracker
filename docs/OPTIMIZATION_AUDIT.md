# Tracker optimization audit

Reviewed revision: `6980f9c` on `main`  
Date: 2026-09-16  
Disposition: report only; no application changes or fixes applied.

## Executive assessment

The strongest opportunities are reducing full-history database reads, removing repeated analytics work, restoring list virtualization, and making workout selectors actually skip unchanged content. These costs grow with stored workout history or active-session size. They are more important than isolated missing `const` constructors or arithmetic micro-optimizations.

This report identifies **30 active-path optimization opportunities and three latent concerns**. Related occurrences are grouped rather than counted as separate defects. “High” means prioritize as data grows, not that a production slowdown has been measured. “Low” means defer unless representative workloads justify the complexity.

### Evidence and limits

- The review covered all non-generated domain/data files and workout/routing/composition files through scoped reviews, then directly checked feed, history/calendar, exercises, settings, progression, shared chart/unit helpers, CI, the commit hook, root scripts, and selected test infrastructure.
- This is not an exhaustive audit of every platform runner, generated file, test, or theme helper. Secondary UI/tooling reviews did not complete; the direct review covered the principal runtime paths instead. Native builds, bundle sizes, device frame times, battery use, memory soaks, and database timings were not measured.
- Existing `test/perf_tmp_test.dart` passed unchanged: 2,000 sessions × 6 sets; per-exercise estimation **6.435 ms**, the subsequent gym-wide estimation **2.052 ms**, and eight graph calculations **6 ms total**, approximately **0.8 ms/card**. These are single host-test observations, with no warm-up/repetition control. They do not establish release-device jank or expected speedups. This probe times pure analytics, not database reads or widget rendering.
- `flutter test --no-pub test/domain` passed: **20 tests**. The full suite, static analysis, visual sweep, and release builds were not run. There was no code change to validate.
- The initial probe command ran from the repository root and failed to find `pubspec.yaml`; rerunning from `tracker/` passed. That was an invocation error, not a project defect.
- The pre-existing untracked `tracker/test/perf_tmp_test.dart` was not edited, staged, or committed.

Paths below are repository-relative. Complexity uses N for sessions, S for total stored sets, E for exercises, and G for graph cards. Exact gains require representative measurements.

## High priority: historical data and rendering

### 1. Session date queries do not use secondary indexes

**Evidence:** `tracker/lib/data/repositories/workout_session_repository.dart:19–25,33–39,46–50,59–63`; `docs/ISAR_SCHEMA.md:81–85`.

**What and why:** Recent and date-range queries filter and sort an unindexed collection. A small result limit bounds returned objects, not the work required to find those objects.

**Impact:** Opening the feed or querying a day examines an increasingly large history. Relevant watcher updates repeat query work.

**Recommended fix:** Add suitable timestamp indexes and rewrite the queries to use indexed ranges and ordering. Preserve completed-only filtering and date boundary semantics. Adding annotations without changing query construction is insufficient. Regenerate schemas and verify existing-data compatibility under the additive-only freeze. Do not add indexes to every field blindly.

### 2. History watches complete sessions and every embedded set

**Evidence:** `tracker/lib/data/repositories/workout_session_repository.dart:74–75`; `tracker/lib/ui/history/widgets/history_page.dart:35`.

**What and why:** The history query has no result bound. Its non-lazy watcher delivers the complete result, including embedded sets, when results change.

**Impact:** Allocation and deserialization scale with N + S per refresh, even for a single new workout. The calendar also receives the entire history.

**Recommended fix:** Add paginated history and month-scoped calendar queries. Use lightweight summaries for dates, counts, and list labels; fetch full sets on demand. Maintain a separate compact date index for streaks so month windowing does not change streak semantics. Consider additive summary fields only if measured read costs justify schema work.

### 3. History's builder list is not effectively viewport-lazy

**Evidence:** `tracker/lib/ui/history/widgets/history_page.dart:89–104,112–125`.

**What and why:** `ListView.builder` is shrink-wrapped, non-scrolling, and nested inside a `SliverToBoxAdapter`. The outer scroll view gives the inner list content-sized layout rather than a bounded scrolling viewport.

**Impact:** Long histories require building/measuring content beyond the visible screen. Pagination alone does not fix an already large loaded page.

**Recommended fix:** Make the selected history view participate directly in the outer sliver viewport, or give the list its own bounded viewport. Use a real `SliverList` for rows and preserve the list/calendar toggle and scroll position.

### 4. Every feed graph build recalculates its historical series

**Evidence:** `tracker/lib/ui/feed/widgets/feed_page_graph_card.dart:29–34`; `tracker/lib/domain/services/analytics.dart:49–77,87–97`.

**What and why:** `build()` invokes timeframe selection, aggregation, allocation, and sorting. Each card repeats this independently. These calls bypass `AnalyticsService`.

**Impact:** Worst-case work approaches O(G × (S + N log N)) per rebuild. Even a short timeframe scans session dates. This is build-time work, not evidence that it runs every animation frame.

**Recommended fix:** Compute immutable graph results when sessions, multipliers, graph configuration, or display units change. Share equivalent queries between cards. Invalidate with actual data revisions, not only session count; edits can preserve count. Preserve the current timeframe anchor to the newest session unless changing that behavior intentionally.

### 5. Ending a workout waits for avoidable full-history estimation

**Evidence:** `tracker/lib/ui/workout/view_models/workout_cubit.dart:459–493`; `tracker/lib/ui/settings/widgets/gyms_page.dart:103–114`; `tracker/lib/domain/services/analytics.dart:500–515`.

**What and why:** Secondary-gym completion loads all gyms and sessions, computes per-exercise estimates, then calls a scalar estimator that repeats the same calculation. Gym settings repeats the two estimator calls as well. The final idle emission waits for optional estimation.

**Impact:** Full-history memory allocation and repeated synchronous analytics run on the UI isolate. An `async` method does not move its CPU work to another isolate. Completion latency grows with history.

**Recommended fix:** Return exercise estimates and their scalar median together. Fetch the target gym directly and scope history to the relevant gyms where semantics permit. If narrowing history, preserve the estimator's current global reference date. Complete the durable workout-save transition independently of optional estimation, with serialized follow-up work and explicit error handling. Use incremental aggregates or an isolate only after measuring the remaining cost.

### 6. The workout selector cannot recognize unchanged presentation

**Evidence:** `tracker/lib/ui/workout/widgets/workout_page.dart:105–139,279–326`.

**What and why:** `_WorkoutPresentation.fromState()` creates a new identity-only object on every state emission. It has no value equality. The selector therefore does not suppress equivalent selections; it also groups all exercise cards into one selected body.

**Impact:** Every logged set rebuilds unaffected cards/forms. Even a transient save-error change rebuilds the active-workout body.

**Recommended fix:** Use immutable value-comparable selections for header, plan structure, set count, and each exercise's sets. Equality on the aggregate alone will not isolate individual set changes. Preserve list identity or use deliberate content equality where needed.

### 7. Workout cards and logged sets are eagerly mounted

**Evidence:** `tracker/lib/ui/workout/widgets/workout_page.dart:109–125,422–441`.

**What and why:** The active workout is expanded into columns beneath one sliver adapter. `CustomScrollView` does not make that column's children lazy.

**Impact:** Offscreen forms, their controllers, and set rows remain mounted. Build/layout and retained memory grow with the whole session.

**Recommended fix:** Use builder-backed slivers for exercise sections. Flatten headers, rows, and forms if individual sections can become large. Preserve unsaved field drafts outside children that virtualization can dispose.

## Medium priority: repeated runtime work

### 8. The feed preloads all history even without graphs

**Evidence:** `tracker/lib/ui/feed/widgets/feed_page.dart:38–55,124–129`.

**What and why:** Initial feed loading always fetches every session and exercise, even when the graph list is empty. Recent activity already has a separate three-session watcher.

**Impact:** The initial feed retains lifetime history and an exercise library that may not be displayed. Memory and loading work grow independently of visible recent activity.

**Recommended fix:** Load analytics only when graph configurations require it. Load exercise choices when opening the graph editor, or share an existing library snapshot. Use bounded graph queries or compact aggregates instead of always retaining raw history. Make refresh/invalidation explicit; do not optimize by leaving stale data cached forever.

### 9. User-created feed graphs are rendered eagerly

**Evidence:** `tracker/lib/ui/feed/widgets/feed_page.dart:76–118,228`.

**What and why:** Every graph card is placed in one column inside a sliver adapter. Exercise-name lookup also linearly scans the exercise list for each card.

**Impact:** Offscreen cards run their build-time analytics and retain chart content. Name resolution adds O(G × E) lookup work.

**Recommended fix:** Render graph cards with a builder-backed sliver and stable configuration identity. Maintain an ID-to-name map on exercise updates. Combine with finding 4 rather than creating a separate cache in every layer.

### 10. The chart redraws all observations, including indistinguishable points

**Evidence:** `tracker/lib/ui/core/ui/line_chart.dart:80–102,154–175`.

**What and why:** Each paint scans extrema, lays out four labels, constructs a full path, and draws a dot for every point. There is no resolution-aware reduction.

**Impact:** Painting scales with historical point count even when many points occupy the same few pixels. Repeated label construction adds native text-layout work.

**Recommended fix:** Cache geometry and label layout against immutable data, chart size, style, and unit. Dispose retained text painters appropriately. For dense histories, use a documented downsampling strategy that preserves extrema, endpoints, and the chart's existing spacing semantics; avoid silently changing ordinal spacing to time spacing. Suppress dense dots. Profile before adding complicated rendering machinery. The existing `shouldRepaint` does prevent some repaints; this is not an always-repaint painter.

### 11. Unit conversion recreates entire chart series on every build

**Evidence:** `tracker/lib/ui/core/ui/weight_format.dart:24–35`; `tracker/lib/ui/exercises/widgets/exercise_detail_page.dart:76`; `tracker/lib/ui/analytics/widgets/progression_page.dart:121–126`; `tracker/lib/ui/core/ui/line_chart.dart:182–187`.

**What and why:** `displayProgressionPoints()` creates a new list and a new point per observation, including the identity kg conversion. The painter compares list identity, so the replacement also defeats unchanged-data repaint suppression.

**Impact:** O(points) allocations on parent rebuilds, followed by otherwise avoidable repaint work.

**Recommended fix:** Reuse immutable canonical points for kilograms. Cache converted points by source revision and unit, or apply a unit transform in presentation without allocating replacement points. Ensure unit changes explicitly invalidate rendering.

### 12. Exercise detail overfetches and computes unused metrics

**Evidence:** `tracker/lib/ui/exercises/widgets/exercise_detail_page.dart:48–68,76–77,159`; `tracker/lib/domain/services/analytics.dart:182–236`.

**What and why:** Opening one exercise fetches every session. The snapshot computes best-1RM, peak-weight, and whole-session volume series, though the page displays only best-1RM and summary values.

**Impact:** Every exercise visit scans unrelated history and creates unused series. The snapshot volume series can retain points for sessions unrelated to that exercise.

**Recommended fix:** Provide an exercise-specific repository/analytics path or an explicit metric projection. Preserve normalization and summary semantics. For general progression, which genuinely needs all history, share compact revisioned aggregates rather than repeating raw-history reads on each visit.

### 13. Gym management preloads raw workout history for an optional action

**Evidence:** `tracker/lib/ui/settings/widgets/gyms_page.dart:31–42,233`.

**What and why:** Merely opening gym management loads all sessions. Until estimation is requested, the UI uses that list principally to decide whether an estimation action is available.

**Impact:** History-sized I/O and retained memory while editing a gym name or multiplier.

**Recommended fix:** Use an existence/count query for availability and fetch fresh estimation inputs on demand. Reuse the consolidated estimator from finding 5. This also avoids keeping a one-time historical snapshot as the estimation source indefinitely.

### 14. Weighted gym means allocate one object per historical set

**Evidence:** `tracker/lib/domain/services/analytics.dart:530–553,573–586`.

**What and why:** Relevant sets become `_WeightedValue` objects stored in per-exercise lists, then are traversed again solely to calculate weighted sums.

**Impact:** O(S) temporary objects and storage for a calculation that needs O(E) accumulators. Duplicate estimator calls amplify this cost.

**Recommended fix:** Accumulate weighted-value totals and weight totals directly per gym/exercise. Preserve recency weighting, warmup exclusion, zero handling, and scalar median behavior. Verify numerical equivalence within an appropriate floating-point tolerance.

### 15. Every log append queues a full durable file rewrite

**Evidence:** `tracker/lib/data/services/app_log.dart:37–39,49–77`.

**What and why:** Each append queues another future that creates/checks the file and rewrites the entire current buffer with `flush: true`. Errors with stacks schedule two writes. The buffer is bounded, but the pending future chain is not.

**Impact:** Error bursts create redundant I/O, repeated string joins, durable flushes, and a growing queue. Queued operations can rewrite effectively identical contents.

**Recommended fix:** Coalesce writes while one is in flight using a dirty flag and bounded cadence. Initialize the destination once. Preserve explicit flushing for export or lifecycle needs and keep logging failures non-fatal. Do not trade away required diagnostic durability silently.

### 16. Text edits rebuild complete add-set forms

**Evidence:** `tracker/lib/ui/workout/widgets/workout_page.dart:590–591,602–658`.

**What and why:** Both text controllers call `setState` on every notification even when their error is already null. Selection notifications can trigger this too. Free-form mode recreates the complete exercise dropdown map.

**Impact:** O(E) dropdown allocation per notification plus rebuilding unrelated controls during typing.

**Recommended fix:** Clear an error only when it exists. Keep field validation updates local and cache dropdown items until exercise data changes. No debounce is needed merely to avoid null-to-null error updates.

### 17. Split-name typing rebuilds every day row

**Evidence:** `tracker/lib/ui/workout/widgets/new_split_page.dart:205–251`.

**What and why:** Page-level `setState` runs on each title change, while the day list is eagerly expanded in the same page.

**Impact:** O(days) widget reconstruction per keystroke even when validation does not change.

**Recommended fix:** Isolate title validation and update only when displayed validation changes. Use lazy slivers for large day lists, preserving reorder/edit state.

### 18. Day-title typing rebuilds an eager reorderable list

**Evidence:** `tracker/lib/ui/workout/widgets/split_day_editor_page.dart:103–115,153–170`.

**What and why:** The title triggers a page rebuild. A shrink-wrapped, non-scrolling `ReorderableListView` sits inside the outer scroll view and uses eager children.

**Impact:** All exercise rows are reconstructed during typing; layout scales with the whole list during changes and reorders.

**Recommended fix:** Isolate the live title/app-bar update and use `SliverReorderableList` in the existing viewport. Preserve stable identities and input drafts.

### 19. The split library rebuilds eager cards and summaries

**Evidence:** `tracker/lib/ui/workout/widgets/editor_page.dart:34,56–76,145–160`.

**What and why:** A complete-list stream drives eagerly constructed split/day content and repeated joined exercise-name subtitles.

**Impact:** Every split update causes presentation work across the loaded library, including offscreen entries.

**Recommended fix:** Use lazy slivers, stable split/day identities, and summaries cached against split and name revisions. Start with viewport laziness; add per-item subscriptions only if measurement warrants them.

### 20. Hidden tabs continue consuming query updates

**Evidence:** `tracker/lib/routing/home_page.dart:43–56`; `tracker/lib/ui/feed/widgets/feed_page.dart:124–129,142–144`; `tracker/lib/ui/history/widgets/history_page.dart:33–35,51–54`; `tracker/lib/ui/workout/widgets/editor_page.dart:29–44`.

**What and why:** Visited tabs remain mounted under `Offstage`. Feed, history, and editor do not detach these subscriptions on tab visibility changes. Their stream identities are stable; this is not a resubscription leak.

**Impact:** Relevant updates can materialize query results and rebuild hidden trees while another tab is visible. History is the largest concern because its query is unbounded.

**Recommended fix:** Reuse the visibility contract already implemented by ExercisesPage. Cancel/resubscribe when appropriate, retain the last presentation, and refresh on activation. Define route visibility separately if necessary. `TickerMode` alone does not stop streams.

### 21. Every workout mutation serializes the whole active session

**Evidence:** `tracker/lib/ui/workout/view_models/workout_cubit.dart:280–290,374–385,402,502–503`.

**What and why:** Set mutations, gym changes, and transient save-error emissions serialize the entire plan and set list for hydration.

**Impact:** O(plan + sets) serialization per action. Repeated appends accumulate quadratic total serialization work across a sufficiently large session. This happens per action, not per text keystroke; text entry does not emit workout state.

**Recommended fix:** First avoid persisting transient-only changes. Keep full snapshots if realistic sessions remain cheap. For demonstrated large-session costs, consider incremental durable set storage plus lightweight hydrated metadata. Do not debounce persistence without an explicit crash-recovery policy; surviving restarts is a product requirement.

### 22. The exercise tab performs duplicate initial reads

**Evidence:** `tracker/lib/ui/exercises/widgets/exercises_page.dart:76–85`; `tracker/lib/data/repositories/exercise_repository.dart:34–36`.

**What and why:** `_subscribe()` calls `getAll()` and immediately attaches a watcher configured with `fireImmediately: true`. Both deliver an initial list.

**Impact:** Duplicate materialization and rebuilds each time the tab resubscribes, not only on first app launch. Completion ordering also makes these independently delivered snapshots harder to reason about.

**Recommended fix:** Use the initial watcher emission as the single initial read and model loading/error state explicitly. Preserve visibility-based cancellation, which is already implemented correctly here.

### 23. Exercise grouping and group contents are rebuilt eagerly

**Evidence:** `tracker/lib/ui/exercises/widgets/exercises_page.dart:111–120,143–168,193–217`.

**What and why:** Both muscle and movement grouping functions run while building tab entries. Each built group constructs its full list of `FItem` widgets and equipment-label strings.

**Impact:** Work grows with library size and muscle-group memberships; exercises belonging to multiple groups generate repeated presentation. Hidden-tab construction at the framework level is not assumed, but both grouping calls are evaluated eagerly by this code.

**Recommended fix:** Compute grouping and label projections when the exercise snapshot changes. Make expanded group contents lazy for large libraries, rather than constructing every row up front. Keep the existing stable exercise keys.

## Lower priority: bounded workloads and developer workflow

### 24. Workout state copies unchanged immutable collections

**Evidence:** `tracker/lib/ui/workout/view_models/workout_cubit.dart:136–137,302–317,374–385`.

**What and why:** `copyWith` routes both lists through defensive copying. Appending first builds a list and then copies it again; metadata updates also copy the unchanged plan and sets.

**Impact:** Redundant O(plan + sets) allocations and repeated state-local derived calculations. Usually smaller than whole-page rebuilding or history estimation.

**Recommended fix:** Use a private ownership-safe constructor to retain already-immutable lists and only copy changed inputs. Preserve defensive copies at external boundaries; do not expose mutable collections to gain speed.

### 25. Narrow detail pages load the entire exercise library for names

**Evidence:** `tracker/lib/ui/workout/widgets/split_day_page.dart:42–45`; `tracker/lib/ui/workout/widgets/split_day_editor_page.dart:56–62`; `tracker/lib/ui/history/widgets/session_detail_page.dart:39–45`.

**What and why:** Each page fetches all exercise objects to label a small set of referenced IDs.

**Impact:** Repeated O(E) database materialization and name-map allocations when navigating between details.

**Recommended fix:** Add a batch ID/name projection or share a revisioned name index. When the picker returns a new exercise, retain its name directly. Keep missing/deleted exercise fallbacks intact.

### 26. Smaller user-created collections are also rendered eagerly

**Evidence:** `tracker/lib/ui/workout/widgets/split_day_page.dart:85–137`; `tracker/lib/ui/history/widgets/session_detail_page.dart:52–55,93–99`; `tracker/lib/ui/workout/widgets/gym_picker.dart:28–49`; `tracker/lib/ui/settings/widgets/gyms_page.dart:227–239`.

**What and why:** Day exercises, completed-session sets, and gyms are expanded into columns. Session details also allocate a working-set list solely to fold its volume.

**Impact:** Opening a large detail or unusually large gym collection mounts all rows. These are normally small personal collections, so this ranks below lifetime history.

**Recommended fix:** Use lazy rows when realistic sizes justify them; constrain the gym sheet's height. Cache session summary values or fold working sets without the intermediate list. Do not replace every small fixed column indiscriminately.

### 27. Search renormalizes every exercise title per edit

**Evidence:** `tracker/lib/ui/workout/widgets/exercise_picker_page.dart:41–47,61–63`.

**What and why:** Search traverses and lowercases the library and constructs a new result list on every input change.

**Impact:** O(total title characters) work per query edit. The seeded library is small; this matters primarily for large custom libraries.

**Recommended fix:** Precompute normalized titles and skip unchanged normalized queries. Introduce debounce or repository search only if necessary. The existing result sliver is already lazy.

### 28. Reorderable keys change with item position

**Evidence:** `tracker/lib/ui/workout/widgets/split_day_editor_page.dart:162`.

**What and why:** A row's key includes its current index, so reorder/delete operations change keys for shifted rows.

**Impact:** Avoidable element remounts and internal widget-state initialization, rather than reusing the moved rows.

**Recommended fix:** Assign each list occurrence a stable editor-local identity independent of index. Exercise ID alone is insufficient because duplicate exercise occurrences must remain distinguishable.

### 29. Small redundant reads and overly broad subscriptions remain

**Evidence:** `tracker/lib/ui/feed/widgets/feed_page.dart:44,128–138,210–225`; `tracker/lib/ui/workout/widgets/new_split_page.dart:181–185`; `tracker/lib/routing/home_page.dart:113–125`; `tracker/lib/ui/workout/widgets/workout_page.dart:489–494`.

**What and why:** Feed startup reads gyms twice. New-split creation reads full split objects only to find the maximum order. Navigation and the feed workout action observe whole workout state but need only `isInProgress`; the free-form card observes more than its set list requires.

**Impact:** Extra small reads, unnecessary object materialization, and avoidable widget/semantics work per mutation. These are separate minor occurrences, grouped to avoid inflating the main findings.

**Recommended fix:** Reuse one feed gym result; expose a repository order aggregate/projection; select only the boolean or value-equal sets projection each widget uses. Do not infer a whole-shell rebuild from the navigation-item builder.

### 30. The commit hook performs whole-package mutation on every commit

**Evidence:** `.husky/pre-commit:24–34`.

**What and why:** The hook always runs package-wide `dart fix --apply` and `dart format .`, then stages all of `tracker`, regardless of the intended commit scope.

**Impact:** Unrelated or documentation-only commits pay analysis/formatting cost. More importantly, the broad `git add` can accidentally include unrelated user work, including the existing untracked performance probe. This is a workflow correctness concern as well as wasted work.

**Recommended fix:** Restrict formatting to intended Dart changes, skip Dart tooling when none apply, and move package-wide autofixes to an explicit maintenance command. Preserve partial staging rather than broadly restaging the package. Do not bypass the hook or commit anything as part of this audit.

## Latent concerns: do not prioritize ahead of active bottlenecks

### L1. Analytics cache hits still walk all inputs

**Evidence:** `tracker/lib/domain/services/analytics.dart:258–267,323–362`.

**What and why:** Snapshot lookup fingerprints every session/set and sorts multiplier maps before accessing the cache. A supplied revision does not skip this work.

**Impact:** Cache hits remain O(N + S), plus multiplier sorting. Current inspected snapshot consumers mostly load once; this is not the feed's build-time cache path.

**Recommended fix:** Introduce a trusted immutable-input/repository-revision path if the service becomes reactive or frequently reused. `sessions.length` is not a sufficient revision: edits and multiplier updates must invalidate results.

### L2. Snapshot caches have no eviction bound

**Evidence:** `tracker/lib/domain/services/analytics.dart:172,267–280`.

**What and why:** Each different fingerprint/filter/revision retains another snapshot until `clear()` or service disposal.

**Impact:** A long-lived reactive service can retain multiple history-length series across many revisions. Current page-local, mostly one-load usage limits present exposure; no memory leak was demonstrated.

**Recommended fix:** Retain only the current data revision with a bounded filter cache, or use a small LRU. Set an explicit memory/entry budget before making this service shared and long-lived.

### L3. Movement fallback repeatedly sorts identical ratio groups

**Evidence:** `tracker/lib/domain/services/analytics.dart:561–566,596–598`.

**What and why:** Every missing exercise computes the median of the same group's fallback ratios again. The median copies and sorts its input.

**Impact:** F missing exercises sharing K ratios cost O(F × K log K), with repeated lists. Inspected production callers do not pass the optional exercise-group map, so this is currently a dormant path.

**Recommended fix:** Compute one median per group and reuse it. Preserve the existing upper-middle median convention unless changing analytics semantics intentionally.

## Do not mistake these for demonstrated performance defects

- The calendar already builds `WorkoutDateIndex` on session-list replacement and uses date/month lookups. Its grid has at most 42 cells. It does not scan the full history per painted cell.
- The session-to-set loops in analytics are linear in the total number of sets, not automatically quadratic merely because loops are nested.
- The composition root does not repeatedly open Isar. Seeding is guarded and deferred after the first frame. No cold-start budget violation was measured.
- Settings state has value equality. Its small controls do not justify a blanket recommendation to add selectors everywhere.
- Explicit scoped text controllers are created outside `build()` and disposed. No indefinite ticker or controller leak was verified. Hidden streams are a separate, demonstrated issue.
- Theme construction, short date formatting, scalar kg/lb conversion, and small fixed stat rows are not established bottlenecks. Typography-file length is not runtime cost.
- Screenshot capture intentionally rewrites a manifest after each image for crash recovery. Without suite timings, removing that safeguard is not justified.
- The CI file has no demonstrated duplicate test invocation. This audit does not label every uncached tool or missing pipeline feature as a proven optimization problem.
- No files under `tracker/build` are currently tracked according to `git ls-files`, despite older project notes suggesting otherwise.

## Additional correctness notes, outside the optimization count

These should not be confused with performance tuning:

- Feed analytics are loaded once, while the recent-session stream updates independently (`feed_page.dart:38–55,124–129`). Graph settings are read with `context.read` through `SettingsCubit.maybeOf`, not watched (`settings_cubit.dart:155–160`). Any caching/refactor must explicitly support graph edits, new sessions, gym updates, and unit changes rather than preserving stale snapshots.
- Progression converts volume points to display units and then passes their sum into `formatWeight`, which converts kilograms again (`progression_page.dart:121–125,156`; `weight_format.dart:16–21`). The pounds path needs a focused correctness test before changing analytics presentation.
- Chart repaint invalidation omits `unit` (`line_chart.dart:182–187`). If point identity is stabilized as recommended, unit-only changes must still repaint labels.
- The local Actions script ends after setup and `Pause`; it never invokes `act` (`run-github-actions-locally.ps1:247–265`). It also inserts a fixed 10-second Windows Docker delay. If repairing that workflow later, invoke the requested workflow after a bounded readiness check instead of claiming it currently executes CI.

## Recommended execution order and verification

1. **Remove provable duplicate work:** consolidated gym estimation, exercise initial watcher read, redundant feed gym read, null-to-null field validation updates. Compare outputs and query/rebuild counts before and after.
2. **Fix growth-sensitive paths:** indexed/windowed session queries, true history slivers, lazy feed/workout content. Test 100, 1,000, and 10,000 sessions with realistic set counts. Verify pagination ordering, date boundaries, deleted exercises, and draft preservation.
3. **Narrow invalidation:** value-equal per-exercise selectors and revisioned graph presentation. Count rebuilds when one set, one gym, one graph, or only an error changes. Test updates that preserve session count.
4. **Measure rendering and completion:** profile representative devices, then decide whether chart reduction, incremental aggregates, or isolates are necessary. Record build/raster times and end-workout latency separately.
5. **Preserve guarantees:** retain hydration recovery, canonical kilograms, warmup exclusion, normalization, additive-only schema changes, and logger failure isolation. Run domain/data/widget tests plus the visual sweep after UI changes. Keep the known Isar test-process constraints when adding database tests.

The audit does not mark production-readiness phases complete. Its findings are inputs to the existing roadmap, not proof that its performance gates have passed.
