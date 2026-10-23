# Refining the app

Verified against the codebase on 2026-10-22. Completed items have been removed; only unfinished refinements remain.

## Workout

- [ ] (in progress) Make "Start workout" button either before or after the split list. Configurable in settings (Before/After/Delete). **Progress:** the setting model survives (`FreeStartPlacement { before, after, disabled }`, `SettingsState.freeStartPlacement`, `SettingsCubit.setFreeStartPlacement`), but nothing reads it: Settings has no placement control, no page renders the button before/after a split list, and `BuildStartWorkoutButton` in `editor_page.dart` is unused. The feature was implemented once and lost when the workout/editor pages were split.

## Features Refine

### Inputs

- [ ] (in progress) Input validation on every input. "Cannot be empty", "Must be greater than X". Error indicators. **Progress:** almost all forms validate with inline errors (split/day/gym/session names, weight/reps, settings defaults, exercise name via `FTextFormField`). Remaining gaps: the feed graph editor's Title field shows no error, it only disables Save while empty, and the exercise form reports a missing target muscle with a toast rather than an inline error.
