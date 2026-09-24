// Opt-in host diagnostic for CALENDAR_OPTIMIZATION_PLAN.md follow-ups A/B/C.
// Run with: flutter test --dart-define=CALENDAR_BENCHMARK=true
//   test/ui/history/calendar_query_benchmark_test.dart --reporter expanded
// Debug host timers are NOT device frame, heap, or cold-storage measurements.
// No timing thresholds: assertions validate the fixture and production behavior.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:tracker/data/repositories/workout_session_repository.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/history/view_models/calendar_view_model.dart';
import 'package:tracker/ui/history/widgets/calendar/calendar_grid.dart';

import '../../../testing/test_helpers.dart';

const _enabled = bool.fromEnvironment('CALENDAR_BENCHMARK');
const _warmups = 8;
const _rounds = 40;
const _syncBatch = 10;
const _setsPerSession = 24;
final _denseDay = DateTime(2026, 9, 15);
final _typicalDay = DateTime(2026, 9, 14);
final _emptyDay = DateTime(2026, 9, 16);
Object? _sink;

WorkoutSession _session(int i) {
  final DateTime start;
  if (i < 200) {
    // Exactly 200 unique instants inside the same local calendar day.
    start = DateTime(2026, 9, 15, 6).add(Duration(minutes: i * 4));
  } else if (i == 200) {
    start = DateTime(2026, 9, 14, 18);
  } else {
    // Three sessions per prior local date: ~9 years at 10k, a heavy history.
    final j = i - 201;
    start = DateTime(2026, 9, 13 - j ~/ 3, 7 + (j % 3) * 5);
  }
  return WorkoutSession(
    title: 'Session ${i + 1}: ${i.isEven ? 'Upper body' : 'Lower body'}',
    startTime: start,
    endTime: start.add(Duration(minutes: 55 + i % 35)),
    gymId: 1 + i % 3,
    sets: [
      for (var k = 0; k < _setsPerSession; k++)
        WorkoutSet(
          exerciseId: 1 + k ~/ 4 + (i % 2) * 6,
          weight: (k % 4 == 0 ? 30.0 : 60.0) + (i % 20) * 2.5,
          reps: k % 4 == 0 ? 12 : 6 + (i + k) % 5,
          type: k % 4 == 0 ? SetType.warmup : SetType.working,
          order: k,
        ),
    ],
  )..id = i + 1;
}

void _log(Map<String, Object?> event) {
  // ignore: avoid_print
  print('CALENDAR_BENCH ${jsonEncode(event)}');
}

void _report(int n, String name, List<double> samples, int batch) {
  final sorted = [...samples]..sort();
  final mid = sorted.length ~/ 2;
  _log({
    'n': n,
    'operation': name,
    'unit': 'us/op',
    'warmups': _warmups,
    'rounds': _rounds,
    'batch': batch,
    'min': sorted.first,
    'median': (sorted[mid - 1] + sorted[mid]) / 2,
    'p95': sorted[(sorted.length * .95).ceil() - 1],
    'max': sorted.last,
    'samples': samples,
  });
}

// Rotate operation order on each round to reduce systematic ordering bias.
// Samples include Dart/native scheduling and allocation/GC when encountered.
Future<void> _measureAsync(
  int n,
  Map<String, Future<Object?> Function()> operations,
) async {
  final names = operations.keys.toList();
  final samples = {for (final name in names) name: <double>[]};
  for (var round = -_warmups; round < _rounds; round++) {
    for (var j = 0; j < names.length; j++) {
      final name = names[(j + round + _warmups) % names.length];
      final watch = Stopwatch()..start();
      _sink = await operations[name]!();
      watch.stop();
      if (round >= 0) samples[name]!.add(watch.elapsedMicroseconds.toDouble());
    }
  }
  for (final name in names) {
    _report(n, name, samples[name]!, 1);
  }
}

void _measureSync(int n, Map<String, Object? Function()> operations) {
  final names = operations.keys.toList();
  final samples = {for (final name in names) name: <double>[]};
  for (var round = -_warmups; round < _rounds; round++) {
    for (var j = 0; j < names.length; j++) {
      final name = names[(j + round + _warmups) % names.length];
      final op = operations[name]!;
      final watch = Stopwatch()..start();
      for (var k = 0; k < _syncBatch; k++) {
        _sink = op();
      }
      watch.stop();
      if (round >= 0) {
        samples[name]!.add(watch.elapsedMicroseconds / _syncBatch);
      }
    }
  }
  for (final name in names) {
    _report(n, name, samples[name]!, _syncBatch);
  }
}

