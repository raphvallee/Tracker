# Isar tests hang on the 4-vCPU CI runner

Read this before adding a widget or integration test that touches a real Isar
database. The failure only shows up on GitHub's `ubuntu-latest` runner, which
has 4 vCPUs. It passes on developer machines, which usually have 6 to 16 cores,
so it is easy to misdiagnose. Debugging it from the CI log alone took hours.

## Symptoms

- `flutter test` passes locally (Windows or macOS) but the `Dart / build` job
  fails on GitHub.
- The failing tests report `TimeoutException after 0:10:00.000000: Test timed
  out after 10 minutes` or `TimeoutException after 0:00:30.000000`.
- The timeout hits a test that does nothing unusual, and sometimes a *later*,
  simple repository test (one that only does `put` and `getById`) is the one
  reported as timing out.
- Removing an unrelated `print`, reordering tests, or adding `pumpAndSettle`
  does not help.

## Root cause

`libisar` (the native Isar core) runs a native worker pool sized to the number
of CPUs. On a 4-vCPU machine that pool has about 4 workers. Each Isar instance
opened in a process holds on to workers while it has open watchers or pending
IO. Inside one `flutter_tester` process, once several Isar-backed cases have
run, the pool is exhausted and the next Isar call never completes.

The result is not a crash. Native IO just stops returning, so the Dart future
never completes, and the test sits until the `test` package's timeout fires.
Because the stall is in native code, the stack trace points at the Dart line
that was waiting, which is usually an innocent `await` in the test or widget.

The same test file can pass on a 6-core laptop because its pool is larger.

The original occurrence is documented in commit `36405dd` ("Fix Test Suite
running on 4 vCPU failing"). It split the overflow sweep into one
`*_test.dart` file per window size, with the comment: "libisar's native worker
pool is sized to the CPU count (4 on the CI runner), and one process running 6
size cases in a row wedges native IO around the 5th case." See
`tracker/test/ui/overflow/layout_overflow_sweep.dart`.

## Rules

1. **One Isar-backed case per test file.** Flutter runs each `*_test.dart` file
   in its own process, and each process gets a fresh native pool. A file with
   several Isar-backed `testWidgets` or `test` cases is the failure pattern.
2. Widget-only tests that never open Isar can share a file. Only put the
   Isar-backed cases in their own files.
3. Put shared fixtures and helpers in `tracker/testing/`, not in a test file
   that another test imports. See `tracker/testing/session_edit_helpers.dart`.
4. Use `tester.runAsync` for Isar IO inside a `testWidgets` body. Real IO does
   not complete in the fake-async zone.
5. Do not rely on `pumpAndSettle` when a real Isar watcher is on screen. Use
   timed pumps (see `settleSessionFlow` in the same helper file).
6. Do not change `flutter test --concurrency` or the workflow's thread count to
   fix this. It is a per-process problem, and changing concurrency only moves
   the failure.

## Worked example: `session_edit_delete_test.dart` (PR 28)

The original file had five Isar-backed cases in one process: the saved-edit
widget test, the delete widget test, the repository round-trip, and the
`setUpAll` Isar init. On the 4-vCPU runner:

- The saved-edit test passed.
- The delete widget test hung for the full 10-minute test timeout.
- The repository round-trip test then timed out after 30 seconds, because the
  pool was already wedged by the earlier hang.

The reported failure was the repository test, which looked like a repository
bug. It was not. The delete test was the first to stall.

The fix was to split the file, as described in rule 1:

- `session_edit_delete_test.dart`: widget-only tests (no Isar)
- `session_edit_persist_test.dart`: saved-edit persistence
- `session_delete_persist_test.dart`: delete persistence
- `session_edit_delete_repo_test.dart`: repository round-trip

After the split, `act` with a 4-CPU container passed 130 tests.

## How to reproduce on Windows with `act`

Use the repo script `run-github-actions-locally.ps1` to install and start
Docker and `act`. The `act` options below are what reproduce the GitHub
runner:

```powershell
act pull_request -W .github/workflows/dart.yml -j build `
  -P ubuntu-latest=catthehacker/ubuntu:act-latest `
  --container-architecture linux/amd64 `
  --container-options "--cpus 4" `
  --bind
```

- `--container-options "--cpus 4"` matches the GitHub runner's CPU count. This
  is what makes the pool-wedge reproduce locally. Without it, the Linux
  container sees the host's CPU count and passes.
- `--bind` mounts the host folder directly. Without it, `act` copies the
  workspace without a usable `.git`, and the step "Ensure generated code is
  committed" fails with `fatal: not a git repository`. That is an `act`
  limitation, not a test failure.
- `catthehacker/ubuntu:act-latest` is the image that has the tools the Flutter
  action expects. The default `act` image does not.

### Run from a clean clone

`act` copies the working directory, so uncommitted changes count. Run it
from a fresh clone of the branch to avoid testing the wrong code.

Before you trust a result, confirm which commit was tested:

```powershell
git -C <clone> log --oneline -1
```

In this PR, an earlier `act` run reported success on the wrong commit because a
`git reset` failed silently and the old commit was still checked out. Always
check the commit first.

### Read the log, not the tail

`act` prints a final `Job failed` line that is easy to miss when piping through
`Select-Object -Last 3`. Look for `❌  Failure` and `Test timed out` in the full
log:

```powershell
Select-String -Path <log> -Pattern '❌|Test timed out|tests passed|tests failed'
```

## Debugging an Isar stall

- The `SWEEP:` and `SCREENSHOT:` markers in the visual sweep name the stage
  that stalled. Add similar markers when you write a new Isar-heavy flow.
- `TimeoutException after 0:10:00` means the test hung, not that it was slow.
  Don't raise the timeout. Find the case that opened Isar first.
- Check how many Isar instances the file opens. Each `openTestIsar` in one
  file counts toward the pool. Widget tests that open Isar and never close it
  (because close never completes in fake async) make the pool worse for later
  tests in the same process.
- Check for `print` or `debugPrint` left in production code. The CI log shows
  them, but they do not cause the stall.

## Checklist for a new Isar-backed test

- [ ] It is in its own `*_test.dart` file, unless it is widget-only.
- [ ] Its file has a comment pointing to this doc.
- [ ] Shared fixtures live in `tracker/testing/`.
- [ ] Isar IO inside `testWidgets` goes through `tester.runAsync`.
- [ ] It passes under `act` with `--container-options "--cpus 4"`, not only
      locally.
