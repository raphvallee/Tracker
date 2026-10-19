import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import '../../testing/test_helpers.dart';

void main() {
  testWidgets(
    'system back pops the active tab subpage instead of exiting the app',
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

      navBar.onChange!(4);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(find.text('Name'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Name'), findsNothing);
      expect(
        find.text('No exercises in the library yet.'),
        findsOneWidget,
        reason: 'the app must not exit; the tab root remains',
      );
      expect(find.byType(FBottomNavigationBar), findsOneWidget);
      expect(
        exitRequests,
        isEmpty,
        reason: 'a poppable subpage must consume the back press',
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(exitRequests.length, 1, reason: 'back at the root must exit');
      expect(find.byType(FBottomNavigationBar), findsOneWidget);
    },
  );

  testWidgets(
    'tab round-trip with a subpage open leaves no back button on the tab root '
    'after the subpage is popped',
    (tester) async {
      await pumpApp(tester);

      final navBar = tester.widget<FBottomNavigationBar>(
        find.byType(FBottomNavigationBar),
      );

      navBar.onChange!(4);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(find.text('Name'), findsOneWidget);

      expect(find.byIcon(FLucideIcons.chevronLeft), findsOneWidget);

      await tester.pump();
      navBar.onChange!(4);
      await tester.pumpAndSettle();

      expect(
        find.byIcon(FLucideIcons.chevronLeft),
        findsOneWidget,
        reason: 'only the pushed subpage may show a back button',
      );

      await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
      await tester.pumpAndSettle();
      expect(find.text('Name'), findsNothing);

      expect(
        find.byIcon(FLucideIcons.chevronLeft),
        findsNothing,
        reason: 'tab root must not show a back button',
      );

      expect(
        find.text('No exercises in the library yet.'),
        findsOneWidget,
        reason: 'popping must never remove the tab root page',
      );
      expect(find.byType(FBottomNavigationBar), findsOneWidget);
    },
  );

  testWidgets(
    'theme flip while a subpage is open bakes no back button into the tab root',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Units'), findsOneWidget);
      expect(find.byIcon(FLucideIcons.chevronLeft), findsOneWidget);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      expect(
        find.byIcon(FLucideIcons.chevronLeft),
        findsOneWidget,
        reason: 'only the pushed subpage may show a back button',
      );

      await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
      await tester.pumpAndSettle();
      expect(find.text('Units'), findsNothing);

      expect(find.byIcon(FLucideIcons.chevronLeft), findsNothing);
      expect(
        find.text('Recent activity'),
        findsOneWidget,
        reason: 'popping must never remove the tab root page',
      );
    },
  );
}
