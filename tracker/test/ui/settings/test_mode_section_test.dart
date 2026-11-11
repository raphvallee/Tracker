import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/ui/core/ui/test_mode_scope.dart';
import 'package:tracker/ui/settings/widgets/settings_page.dart';

import '../../../testing/test_helpers.dart';

Widget _settings({required bool enabled, required List<Object> calls}) =>
    TestModeScope(
      enabled: enabled,
      busy: false,
      setEnabled: (on) async => calls.add(on),
      reset: () async => calls.add('reset'),
      child: const SettingsPage(),
    );

final _scroll = find
    .descendant(
      of: find.byType(SettingsPage),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets('settings turn test mode on from the Testing section', (
    tester,
  ) async {
    final calls = <Object>[];
    await pumpAppPage(tester, _settings(enabled: false, calls: calls));
    await tester.scrollUntilVisible(
      find.text('Test mode'),
      200,
      scrollable: _scroll,
    );
    expect(find.text('Testing'), findsOneWidget);
    expect(find.text('Reset sample data'), findsNothing);

    await tester.tap(find.text('Test mode'));
    await tester.pumpAndSettle();
    expect(calls, [true]);
  });

  testWidgets('in test mode, settings reset the sample data or turn it off', (
    tester,
  ) async {
    final calls = <Object>[];
    await pumpAppPage(tester, _settings(enabled: true, calls: calls));
    await tester.scrollUntilVisible(
      find.text('Reset sample data'),
      200,
      scrollable: _scroll,
    );

    await tester.tap(find.text('Reset sample data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test mode'));
    await tester.pumpAndSettle();
    expect(calls, ['reset', false]);
  });

  testWidgets('without test mode wired in, there is no Testing section', (
    tester,
  ) async {
    await pumpAppPage(tester, const SettingsPage());
    expect(find.text('Testing'), findsNothing);
  });
}
