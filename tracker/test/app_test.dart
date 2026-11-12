// In-memory Storage, not HydratedStorage: the real implementation keeps a
// static lock that cannot complete across the test's fake-async zone once a
// cubit has been pumped, so it can't survive repeated pumps in one file.

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';

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

      expect(find.byType(FBottomNavigationBar), findsOneWidget);
      expect(find.byType(FBottomNavigationBarItem), findsNWidgets(5));
      expect(find.text('Workout'), findsOneWidget);

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

  testWidgets('builds the History tab offstage shortly after launch', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byType(HistoryPage), findsNothing);
    expect(find.byType(HistoryPage, skipOffstage: false), findsOneWidget);

    tester
        .widget<FBottomNavigationBar>(find.byType(FBottomNavigationBar))
        .onChange!(1);
    await tester.pump();
    expect(find.byType(HistoryPage), findsOneWidget);
  });

  testWidgets('tapping outside a text field clears its focus', (
    WidgetTester tester,
  ) async {
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
