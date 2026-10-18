# Isar schema reference (pre-1.0 freeze)

**Freeze rules (PRODUCTION_READINESS.md Phase 1):** until after the v1.0
release, schema changes are **additive only** - new fields and new enum values
appended at the end of an enum. **No field renames or deletions**: Isar
auto-migrates added fields, but renames lose data and deletions discard it.
After changing any `@collection`/`@embedded`/`@enumerated` annotation, run
`cd tracker && dart run build_runner build` and commit the regenerated
`*.g.dart` files (CI verifies both).

The database is a single Isar instance (`tracker/lib/data/services/db.dart`),
opened only by `main.dart`. Current schema (recreate this page whenever the
schema changes):

## Collections

### `Exercise` (`tracker/lib/domain/models/exercise.dart`)

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `Id` (autoIncrement) | |
| `title` | `String` | |
| `description` | `String?` | |
| `primaryMuscle` | `List<Muscle>` `@enumerated` | |
| `secondaryMuscle` | `List<Muscle>?` `@enumerated` | |
| `equipment` | `List<Equipment>` `@enumerated` | |
| `movementPattern` | `MovementPattern` `@enumerated` | non-nullable (Isar 3.1 generator requirement) |

### `Gym` (`tracker/lib/domain/models/gym.dart`)

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `Id` (autoIncrement) | |
| `name` | `String` | |
| `description` | `String?` | |
| `isPrimary` | `bool` | primary gym = baseline, multiplier 1.0 |
| `order` | `int` | |
| `multiplier` | `double` | weight-equivalence vs. primary gym |
| `perExerciseMultipliers` | `List<GymExerciseMultiplier>` | embedded rows |

### `WorkoutSession` (`tracker/lib/domain/models/workout_session.dart`)

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `Id` (autoIncrement) | |
| `title` | `String` | |
| `startTime` | `DateTime` | |
| `endTime` | `DateTime?` | |
| `gymId` | `int?` | foreign key by id, intentionally no `IsarLink` |
| `sets` | `List<WorkoutSet>` | embedded |

### `WorkoutSplit` (`tracker/lib/domain/models/workout_split.dart`)

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `Id` (autoIncrement) | |
| `title` | `String` | |
| `description` | `String` | |
| `splitDays` | `List<WorkoutSplitDay>` | embedded |
| `order` | `int` | |

## Embedded types

| Type | Fields |
| --- | --- |
| `WorkoutSet` | `exerciseId int`, `weight double`, `reps int`, `type SetType @enumerated`, `order int` |
| `WorkoutSplitDay` | `title String`, `description String`, `exercises List<ExerciseItem>`, `order int` |
| `ExerciseItem` | `exerciseId int`, `order int`, `sets List<PlannedSet>`, plus legacy `targetSets int?`, `targetReps int?`, `restSeconds int?` (no longer written by the editor) |
| `PlannedSet` | `order int`, `minReps int` (fixed reps), `maxReps int?` (null = fixed, non-null = range `minReps..maxReps`) |
| `GymExerciseMultiplier` | `exerciseId int`, `multiplier double` |

## Enums

- `Muscle` (16 values) / `MuscleGroup` (abdominals, arms, shoulders, back, legs, chest) - pure Dart mapping (`muscle.dart`), not stored directly
- `MovementPattern` - unspecified, push, pull, legs, core, fullBody
- `Equipment` - dumbbell, barbell, machine, bodyweight, cable
- `SetType` - warmup, working

`@enumerated` enum fields must stay non-nullable and models must not carry
computed getters (Isar 3.1 generator rejects both). Append new enum values at
the end only; never reorder or rename existing values.

## Indexes

None declared today beyond the implicit `id` primary keys. Phase 4 of
PRODUCTION_READINESS.md plans indexes for queried/watched fields (session
dates, `exerciseId`, gym id) once query paths are audited.

## Not in Isar (hydration JSON)

`WorkoutState` and `SettingsState` (HydratedBloc) serialize to JSON, not Isar.
Those payloads carry a `'v'` schema version; unknown versions fall back to
safe defaults instead of crashing (see the cubits in `lib/ui/*/view_models/`).
`WorkoutSplitTemplate` and `workoutSplitTemplates` are pure Dart seed
constants, never persisted.
