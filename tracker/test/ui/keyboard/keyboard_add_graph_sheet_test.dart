// Keyboard reveal check - add-graph-sheet. One Isar-backed case per file
// (see keyboard_scenarios.dart).
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/test_helpers.dart';
import 'keyboard_scenarios.dart';

void main() {
  setUpAll(initIsarCore);
  testWidgets('add-graph-sheet @320x568-min', (tester) async {
    await runKeyboardScenario(tester, 'add-graph-sheet', addGraphSheetScenario);
  });
}
