// New split editor: the split-name error is validated only on Save, never
// while the page is idle, and typing clears it. No Isar here - an empty name
// is rejected before the repository is touched.

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/workout/widgets/new_split_page.dart';

import '../../../testing/test_helpers.dart';

void main() {
  const emptyError = 'Cannot be empty';

  testWidgets('the name error shows only on Save and typing clears it', (
    tester,
  ) async {
    await pumpAppPage(tester, const SplitEditorPage());
    expect(find.text('New Split'), findsOneWidget);
    expect(find.text(emptyError), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsOneWidget);
    expect(find.text('New Split'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(FTextField, 'Split name'),
      'Upper Body',
    );
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsNothing);

    // Clearing the name again waits for the next Save.
    await tester.enterText(find.widgetWithText(FTextField, 'Split name'), '');
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsOneWidget);
  });
}
