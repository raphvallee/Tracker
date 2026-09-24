# Workout calendar optimization audit

Date: 2026-09-16. Scope: calendar indexing and widget lifecycle, history integration, repository query path, installed Forui tab implementation, and calendar/history tests. Read-only application review; no production changes.

## Conclusion

The calendar already uses a prebuilt date index. Its per-cell queries do not scan sessions. The meaningful problems are full-history loading, rebuilding the index after List/Calendar remounts and complete repository snapshots, and unnecessary rendering around selected-day changes. Month navigation itself is bounded and already cached appropriately.

The existing index type is `WorkoutDateIndex`. Introducing a second index to eliminate supposed per-cell scans would duplicate an optimization that is already present.

## Current execution costs

Let N be all sessions, S all embedded sets, D distinct workout days, R the consecutive-day streak, and K sessions on the selected day. Hash lookups are expected O(1).

- **First history load:** the unbounded watcher materializes N sessions and their S embedded sets. The history view defaults to List; the calendar index is not built until Calendar is selected.
- **First calendar mount:** one pass over N sessions groups dates. Additional passes over D dates create read-only wrappers, a day set, and month counts. Streak calculation walks R days. Time O(N + D + R); auxiliary storage O(N + D), principally references to existing session objects rather than copied set payloads.
- **Month navigation:** creates 28, 35, or 42 grid positions, looks up one month count, and performs at most 31 date lookups. No session traversal and no repository query.
- **Day selection:** one date lookup retrieves the pre-grouped K sessions. The selection-dependent widget subtree rebuilds, including the grid, metric strip, heading, and day list.
- **New session-list instance:** rebuilds the complete index, even if only one session changed or none of its calendar-relevant fields changed.
- **List/Calendar switching:** the installed non-expanding FTabs renders only its selected child. Returning from List mounts a new calendar and rebuilds its index from N sessions.

Evidence: `tracker/lib/ui/history/widgets/calendar/calendar_grid.dart:11–50`; `tracker/lib/ui/history/widgets/calendar/history_calendar.dart:40–99,148–177`; `tracker/lib/ui/history/widgets/history_page.dart:35,89–104`. Installed dependency: `~/.pub-cache/hosted/pub.dev/forui-0.26.0/lib/src/widgets/tabs/tabs.dart:124,216–226`.

## Findings

### 1. High: a one-month calendar receives complete lifetime workout payloads

**Where:** `tracker/lib/ui/history/widgets/history_page.dart:35`; `tracker/lib/data/repositories/workout_session_repository.dart:75–76`; `tracker/lib/domain/models/workout_session.dart:29`.

**What is unoptimized:** `watchAll()` supplies all sessions, including every embedded set, regardless of the visible month.

**Why:** The calendar receives persistence objects suitable for full workout details instead of compact calendar presentation data. Dots and month counts only require dates; selected-day rows require IDs, titles, counts, and optional gym references.

**Impact:** Read/deserialization cost grows with N + S. A calendar showing a few workouts can retain years of set payloads. Updates repeat materialization before the index does any work.

**Recommended fix:** Separate a compact all-history date/count index from selected-month/day summary data. Fetch full session details by ID when opening a workout. First measure whether projecting dates and summaries suffices; additive persisted summaries are an option, not a mandatory schema migration. Preserve streak access to dates outside the displayed month.

**Important distinction:** Adding an index alone does not optimize the current unfiltered `watchAll()` path: it still asks for every object. Timestamp indexes help only after introducing scoped queries. Existing date methods use filters and lack timestamp indexes; they are not currently called by calendar navigation.

### 2. Medium: switching List/Calendar discards the index and navigation state

**Where:** `tracker/lib/ui/history/widgets/history_page.dart:90–104`; `tracker/lib/ui/history/widgets/calendar/history_calendar.dart:40–51`; installed Forui `tabs.dart:216–226`.

**What is unoptimized:** The default `expands: false` tab body inserts only `children[index].child`. Switching from Calendar to List replaces a `HistoryCalendar` subtree with a `ListView` subtree. Switching back mounts a new calendar.

**Why:** The index, displayed month, and selected date all belong to the disposable calendar widget state.

**Impact:** Each return to Calendar repeats O(N + D + R) index construction even when data did not change. The month and selection reset to today, requiring repeated navigation if the user was inspecting an older month.

