import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';

const double _keyboardHeight = 300;
const ValueKey _fieldKey = ValueKey('subject-field');

/// Fakes the on-screen keyboard. [FakeViewPadding] is in physical pixels;
/// the app reads logical pixels (physical / devicePixelRatio).
Future<void> _openKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = FakeViewPadding(
    bottom: _keyboardHeight * tester.view.devicePixelRatio,
  );
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpAndSettle();
}

Widget _page({required bool keyboardAwareReveal}) => MaterialApp(
  builder: (context, child) => FTheme(
    data: keyboardAwareReveal
        ? keyboardAwareFieldReveal(
            FTheme.neutral.light.touch,
            MediaQuery.viewInsetsOf(context).bottom,
          )
        : FTheme.neutral.light.touch,
    child: child!,
  ),
  home: Scaffold(
    resizeToAvoidBottomInset: false,
    body: Builder(
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: keyboardClearanceOf(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 900),
            FTextField(
              key: _fieldKey,
              control: FTextFieldControl.managed(
                controller: TextEditingController(),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _pumpScrolledBehindKeyboard(
  WidgetTester tester, {
  required bool keyboardAwareReveal,
}) async {
  await tester.pumpWidget(_page(keyboardAwareReveal: keyboardAwareReveal));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
  await tester.pumpAndSettle();
  await _openKeyboard(tester);
}

void main() {
  testWidgets('a focused field scrolls above the keyboard', (tester) async {
    await _pumpScrolledBehindKeyboard(tester, keyboardAwareReveal: true);

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final before = tester.getBottomRight(find.byKey(_fieldKey)).dy;
    expect(
      before,
      greaterThan(screenHeight - _keyboardHeight),
      reason: 'precondition: the field sits behind the keyboard',
    );

    await tester.tap(find.byKey(_fieldKey));
    await tester.pumpAndSettle();

    final after = tester.getBottomRight(find.byKey(_fieldKey)).dy;
    expect(
      after,
      lessThan(screenHeight - _keyboardHeight),
      reason: 'the focused field must end up fully visible above the keyboard',
    );
    expect(
      after,
      lessThanOrEqualTo(screenHeight - _keyboardHeight - 24),
      reason: 'the focused field must keep a visible gap above the keyboard',
    );
  });
}
