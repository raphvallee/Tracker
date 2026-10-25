// Regression tests for the keyboard hiding a focused field (Refine.md,
// General #1). The shell Scaffolds do not resize for the on-screen keyboard
// (it overlays them), so Flutter's own caret reveal - which only scrolls
// until the caret clears the scrollable's bounds - leaves the field behind
// the keyboard unless the field's scroll padding includes the keyboard
// height. keyboardAwareFieldReveal (applied app-wide in MyApp's builder)
// grows that padding; these tests pump the same wiring in isolation.

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
    // Mirrors the shell Scaffolds: the keyboard overlays instead of resizing,
    // so scrollables must be able to scroll past it.
    resizeToAvoidBottomInset: false,
    body: Builder(
      builder: (context) => SingleChildScrollView(
        // Same contract as real pages: the bottom padding grows by the
        // keyboard height plus the reveal gap (keyboardClearanceOf) so the
        // focused field has the scroll room its reveal needs above the
        // keyboard.
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

/// Scrolls the page to the end (the field lands near the screen bottom),
/// then opens the fake keyboard without moving the content.
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
    // The reveal must also leave breathing room: the field box may not rest
    // directly against the keyboard's top edge (kKeyboardRevealGap applies to
    // the caret line; the box rides a little higher still).
    expect(
      after,
      lessThanOrEqualTo(screenHeight - _keyboardHeight - 24),
      reason: 'the focused field must keep a visible gap above the keyboard',
    );
  });

  testWidgets('without the keyboard-aware reveal the field stays hidden', (
    tester,
  ) async {
    await _pumpScrolledBehindKeyboard(tester, keyboardAwareReveal: false);

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    await tester.tap(find.byKey(_fieldKey));
    await tester.pumpAndSettle();

    expect(
      tester.getBottomRight(find.byKey(_fieldKey)).dy,
      greaterThanOrEqualTo(screenHeight - _keyboardHeight),
      reason: 'documents the unfixed behavior this suite guards against',
    );
  });
}
