import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/repositories/exercise_repository.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/data/repositories/workout_session_repository.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/history/widgets/calendar/history_calendar.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/history/widgets/session_lookup_page.dart';

void main() {
  testWidgets(
    'lookup renders loading, missing, failure, retry and current full sets',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        _app(
          repository,
          const SessionLookupPage(id: 1, gymNames: {7: 'Current gym'}),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repository.sessions.lookups.last.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('This workout no longer exists.'), findsOneWidget);
      await tester.tap(find.text('Retry workout'));
      await tester.pump();
      repository.sessions.lookups.last.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load workout.'), findsOneWidget);
      await tester.tap(find.text('Retry workout'));
      await tester.pump();
      final session = WorkoutSession(
        title: 'Fresh detail',
        startTime: DateTime(2026, 3, 1),
        gymId: 7,
        sets: [WorkoutSet(exerciseId: 1, weight: 123, reps: 4, order: 0)],
      );
      repository.sessions.lookups.last.complete(session);
      await tester.pumpAndSettle();
      expect(find.byType(SessionDetailPage), findsOneWidget);
      expect(find.text('123 kg × 4'), findsOneWidget);
      expect(
        tester
            .widget<SessionDetailPage>(find.byType(SessionDetailPage))
            .gymName,
        'Current gym',
      );
    },
  );

  testWidgets(
    'lookup rejects replaced repository and changed ID completions and disposal',
    (tester) async {
      final first = _Repository();
      final second = _Repository();
      await tester.pumpWidget(
        _app(first, const SessionLookupPage(id: 1, gymNames: {})),
      );
      await tester.pumpWidget(
        _app(second, const SessionLookupPage(id: 1, gymNames: {})),
      );
      first.sessions.lookups.single.completeError(StateError('obsolete'));
      await tester.pump();
      expect(find.text('Could not load workout.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(
        _app(second, const SessionLookupPage(id: 2, gymNames: {})),
      );
      second.sessions.lookups.first.complete(
        WorkoutSession(title: 'Old ID', startTime: DateTime.now()),
      );
      await tester.pump();
      expect(find.text('Old ID'), findsNothing);
      expect(second.sessions.ids, [1, 2]);
      await tester.pumpWidget(const SizedBox.shrink());
      second.sessions.lookups.last.completeError(StateError('disposed'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'calendar repeated taps open one lookup; pop during request is safe',
    (tester) async {
      final repository = _Repository();
      final session = WorkoutSession(
        title: 'Open me',
        startTime: DateTime.now(),
      )..id = 1;
      await tester.pumpWidget(
        _app(
          repository,
          Scaffold(
            body: HistoryCalendar(sessions: [session], gymNames: const {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final item = tester.widget<FItem>(
        find
            .ancestor(of: find.text('Open me'), matching: find.byType(FItem))
            .first,
      );
      item.onPress!();
      item.onPress!();
      await tester.pump();
      expect(repository.sessions.lookups, hasLength(1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SessionLookupPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(SessionLookupPage))).pop();
      await tester.pumpAndSettle();
      repository.sessions.lookups.single.completeError(StateError('late'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Widget _app(_Repository repository, Widget child) => MaterialApp(
  builder: (context, child) =>
      FTheme(data: FTheme.neutral.light.desktop, child: child!),
  home: RepositoryScope(repository: repository, child: child),
);

class _Repository extends Fake implements TrackerRepository {
  @override
  final _Sessions sessions = _Sessions();
  @override
  final exercises = _Exercises();
}

class _Exercises extends Fake implements ExerciseRepository {
  @override
  Future<List<Exercise>> getAll() async => const [];
}

class _Sessions extends Fake implements WorkoutSessionRepository {
  final lookups = <Completer<WorkoutSession?>>[];
  final ids = <int>[];
  @override
  Future<WorkoutSession?> getById(int id) {
    ids.add(id);
    final completer = Completer<WorkoutSession?>();
    lookups.add(completer);
    return completer.future;
  }
}
