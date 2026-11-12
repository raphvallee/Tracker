// Layout overflow sweep - 1920x1080 maximized window. One size per file: each
// *_test.dart runs in its own flutter_tester process, giving the sweep a
// fresh libisar native worker pool (see layout_overflow_sweep.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../testing/test_helpers.dart';
import 'layout_overflow_sweep.dart';

void main() {
  setUpAll(initIsarCore);
  testWidgets('no overflow at 1920x1080-maximized', (tester) async {
    await sweepSize(tester, '1920x1080-maximized', const Size(1920, 1080));
  });
}
