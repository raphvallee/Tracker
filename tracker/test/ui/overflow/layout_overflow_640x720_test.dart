// Layout overflow sweep - 640x720 snap-half window. One size per file: each
// *_test.dart runs in its own flutter_tester process, giving the sweep a
// fresh libisar native worker pool (see layout_overflow_sweep.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../testing/test_helpers.dart';
import 'layout_overflow_sweep.dart';

void main() {
  setUpAll(initIsarCore);
  testWidgets('no overflow at 640x720-snap-half', (tester) async {
    await sweepSize(tester, '640x720-snap-half', const Size(640, 720));
  });
}
