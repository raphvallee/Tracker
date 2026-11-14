import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/exercise_library.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/dashed_outline.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/exercises/widgets/exercise_detail_page.dart';
import 'package:tracker/ui/exercises/widgets/new_exercise_page.dart';

/// The pieces the three Exercises tab layouts share: rows, the recently
/// trained strip, the gauges and the tile that adds an exercise.

/// A set in one line: "80 kg × 8", or "12 reps" for a set without weight.
String topSetLabel(BuildContext context, WorkoutSet set) => set.weight == 0
    ? (set.reps == 1 ? '1 rep' : '${formatReps(set.reps)} reps')
    : '${formatWeight(context, set.weight)} × ${formatReps(set.reps)}';

/// When an exercise was last trained, as a sentence start: "Yesterday",
/// "3 days ago".
String lastTrainedLabel(DateTime date, DateTime now) {
  final label = agoLabel(date, now: now);
  return label[0].toUpperCase() + label.substring(1);
}

/// [items] as a sentence list: "a", "a and b", "a, b and c".
String andList(List<String> items) => switch (items.length) {
  0 => '',
  1 => items.first,
  _ =>
    '${items.sublist(0, items.length - 1).join(', ')} and '
        '${items.last}',
};

/// What an exercise needs and works, in one line: "Barbell, lats and
/// traps".
String exerciseSubtitle(Exercise exercise) {
  final worked = andList([
    for (final muscle in exercise.primaryMuscle)
      muscleLabel(muscle).toLowerCase(),
  ]);
  return [
    if (exercise.equipment.isNotEmpty)
      exercise.equipment.map((e) => e.displayName).join(', '),
    if (worked.isNotEmpty) worked,
  ].join(', ');
}

/// "4 of 7 in your split", "None in your split".
String inSplitLabel(int inSplit, int total) => inSplit == 0
    ? 'None in your split'
    : inSplit == total
    ? (total == 1 ? 'In your split' : 'All $total in your split')
    : '$inSplit of $total in your split';

/// "7 exercises", "1 exercise".
String exerciseCount(int n) => n == 1 ? '1 exercise' : '$n exercises';

/// What a group of exercises works, from its breakdown: "Chest, shoulders
/// and arms".
String worksLabel(LibraryGroup group) {
  final label = andList([
    for (final part in group.parts) part.label.toLowerCase(),
  ]);
  return label.isEmpty ? '' : label[0].toUpperCase() + label.substring(1);
}

void openExercise(BuildContext context, Exercise exercise) =>
    pushTo(context, ExerciseDetailPage(exercise: exercise));

void openNewExercise(BuildContext context) =>
    pushTo(context, const NewExercisePage());

/// The way every press in the library answers: a short dim while held.
class PressFade extends StatelessWidget {
  const PressFade({
    super.key,
    required this.onPress,
    required this.child,
    this.semanticsLabel,
    this.selected = false,
  });

  final VoidCallback onPress;
  final Widget child;
  final String? semanticsLabel;
  final bool selected;

  @override
  Widget build(BuildContext context) => FTappable(
    onPress: onPress,
    semanticsLabel: semanticsLabel,
    selected: selected,
    builder: (context, states, child) => AnimatedOpacity(
      duration: const Duration(milliseconds: 100),
      opacity: states.contains(FTappableVariant.pressed) ? 0.7 : 1,
      child: child,
    ),
    child: child,
  );
}

/// The outlined box tiles and strip cards sit in.
BoxDecoration tileDecoration(BuildContext context, {bool selected = false}) {
  final colors = context.theme.colors;
  return BoxDecoration(
    color: colors.card,
    border: Border.all(
      color: selected ? colors.foreground : colors.border,
      width: selected ? 1.5 : 1,
    ),
    borderRadius: BorderRadius.circular(12),
  );
}

