import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import '../../testing/test_helpers.dart';

void main() {
  testWidgets(
    'second system back while the discard dialog is up is swallowed',
    (tester) async {
      final exitRequests = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') exitRequests.add(call);
          return null;
        },
      );

      await pumpApp(tester);

      final navBar = tester.widget<FBottomNavigationBar>(
        find.byType(FBottomNavigationBar),
      );

      navBar.onChange!(3);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Split'));
      await tester.pumpAndSettle();
      expect(find.text('Split name'), findsOneWidget);

      // Make the split editor dirty so its PopScope guards the back press.
      await tester.enterText(find.byType(FTextField).first, 'Push day');
      await tester.pump();

      // First back press: the split editor intercepts and shows the discard
      // confirmation dialog.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Split name'), findsOneWidget);
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(exitRequests, isEmpty);

      // Second back press while the dialog is up: must be swallowed instead
      // of dismissing the pending dialog or falling through to
      // SystemNavigator.pop() (which would kill the whole app).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        exitRequests,
        isEmpty,
        reason: 'a pending discard dialog must swallow extra back presses',
      );
      expect(
        find.byType(FBottomNavigationBar),
        findsOneWidget,
        reason: 'the app must survive the second back press',
      );
      expect(
        find.text('Discard changes?'),
        findsOneWidget,
        reason: 'the pending dialog must stay up',
      );
      expect(
        find.text('Split name'),
        findsOneWidget,
        reason: 'the editor must stay open until the dialog is answered',
      );
    },
  );

  testWidgets(
    'after the dialog is answered, back at the tab root exits again',
    (tester) async {
      final exitRequests = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') exitRequests.add(call);
          return null;
        },
      );

      await pumpApp(tester);

      final navBar = tester.widget<FBottomNavigationBar>(
        find.byType(FBottomNavigationBar),
      );

      navBar.onChange!(3);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Split'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(FTextField).first, 'Push day');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      // The guard must not block taps inside the dialog: discarding pops the
      // editor back to the tab root.
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Split name'), findsNothing);

      // Back at the tab root, a back press exits as before.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(exitRequests.length, 1, reason: 'back at the root must exit');
      expect(find.byType(FBottomNavigationBar), findsOneWidget);
    },
  );
}
