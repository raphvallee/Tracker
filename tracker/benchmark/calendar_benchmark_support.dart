// Shared fixtures and host for the History calendar benchmarks. Used by the
// widget-level harness (history_calendar_benchmark_test.dart) and the device
// harness (history_calendar_device_test.dart).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';

const List<int> sessionCounts = [500, 2000];

/// Finds an icon-only [FButton] by its semantics tooltip (AppIconButton).
///
/// Material's `find.byTooltip` matched the old `Tooltip` widgets; since the
/// Forui swap the tooltip lives on `FButton.semanticsTooltip` instead.
Finder fButtonByTooltip(String tooltip) => find.byWidgetPredicate(
  (w) => w is FButton && w.semanticsTooltip == tooltip,
);

/// Frame budget the device harness enforces (p95 of UI-thread frame build).
/// Overridable with --dart-define=CAL_BUDGET_MS when profiling on a throttled
/// or slow device, where the 7ms gate for normal hardware does not apply.
const int frameBudgetMs = int.fromEnvironment('CAL_BUDGET_MS', defaultValue: 7);

/// Deterministic history: about one workout every other day, counting back
/// from today, each with 4-12 sets.
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

/// Pumps the app-like shell once and returns the notifier that drives the
/// calendar's sessions. A null value unmounts the calendar.
///
/// With [remountOnChange], every new list gets a new key, so a single pump
/// unmounts the old calendar and mounts the new one (one measured frame per
/// mount). Without it, a new list updates the existing calendar in place.
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

/// One user interaction: dispatch the tap, then render the frame it dirtied.
/// flutter_test's tap does not render, so the pump is part of the interaction.
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

/// Day cells of the month grid. They are the only InkWells with an 8px corner
/// radius; the month nav buttons use the default shape.
Finder dayCells() => find.byWidgetPredicate(
  (widget) =>
      widget is InkWell && widget.borderRadius == BorderRadius.circular(8),
);

/// Duration samples (microseconds) summarized in milliseconds.
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