void main() {
  test(
    'calendar query and semantic projection host benchmark',
    () async {
      await initIsarCore();
      // One shared native instance for both sizes; never reopen per case.
      final isar = await openTestIsar([
        WorkoutSessionSchema,
      ], name: 'calendar_query_benchmark');
      final directory = Directory(isar.directory!);
      addTearDown(() async {
        _sink = null;
        await isar.close(deleteFromDisk: true);
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final repo = WorkoutSessionRepository(isar);
      _log({
        'environment': Platform.operatingSystemVersion,
        'dart': Platform.version,
        'mode': kDebugMode ? 'debug/test JIT' : 'non-debug',
        'timezone': _denseDay.timeZoneName,
        'utcOffsetMinutes': _denseDay.timeZoneOffset.inMinutes,
        'dataset':
            'deterministic IDs; 200 dense, 1 typical, then 3/day '
            'before typical date; 24 embedded sets/session: '
            '6 exercises x (1 warmup + 3 working); three gyms',
        'method':
            'one temporary DB grown 1000 -> 10000; seeding and '
            'correctness checks excluded; 8 rotating warmup rounds; '
            '40 rotating timed rounds; synchronous batch 10; '
            'warm-cache host latency only; no frame/heap/cold-read claims',
      });

      var existing = 0;
      for (final n in [1000, 10000]) {
        await isar.writeTxn(() async {
          await isar.workoutSessions.putAll([
            for (var i = existing; i < n; i++) _session(i),
          ]);
        });
        existing = n;
        expect(await isar.workoutSessions.count(), n);
        final dense = await repo.getForDate(_denseDay);
        expect(dense.length, 200);
        expect(dense.expand((s) => s.sets).length, 4800);
        expect(dense.first.id, 200);
        expect(dense.last.id, 1);
        expect((await repo.getForDate(_typicalDay)).length, 1);
        expect(await repo.getForDate(_emptyDay), isEmpty);
        expect((await repo.getSummariesForDate(_denseDay)).length, 200);
        final starts = await repo.getStartTimes();
        final freshStarts = await repo.getStartTimes();
        expect(starts.length, n);
        expect(freshStarts, starts);
        expect(identical(freshStarts, starts), isFalse);
        _log({
          'fixtureVerified': n,
          'embeddedSets': n * _setsPerSession,
          'denseDaySessions': dense.length,
          'typicalDaySessions': 1,
          'emptyDaySessions': 0,
        });

        final queries = <String, Future<Object?> Function()>{};
        for (final entry in {
          'empty': _emptyDay,
          'typical': _typicalDay,
          'dense200': _denseDay,
        }.entries) {
          final day = entry.value;
          final next = DateTime(day.year, day.month, day.day + 1);
          queries['${entry.key}.repository.getForDate'] = () =>
              repo.getForDate(day);
          queries['${entry.key}.repository.getSummariesForDate'] = () =>
              repo.getSummariesForDate(day);
          // Same unindexed half-open filter and ordering as getForDate, but
          // only one native property. Diagnostic control, NOT a replacement
          // summary API: it cannot produce title, ID, gym and set count.
          queries['${entry.key}.filteredSortedStartProperty'] = () => isar
              .workoutSessions
              .filter()
              .startTimeBetween(day, next, includeUpper: false)
              .sortByStartTimeDesc()
              .startTimeProperty()
              .findAll();
          queries['${entry.key}.filteredCount'] = () => isar.workoutSessions
              .filter()
              .startTimeBetween(day, next, includeUpper: false)
              .count();
        }
        queries['all.repository.getStartTimes'] = repo.getStartTimes;
        queries['all.repository.getAll.decodeBaseline'] = repo.getAll;
        await _measureAsync(n, queries);

        final previous = WorkoutDateProjection(starts);
        final fresh = WorkoutDateProjection(freshStarts);
        expect(mapEquals(previous.dateCounts, fresh.dateCounts), isTrue);
        final model = CalendarViewModel(now: () => _denseDay);
        final changedModel = CalendarViewModel(now: () => _denseDay);
        try {
          model.updateDates(starts);
          final retainedIndex = model.dateIndex;
          expect(model.updateDates(freshStarts), isFalse);
          expect(identical(model.dateIndex, retainedIndex), isTrue);
          final altered = [...freshStarts];
          altered[0] = DateTime(2026, 10, 1, 12);
          var useAltered = false;
          _measureSync(n, {
            'control.synchronousDispatch': () => starts.length,
            'projection.normalizeDateCountsAndInstants': () =>
                WorkoutDateProjection(freshStarts),
            'comparison.mapEquals.equalDateCounts': () =>
                mapEquals(previous.dateCounts, fresh.dateCounts),
            'index.fromExistingProjection': () =>
                WorkoutDateIndex.fromProjection(fresh),
            'projection.matchesLocalTimezone': () => fresh.matchesLocalTimezone,
            'viewModel.updateDates.unchanged': () =>
                model.updateDates(freshStarts),
            'viewModel.updateDates.changedAndMaterializeIndex': () {
              useAltered = !useAltered;
              changedModel.updateDates(useAltered ? altered : freshStarts);
              return changedModel.dateIndex;
            },
          });
          expect(identical(model.dateIndex, retainedIndex), isTrue);
          expect(_sink, isNotNull);
          _log({
            'n': n,
            'occupiedDates': previous.dateCounts.length,
            'unchangedIndexIdentityPreserved': true,
          });
        } finally {
          model.dispose();
          changedModel.dispose();
        }
      }
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