**Recommended fix:** Lift the revisioned index and selected month/day into the retained history state or a calendar view model. Supply that presentation state to the calendar. Prefer this over retaining both complete List and Calendar trees with an `IndexedStack`, which can preserve expensive list layout and memory. A key alone does not keep a removed subtree alive.

**Verification:** Use a counted input list: first Calendar mount reads N entries; a month change reads zero more; returning to Calendar should read zero more if the repository revision is unchanged. Assert the displayed month and selection survive the switch.

### 3. Medium: every replacement snapshot rebuilds the entire date index

**Where:** `tracker/lib/ui/history/widgets/calendar/history_calendar.dart:55–62`; `tracker/lib/ui/history/widgets/calendar/calendar_grid.dart:11–36`.

**What is unoptimized:** Invalidation uses list identity, not calendar-relevant changes. A fresh list causes full regrouping, even if one workout's weights changed but its date did not.

**Why:** The widget cannot distinguish date changes, row-label/count changes, and changes relevant only to session details.

**Impact:** O(N + D + R) main-isolate processing and new map/list/set wrappers per delivered replacement snapshot. An unrelated change can rebuild the visible month's derived state.

**Recommended fix:** Start with compact calendar projections and a reliable repository revision. If profiling still shows costly frequent updates, apply ID-based deltas to day buckets and month counts. When moving/deleting a workout, adjust both affected dates and change month workout-day counts only when a day changes between empty and nonempty. Do not substitute `sessions.length` as the revision: edits can preserve count.

**Limit:** A diff computed by scanning every incoming full list remains O(N); it may reduce allocations but does not remove the full-read bottleneck. Incremental state needs a trustworthy change source or cheaper projections.

### 4. Medium: offstage history still processes repository updates

**Where:** `tracker/lib/routing/home_page.dart:44–57`; `tracker/lib/ui/history/widgets/history_page.dart:28–55`.

**What is unoptimized:** The shell retains visited tabs under `Offstage`. History keeps its stream attached and does not use `TabVisibilityScope` to detach it.

**Why:** Offstage prevents painting, not stream delivery or state updates.

**Impact:** A new workout can cause full-history materialization and hidden history rebuilding. If Calendar is the selected history subtab, its index also rebuilds despite being invisible.

**Recommended fix:** Suspend the history subscription when its top-level tab is inactive, retaining compact presentation state. Resubscribe and refresh on activation. Decide separately whether covering the page with session details should also suspend updates. Do not merely pause a subscription if that would buffer every missed event. `TickerMode` does not stop queries.

### 5. Low normally, medium for large day lists: selected-day rows are not effectively lazy

**Where:** `tracker/lib/ui/history/widgets/calendar/history_calendar.dart:121–123,189–238`.

**What is unoptimized:** The selected day's `ListView.builder` is shrink-wrapped and non-scrolling inside a `SingleChildScrollView`. In the app it also sits below History's outer scroll view and sliver adapter.

**Why:** The inner list receives content-sized vertical layout rather than a bounded viewport. A builder constructor alone does not provide effective virtualization in this arrangement.

**Impact:** Layout and mounted row count grow with K rather than visible rows. Normal one-to-three-workout days are cheap; imported, duplicated, or stress-test histories expose the problem.

**Recommended fix:** Use one clear scroll owner. Put the calendar header/grid in a sliver adapter and selected-day rows in a lazy sliver list, with tab controls outside that content. Alternatively give the calendar a genuinely bounded viewport. Do not virtualize a 42-cell month grid merely because it uses `shrinkWrap`; the unbounded day-session list is the scaling concern.

### 6. Low: selecting a day rebuilds more than the changed selection

**Where:** `tracker/lib/ui/history/widgets/calendar/history_calendar.dart:148–177,281–313`.

**What is unoptimized:** The notifier builder recreates the grid, both metrics, selected-day heading, and list. Month workout-day count and streak do not depend on the selection.

**Why:** Selection-independent metrics sit inside the selection-dependent subtree; every date cell receives a newly evaluated selection flag through a rebuilt grid.

**Impact:** Bounded widget construction on each new selected date. The two changed selection indicators do not require month metrics to rebuild. This is smaller than full-history loading and remounting.

**Recommended fix:** Move the metric strip outside the selection listener or pass it as an invariant builder child. Consider per-cell selection listeners only if rebuild profiling justifies added complexity; 42 listeners are not automatically better than rebuilding 42 simple cells. Repeatedly selecting the same date is already suppressed by `ValueNotifier` equality.

