import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/workout/widgets/new_split_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
  const emptyError = 'Cannot be empty';

  testWidgets('shows no name error when a new split opens', (tester) async {
    await pumpAppPage(tester, const SplitEditorPage());

    expect(find.text('New Split'), findsOneWidget);
    expect(find.text(emptyError), findsNothing);
  });

  testWidgets('Save with an empty name shows the name error', (tester) async {
    await pumpAppPage(tester, const SplitEditorPage());

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text(emptyError), findsOneWidget);
    expect(find.text('New Split'), findsOneWidget);
  });

  testWidgets('typing a name clears the error', (tester) async {
    await pumpAppPage(tester, const SplitEditorPage());
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(FTextField, 'Split name'),
      'Upper Body',
    );
    await tester.pumpAndSettle();

    expect(find.text(emptyError), findsNothing);
  });

  testWidgets('clearing the name again waits for the next Save', (
    tester,
  ) async {
    await pumpAppPage(tester, const SplitEditorPage());
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(FTextField, 'Split name'),
      'Upper Body',
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(FTextField, 'Split name'), '');
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsOneWidget);
  });
}
