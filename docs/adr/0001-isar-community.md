# ADR 0001 - Stay on isar_community through v1.0

- **Status:** Accepted (decision made 2026-09-02, recorded 2026-09-03)
- **Context phase:** PRODUCTION_READINESS.md Phase 1

## Context

Tracker persists all user data locally in Isar (offline first, no cloud). The
dependency is the community fork **`isar_community ^3.3.2`** of the stalled
upstream `isar` project. Upstream is effectively unmaintained; the fork is
community-maintained, which is a long-term liability:

- no guarantee of timely security fixes,
- no guarantee of alignment with store requirements (e.g. Android 16 KB
  page-size alignment of `libisar.so` must be verified separately, Phase 2),
- potential breakage against future Flutter versions.

## Decision

**Stay on `isar_community` for v1.0 (iOS + Android). No migration before 1.0.**

- Exact versions are pinned for CI via the committed `tracker/pubspec.lock`.
- Automated watch (dependabot/renovate) is deferred; for now the fork's
  releases page is checked manually when touching persistence, and before any
  store submission. A dependabot config for `tracker/` is an approved-but-not-
  scheduled Phase 1 nice-to-have.
- ~~The `dependency_overrides` pin `path_provider_android <2.3.0` (works around a
  `jni` 1.0.x compile break) is re-verified on every minor bump of
  `path_provider_android`.~~ Retired 2026-10-19: `jni 1.1.0` fixed the compile
  break (dart-lang/native#3235) and the pin was removed.

## Escape hatch (if the fork dies or an unpatched security issue appears)

Migration path to `drift`/SQLite: all persistence access already flows through
the repository layer (`TrackerRepository` + per-entity repositories in
`tracker/lib/data/repositories/`); pages and cubits never touch Isar directly.
Migration therefore means (1) add the Phase 2 export feature as canonical JSON
of all collections, (2) implement a `drift` schema mirroring
`docs/ISAR_SCHEMA.md`, (3) swap repository implementations to drift behind the
unchanged facade, (4) on first launch, import the Isar export into drift, then
rename the old `.isar` files aside (never silently delete). The schema
reference page doubles as the drift schema source of truth.

## Revisit triggers

- The fork stops accepting fixes and a needed fix (security or store
  compliance) appears.
- The fork's native binaries cannot satisfy a Play requirement (e.g. 16 KB
  page-size alignment) before the deadline.
- Upstream Isar revives with a maintained release that supersedes the fork.

## Consequences

- No schema/tooling migration work before 1.0 (Phase 2 explicitly defers it).
- The freeze rules in `docs/ISAR_SCHEMA.md` keep the eventual migration surface
  small and documented.
