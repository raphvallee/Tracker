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

    await tester.enterText(find.widgetWithText(FTextField, 'Split name'), '');
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(emptyError), findsOneWidget);
  });
}
