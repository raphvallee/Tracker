import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/split_rotation.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/accent_button.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/dashed_outline.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/splits/widgets/new_split_sheet.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'day_preview_sheet.dart';
import 'gym_picker.dart';
import 'start_workout.dart';
import 'workout_dock.dart';

/// The Workout tab before a workout: the day that is due next with its plan,
/// the split's other days in the order they come up (a tap previews, the play
/// button starts), and the quiet links: another split, an empty workout, the
/// restore of a workout that just ended. Start is docked at the bottom, over
/// the gym the workout starts at.
class StartView extends StatefulWidget {
  const StartView({super.key, this.canRestore = false});

  /// Whether a workout that just ended or was discarded can come back.
  final bool canRestore;

  @override
  State<StartView> createState() => _StartViewState();
}

class _StartViewState extends State<StartView> {
  final List<StreamSubscription<Object?>> _subscriptions = [];
  List<WorkoutSplit>? _splits;
  List<SplitDayVisit> _visits = const [];
  List<Gym> _gyms = const [];
  Map<int, String> _names = const {};
  bool _didLoad = false;
  Timer? _windowTicker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) {
      _splits = const [];
      return;
    }
    _subscriptions
      ..add(
        repo.splits.watchAll().listen(
          (splits) => setState(
            () =>
                _splits = [...splits]
                  ..sort((a, b) => a.order.compareTo(b.order)),
          ),
        ),
      )
      ..add(repo.gyms.watchAll().listen((gyms) => setState(() => _gyms = gyms)))
      ..add(
        repo.exercises.watchAll().listen(
          (exercises) => setState(
            () => _names = {
              for (final exercise in exercises) exercise.id: exercise.title,
            },
          ),
        ),
      )
      ..add(repo.sessions.watchChanges().listen((_) => _loadVisits()));
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    final visits = await RepositoryScope.maybeOf(context)?.sessions
        .getSplitVisits();
    if (!mounted || visits == null) return;
    setState(() => _visits = visits);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _windowTicker?.cancel();
    super.dispose();
  }

  Future<void> _pickGym(BuildContext context) async {
    final cubit = context.read<WorkoutCubit>();
    final picked = await showGymPicker(
      context,
      _gyms,
      currentId: startGymOf(_gyms, cubit.state.nextGymId)?.id,
      oneWorkoutOnly: true,
    );
    if (picked is Gym) cubit.pickNextGym(picked);
  }

  void _preview(BuildContext context, UpNext upNext, int dayIndex) {
    showDayPreview(
      context,
      split: upNext.split,
      dayIndex: dayIndex,
      names: _names,
      lastDone: upNext.lastDone[dayIndex],
    );
  }

  @override
  Widget build(BuildContext context) {
    final workout = context.read<WorkoutCubit>().state;
    // The restore window lapses with wall-clock time, which no cubit state
    // change announces. While it is live, tick periodically so the restore
    // button disappears on time (and stays away afterwards).
    final canRestore =
        widget.canRestore &&
        (workout.canRestoreSaved() || workout.canRestoreDiscarded());
    _windowTicker?.cancel();
    _windowTicker = canRestore
        ? Timer.periodic(const Duration(seconds: 30), (_) {
            if (mounted) setState(() {});
          })
        : null;

    final splits = _splits;
    if (splits == null) {
      return CustomScrollView(
        slivers: <Widget>[CustomAppBar(context, title: 'Workout')],
      );
    }
    return _withCurrentSplit((currentSplitId) {
      final next = splits.isEmpty
          ? null
          : upNext(splits, _visits, currentSplitId: currentSplitId);
      final nextDay = next?.dayIndex;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: CustomScrollView(
              slivers: <Widget>[
                CustomAppBar(context, title: 'Workout'),
                SliverToBoxAdapter(
                  child: MaxWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (next == null)
                            const _FirstRun()
                          else
                            _splitStart(context, next),
                          _links(
                            context,
                            splits: splits,
                            current: next?.split,
                            emptyWorkout: nextDay != null,
                            canRestore: canRestore,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _dock(context, next),
        ],
      );
    });
  }

  /// The one next step: start the day that is due, or with no day to start,
  /// an empty workout. The gym it starts at sits right above.
  Widget _dock(BuildContext context, UpNext? next) {
    final dayIndex = next?.dayIndex;
    return BlocSelector<WorkoutCubit, WorkoutState, int?>(
      selector: (state) => state.nextGymId,
      builder: (context, nextGymId) {
        final gym = startGymOf(_gyms, nextGymId);
        return WorkoutDock(
          above: gym == null
              ? null
              : _GymLine(name: gym.name, onPress: () => _pickGym(context)),
          child: next == null || dayIndex == null
              ? AccentButton(
                  large: true,
                  prefix: FLucideIcons.play,
                  label: 'Start empty workout',
                  onPress: () => startEmptyWorkout(context),
                )
              : AccentButton(
                  large: true,
                  prefix: FLucideIcons.play,
                  label: 'Start ${next.split.splitDays[dayIndex].title}',
                  onPress: () => startSplitDay(
                    context,
                    split: next.split,
                    dayIndex: dayIndex,
                    names: _names,
                  ),
                ),
        );
      },
    );
  }

  /// The ways to train that are not the day due: rarely used, so they stay
  /// one row of quiet links.
  Widget _links(
    BuildContext context, {
    required List<WorkoutSplit> splits,
    required WorkoutSplit? current,
    required bool emptyWorkout,
    required bool canRestore,
  }) {
    final links = <Widget>[
      if (current != null && splits.length > 1)
        _link(
          'Another split',
          () => _showOtherSplits(context, splits, current),
        ),
      if (emptyWorkout)
        _link('Empty workout', () => startEmptyWorkout(context)),
      if (canRestore)
        _link(
          'Restore last workout',
          context.read<WorkoutCubit>().restoreLastWorkout,
          icon: FLucideIcons.rotateCcw,
        ),
    ];
    if (links.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(alignment: WrapAlignment.center, spacing: 4, children: links),
    );
  }

  Widget _link(String label, VoidCallback onPress, {IconData? icon}) => FButton(
    variant: .ghost,
    size: .sm,
    mainAxisSize: .min,
    onPress: onPress,
    prefix: icon == null ? null : Icon(icon),
    child: Text(label),
  );

  Widget _withCurrentSplit(Widget Function(int? currentSplitId) builder) {
    if (SettingsCubit.maybeOf(context) == null) return builder(null);
    return BlocSelector<SettingsCubit, SettingsState, int?>(
      selector: (settings) => settings.currentSplitId,
      builder: (context, currentSplitId) => builder(currentSplitId),
    );
  }

  Widget _splitStart(BuildContext context, UpNext upNext) {
    final theme = context.theme;
    final split = upNext.split;
    final next = upNext.dayIndex;
    final days = split.splitDays.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Up next in ${split.title}',
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        if (next == null)
          _NoDays(split: split)
        else
          _UpNextCard(
            split: split,
            dayIndex: next,
            names: _names,
            lastDone: upNext.lastDone[next],
            onPreview: () => _preview(context, upNext, next),
          ),
        if (next != null && days > 1) ...[
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 6),
            child: Text(
              'Then',
              style: theme.typography.body.xs.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FCard(
            child: FItemGroup(
              divider: .full,
              children: <FItem>[
                // In the order the rotation brings them up.
                for (var step = 1; step < days; step++)
                  _dayItem(
                    context,
                    key: ValueKey(
                      'start-day-${split.id}-${(next + step) % days}',
                    ),
                    day: split.splitDays[(next + step) % days],
                    lastDone: upNext.lastDone[(next + step) % days],
                    onStart: () => startSplitDay(
                      context,
                      split: split,
                      dayIndex: (next + step) % days,
                      names: _names,
                    ),
                    onPreview: () =>
                        _preview(context, upNext, (next + step) % days),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  FItem _dayItem(
    BuildContext context, {
    required Key key,
    required WorkoutSplitDay day,
    required DateTime? lastDone,
    required VoidCallback onStart,
    required VoidCallback onPreview,
  }) {
    final accents = TrackerAccents.of(context);
    final count = day.exercises.length;
    return FItem(
      key: key,
      title: Text(day.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        lastDone == null
            ? plural('exercise', count)
            : '${plural('exercise', count)}, last done ${dayLabel(lastDone)}',
        overflow: TextOverflow.ellipsis,
      ),
      // The row previews the day; only the play button starts it.
      suffix: FTappable(
        semanticsLabel: 'Start ${day.title}',
        onPress: onStart,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accents.live, width: 1.5),
          ),
          child: Icon(FLucideIcons.play, size: 16, color: accents.live),
        ),
      ),
      onPress: onPreview,
    );
  }

  void _showOtherSplits(
    BuildContext context,
    List<WorkoutSplit> saved,
    WorkoutSplit current,
  ) {
    // Listed as the Splits tab lists them: most recently used first.
    final settings = SettingsCubit.maybeOf(context)?.state;
    final splits = splitsByLastUsed(
      saved,
      _visits,
      currentSplitId: settings?.currentSplitId,
      usedAt: settings?.splitsUsedAt ?? const {},
    );
    showFSheet<void>(
      context: context,
      side: .btt,
      useRootNavigator: true,
      mainAxisMaxRatio: 0.85,
      builder: (sheetContext) {
        final theme = sheetContext.theme;
        return SheetSurface(
          scrollable: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Start from another split',
                style: theme.typography.body.lg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final split in splits)
                if (split.id != current.id) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 6),
                    child: Text(
                      split.title,
                      style: theme.typography.body.xs.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (split.splitDays.isEmpty)
                    Text(
                      'No days yet.',
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    )
                  else
                    ItemCard(
                      divider: .full,
                      children: <FItem>[
                        for (var i = 0; i < split.splitDays.length; i++)
                          _dayItem(
                            sheetContext,
                            key: ValueKey('other-day-${split.id}-$i'),
                            day: split.splitDays[i],
                            lastDone: lastDoneByDay(split, _visits)[i],
                            onStart: () {
                              Navigator.of(sheetContext).pop();
                              startSplitDay(
                                context,
                                split: split,
                                dayIndex: i,
                                names: _names,
                              );
                            },
                            onPreview: () {
                              Navigator.of(sheetContext).pop();
                              showDayPreview(
                                context,
                                split: split,
                                dayIndex: i,
                                names: _names,
                                lastDone: lastDoneByDay(split, _visits)[i],
                              );
                            },
                          ),
                      ],
                    ),
                ],
            ],
          ),
        );
      },
    );
  }
}

