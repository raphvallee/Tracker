// Driver for history_calendar_device_test.dart. Writes the raw FrameTiming
// summaries to build/history_calendar_benchmark.json (build/ is gitignored).
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) {
      print('BENCH no response data');
      return;
    }
    final file = File('build/history_calendar_benchmark.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    print('BENCH wrote ${file.path}');
  },
);
