import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/workout/widgets/new_split_page.dart';

import '../../../testing/fakes/in_memory_storage.dart';
import '../../../testing/test_helpers.dart';

WorkoutSplit _split() {
  final split = WorkoutSplit(title: 'Push Pull Legs', description: '3-day');
  split.splitDays = [
    WorkoutSplitDay(title: 'Push', order: 0),
    WorkoutSplitDay(title: 'Pull', order: 1),
    WorkoutSplitDay(title: 'Legs', order: 2),
  ];
  return split;
}

void main() {
  setUp(() {
    // In-memory storage: the real HydratedStorage deadlocks the widget-test
    // fake-async zone once the app shell is pumped.
    HydratedBloc.storage = InMemoryStorage();
  });

  testWidgets('remove day asks first and cancel keeps the day', (tester) async {
    await pumpAppPage(tester, SplitEditorPage(split: _split()));
    expect(find.text('Pull'), findsOneWidget);

    await tester.tap(fButtonByTooltip('Remove day').at(1));
    await tester.pumpAndSettle();

    expect(find.text('Remove day?'), findsOneWidget);
    expect(find.textContaining('"Pull"'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Remove day?'), findsNothing);
    expect(find.text('Pull'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);
  });

  testWidgets('confirming remove drops only that day', (tester) async {
    await pumpAppPage(tester, SplitEditorPage(split: _split()));

    await tester.tap(fButtonByTooltip('Remove day').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Remove day?'), findsNothing);
    expect(find.text('Pull'), findsNothing);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);
    expect(fButtonByTooltip('Remove day'), findsNWidgets(2));
  });
}