/// "4 × 8-12" for an exercise whose working sets share a target, else its
/// working set count.
String _compactSets(PlanExercise exercise) {
  final working = [
    for (final set in exercise.sets)
      if (!set.isWarmup) SetTarget.fromPlanned(set),
  ];
  if (working.isEmpty) return '';
  return working.every((target) => target == working.first)
      ? '${working.length} × ${working.first.label}'
      : plural('set', working.length);
}

/// The day that is due: its name, what it holds and its first exercises. A
/// tap previews the whole day.
class _UpNextCard extends StatelessWidget {
  const _UpNextCard({
    required this.split,
    required this.dayIndex,
    required this.names,
    required this.lastDone,
    required this.onPreview,
  });

  final WorkoutSplit split;
  final int dayIndex;
  final Map<int, String> names;
  final DateTime? lastDone;
  final VoidCallback onPreview;

  /// Exercises listed before the rest folds into "2 more".
  static const _listed = 4;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final day = split.splitDays[dayIndex];
    final plan = planOf(
      split,
      dayIndex,
      names,
      fallback: defaultSetTargetOf(context),
    );
    final sets = plan.fold(
      0,
      (total, exercise) => total + exercise.sets.length,
    );
    final last = lastDone;
    final facts = plan.isEmpty
        ? 'No exercises yet.'
        : '${plural('exercise', plan.length)}, ${plural('set', sets)}. '
              '${last == null ? 'Not done yet.' : 'Last done ${dayLabel(last)}.'}';
    final shown = plan.length > _listed ? _listed - 1 : plan.length;
    return FTappable(
      semanticsLabel: 'Preview ${day.title}',
      onPress: onPreview,
      child: FCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                day.title,
                style: theme.typography.body.xl2.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(facts, style: muted),
              if (plan.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: theme.colors.border),
                const SizedBox(height: 8),
                for (final exercise in plan.take(shown))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            exercise.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.body.sm,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_compactSets(exercise), style: muted),
                      ],
                    ),
                  ),
                if (plan.length > shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('${plan.length - shown} more', style: muted),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The gym the workout starts at, as a fact that can be corrected: the name
/// and Change. Nothing asks for it; home is assumed.
class _GymLine extends StatelessWidget {
  const _GymLine({required this.name, required this.onPress});

  final String name;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = theme.typography.body.xs.copyWith(
      fontWeight: FontWeight.w600,
    );
    return FTappable(
      semanticsLabel: 'Gym: $name. Change gym',
      onPress: onPress,
      child: SizedBox(
        height: 40,
        child: Row(
          children: <Widget>[
            const Icon(FLucideIcons.mapPin, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Change',
              style: style.copyWith(color: theme.colors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDays extends StatelessWidget {
  const _NoDays({required this.split});

  final WorkoutSplit split;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${split.title} has no days yet',
              style: theme.typography.body.md.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add days like Push, Pull and Legs, and the next one will be '
              'waiting here.',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            FButton(
              variant: .outline,
              onPress: () => HomePageSingleton().changeTab(TabName.splits),
              child: const Text('Add days in Splits'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirstRun extends StatelessWidget {
  const _FirstRun();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.colors.mutedForeground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    for (final (i, day) in [
                      'Push',
                      'Pull',
                      'Legs',
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(child: _DayTile(label: day)),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Plan your split',
                  style: theme.typography.body.xl.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'A split is your training plan, broken into days like '
                  'Push, Pull and Legs. Plan one and the day you are due '
                  'will be waiting here.',
                  style: theme.typography.body.xs.copyWith(color: muted),
                ),
                const SizedBox(height: 14),
                FButton(
                  variant: .outline,
                  onPress: () {
                    HomePageSingleton().changeTab(TabName.splits);
                    showNewSplitSheet(context);
                  },
                  child: const Text('Plan a split'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            'Or just train: start an empty workout and add exercises as '
            'you go.',
            textAlign: TextAlign.center,
            style: theme.typography.body.xs.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// One dashed placeholder day of the first-run split illustration.
class _DayTile extends StatelessWidget {
  const _DayTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return CustomPaint(
      painter: DashedOutline(
        color: theme.colors.mutedForeground.withValues(alpha: 0.6),
      ),
      child: SizedBox(
        height: 52,
        child: Center(
          child: Text(
            label,
            style: theme.typography.body.xs.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
