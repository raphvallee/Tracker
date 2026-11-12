// Layout overflow sweep - 480x800 tall window. One size per file: each
// *_test.dart runs in its own flutter_tester process, giving the sweep a
// fresh libisar native worker pool (see layout_overflow_sweep.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../testing/test_helpers.dart';
import 'layout_overflow_sweep.dart';

void main() {
  setUpAll(initIsarCore);
  testWidgets('no overflow at 480x800-tall', (tester) async {
    await sweepSize(tester, '480x800-tall', const Size(480, 800));
  });
}
