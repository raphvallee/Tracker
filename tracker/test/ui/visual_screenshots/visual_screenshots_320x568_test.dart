// Visual screenshot sweep - 320x568 minimum window. One size per file: each
// *_test.dart runs in its own flutter_tester process, giving the sweep a
// fresh libisar native worker pool (see visual_screenshot_sweep.dart).
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/test_helpers.dart';
import 'visual_screenshot_sweep.dart';

void main() {
  setUpAll(initIsarCore);
  testWidgets('capture screens at 320x568-min', (tester) async {
    await captureScreensAt(tester, '320x568-min', 320, 568);
  });
}
