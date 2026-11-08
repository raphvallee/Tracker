// Fake-async caveats (all load-bearing):
//  * Every capture's IO/encoding runs inside `tester.runAsync` - real file IO
//    and PNG encoding never complete in the testWidgets fake-async zone.
//  * Capture strictly between settle and pop: after pop the boundary shows the
//    base page again.
//  * `image.dispose()` after encoding (leak-tracker hygiene).
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wrap the app under test in
/// `RepaintBoundary(key: screenshotBoundaryKey, child: const MyApp())` ABOVE
/// MaterialApp so captures include dialogs, sheets, toasts and the bottom bar
/// (route-level boundaries can exclude overlay entries).
final GlobalKey screenshotBoundaryKey = GlobalKey();

/// Resolve `<packageRoot>/build/test_screenshots`, creating it. `flutter test`
/// runs with the package root as CWD; the walk-up is defensive. Do NOT use
/// `Platform.script` - under flutter test it points at the test-runner
/// bootstrap kernel, not at a test file.
Directory screenshotDir() {
  var dir = Directory.current;
  for (var i = 0; i < 3; i++) {
    if (File('${dir.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
      break;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  final out = Directory(
    '${dir.path}${Platform.pathSeparator}build'
    '${Platform.pathSeparator}test_screenshots',
  );
  out.createSync(recursive: true);
  return out;
}

class ScreenshotRecorder {
  ScreenshotRecorder(this.tester);

  final WidgetTester tester;
  late String _sizeLabel;
  late int _width;
  late int _height;
  int _counter = 0;
  bool _manifestAnnounced = false;
  final List<Map<String, Object?>> _entries = [];

  void beginRun({
    required String sizeLabel,
    required int width,
    required int height,
  }) {
    _sizeLabel = sizeLabel;
    _width = width;
    _height = height;
    _counter = 0;
  }

  Future<void> capture(String label, {bool fail = false}) async {
    final n = ++_counter;
    final fileName =
        '${n.toString().padLeft(3, '0')}_${_sanitize(label)}'
        '${fail ? '_FAIL' : ''}@${_width}x$_height.png';
    final dir = screenshotDir();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    var written = false;
    await tester.runAsync(() async {
      final obj = screenshotBoundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) {
        print('SCREENSHOT-SKIP (no boundary): $fileName');
        return;
      }
      final image = await obj.toImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          print('SCREENSHOT-SKIP (null bytes): $fileName');
          return;
        }
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        written = true;
      } finally {
        image.dispose();
      }
      _entries.add({
        'file': fileName,
        'label': label,
        'size': _sizeLabel,
        'width': _width,
        'height': _height,
        'fail': fail,
      });
      await _writeManifest(dir);
    });
    if (written) print('SCREENSHOT: ${file.path}');
  }

  /// Best-effort capture of a screen that threw; never throws itself - a
  /// capture problem must not turn into a second test failure.
  Future<void> captureFailure(String label) async {
    try {
      await capture(label, fail: true);
    } catch (e) {
      print('SCREENSHOT: failure capture failed: $e');
    }
  }

  /// Rewritten after every capture so it exists even if a later size run
  /// crashes the suite. Each sweep size runs in its own process, so entries
  /// other processes already wrote are kept (minus files this run replaced);
  /// run-visual-tests.ps1 runs the sizes one at a time so writes never race.
  Future<void> _writeManifest(Directory dir) async {
    final manifest = File('${dir.path}${Platform.pathSeparator}manifest.json');
    final mine = {for (final entry in _entries) entry['file']};
    final others = <Object?>[];
    if (manifest.existsSync()) {
      try {
        final previous = jsonDecode(await manifest.readAsString());
        if (previous is Map && previous['entries'] is List) {
          for (final entry in previous['entries'] as List) {
            if (entry is Map && !mine.contains(entry['file'])) {
              others.add(entry);
            }
          }
        }
      } on FormatException {
        // A torn write from a concurrent run: start the index over.
      }
    }
    const encoder = JsonEncoder.withIndent('  ');
    await manifest.writeAsString(
      encoder.convert({
        'outputDir': dir.path,
        'entries': [...others, ..._entries],
      }),
      flush: true,
    );
    if (!_manifestAnnounced) {
      _manifestAnnounced = true;
      print('MANIFEST: ${manifest.path}');
    }
  }

  String _sanitize(String label) {
    final dashed = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return dashed.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
