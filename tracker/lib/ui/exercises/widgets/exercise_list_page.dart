import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/services/exercise_library.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/exercises/widgets/library_parts.dart';

/// Some of the library on a page of its own: a group's exercises, a day of
/// the current split, or all of them. It follows the library while it is
/// open, so an exercise edited from it shows its new name on return.
class ExerciseListPage extends StatelessWidget {
  const ExerciseListPage({
    super.key,
    required this.title,
    required this.library,
    required this.select,
    this.splitDay = false,
  });

  final String title;
  final ValueListenable<ExerciseLibrary> library;

  /// The exercises this page lists, from the library as it is now.
  final List<Exercise> Function(ExerciseLibrary library) select;

  /// Lists a day of the current split: every exercise is in it, so the page
  /// names the split instead of counting and tagging them.
  final bool splitDay;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: library,
    builder: (context, library, _) {
      final theme = context.theme;
      final exercises = select(library);
      final inSplit = exercises.where(library.inSplit).length;
      final split = library.split;
      final quiet = theme.typography.body.xs.copyWith(
        color: theme.colors.mutedForeground,
      );
      return CustomScrollView(
        slivers: <Widget>[
          CustomAppBar(context, title: title),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverToBoxAdapter(
              child: MaxWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (exercises.isNotEmpty && split != null) ...[
                      Text(
                        splitDay
                            ? '${exerciseCount(exercises.length)} in '
                                  '${split.title}'
                            : '${exerciseCount(exercises.length)}, '
                                  '${inSplitLabel(inSplit, exercises.length).toLowerCase()}',
                        style: quiet,
                      ),
                      if (!splitDay) ...[
                        const SizedBox(height: 8),
                        CoverageBar(filled: inSplit, total: exercises.length),
                      ],
                      const SizedBox(height: 16),
                    ],
                    if (exercises.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'No exercises here any more.',
                          textAlign: TextAlign.center,
                          style: theme.typography.body.sm.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      )
                    else
                      ItemCard(
                        divider: .full,
                        children: [
                          for (final exercise in exercises)
                            exerciseItem(
                              context,
                              library,
                              exercise,
                              marksSplit: !splitDay,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// The group with [key] in [grouping], as the library is now.
List<Exercise> groupExercises(
  ExerciseLibrary library,
  ExerciseGrouping grouping,
  String key,
) {
  for (final group in library.groupsBy(grouping)) {
    if (group.key == key) return group.exercises;
  }
  return const [];
}

/// Opens [group]'s exercises on a page of their own.
void openGroup(
  BuildContext context,
  ValueListenable<ExerciseLibrary> source,
  ExerciseGrouping grouping,
  LibraryGroup group,
) => pushTo(
  context,
  ExerciseListPage(
    title: group.title,
    library: source,
    select: (library) => groupExercises(library, grouping, group.key),
    splitDay: grouping == ExerciseGrouping.splitDay,
  ),
);

/// Opens every exercise, A to Z.
void openAllExercises(
  BuildContext context,
  ValueListenable<ExerciseLibrary> source,
) => pushTo(
  context,
  ExerciseListPage(
    title: 'All exercises',
    library: source,
    select: (library) => library.exercises,
  ),
);
