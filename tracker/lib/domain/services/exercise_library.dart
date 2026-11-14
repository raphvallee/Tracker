import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/muscle.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/fuzzy_search.dart';
import 'package:tracker/domain/services/session_summary.dart';
import 'package:tracker/domain/services/split_rotation.dart';

/// The muscle groups in the order the library lists them.
const muscleGroupOrder = <MuscleGroup>[
  MuscleGroup.chest,
  MuscleGroup.back,
  MuscleGroup.legs,
  MuscleGroup.shoulders,
  MuscleGroup.arms,
  MuscleGroup.abdominals,
];

/// Equipment in the order the library lists it.
const _equipmentOrder = <Equipment>[
  Equipment.machine,
  Equipment.cable,
  Equipment.dumbbell,
  Equipment.barbell,
  Equipment.bodyweight,
];

String muscleGroupLabel(MuscleGroup group) => switch (group) {
  MuscleGroup.abdominals => 'Abdominals',
  MuscleGroup.arms => 'Arms',
  MuscleGroup.shoulders => 'Shoulders',
  MuscleGroup.back => 'Back',
  MuscleGroup.legs => 'Legs',
  MuscleGroup.chest => 'Chest',
};

/// A muscle's everyday name: "Lats", "Front delts", "Quads".
String muscleLabel(Muscle muscle) => switch (muscle) {
  Muscle.abdominals => 'Abs',
  Muscle.obliques => 'Obliques',
  Muscle.biceps => 'Biceps',
  Muscle.triceps => 'Triceps',
  Muscle.frontDelts => 'Front delts',
  Muscle.sideDelts => 'Side delts',
  Muscle.rearDelts => 'Rear delts',
  Muscle.lowerBack => 'Lower back',
  Muscle.lats => 'Lats',
  Muscle.traps => 'Traps',
  Muscle.chest => 'Chest',
  Muscle.glutes => 'Glutes',
  Muscle.gastroc => 'Calves',
  Muscle.soleus => 'Soleus',
  Muscle.hamstrings => 'Hamstrings',
  Muscle.quadriceps => 'Quads',
};

String movementLabel(MovementPattern pattern) => switch (pattern) {
  MovementPattern.unspecified => 'Other',
  MovementPattern.push => 'Push',
  MovementPattern.pull => 'Pull',
  MovementPattern.legs => 'Legs',
  MovementPattern.core => 'Core',
  MovementPattern.fullBody => 'Full body',
};

/// [exercises] under each muscle group their target muscles belong to: an
/// exercise for two muscles of one group is listed once.
Map<MuscleGroup, List<Exercise>> groupExercisesByMuscle(
  List<Exercise> exercises,
) {
  final grouped = <MuscleGroup, List<Exercise>>{};
  for (final exercise in exercises) {
    for (final group in _groupsOf(exercise)) {
      grouped.putIfAbsent(group, () => []).add(exercise);
    }
  }
  return grouped;
}

Set<MuscleGroup> _groupsOf(Exercise exercise) => {
  for (final muscle in exercise.primaryMuscle) Muscle.muscleToGroup[muscle]!,
};

/// The last time an exercise was trained, and its top set that day (see
/// [topSetOf]).
class ExerciseActivity {
  const ExerciseActivity({required this.lastTrained, required this.topSet});

  final DateTime lastTrained;
  final WorkoutSet topSet;
}

/// Each exercise logged in [sessions], by id, with its latest workout.
Map<int, ExerciseActivity> exerciseActivityOf(
  Iterable<WorkoutSession> sessions,
) {
  final newestFirst = sessions.toList()
    ..sort((a, b) => b.startTime.compareTo(a.startTime));
  final found = <int, ExerciseActivity>{};
  for (final session in newestFirst) {
    for (final logged in groupByExercise(session.sets)) {
      if (found.containsKey(logged.exerciseId)) continue;
      if (logged.topSet case final top?) {
        found[logged.exerciseId] = ExerciseActivity(
          lastTrained: session.startTime,
          topSet: top,
        );
      }
    }
  }
  return found;
}

