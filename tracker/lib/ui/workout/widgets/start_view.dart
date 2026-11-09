import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
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
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/splits/widgets/new_split_sheet.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';

import 'day_preview_sheet.dart';
import 'gym_picker.dart';
import 'start_workout.dart';

/// The Workout tab before a workout: the day that is due next, the split's
/// other days (tap starts, hold previews), an empty workout, and the restore
/// button for a workout that just ended.
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
    final picked = await showGymPicker(context, _gyms);
    if (picked is Gym) cubit.rememberGym(picked);
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
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(context, title: 'Workout'),
        SliverToBoxAdapter(
          child: MaxWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: splits == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (splits.isEmpty)
                          const _FirstRun()
                        else
                          _withCurrentSplit(
                            (currentSplitId) => _splitStart(
                              context,
                              upNext(
                                splits,
                                _visits,
                                currentSplitId: currentSplitId,
                              )!,
                              splits,
                            ),
                          ),
                        if (canRestore) ...[
                          const SizedBox(height: 6),
                          FButton(
                            variant: .ghost,
                            onPress: context
                                .read<WorkoutCubit>()
                                .restoreLastWorkout,
                            prefix: const Icon(FLucideIcons.rotateCcw),
                            child: const Text('Restore last workout'),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _withCurrentSplit(Widget Function(int? currentSplitId) builder) {
    if (SettingsCubit.maybeOf(context) == null) return builder(null);
    return BlocSelector<SettingsCubit, SettingsState, int?>(
      selector: (settings) => settings.currentSplitId,
      builder: (context, currentSplitId) => builder(currentSplitId),
    );
  }

  Widget _splitStart(
    BuildContext context,
    UpNext upNext,
    List<WorkoutSplit> splits,
  ) {
    final theme = context.theme;
    final split = upNext.split;
    final next = upNext.dayIndex;
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
          BlocSelector<WorkoutCubit, WorkoutState, int?>(
            selector: (state) => state.lastGymId,
            builder: (context, lastGymId) => _UpNextCard(
              split: split,
              dayIndex: next,
              names: _names,
              lastDone: upNext.lastDone[next],
              gym: startGymOf(_gyms, lastGymId),
              onPickGym: () => _pickGym(context),
              onStart: () => startSplitDay(
                context,
                split: split,
                dayIndex: next,
                names: _names,
              ),
              onHold: () => _preview(context, upNext, next),
            ),
          ),
        if (next != null && split.splitDays.length > 1) ...[
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 6),
            child: Text(
              'Other days',
              style: theme.typography.body.xs.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FCard(
            child: FItemGroup(
              divider: .full,
              children: <FItem>[
                for (var i = 0; i < split.splitDays.length; i++)
                  if (i != next)
                    _dayItem(
                      context,
                      key: ValueKey('start-day-${split.id}-$i'),
                      day: split.splitDays[i],
                      lastDone: upNext.lastDone[i],
                      onPress: () => startSplitDay(
                        context,
                        split: split,
                        dayIndex: i,
                        names: _names,
                      ),
                      onLongPress: () => _preview(context, upNext, i),
                    ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Tap a day to start it. Hold it to preview.',
              textAlign: TextAlign.center,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
        ],
        if (splits.length > 1) ...[
          const SizedBox(height: 8),
          FButton(
            variant: .ghost,
            onPress: () => _showOtherSplits(context, splits, split),
            child: const Text('Days from other splits'),
          ),
        ],
        const SizedBox(height: 14),
        FButton(
          variant: .outline,
          onPress: () => startEmptyWorkout(context),
          prefix: const Icon(FLucideIcons.plus),
          child: const Text('Empty workout'),
        ),
      ],
    );
  }

  FItem _dayItem(
    BuildContext context, {
    required Key key,
    required WorkoutSplitDay day,
    required DateTime? lastDone,
    required VoidCallback onPress,
    required VoidCallback onLongPress,
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
      suffix: Semantics(
        label: 'Start ${day.title}',
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accents.live, width: 1.5),
          ),
          child: Icon(FLucideIcons.play, size: 16, color: accents.live),
        ),
      ),
      onPress: onPress,
      onLongPress: onLongPress,
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
                'Days from other splits',
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
                    FCard(
                      child: FItemGroup(
                        divider: .full,
                        children: <FItem>[
                          for (var i = 0; i < split.splitDays.length; i++)
                            _dayItem(
                              sheetContext,
                              key: ValueKey('other-day-${split.id}-$i'),
                              day: split.splitDays[i],
                              lastDone: lastDoneByDay(split, _visits)[i],
                              onPress: () {
                                Navigator.of(sheetContext).pop();
                                startSplitDay(
                                  context,
                                  split: split,
                                  dayIndex: i,
                                  names: _names,
                                );
                              },
                              onLongPress: () {
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
                    ),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({
    required this.split,
    required this.dayIndex,
    required this.names,
    required this.lastDone,
    required this.gym,
    required this.onPickGym,
    required this.onStart,
    required this.onHold,
  });

  final WorkoutSplit split;
  final int dayIndex;
  final Map<int, String> names;
  final DateTime? lastDone;
  final Gym? gym;
  final VoidCallback onPickGym;
  final VoidCallback onStart;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final day = split.splitDays[dayIndex];
    final plan = planOf(split, dayIndex, names);
    final sets = plan.fold(
      0,
      (total, exercise) => total + exercise.sets.length,
    );
    final last = lastDone;
    final facts = plan.isEmpty
        ? 'No exercises yet.'
        : '${plural('exercise', plan.length)}, ${plural('set', sets)}. '
              '${last == null ? 'Not done yet.' : 'Last done ${dayLabel(last)}.'}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onHold,
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
              if (plan.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  plan.map((exercise) => exercise.name).join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(facts, style: theme.typography.body.xs),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: _GymChip(name: gym?.name, onPress: onPickGym),
              ),
              const SizedBox(height: 14),
              AccentButton(
                large: true,
                prefix: FLucideIcons.play,
                label: 'Start ${day.title}',
                onPress: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gym the workout starts at; a long name is cut short, never wrapped.
class _GymChip extends StatelessWidget {
  const _GymChip({required this.name, required this.onPress});

  final String? name;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FTappable(
      semanticsLabel: name == null ? 'Choose a gym' : 'Gym: $name. Change gym',
      onPress: onPress,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(FLucideIcons.mapPin, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name ?? 'No gym',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.xs.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(FLucideIcons.chevronDown, size: 15),
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
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(
            'Or just train',
            style: theme.typography.body.xs.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AccentButton(
          large: true,
          prefix: FLucideIcons.play,
          label: 'Start empty workout',
          onPress: () => startEmptyWorkout(context),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Add exercises as you go.',
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
