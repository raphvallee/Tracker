// Visual screenshot sweep - 800x600 small window. One size per file: each
// *_test.dart runs in its own flutter_tester process, giving the sweep a
// fresh libisar native worker pool (see visual_screenshot_sweep.dart).
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/test_helpers.dart';
import 'visual_screenshot_sweep.dart';

void main() {
  setUpAll(initIsarCore);
  testWidgets('capture screens at 800x600-small', (tester) async {
    await captureScreensAt(tester, '800x600-small', 800, 600);
  });
}
