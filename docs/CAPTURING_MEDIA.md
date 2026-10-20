# Capturing screenshots and videos of the app

Fixed procedure for agents. Do not research capture methods - follow this
document. Two tiers cover every need; pick from the table and execute.

| Need | Tier | How |
|---|---|---|
| Static screenshot of any page/dialog/sheet | 1 | `pwsh run-visual-tests.ps1` |
| Static screenshot of a page NOT in the sweep | 1 | add one `visit()` line, re-run sweep |
| Screenshot of a state that needs interaction (typed text, dialog open, mid-flow) | 2 | integration test + `capture-app-media.ps1 -Mode screenshot -Test ...` |
| Video of a flow, agent-driven | 2 | integration test + `capture-app-media.ps1 -Mode video -Test ...` |
| Video of a flow, human-driven (agent records while the user demos) | 2 | `capture-app-media.ps1 -Mode video -Seconds 60` |

Always verify the result before delivering: PNGs are images, so Read the file
directly; for videos, extract frames (`ffmpeg -i video.mp4 -vf fps=1 frame%d.png`)
and Read 2-3 of them.

Output locations (all gitignored under `tracker/build/`):

- Tier 1: `tracker/build/test_screenshots/*.png` + `manifest.json`
- Tier 2: `tracker/build/captures/*` (logs land here too in `-Test` mode)

---

## Tier 1: widget-test captures (default for page screenshots)

Deterministic, no window or device needed, runs anywhere Flutter runs.
`pwsh run-visual-tests.ps1` renders every app page, dialog and sheet at
320x568, 800x600 and 1280x720 with real fonts, writing ~66 PNGs plus a
`manifest.json` (file -> page/size mapping) to `tracker/build/test_screenshots/`.

For a screenshot of one specific page:

1. Add one line to `tracker/test/ui/visual_screenshots_test.dart` in the
   pushed-pages block (after line `await visit('Settings page', ...)`):
   `await visit('My page label', const MyPage());`
   Pass `dataReady: () => tester.any(find.text('...'))` when the page loads
   content async from Isar, or the capture shows the loading state.
2. Run `pwsh run-visual-tests.ps1`.
3. Read the PNG for your label at the size(s) you need; keep the `visit()`
   line if the page belongs in the permanent sweep (it also gains overflow
   regression coverage), otherwise remove it.

Notes that come from hard-won experience (do not re-derive):

- The sweep runs under `flutter test` fake-async: never add `pumpAndSettle`
  (loading spinners animate forever); use the existing `settle()`/
  `settleForData()` helpers.
- Capture must happen before `navigator.pop()` - afterwards the boundary
  shows the base page again.
- Files named `*_FAIL*.png` are auto-captures of a screen that threw a render
  exception; `SCREENSHOT-SWEEP:` lines in the test output map captures to pages.
- Add `-NoClean` to keep previous captures across runs.

## Tier 2: real-app window captures (screenshots of interactions, all videos)