### 7. Test gap: the “bounded internal day list” test does not establish boundedness

**Where:** `tracker/test/ui/history/history_test.dart:17–33`; `tracker/test/ui/history/calendar_test.dart:10–89`.

**What is unoptimized:** There is no regression guard for actual history-scaling or mounted-row costs. The named bounded-list test only checks that a ListView and one label exist for eight sessions.

**Why:** It does not check a finite viewport, offscreen row construction, source-list reads, frame cost, or repository query scope.

**Impact:** A complete eager list passes. Existing tests can remain green while tab switches rebuild every date index or a data update reloads all sets.

**Recommended fix:** Add deterministic operation-count and lifecycle tests before timing thresholds: zero source reads for month/day navigation, retained index across subtab switching, bounded mounted rows with 200 same-day sessions, and correct invalidation for date/title/count changes. Use profile-device benchmarks for frame budgets rather than flaky host-test stopwatch assertions.

## Correctness boundaries for optimization

These are not performance findings, but a cache or query change must address them deliberately.

- **Streak can become stale at midnight.** The index calculates streak once and the widget updates it only on mount or session-list replacement. Navigating months does not advance its clock. With no repository event after midnight, the displayed streak can be outdated. Separate time-dependent streak invalidation from data-dependent date indexing; inject a date/clock and refresh on date rollover or resume.
- **Duration subtraction is not calendar-day subtraction across DST.** `_currentStreak` subtracts 24 hours from local midnight (`calendar_grid.dart:82–88`). Across a DST transition, that can produce 23:00 or 01:00 rather than a date-key midnight. Use calendar-date arithmetic and test in a DST-observing timezone. `getForDate()` also calculates its upper bound with a 24-hour duration; do not reuse that boundary unchanged for a month/day query refactor.
- **UTC inputs are not explicitly converted to local dates.** `WorkoutDateIndex` reads year/month/day directly from `session.startTime`. Current local-time persistence may hide this, but UTC imports can land in a different local calendar day. Define the intended policy and apply `toLocal()` if local-day grouping is the contract.
- **List identity assumes immutable snapshots.** Mutating a session date while reusing the same list skips index invalidation. Read-only map/list wrappers also do not make the referenced `WorkoutSession` objects immutable. Either require immutable snapshots or own explicit revisions.
- **Streak semantics need a precise contract.** Implementation counts a streak ending today, or yesterday when today has no workout. It does not jump back to an arbitrary last historical workout, despite the comment's broader wording. Preserve the intended rule in tests.

## What is already optimized

- `sessionsOn()` is a map lookup, not `.where()` over N sessions.
- `monthWorkoutDays()` uses precomputed month counts.
- Month navigation does not reconstruct `WorkoutDateIndex`.
- `_daysWithWorkouts` caches membership for cell rendering.
- Grid construction is at most 42 entries; visible date membership requires at most 31 lookups.
- Day selection does not rebuild the index or trigger a database query.
- There is no all-month pre-rendering, multi-year grid allocation, or per-cell database call in this code.
- The notifier is disposed. No controller leak was established.
- Notifier updates inside month `setState` do not prove two completed frames; Flutter can coalesce dirty-element work.

## Verification status

Source and installed dependency behavior were inspected. A disposable benchmark outside the repository (`~/.claude/jobs/d0818fb7/tmp/calendar_audit_test.dart`) then ran successfully; host-widget-test timings, single-run, debug mode, no device/frame profiling:

- Index construction median: 1,000 sessions ≈ 1.2 ms; 10,000 ≈ 5.7 ms; 100,000 ≈ 76 ms. Cost scales with N; month/day lookups performed zero source-list reads after indexing.
- Counted source list: first calendar mount read 1,000 entries; month navigation added 0; switching List→Calendar→Calendar re-read all 1,000 (full remount).
- With 200 same-day sessions, 200 session labels were mounted — the selected-day list is not effectively bounded.

Existing repository tests also passed: `test/ui/history/calendar_test.dart` + `test/ui/history/history_test.dart`, 11 tests. These existing tests did not cover the measured scaling, remount, or bounded-row behaviors; finding 7 stands. Timings support relative comparisons only, not device-frame claims.

Recommended order: preserve index/navigation state across subtab switches; narrow the data loaded and watched; suspend hidden subscriptions; establish one lazy scrolling viewport; then trim selection rebuilds if profiling shows value. Keep the existing O(1) date lookup rather than replacing it.
