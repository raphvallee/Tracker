// Widget-only: no Isar. The restore and persistence flows that need a real
// database each live in their own file (docs/TESTING_ISAR_CI.md).

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/main.dart';
import 'package:tracker/ui/core/ui/plan_bar.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/history/widgets/session_detail_page.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

import '../../../testing/test_helpers.dart';

final _start = DateTime(DateTime.now().year, 1, 5, 18, 4);

WorkoutSession _push() => WorkoutSession(
  title: 'Push',
  startTime: _start,
  endTime: _start.add(const Duration(hours: 1, minutes: 12)),
  gymId: 3,
  sets: [
    WorkoutSet(
      exerciseId: 1,
      weight: 40,
      reps: 10,
      type: SetType.warmup,
      order: 0,
    ),
    WorkoutSet(exerciseId: 1, weight: 80, reps: 8, order: 1, rpe: 8),
    WorkoutSet(exerciseId: 2, weight: 50, reps: 8, order: 2),
    WorkoutSet(exerciseId: 1, weight: 80, reps: 7, order: 3, rpe: 9),
  ],
);

void main() {
  group('SessionDetailPage', () {
    testWidgets('says when, how long, where and how much, then every set', (
      tester,
    ) async {
      await pumpAppPage(
        tester,
        SessionDetailPage(session: _push(), gymName: 'Home gym'),
      );

      expect(find.text('Push'), findsOneWidget);
      expect(
        find.text('${weekdayLabel(_start)} 5 Jan, 18:04 to 19:16'),
        findsOneWidget,
      );
      // Working volume only: 80 x 8 + 50 x 8 + 80 x 7.
      expect(
        find.text('1 h 12 min at Home gym, 1,600 kg lifted'),
        findsOneWidget,
      );

      final bar = tester.widget<PlanBar>(find.byType(PlanBar));
      expect(bar.ink, isTrue, reason: 'a finished workout is drawn in ink');
      expect([for (final s in bar.segments) s.sets], [2, 1]);
      expect(find.text('3 sets'), findsOneWidget);

      // Grouped under their exercise in logged order; numbers count working
      // sets only.
      expect(find.text('Exercise 1'), findsOneWidget);
      expect(find.text('2 sets, 1 warm-up'), findsOneWidget);
      expect(find.text('Exercise 2'), findsOneWidget);
      expect(find.text('1 set'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('RPE 8'), findsOneWidget);
      expect(find.text('RPE 9'), findsOneWidget);
      expect(find.text('×'), findsNWidgets(4));

      expect(find.text('Edit'), findsOneWidget);
      expect(find.textContaining('Delete'), findsNothing);
      expect(fButtonByTooltip('Workout options'), findsNothing);
    });

    testWidgets('a tap on an exercise folds it to its best set, and back', (
      tester,
    ) async {
      await pumpAppPage(tester, SessionDetailPage(session: _push()));

      await tester.tap(find.text('Exercise 1'));
      await tester.pumpAndSettle();
      expect(find.text('Best set 80 kg × 8'), findsOneWidget);
      expect(find.text('RPE 8'), findsNothing);
      // The other exercise stays open.
      expect(find.text('Exercise 2'), findsOneWidget);
      expect(find.text('2 sets, 1 warm-up'), findsOneWidget);

      await tester.tap(find.text('Exercise 1'));
      await tester.pumpAndSettle();
      expect(find.text('Best set 80 kg × 8'), findsNothing);
      expect(find.text('RPE 8'), findsOneWidget);
    });

    testWidgets('weights and effort follow the chosen unit and scale', (
      tester,
    ) async {
      await pumpApp(tester, unit: WeightUnit.pounds);
      tester
          .element(find.byType(MyApp))
          .read<SettingsCubit>()
          .setEffortScale(EffortScale.rir);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => SessionDetailPage(session: _push()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RIR 2'), findsOneWidget);
      expect(find.text('RIR 1'), findsOneWidget);
      expect(find.text('lb'), findsNWidgets(4));
      expect(find.textContaining('lb lifted'), findsOneWidget);
    });

    testWidgets('a workout with no sets says so', (tester) async {
      await pumpAppPage(
        tester,
        SessionDetailPage(
          session: WorkoutSession(title: 'Legs', startTime: _start),
        ),
      );
      expect(find.text('No sets were logged in this workout.'), findsOneWidget);
      expect(find.text('0 sets'), findsOneWidget);
    });

    testWidgets('Edit opens the workout as a draft', (tester) async {
      await pumpAppPage(tester, SessionDetailPage(session: _push()));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit workout'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      // Nothing changed yet: no save bar.
      expect(find.textContaining('unsaved change'), findsNothing);
      await tester.tap(find.byIcon(FLucideIcons.chevronLeft));
      await tester.pumpAndSettle();
      expect(find.text('Push'), findsOneWidget);
    });
  });
}