/// A heading over a part of the hub, with an optional action on its right.
class HubHeading extends StatelessWidget {
  const HubHeading({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (action case final action?)
            PressFade(
              onPress: onAction ?? () {},
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  action,
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One exercise in a card of rows: its name, tagged when it is in the
/// current split (unless [marksSplit] is off, in a list of one split day),
/// what it needs and works, then last time's top set and when.
FItem exerciseItem(
  BuildContext context,
  ExerciseLibrary library,
  Exercise exercise, {
  bool marksSplit = true,
}) {
  final theme = context.theme;
  final activity = library.activityOf(exercise);
  final quiet = theme.typography.body.xs.copyWith(
    color: theme.colors.mutedForeground,
  );
  final tagged = marksSplit && library.inSplit(exercise);
  return FItem(
    key: ValueKey<String>('exercise-${exercise.id}'),
    title: Row(
      children: <Widget>[
        Flexible(
          child: Text(
            exercise.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (tagged) ...[const SizedBox(width: 6), const InSplitTag()],
      ],
    ),
    subtitle: Text(
      exerciseSubtitle(exercise),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    suffix: activity == null
        ? Text('Not trained yet', style: quiet)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                topSetLabel(context, activity.topSet),
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.foreground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                lastTrainedLabel(activity.lastTrained, library.now),
                style: quiet,
              ),
            ],
          ),
    onPress: () => openExercise(context, exercise),
  );
}

/// The exercises trained most recently, side by side, scrolling sideways:
/// each with last time's top set and when.
class RecentStrip extends StatelessWidget {
  const RecentStrip({super.key, required this.library, this.limit = 10});

  final ExerciseLibrary library;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final recent = library.recentlyTrained.take(limit).toList();
    // At most [limit] cards, so they are all built: the row is as tall as
    // its tallest card, whatever the text size.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (i, exercise) in recent.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              _RecentCard(library: library, exercise: exercise),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.library, required this.exercise});

  final ExerciseLibrary library;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final activity = library.activityOf(exercise)!;
    return PressFade(
      key: ValueKey<String>('recent-${exercise.id}'),
      onPress: () => openExercise(context, exercise),
      child: Container(
        width: 132,
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
        decoration: tileDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              exercise.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.xs.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const SizedBox(height: 10),
            // Shrunk to fit rather than cut: a heavy set's number is the
            // point of the card.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                topSetLabel(context, activity.topSet),
                maxLines: 1,
                style: theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              lastTrainedLabel(activity.lastTrained, library.now),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A ring filled as far as [filled] goes into [total]: how many of a
/// group's exercises are in the current split.
class CoverageRing extends StatelessWidget {
  const CoverageRing({
    super.key,
    required this.filled,
    required this.total,
    this.size = 30,
  });

  final int filled;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Semantics(
      label: inSplitLabel(filled, total),
      child: CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          fraction: total == 0 ? 0 : filled / total,
          track: colors.secondary,
          fill: colors.foreground,
        ),
      ),
    );
  }
}

/// The small outlined "In split" mark beside an exercise the current split
/// plans.
class InSplitTag extends StatelessWidget {
  const InSplitTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colors.mutedForeground),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'In split',
        maxLines: 1,
        style: theme.typography.body.xs.copyWith(
          fontSize: 10.5,
          height: 1,
          fontWeight: FontWeight.w600,
          color: theme.colors.mutedForeground,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.5;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * fraction.clamp(0, 1),
        false,
        paint..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      fraction != old.fraction || track != old.track || fill != old.fill;
}

/// A dash per exercise, [filled] of them filled (the ones in the current
/// split); past
/// [maxDashes] it is one continuous bar filled as far.
class CoverageBar extends StatelessWidget {
  const CoverageBar({
    super.key,
    required this.filled,
    required this.total,
    this.height = 4,
    this.maxDashes = 12,
  });

  final int filled;
  final int total;
  final double height;
  final int maxDashes;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    if (total > maxDashes) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: colors.secondary),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: total == 0 ? 0 : filled / total,
                child: ColoredBox(color: colors.foreground),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i < filled ? colors.foreground : colors.secondary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A square per exercise, [filled] of them filled (the ones in the
/// current split), at most
/// [maxSquares] (more read as a short bar).
class SquareCount extends StatelessWidget {
  const SquareCount({
    super.key,
    required this.filled,
    required this.total,
    this.maxSquares = 6,
  });

  final int filled;
  final int total;
  final int maxSquares;

  static const double _square = 7;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    if (total > maxSquares) {
      final width = maxSquares * (_square + 2) - 2;
      return SizedBox(
        width: width,
        child: CoverageBar(
          filled: filled,
          total: total,
          height: _square,
          maxDashes: 0,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: _square,
            height: _square,
            decoration: BoxDecoration(
              color: i < filled ? colors.foreground : colors.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}

/// The dashed tile that adds an exercise, last in a grid of groups.
class NewExerciseTile extends StatelessWidget {
  const NewExerciseTile({super.key, this.minHeight = 84});

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return PressFade(
      onPress: () => openNewExercise(context),
      child: CustomPaint(
        painter: DashedOutline(
          color: theme.colors.border,
          radius: 12,
          width: 1.5,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(FLucideIcons.plus, size: 20),
                const SizedBox(height: 6),
                Text(
                  'New exercise',
                  style: theme.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [cells] two to a row (more on a wide window), each row as tall as its
/// tallest cell.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.cells, this.minCellWidth = 160});

  final List<Widget> cells;
  final double minCellWidth;

  static const double gap = 8;

  static int columnsFor(double width, {double minCellWidth = 160}) =>
      (width / minCellWidth).floor().clamp(2, 4);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = columnsFor(
        constraints.maxWidth,
        minCellWidth: minCellWidth,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var row = 0; row < cells.length; row += columns) ...[
            if (row > 0) const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = row; i < row + columns; i++) ...[
                    if (i > row) const SizedBox(width: gap),
                    Expanded(
                      child: i < cells.length
                          ? cells[i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}
