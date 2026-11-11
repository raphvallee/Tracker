import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/set_prefill.dart';
import 'package:tracker/domain/services/split_rotation.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/accent_button.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/dashed_outline.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/splits/widgets/new_split_sheet.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'gym_picker.dart';
import 'plan_bar.dart';
import 'start_workout.dart';
import 'workout_dock.dart';

/// The Workout tab before a workout: the split's name, whose sheet trains
/// from another split or from an empty workout, then the split's days in a
/// row, the one that is up next opened with its plan (a tap on another day
/// opens that one in its place). Start is docked at the bottom, over the gym
/// the workout starts at, and starts the day that is open.
class StartView extends StatefulWidget {
  const StartView({super.key});

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

  /// The split shown in place of the current one, picked from the split
  /// sheet: for this visit of the tab, the current split stays what it is.
  int? _shownSplitId;

  /// The day opened in place of the one that is up next.
  int? _pickedDay;

  /// Last session's sets by exercise: the plan's "Last 70 kg × 8".
  Map<int, PreviousPerformance> _last = const {};
  final Set<int> _lastAsked = {};

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
      ..add(
        repo.sessions.watchChanges().listen((_) {
          // What was done last may have changed with the sessions.
          _lastAsked.clear();
          _loadVisits();
        }),
      );
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    final visits = await RepositoryScope.maybeOf(context)?.sessions
        .getSplitVisits();
    if (!mounted || visits == null) return;
    setState(() => _visits = visits);
  }

  /// Loads what [exerciseIds] did last time, once per exercise.
  void _ensureLast(Iterable<int> exerciseIds) {
    final missing = [
      for (final id in exerciseIds)
        if (_lastAsked.add(id)) id,
    ];
    if (missing.isEmpty) return;
    RepositoryScope.maybeOf(context)?.sessions
        .getPreviousPerformances(missing)
        .then((found) {
          if (!mounted) return;
          setState(
            () => _last = {
              for (final MapEntry(:key, :value) in _last.entries)
                if (!missing.contains(key)) key: value,
              ...found,
            },
          );
        });
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
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

  /// The split on screen with its rotation: [current], unless another one
  /// was picked from the split sheet.
  UpNext? _shownOf(List<WorkoutSplit> splits, UpNext? current) {
    if (current == null) return null;
    for (final split in splits) {
      if (split.id == _shownSplitId && split.id != current.split.id) {
        return upNext([split], _visits);
      }
    }
    return current;
  }

  /// The day that is open: the one picked in the row, else the one up next.
  int? _dayOf(UpNext? shown) {
    final picked = _pickedDay;
    if (shown == null || shown.dayIndex == null) return null;
    return picked != null && picked < shown.split.splitDays.length
        ? picked
        : shown.dayIndex;
  }

  @override
  Widget build(BuildContext context) {
    final splits = _splits;
    if (splits == null) {
      return CustomScrollView(slivers: <Widget>[_header(context)]);
    }
    return _withCurrentSplit((currentSplitId) {
      final current = splits.isEmpty
          ? null
          : upNext(splits, _visits, currentSplitId: currentSplitId);
      final shown = _shownOf(splits, current);
      final dayIndex = _dayOf(shown);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: CustomScrollView(
              slivers: <Widget>[
                _header(context),
                SliverToBoxAdapter(
                  child: MaxWidth(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (shown == null || current == null)
                            _inset(const _FirstRun(), top: 4)
                          else ...[
                            _inset(
                              _SplitName(
                                title: shown.split.title,
                                onPress: () => _pickSplit(
                                  context,
                                  splits,
                                  currentId: current.split.id,
                                  shownId: shown.split.id,
                                ),
                              ),
                            ),
                            if (dayIndex == null)
                              _inset(_NoDays(split: shown.split), top: 6)
                            else ...[
                              _DayRail(
                                key: ValueKey('day-rail-${shown.split.id}'),
                                split: shown.split,
                                due: shown.dayIndex!,
                                selected: dayIndex,
                                lastDone: shown.lastDone,
                                onSelect: (day) =>
                                    setState(() => _pickedDay = day),
                              ),
                              _inset(
                                _dayPlan(context, shown.split, dayIndex),
                                top: 14,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _dock(context, shown, dayIndex),
        ],
      );
    });
  }

  /// The pinned title.
  Widget _header(BuildContext context) =>
      CustomAppBar(context, title: 'Workout');

  /// The page's side margin: everything keeps it but the row of days, which
  /// runs to the screen edges.
  Widget _inset(Widget child, {double top = 0}) =>
      Padding(padding: EdgeInsets.fromLTRB(16, top, 16, 0), child: child);

  /// The one next step: start the day that is open, or with no day to
  /// start, an empty workout. The gym it starts at sits right above.
  Widget _dock(BuildContext context, UpNext? shown, int? dayIndex) {
    return BlocSelector<WorkoutCubit, WorkoutState, int?>(
      selector: (state) => state.nextGymId,
      builder: (context, nextGymId) {
        final gym = startGymOf(_gyms, nextGymId);
        return WorkoutDock(
          above: gym == null
              ? null
              : _GymLine(name: gym.name, onPress: () => _pickGym(context)),
          child: shown == null || dayIndex == null
              ? AccentButton(
                  large: true,
                  prefix: FLucideIcons.play,
                  label: 'Start empty workout',
                  onPress: () => startEmptyWorkout(context),
                )
              : AccentButton(
                  large: true,
                  prefix: FLucideIcons.play,
                  label: 'Start ${shown.split.splitDays[dayIndex].title}',
                  onPress: () => startSplitDay(
                    context,
                    split: shown.split,
                    dayIndex: dayIndex,
                    names: _names,
                  ),
                ),
        );
      },
    );
  }

  Widget _withCurrentSplit(Widget Function(int? currentSplitId) builder) {
    if (SettingsCubit.maybeOf(context) == null) return builder(null);
    return BlocSelector<SettingsCubit, SettingsState, int?>(
      selector: (settings) => settings.currentSplitId,
      builder: (context, currentSplitId) => builder(currentSplitId),
    );
  }

  /// The open day: its name, when it was last done and how long it took,
  /// the shape of its plan as a bar, then its exercises with what they ask
  /// for and what each did last time.
  Widget _dayPlan(BuildContext context, WorkoutSplit split, int dayIndex) {
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final day = split.splitDays[dayIndex];
    final plan = planOf(
      split,
      dayIndex,
      _names,
      fallback: defaultSetTargetOf(context),
    );
    _ensureLast(plan.map((exercise) => exercise.exerciseId));
    final working = [
      for (final exercise in plan)
        exercise.sets.where((set) => !set.isWarmup).length,
    ];
    final sets = working.fold(0, (total, count) => total + count);
    final visit = lastVisitOf(split, dayIndex, _visits);
    final length = visit?.duration;
    final facts = visit == null
        ? 'Not done yet'
        : 'Last done ${agoLabel(visit.startTime)}'
              '${length == null ? '' : ', in ${lengthLabel(length)}'}';
    return Column(
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
        const SizedBox(height: 4),
        Text(facts, style: muted),
        if (plan.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('No exercises yet. Add some in Splits.', style: muted),
          )
        else ...[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: PlanBar(
                  segments: [
                    for (final count in working) PlanSegment(sets: count),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(plural('set', sets), style: muted),
            ],
          ),
          const SizedBox(height: 6),
          for (final (i, exercise) in plan.indexed)
            _exerciseRow(context, i, exercise, isLast: i == plan.length - 1),
        ],
      ],
    );
  }

  Widget _exerciseRow(
    BuildContext context,
    int index,
    PlanExercise exercise, {
    required bool isLast,
  }) {
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final top = _last[exercise.exerciseId]?.topSet;
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.colors.border)),
            ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (top != null)
                  Text(
                    'Last ${formatWeight(context, top.weight)} × '
                    '${formatReps(top.reps)}',
                    style: muted,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(_compactSets(exercise), style: muted),
        ],
      ),
    );
  }

  /// The split sheet: which split's days this tab shows, and last of all an
  /// empty workout. Picking a split moves the tab, not the current split.
  Future<void> _pickSplit(
    BuildContext context,
    List<WorkoutSplit> saved, {
    required int currentId,
    required int shownId,
  }) async {
    // Listed as the Splits tab lists them: most recently used first.
    final settings = SettingsCubit.maybeOf(context)?.state;
    final splits = splitsByLastUsed(
      saved,
      _visits,
      currentSplitId: settings?.currentSplitId,
      usedAt: settings?.splitsUsedAt ?? const {},
    );
    final picked = await showFSheet<int>(
      context: context,
      side: .btt,
      useRootNavigator: true,
      mainAxisMaxRatio: 0.85,
      builder: (sheetContext) {
        final theme = sheetContext.theme;
        final accents = TrackerAccents.of(sheetContext);
        return SheetSurface(
          scrollable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Train from',
                style: theme.typography.body.lg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              ItemCard(
                divider: .full,
                children: <FItem>[
                  for (final split in splits)
                    FItem(
                      key: ValueKey('train-from-${split.id}'),
                      title: Text(split.title, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        split.id == currentId
                            ? 'Current split, '
                                  '${plural('day', split.splitDays.length)}'
                            : plural('day', split.splitDays.length),
                      ),
                      suffix: split.id == shownId
                          ? Icon(FLucideIcons.check, color: accents.live)
                          : null,
                      selected: split.id == shownId,
                      onPress: () => Navigator.of(sheetContext).pop(split.id),
                    ),
                  FItem(
                    key: const ValueKey('train-from-empty'),
                    title: const Text('Empty workout'),
                    subtitle: const Text('Pick exercises as you go'),
                    onPress: () async {
                      Navigator.of(sheetContext).pop();
                      await startEmptyWorkout(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _shownSplitId = picked;
      _pickedDay = null;
    });
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

/// The split the days below belong to. A tap opens the sheet to train from
/// another split, or from an empty workout.
class _SplitName extends StatelessWidget {
  const _SplitName({required this.title, required this.onPress});

  final String title;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final name = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.body.xs.copyWith(fontWeight: FontWeight.w600),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: FTappable(
        semanticsLabel: 'Split: $title. Choose what to train from',
        onPress: onPress,
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(child: name),
              const SizedBox(width: 4),
              Icon(
                FLucideIcons.chevronDown,
                size: 14,
                color: theme.colors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The split's days in rotation order, one chip each: the day that is up
/// next says so, the others say when they were last done. A tap opens a
/// day below. Days that do not fit scroll sideways, a cut-off chip at the
/// edge showing there are more; the row opens on the day that is open.
class _DayRail extends StatefulWidget {
  const _DayRail({
    super.key,
    required this.split,
    required this.due,
    required this.selected,
    required this.lastDone,
    required this.onSelect,
  });

  final WorkoutSplit split;

  /// The day that is up next.
  final int due;

  /// The day that is open.
  final int selected;
  final Map<int, DateTime> lastDone;
  final ValueChanged<int> onSelect;

  @override
  State<_DayRail> createState() => _DayRailState();
}

class _DayRailState extends State<_DayRail> {
  static const _gap = 6.0;
  static const _margin = 16.0;
  static const _minChip = 90.0;

  /// How much of the first chip that does not fit stays in view.
  static const _peek = 0.12;

  final _controller = ScrollController();
  List<GlobalKey> _keys = const [];

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(covariant _DayRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _reveal(animate: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls the row, and only the row, to the open day.
  void _reveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (widget.selected >= _keys.length) return;
      final chip = _keys[widget.selected].currentContext?.findRenderObject();
      if (chip == null) return;
      _controller.position.ensureVisible(
        chip,
        alignment: 0.5,
        duration: animate && !MediaQuery.disableAnimationsOf(context)
            ? const Duration(milliseconds: 220)
            : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.split.splitDays;
    if (_keys.length != days.length) {
      _keys = [for (final _ in days) GlobalKey()];
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = days.length;
        final room = constraints.maxWidth - _margin * 2 - _gap * (count - 1);
        final fits = room / count >= _minChip;
        // When they do not fit: as many whole chips as there is room for,
        // plus a sliver of the next one.
        final whole =
            ((constraints.maxWidth - _margin - _peek * _minChip) /
                    (_minChip + _gap))
                .floor()
                .clamp(1, count);
        final width = fits
            ? room / count
            : (constraints.maxWidth - _margin - _gap * whole) / (whole + _peek);
        return SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: fits ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.symmetric(horizontal: _margin),
          child: Row(
            children: <Widget>[
              for (final (i, day) in days.indexed) ...[
                if (i > 0) const SizedBox(width: _gap),
                SizedBox(
                  key: _keys[i],
                  width: width,
                  child: _DayChip(
                    title: day.title,
                    isDue: i == widget.due,
                    isSelected: i == widget.selected,
                    lastDone: widget.lastDone[i],
                    onPress: () => widget.onSelect(i),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.title,
    required this.isDue,
    required this.isSelected,
    required this.lastDone,
    required this.onPress,
  });

  final String title;
  final bool isDue;
  final bool isSelected;
  final DateTime? lastDone;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final last = lastDone;
    final when = isDue
        ? 'Up next'
        : last == null
        ? 'Not done yet'
        : _capitalized(agoLabel(last));
    return FTappable(
      semanticsLabel: '$title, ${when.toLowerCase()}',
      selected: isSelected,
      onPress: onPress,
      child: Container(
        height: 50,
        // The outline grows inward: the text stays where it is.
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 9 : 10),
        decoration: BoxDecoration(
          color: theme.colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accents.live : theme.colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            Text(
              when,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.xs.copyWith(
                fontSize: 11,
                height: 1.3,
                color: isDue ? accents.live : theme.colors.mutedForeground,
                fontWeight: isDue ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalized(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
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