/// Where each session started from a split day sits in its split, for
/// [currentSplitOf].
List<SplitDayVisit> splitVisitsOf(Iterable<WorkoutSession> sessions) => [
  for (final session in sessions)
    if ((session.splitId, session.splitDayIndex) case (
      final splitId?,
      final dayIndex?,
    ))
      SplitDayVisit(
        splitId: splitId,
        dayIndex: dayIndex,
        startTime: session.startTime,
      ),
];

/// A split day's name, or "Day 2" when it has none.
String splitDayTitle(WorkoutSplitDay day, int index) =>
    day.title.trim().isEmpty ? 'Day ${index + 1}' : day.title.trim();

/// What the library is sorted into: muscle groups, the days of the current
/// split, or equipment.
enum ExerciseGrouping { muscle, splitDay, equipment }

/// One line of a group's breakdown: how many of its exercises work a muscle
/// (for split days and equipment, a muscle group), and how many of those
/// are in the current split.
class LibraryPart {
  const LibraryPart({
    required this.label,
    required this.total,
    required this.inSplit,
  });

  final String label;
  final int total;
  final int inSplit;

  @override
  bool operator ==(Object other) =>
      other is LibraryPart &&
      label == other.label &&
      total == other.total &&
      inSplit == other.inSplit;

  @override
  int get hashCode => Object.hash(label, total, inSplit);

  @override
  String toString() => 'LibraryPart($label, $inSplit of $total)';
}

/// A muscle group, split day or piece of equipment and its exercises: A to
/// Z, or a split day's in the day's order.
class LibraryGroup {
  const LibraryGroup({
    required this.key,
    required this.title,
    required this.exercises,
    required this.inSplit,
    required this.parts,
  });

  /// Stays the same for the same group across reloads: "muscle-back",
  /// "day-0".
  final String key;
  final String title;
  final List<Exercise> exercises;

  /// How many of [exercises] are in the current split.
  final int inSplit;
  final List<LibraryPart> parts;
}

/// The exercise library with when each exercise was last trained and which
/// ones the current split uses: what the Exercises tab shows, worked out
/// once per load.
class ExerciseLibrary {
  ExerciseLibrary({
    required List<Exercise> exercises,
    this.activity = const {},
    this.split,
    required this.now,
  }) : exercises = List.unmodifiable(
         [...exercises]..sort((a, b) => _byTitle(a.title, b.title)),
       ),
       _inSplit = {
         for (final day in split?.splitDays ?? const <WorkoutSplitDay>[])
           for (final item in day.exercises) item.exerciseId,
       };

  /// The library from what is saved. Its split is the one the Workout tab
  /// trains from: [currentSplitId]'s, else the last trained (see
  /// [currentSplitOf]).
  factory ExerciseLibrary.read({
    required List<Exercise> exercises,
    required Iterable<WorkoutSession> sessions,
    List<WorkoutSplit> splits = const [],
    int? currentSplitId,
    required DateTime now,
  }) => ExerciseLibrary(
    exercises: exercises,
    activity: exerciseActivityOf(sessions),
    split: currentSplitOf(
      splits,
      splitVisitsOf(sessions),
      currentSplitId: currentSplitId,
    ),
    now: now,
  );

  static int _byTitle(String a, String b) {
    final folded = a.toLowerCase().compareTo(b.toLowerCase());
    return folded != 0 ? folded : a.compareTo(b);
  }

  /// Every exercise, A to Z.
  final List<Exercise> exercises;

  /// The latest workout of each exercise ever logged, by exercise id.
  final Map<int, ExerciseActivity> activity;

  /// The current split; null when there are no splits.
  final WorkoutSplit? split;
  final DateTime now;

  final Set<int> _inSplit;
  final Map<ExerciseGrouping, List<LibraryGroup>> _groups = {};
  List<Exercise>? _recent;

  bool get isEmpty => exercises.isEmpty;

  ExerciseActivity? activityOf(Exercise exercise) => activity[exercise.id];

  /// Planned on some day of the current split.
  bool inSplit(Exercise exercise) => _inSplit.contains(exercise.id);

