import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/services/exercise_library.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/exercises/widgets/exercise_list_page.dart';
import 'package:tracker/ui/exercises/widgets/library_parts.dart';

/// The library as a list of groups: recently trained exercises on top,
/// then a row per muscle group with a ring for how many of its exercises
/// are in the current split, then a row per day of that split (named after
/// it) and per piece of equipment. A row opens its group on a page of its
/// own.
class LibraryRows extends StatelessWidget {
  const LibraryRows({super.key, required this.source});

  final ValueListenable<ExerciseLibrary> source;

  @override
  Widget build(BuildContext context) {
    final library = source.value;
    final hasRecent = library.recentlyTrained.isNotEmpty;
    final days = library.groupsBy(ExerciseGrouping.splitDay);
    final all = (
      action: 'All ${library.exercises.length}',
      onAction: () => openAllExercises(context, source),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (hasRecent) ...[
          HubHeading(
            title: 'Recently trained',
            action: all.action,
            onAction: all.onAction,
          ),
          RecentStrip(library: library),
        ],
        HubHeading(
          title: 'By muscle',
          action: hasRecent ? null : all.action,
          onAction: hasRecent ? null : all.onAction,
        ),
        ItemCard(
          divider: .full,
          children: [
            for (final group in library.groupsBy(ExerciseGrouping.muscle))
              _muscleRow(context, library, group),
          ],
        ),
        if (library.split case final split? when days.isNotEmpty) ...[
          HubHeading(title: split.title),
          ItemCard(
            divider: .full,
            children: [for (final day in days) _dayRow(context, day)],
          ),
        ],
        const HubHeading(title: 'By equipment'),
        ItemCard(
          divider: .full,
          children: [
            for (final group in library.groupsBy(ExerciseGrouping.equipment))
              FItem(
                key: ValueKey<String>('exercise-group-${group.key}'),
                title: Text(group.title),
                details: Text('${group.exercises.length}'),
                suffix: const Icon(FLucideIcons.chevronRight),
                onPress: () => openGroup(
                  context,
                  source,
                  ExerciseGrouping.equipment,
                  group,
                ),
              ),
          ],
        ),
      ],
    );
  }

  FItem _muscleRow(
    BuildContext context,
    ExerciseLibrary library,
    LibraryGroup group,
  ) {
    final total = group.exercises.length;
    final hasSplit = library.split != null;
    return FItem(
      key: ValueKey<String>('exercise-group-${group.key}'),
      title: Text(group.title),
      subtitle: Text(
        hasSplit
            ? '${exerciseCount(total)}, '
                  '${inSplitLabel(group.inSplit, total).toLowerCase()}'
            : exerciseCount(total),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasSplit) ...[
            CoverageRing(filled: group.inSplit, total: total),
            const SizedBox(width: 8),
          ],
          const Icon(FLucideIcons.chevronRight),
        ],
      ),
      onPress: () => openGroup(context, source, ExerciseGrouping.muscle, group),
    );
  }

  /// A day of the split: its name, what it works and how many exercises.
  FItem _dayRow(BuildContext context, LibraryGroup day) => FItem(
    key: ValueKey<String>('exercise-group-${day.key}'),
    title: Text(day.title),
    subtitle: Text(
      worksLabel(day),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    details: Text('${day.exercises.length}'),
    suffix: const Icon(FLucideIcons.chevronRight),
    onPress: () => openGroup(context, source, ExerciseGrouping.splitDay, day),
  );
}
