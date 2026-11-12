import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';

const double _keyboardHeight = 300;
const ValueKey _fieldKey = ValueKey('subject-field');

/// Fakes the on-screen keyboard at [height] logical pixels. [FakeViewPadding]
/// is in physical pixels; the app reads logical pixels.
void _setKeyboard(WidgetTester tester, double height) {
  tester.view.viewInsets = FakeViewPadding(
    bottom: height * tester.view.devicePixelRatio,
  );
}

/// Reads the theme. Const, so only a theme change rebuilds it.
class _ThemeReader extends StatelessWidget {
  const _ThemeReader();

  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    context.theme;
    builds++;
    return const SizedBox(height: 900);
  }
}

Widget _page() => MaterialApp(
  builder: (context, child) => FTheme(
    data: FTheme.neutral.light.touch,
    child: KeyboardReveal(child: child!),
  ),
  home: Scaffold(
    resizeToAvoidBottomInset: false,
    body: Builder(
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: keyboardClearanceOf(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ThemeReader(),
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

double _screenHeight(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

void _expectAboveKeyboard(WidgetTester tester) {
  final bottom = tester.getBottomRight(find.byKey(_fieldKey)).dy;
  final keyboardTop = _screenHeight(tester) - _keyboardHeight;
  expect(
    bottom,
    lessThanOrEqualTo(keyboardTop - 24),
    reason: 'the focused field must sit above the keyboard, with a gap',
  );
}

void main() {
  testWidgets('a field focused with the keyboard up scrolls above it', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_page());
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    _setKeyboard(tester, _keyboardHeight);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.byKey(_fieldKey)).dy,
      greaterThan(_screenHeight(tester) - _keyboardHeight),
      reason: 'precondition: the field sits behind the keyboard',
    );

    await tester.tap(find.byKey(_fieldKey));
    await tester.pumpAndSettle();

    _expectAboveKeyboard(tester);
  });

  testWidgets('a focused field rides up with the keyboard as it opens, and '
      'nothing reading the theme rebuilds', (tester) async {
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_page());
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_fieldKey));
    await tester.pumpAndSettle();
    final buildsBefore = _ThemeReader.builds;

    // The keyboard opens over ten frames, as on a phone.
    for (var step = 1; step <= 10; step++) {
      _setKeyboard(tester, _keyboardHeight * step / 10);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    _expectAboveKeyboard(tester);
    expect(
      _ThemeReader.builds,
      buildsBefore,
      reason: 'the keyboard animation must not rebuild the app',
    );
  });
}
