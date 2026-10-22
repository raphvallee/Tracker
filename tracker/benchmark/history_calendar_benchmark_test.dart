// Widget-level benchmark for the History calendar (HistoryCalendar), run in
// flutter test (debug JIT). Quick to iterate on; numbers are pessimistic
// versus profile mode, so the device harness is the authoritative check.
//
// Each sample times the pump that performs the work (build + layout + paint,
// no GPU raster). Taps are timed together with the pump that renders them, and
// each tap is checked against the UI so a dropped tap can't pass as a fast
// sample. Outside test/ on purpose so CI's `flutter test` never runs
// timing-sensitive code.
//
// Run from tracker/:
//   flutter test benchmark/history_calendar_benchmark_test.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';

import '../testing/test_fonts.dart';
import 'calendar_benchmark_support.dart';

const int _warmup = 10;
const int _iterations = 60;

void main() {
  for (final count in sessionCounts) {
    group('HistoryCalendar with $count sessions', () {
      testWidgets('mount', (tester) async {
        await tester.runAsync(loadTestFonts);
        final data = buildSessions(count);
        final sessions = await pumpCalendarHost(tester, remountOnChange: true);
        final micros = <int>[];
        for (var i = 0; i < _warmup + _iterations; i++) {
          sessions.value = List.of(data);
          final watch = Stopwatch()..start();
          await tester.pump();
          watch.stop();
          if (i >= _warmup) micros.add(watch.elapsedMicroseconds);
        }
        print(BenchStats(micros).line('mount', count));
      });

      testWidgets('month change (next/prev)', (tester) async {
        await tester.runAsync(loadTestFonts);
        _useTallView(tester);
        await pumpCalendarHost(tester, initial: buildSessions(count));
        var previous = monthHeader(tester);
        final micros = <int>[];
        for (var i = 0; i < _warmup + _iterations; i++) {
          final label = i.isEven ? 'Next month' : 'Previous month';
          final watch = Stopwatch()..start();
          await tapAndRender(tester, fButtonByTooltip(label));
          watch.stop();
          final current = monthHeader(tester);
          expect(current, isNot(previous), reason: 'tap "$label" was dropped');
          previous = current;
          if (i >= _warmup) micros.add(watch.elapsedMicroseconds);
        }
        // Drain FTappable's 100ms press timer created by the last tap;
        // flutter_test fails the test if timers are still pending at the end.
        await tester.pump(const Duration(milliseconds: 150));
        print(BenchStats(micros).line('month change (next/prev)', count));
      });

      testWidgets('select day', (tester) async {
        await tester.runAsync(loadTestFonts);
        _useTallView(tester);
        await pumpCalendarHost(tester, initial: buildSessions(count));
        final cells = dayCells();
        final cellCount = cells.evaluate().length;
        var previous = selectionLabel(tester);
        final micros = <int>[];
        for (var i = 0; i < _warmup + _iterations; i++) {
          final watch = Stopwatch()..start();
          await tapAndRender(tester, cells.at(i % cellCount));
          watch.stop();
          final current = selectionLabel(tester);
          expect(current, isNot(previous), reason: 'day tap $i was dropped');
          previous = current;
          if (i >= _warmup) micros.add(watch.elapsedMicroseconds);
        }
        print(BenchStats(micros).line('select day', count));
      });

      testWidgets('sessions update', (tester) async {
        await tester.runAsync(loadTestFonts);
        final base = buildSessions(count);
        final today = DateTime.now();
        final versions = [
          base,
          [
            ...base,
            WorkoutSession(
              title: 'Extra',
              startTime: DateTime(today.year, today.month, today.day, 18),
            ),
          ],
        ];
        final sessions = await pumpCalendarHost(tester, initial: versions[0]);
        final micros = <int>[];
        for (var i = 0; i < _warmup + _iterations; i++) {
          sessions.value = versions[(i + 1) % 2];
          final watch = Stopwatch()..start();
          await tester.pump();
          watch.stop();
          if (i >= _warmup) micros.add(watch.elapsedMicroseconds);
        }
        print(BenchStats(micros).line('sessions update', count));
      });

      test('building blocks: WorkoutDateIndex.fromSessions', () {
        final sessions = buildSessions(count);
        final micros = <int>[];
        for (var i = 0; i < _warmup + _iterations; i++) {
          final watch = Stopwatch()..start();
          WorkoutDateIndex.fromSessions(sessions);
          watch.stop();
          if (i >= _warmup) micros.add(watch.elapsedMicroseconds);
        }
        print(BenchStats(micros).line('index build (fromSessions)', count));
      });
    });
  }
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