The app runs as a real Windows desktop window titled `Tracker` - set at
runtime by `lib/main.dart` (`setWindowTitle` via the window_size plugin);
`windows/runner/main.cpp` only holds the pre-Dart default `tracker`. ffmpeg's
gdigrab captures that window by title; the repo-root helper script wraps
everything. Requirements: `ffmpeg` on PATH (present on this machine), the
window visible on screen (never minimized), only one app instance running,
and only one capture script instance at a time (the script enforces this
with a mutex - concurrent runs race over the app window and corrupt each
other's capture).

### Screenshot of a state that needs interaction

Write a tiny integration test that drives the app to the state, then let the
script capture when the window is up. `flutter test -d windows` runs a real
app window - real async, so `pumpAndSettle` works normally here (unlike the
widget-test sweep).

1. Create `tracker/integration_test/capture_<feature>_test.dart`. Copy
   `tracker/integration_test/capture_smoke_test.dart` (a working, verified
   example) and change only the "drive the UI" section:

```dart
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/seed.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:window_size/window_size.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/test_helpers.dart';

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Fully live frames so what the window shows matches what the test pumps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(initIsarCore);

  testWidgets('capture: <describe the state>', (tester) async {
    // This test bypasses main() (throwaway data below), so it must set the
    // desktop window title itself: capture-app-media.ps1 locates the window
    // by the title 'Tracker' (the pre-Dart caption is lowercase 'tracker'
    // from windows/runner/main.cpp). Requires
    // import 'package:window_size/window_size.dart'; and 'dart:io'.
    if (Platform.isWindows) setWindowTitle('Tracker');

    // Throwaway data: in-memory HydratedBloc storage + temp Isar, so the
    // capture never touches the user's real app data.
    HydratedBloc.storage = InMemoryStorage();
    final isar = await openTestIsar(
      [
        ExerciseSchema,
        GymSchema,
        WorkoutSplitSchema,
        WorkoutSessionSchema,
      ],
      name: 'isar_capture_<feature>',
    );
    final repo = TrackerRepository(isar);
    await seedExercisesIfNeeded(repo);
    final cubit = WorkoutCubit(repository: repo);

    await tester.pumpWidget(
      RepositoryScope(
        repository: repo,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<WorkoutCubit>.value(value: cubit),
            BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
          ],
          child: const MyApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Drive the UI to the state you want, e.g.:
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // The script captures the window externally. Keep the window on screen
    // until it signals "capture finished" via build/captures/.capture-done
    // (the script deletes that file at the start of every run). Cap the wait
    // so a bare `flutter test` run still terminates.
    const doneFile = 'build/captures/.capture-done';
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!File(doneFile).existsSync() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  });
}
```

The handshake matters: the app window closes the moment the test exits, and a
fixed `Future.delayed` at the end races the script's settle delay - the first
run of this procedure lost the capture exactly that way. The sentinel file
removes the race; keep those lines verbatim in every capture test (add
`import 'dart:io';` at the top).

CI safety: capture tests live in `tracker/integration_test/`, which bare
`flutter test` (what every CI workflow runs) never scans - only `test/` is
discovered. They run exclusively via this script's explicit
`flutter test -d windows <file>` invocation. They must still stay
analyze-clean (`flutter analyze` covers the whole package).

2. Run (the script waits for the window, settles, captures, reports the test
   result and the file path):

```
pwsh ./capture-app-media.ps1 -Mode screenshot -Test tracker/integration_test/capture_calendar_test.dart
```

### Video of an agent-driven flow

Same as above, but `-Mode video`; recording starts the moment the window
appears and is bounded by `-Seconds` (default 10). The script signals the
test to end after recording stops:

```
pwsh ./capture-app-media.ps1 -Mode video -Seconds 25 -Test tracker/integration_test/capture_workout_flow_test.dart
```

Make the test drive the whole flow with `tester.tap`/`enterText`/`pumpAndSettle`
in order, pausing 1-2 s between steps (`await Future<void>.delayed(...)`) so
the video is watchable. Set `-Seconds` to roughly the flow length; if the
test fails early the window closes and the recording simply ends there. The
script records to a Matroska intermediate and remuxes to MP4, so the file
survives an abrupt stop.

### Video while a human demos (or of an already-running app)

```
cd tracker && flutter run -d windows      # or: pwsh ./capture-app-media.ps1 -Mode video -RunApp -Seconds 60
pwsh ./capture-app-media.ps1 -Mode video -Seconds 60
```

The user interacts with the app while it records. `-Seconds` caps the length;
ffmpeg stops by itself if the window closes earlier (the file stays valid -
the script records to a Matroska intermediate and remuxes at the end).

### Troubleshooting

- `No window titled 'Tracker' found` - the build is still running (first
  Windows build takes minutes; `-WindowTimeoutSec` default 600 covers it),
  the title changed (check `windows/runner/main.cpp`), or more than one
  instance/app window matches.
- Black or stale frames - the window is minimized or fully occluded; gdigrab
  needs it visible on the desktop.
- Captured size looks wrong / off-by-titlebar - gdigrab grabs the window
  including its frame in physical pixels; for pixel-perfect client-area
  shots prefer Tier 1.
- Test failed but you still want the video - the file is saved regardless;
  the script prints the test logs under `tracker/build/captures/`.
- Script times out waiting for the window while the test passes - the test
  bypassed `main()`, so the window kept the pre-Dart title `tracker`; call
  `setWindowTitle('Tracker')` at the top of the test body as the template does.
- Empty or failed recording - read `tracker/build/captures/ffmpeg_<stamp>.err.log`
  (the script keeps ffmpeg's own log). Known trap already handled: window
  sizes with odd pixel counts break `yuv420p`, so the script scales to even
  dimensions; if you run ffmpeg by hand, add
  `-vf scale=trunc(iw/2)*2:trunc(ih/2)*2`.