  /// The exercises ever trained, the most recently trained first.
  List<Exercise> get recentlyTrained => _recent ??= List.unmodifiable(
    exercises.where((e) => activity.containsKey(e.id)).toList()..sort(
      (a, b) =>
          activity[b.id]!.lastTrained.compareTo(activity[a.id]!.lastTrained),
    ),
  );

  /// The library sorted by [grouping], empty groups left out. Split days
  /// are none without a split.
  List<LibraryGroup> groupsBy(ExerciseGrouping grouping) =>
      _groups[grouping] ??= List.unmodifiable(
        switch (grouping) {
          ExerciseGrouping.muscle => _byMuscle(),
          ExerciseGrouping.splitDay => _bySplitDay(),
          ExerciseGrouping.equipment => [
            for (final equipment in _equipmentOrder)
              _group(
                'equipment-${equipment.name}',
                equipment.displayName,
                exercises.where((e) => e.equipment.contains(equipment)),
              ),
          ],
        }.whereType<LibraryGroup>(),
      );

  List<LibraryGroup?> _byMuscle() => [
    for (final group in muscleGroupOrder)
      _group(
        'muscle-${group.name}',
        muscleGroupLabel(group),
        exercises.where((e) => _groupsOf(e).contains(group)),
        parts: (members) => [
          for (final muscle in Muscle.values)
            if (Muscle.muscleToGroup[muscle] == group)
              _part(
                muscleLabel(muscle),
                members.where((e) => e.primaryMuscle.contains(muscle)),
              ),
        ],
      ),
  ];

  List<LibraryGroup?> _bySplitDay() {
    final byId = {for (final exercise in exercises) exercise.id: exercise};
    return [
      for (final (i, day) in (split?.splitDays ?? const []).indexed)
        _group('day-$i', splitDayTitle(day, i), {
          // Each exercise once, in the day's order; one since deleted from
          // the library is left out.
          for (final item in day.exercises) ?byId[item.exerciseId],
        }),
    ];
  }

  /// A group of [members], broken down by [parts] (by muscle group unless
  /// given); null when it has no exercises.
  LibraryGroup? _group(
    String key,
    String title,
    Iterable<Exercise> members, {
    List<LibraryPart?> Function(List<Exercise> members)? parts,
  }) {
    final list = List<Exercise>.unmodifiable(members);
    if (list.isEmpty) return null;
    final breakdown =
        parts?.call(list) ??
        [
          for (final group in muscleGroupOrder)
            _part(
              muscleGroupLabel(group),
              list.where((e) => _groupsOf(e).contains(group)),
            ),
        ];
    return LibraryGroup(
      key: key,
      title: title,
      exercises: list,
      inSplit: list.where(inSplit).length,
      parts: List.unmodifiable(breakdown.whereType<LibraryPart>()),
    );
  }

  LibraryPart? _part(String label, Iterable<Exercise> members) {
    final list = members.toList();
    if (list.isEmpty) return null;
    return LibraryPart(
      label: label,
      total: list.length,
      inSplit: list.where(inSplit).length,
    );
  }

  /// The exercises [text] finds: each typed word must find a word of the
  /// name, the equipment, a target muscle, its group or its movement, typos
  /// forgiven. Names that match come first; each part A to Z.
  List<Exercise> search(String text) {
    final query = FuzzyQuery(text);
    if (query.isEmpty) return exercises;
    final byName = <Exercise>[];
    final byOther = <Exercise>[];
    for (final exercise in exercises) {
      final name = searchWords(exercise.title);
      if (query.findsAll(name)) {
        byName.add(exercise);
      } else if (query.findsAll([...name, ..._otherWords(exercise)])) {
        byOther.add(exercise);
      }
    }
    return [...byName, ...byOther];
  }

  static Iterable<String> _otherWords(Exercise exercise) => searchWords(
    [
      for (final equipment in exercise.equipment) equipment.displayName,
      for (final muscle in exercise.primaryMuscle) muscleLabel(muscle),
      for (final group in _groupsOf(exercise)) muscleGroupLabel(group),
      movementLabel(exercise.movementPattern),
    ].join(' '),
  );
}
