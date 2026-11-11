// Outside test/ on purpose so CI's `flutter test` never runs timing-sensitive
// code.
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/services/workout_dates.dart';

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
          sessions.value = isarFresh(data);
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
          final watch = Stopwatch()..start();
          await swipeMonth(tester, next: i.isEven);
          watch.stop();
          final current = monthHeader(tester);
          expect(current, isNot(previous), reason: 'swipe was dropped');
          previous = current;
          if (i >= _warmup) micros.add(watch.elapsedMicroseconds);
        }
        print(BenchStats(micros).line('month change (next/prev)', count));
      });

      testWidgets('pick workout day', (tester) async {
        await tester.runAsync(loadTestFonts);
        _useTallView(tester);
        var picked = 0;
        await pumpCalendarHost(
          tester,
          initial: buildSessions(count),
          onPickDay: (_) => picked++,
        );
        final cells = dayCells();
        final cellCount = cells.evaluate().length;
        expect(cellCount, greaterThan(0));
        final micros = <int>[];
        for (var i = 0; i < _warmup + _iterations; i++) {
          final watch = Stopwatch()..start();
          await tapAndRender(tester, cells.at(i % cellCount));
          watch.stop();
          expect(picked, i + 1, reason: 'day tap $i was dropped');
          if (i >= _warmup) micros.add(watch.elapsedMicroseconds);
        }
        print(BenchStats(micros).line('pick workout day', count));
      });

      testWidgets('sessions update', (tester) async {
        await tester.runAsync(loadTestFonts);
        final base = buildSessions(count);
        final today = DateTime.now();
        final versions = [
          base,
          [
            WorkoutSession(
              title: 'Extra',
              startTime: DateTime(today.year, today.month, today.day, 18),
            ),
            ...base,
          ],
        ];
        final sessions = await pumpCalendarHost(tester, initial: versions[0]);
        final micros = <int>[];
        for (var i = 0; i < _warmup + _iterations; i++) {
          sessions.value = isarFresh(versions[(i + 1) % 2]);
          final watch = Stopwatch()..start();
          await tester.pump();
          watch.stop();
          if (i >= _warmup) micros.add(watch.elapsedMicroseconds);
        }
        print(BenchStats(micros).line('sessions update', count));
      });

      test('index: first month + streak (fresh dates)', () {
        final sessions = buildSessions(count);
        final now = DateTime.now();
        final micros = <int>[];
        for (var i = 0; i < _warmup + _iterations; i++) {
          final starts = [for (final s in isarFresh(sessions)) s.startTime];
          final watch = Stopwatch()..start();
          WorkoutDateIndex(starts)
            ..workoutDaysIn(now.year, now.month)
            ..currentStreak();
          watch.stop();
          if (i >= _warmup) micros.add(watch.elapsedMicroseconds);
        }
        print(BenchStats(micros).line('index: first month + streak', count));
      });
    });
  }
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
