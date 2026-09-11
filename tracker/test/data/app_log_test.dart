// Unit tests for the AppLog ring buffer + file mirror
// (lib/data/services/app_log.dart). Pure Dart file I/O, no Isar/Flutter.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/data/services/app_log.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('app_log_test');
    AppLog.reset();
    AppLog.init(tempDir.path);
  });

  tearDown(() async {
    AppLog.reset();
    await tempDir.delete(recursive: true);
  });

  test('mirrors entries to the log file', () async {
    AppLog.error('test', 'boom');
    AppLog.debug('verbose line');
    await AppLog.pending;

    final file = File('${tempDir.path}/tracker.log');
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('ERR test: boom'));
    expect(content, contains('DBG verbose line'));
  });

  test('entries logged before init land in the file after init', () async {
    AppLog.reset(); // back to uninitialized
    AppLog.error('test', 'early error');
    AppLog.init(tempDir.path);
    AppLog.error('test', 'late error');
    await AppLog.pending;

    final content = File('${tempDir.path}/tracker.log').readAsStringSync();
    expect(content, contains('early error'));
    expect(content, contains('late error'));
  });

  test('ring buffer caps at maxLines and the file matches the ring', () async {
    for (var i = 0; i < AppLog.maxLines + 25; i++) {
      AppLog.error('test', 'line $i');
    }
    await AppLog.pending;

    expect(AppLog.bufferedLines, AppLog.maxLines);
    final content = File('${tempDir.path}/tracker.log').readAsStringSync();
    final lines = content.trim().split('\n');
    expect(lines, hasLength(AppLog.maxLines));
    // Newest entries survive; the oldest were evicted.
    expect(content, contains('line ${AppLog.maxLines + 24}'));
    expect(content, isNot(contains('line 0')));
  });

  test('stack traces are captured indented under the error line', () async {
    AppLog.error('test', 'with stack', StackTrace.current);
    await AppLog.pending;

    final content = File('${tempDir.path}/tracker.log').readAsStringSync();
    expect(content, contains('ERR test: with stack'));
    expect(content, matches(RegExp(r'^    .+', multiLine: true)));
  });
}
