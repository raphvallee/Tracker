// App-shell integration tests: the bottom-nav shell.
//
// MyApp's root build depends on WorkoutCubit, a HydratedCubit, so storage must
// be initialized before pumping (mirroring main()). We use an in-memory Storage
// rather than HydratedStorage's Hive/file storage: the real implementation does
// file I/O and keeps a static lock that cannot complete across the test's
// fake-async zone once a cubit has been pumped, so it can't survive repeated
// pumps in one file.
//
// Note: the shell uses Offstage-Stacked nested Navigators, so every tab's page
// is built (and can throw) even when not selected - the boot test therefore
// also proves every tab resolves to a buildable screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../testing/fakes/in_memory_storage.dart';
import '../testing/test_helpers.dart';

void main() {
  setUp(() {
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets(
    'boots into the five-tab shell, every screen builds, and tabs switch',
    (WidgetTester tester) async {
      final cubit = await pumpApp(tester);

      // The app's root shell is a bottom navigation bar with five pluggable
      // tab destinations (Feed, History, Workout, Editor, Exercises).
      expect(find.byType(FBottomNavigationBar), findsOneWidget);
      expect(find.byType(FBottomNavigationBarItem), findsNWidgets(5));
      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('CurrentWorkout'), findsNothing);

      // The initially selected tab (Feed) rendered without crashing. Note: the
      // other four tabs also build (Offstage), so this also proves every tab
      // resolves to a buildable screen.
      expect(find.text('Progression'), findsOneWidget);

      expect(find.text('Go to Current Workout'), findsNothing);
      cubit.startWorkout();
      expect(cubit.state.isInProgress, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Go to Current Workout'), findsOneWidget);

      // Drive tab switches through onChange rather than hit-testing, which is
      // brittle under the Offstage navigators.
      for (final index in {2, 3, 4, 1, 0}) {
        tester
            .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
            .onChange!(index);
        await tester.pump();
        expect(
          tester
              .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
              .index,
          index,
          reason: 'selecting index $index did not update the nav bar',
        );
      }
    },
  );

  testWidgets('tapping outside a text field clears its focus', (
    WidgetTester tester,
  ) async {
    // The field sits 200 logical pixels below the top edge, so the tap at the
    // top-left lands on empty page background, well outside the field.
    await pumpAppPage(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(top: 200, left: 16),
          child: TextField(
            focusNode: _probeFocusNode,
            controller: TextEditingController(),
          ),
        ),
      ),
    );

    expect(_probeFocusNode.hasFocus, isFalse);
    await tester.showKeyboard(find.byType(TextField));
    expect(_probeFocusNode.hasFocus, isTrue);

    // Flutter's built-in tap-outside handling deliberately does not unfocus
    // on touch events (except web), so this only passes with the app-wide
    // GestureDetector in MyApp's builder.
    await tester.tapAt(const Offset(20, 40));
    await tester.pump();

    expect(_probeFocusNode.hasFocus, isFalse);
  });
}

final FocusNode _probeFocusNode = FocusNode(debugLabel: 'probe-field');
