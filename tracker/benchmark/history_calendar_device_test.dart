// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';

import 'calendar_benchmark_support.dart';

const int _warmup = 10;
const int _iterations = 60;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final count in sessionCounts) {
    group('HistoryCalendar with $count sessions', () {
      testWidgets('mount', (tester) async {
        final data = buildSessions(count);
        final sessions = await pumpCalendarHost(tester, remountOnChange: true);
        await _measure(binding, 'mount', count, (iterations) async {
          for (var i = 0; i < iterations; i++) {
            sessions.value = List.of(data);
            await tester.pump();
          }
        });
      });

      testWidgets('month change (next/prev)', (tester) async {
        await pumpCalendarHost(tester, initial: buildSessions(count));
        var previous = monthHeader(tester);
        await _measure(binding, 'month change (next/prev)', count, (
          iterations,
        ) async {
          for (var i = 0; i < iterations; i++) {
            final label = i.isEven ? 'Next month' : 'Previous month';
            await tapAndRender(tester, fButtonByTooltip(label));
            final current = monthHeader(tester);
            expect(current, isNot(previous), reason: 'tap "$label" dropped');
            previous = current;
          }
        });
      });

      testWidgets('select day', (tester) async {
        await pumpCalendarHost(tester, initial: buildSessions(count));
        final cells = dayCells();
        final cellCount = cells.evaluate().length;
        var previous = selectionLabel(tester);
        await _measure(binding, 'select day', count, (iterations) async {
          for (var i = 0; i < iterations; i++) {
            await tapAndRender(tester, cells.at(i % cellCount));
            final current = selectionLabel(tester);
            expect(current, isNot(previous), reason: 'day tap $i dropped');
            previous = current;
          }
        });
      });

      test('index build (fromSessions)', () {
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

      testWidgets('sessions update', (tester) async {
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
        await _measure(binding, 'sessions update', count, (iterations) async {
          for (var i = 0; i < iterations; i++) {
            sessions.value = versions[(i + 1) % 2];
            await tester.pump();
          }
        });
      });
    });
  }
}

Future<void> _measure(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
  int count,
  Future<void> Function(int iterations) run,
) async {
  await run(_warmup);
  final key = '$name|$count';
  await binding.watchPerformance(() => run(_iterations), reportKey: key);
  final summary = binding.reportData![key] as Map<String, dynamic>;
  final frames = (summary['frame_build_times'] as List<dynamic>).cast<int>();
  final stats = BenchStats(frames);
  print(stats.line(name, count));
  expect(
    stats.p95Ms,
    lessThan(frameBudgetMs),
    reason: '$name with $count sessions is over the ${frameBudgetMs}ms budget',
  );
}
