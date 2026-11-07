// Split day muscle section: rows keep the order they are given, show each
// muscle's total planned sets, mute muscles that are only ever secondary, and
// render nothing without loads. Widget-only (no Isar), so it can share a file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/services/muscle_set_load.dart';
import 'package:tracker/ui/workout/widgets/split_day_muscle_section.dart';

import '../../../testing/test_helpers.dart';

const _chest = MuscleSetLoad(
  muscle: Muscle.chest,
  primarySets: 3,
  secondarySets: 1,
);
const _triceps = MuscleSetLoad(
  muscle: Muscle.triceps,
  primarySets: 0,
  secondarySets: 2,
);
const _biceps = MuscleSetLoad(
  muscle: Muscle.biceps,
  primarySets: 0,
  secondarySets: 1,
);

void main() {
  testWidgets('rows keep the order they are given, top to bottom', (
    tester,
  ) async {
    await pumpAppPage(
      tester,
      SplitDayMuscleSection(loads: const [_chest, _triceps, _biceps]),
    );

    double topOf(Muscle muscle) =>
        tester.getTopLeft(find.byKey(ValueKey('muscle-${muscle.name}'))).dy;
    expect(topOf(Muscle.chest), lessThan(topOf(Muscle.triceps)));
    expect(topOf(Muscle.triceps), lessThan(topOf(Muscle.biceps)));
  });

  testWidgets('shows each muscle name with its primary plus secondary sets', (
    tester,
  ) async {
    await pumpAppPage(
      tester,
      SplitDayMuscleSection(
        loads: const [
          _chest,
          _triceps,
          MuscleSetLoad(
            muscle: Muscle.frontDelts,
            primarySets: 1,
            secondarySets: 0,
          ),
        ],
      ),
    );

    expect(find.text('pectoralis major'), findsOneWidget);
    expect(find.text('4 sets'), findsOneWidget);
    expect(find.text('triceps brachii'), findsOneWidget);
    expect(find.text('2 sets'), findsOneWidget);
    expect(find.text('anterior deltoid'), findsOneWidget);
    expect(find.text('1 set'), findsOneWidget);
  });

  testWidgets('mutes muscles that are only ever secondary', (tester) async {
    await pumpAppPage(
      tester,
      SplitDayMuscleSection(loads: const [_chest, _triceps]),
    );

    final context = tester.element(find.byType(SplitDayMuscleSection));
    final muted = context.theme.colors.mutedForeground;

    expect(
      tester.widget<Text>(find.text('triceps brachii')).style?.color,
      muted,
    );
    expect(tester.widget<Text>(find.text('2 sets')).style?.color, muted);
    expect(
      tester.widget<Text>(find.text('pectoralis major')).style?.color,
      isNot(muted),
    );
    expect(tester.widget<Text>(find.text('4 sets')).style?.color, isNot(muted));
  });

  testWidgets('renders nothing when there are no loads', (tester) async {
    // Align loosens the route's tight constraints so a shrunk section is
    // measurable as zero-sized.
    await pumpAppPage(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: SplitDayMuscleSection(loads: []),
      ),
    );

    expect(find.byType(FCard), findsNothing);
    expect(tester.getSize(find.byType(SplitDayMuscleSection)), Size.zero);
  });

  testWidgets('lays out at the 320px minimum width without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAppPage(
      tester,
      SplitDayMuscleSection(loads: const [_chest, _triceps, _biceps]),
    );

    expect(tester.takeException(), isNull);
  });
}
