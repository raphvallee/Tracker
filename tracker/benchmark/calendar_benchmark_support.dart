import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';

const List<int> sessionCounts = [500, 2000];

Finder fButtonByTooltip(String tooltip) => find.byWidgetPredicate(
  (w) => w is FButton && w.semanticsTooltip == tooltip,
);

const int frameBudgetMs = int.fromEnvironment('CAL_BUDGET_MS', defaultValue: 7);

List<WorkoutSession> buildSessions(int count) {
  final random = Random(7);
  final today = DateTime.now();
  final sessions = <WorkoutSession>[];
  var day = DateTime(today.year, today.month, today.day);
  while (sessions.length < count) {
    if (random.nextDouble() < 0.55) {
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        6 + random.nextInt(12),
      );
      sessions.add(
        WorkoutSession(
          title: 'Workout ${sessions.length}',
          startTime: start,
          endTime: start.add(Duration(minutes: 45 + random.nextInt(45))),
          sets: [
            for (var s = 0; s < 4 + random.nextInt(9); s++)
              WorkoutSet(
                exerciseId: 1 + random.nextInt(30),
                weight: (20 + random.nextInt(80)).toDouble(),
                reps: (5 + random.nextInt(8)).toDouble(),
                type: random.nextInt(8) == 0 ? SetType.warmup : SetType.working,
                order: s,
              ),
          ],
        ),
      );
    }
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return sessions;
}

Future<ValueNotifier<List<WorkoutSession>?>> pumpCalendarHost(
  WidgetTester tester, {
  List<WorkoutSession>? initial,
  bool remountOnChange = false,
}) async {
  final sessions = ValueNotifier<List<WorkoutSession>?>(initial);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          FTheme(data: FTheme.neutral.light.touch, child: child!),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ValueListenableBuilder<List<WorkoutSession>?>(
                valueListenable: sessions,
                builder: (context, value, _) => value == null
                    ? const SizedBox.shrink()
                    : HistoryCalendar(
                        key: remountOnChange ? ValueKey(value) : null,
                        sessions: value,
                        gymNames: const {},
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return sessions;
}

Future<void> tapAndRender(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
}

String monthHeader(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .firstWhere((text) => RegExp(r'^[A-Z][a-z]+ \d{4}$').hasMatch(text));

String selectionLabel(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .firstWhere((text) => text.startsWith('Workouts'));

Finder dayCells() => find.byWidgetPredicate(
  (widget) =>
      widget is InkWell && widget.borderRadius == BorderRadius.circular(8),
);

class BenchStats {
  BenchStats(List<int> micros) : _sorted = ([...micros]..sort());

  final List<int> _sorted;

  double get medianMs => _ms(_sorted[_sorted.length ~/ 2]);
  double get p95Ms => _ms(_sorted[(_sorted.length * 95) ~/ 100]);
  double get maxMs => _ms(_sorted.last);

  String line(String name, int sessions) =>
      'BENCH history_calendar | $name | sessions=$sessions | '
      'n=${_sorted.length} | median=${medianMs.toStringAsFixed(2)}ms | '
      'p95=${p95Ms.toStringAsFixed(2)}ms | max=${maxMs.toStringAsFixed(2)}ms';

  static double _ms(int micros) => micros / 1000;
}
