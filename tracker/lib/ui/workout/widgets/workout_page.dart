import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/decimal_input_formatter.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/set_type_chip.dart';
import 'package:tracker/ui/core/ui/weight_confirmation.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/utils/decimal_input.dart';
import 'package:tracker/utils/form_validators.dart';

import 'gym_picker.dart';

/// The "Current Workout" tab: drives the active session from [WorkoutCubit].
///
/// Idle → a Start button (with gym selection), plus restore buttons for the
/// last saved / last discarded workout. In progress → the session's
/// exercises (from the split plan, or free-form) with inline weight/reps set
/// logging, warmup flags, and an End button that writes a [WorkoutSession].
class WorkoutPage extends StatelessWidget {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutCubit>();
    return BlocListener<WorkoutCubit, WorkoutState>(
      // Error-surfacing contract for writes: a failed end-workout save keeps
      // the session in progress; toast it once per fresh failure. Listened at
      // page level so restore failures raised from the idle view toast too.
      listenWhen: (previous, current) =>
          current.saveError != null && current.saveError != previous.saveError,
      listener: (context, state) => showFToast(
        context: context,
        title: Text(state.saveError!),
        duration: const Duration(seconds: 4),
      ),
      child: CustomScrollView(
        slivers: <Widget>[
          CustomAppBar(context, title: 'Current Workout'),
          // The idle view fills the remaining viewport height so its restore
          // action can sit at the bottom of the page, just above the nav bar.
          // The in-progress view keeps its content-sized sliver (it scrolls).
          BlocSelector<
            WorkoutCubit,
            WorkoutState,
            ({
              bool canRestoreDiscarded,
              bool canRestoreSaved,
              bool isInProgress,
            })
          >(
            selector: (state) => (
              isInProgress: state.isInProgress,
              canRestoreSaved: state.canRestoreSaved(),
              canRestoreDiscarded: state.canRestoreDiscarded(),
            ),
            builder: (context, view) {
              if (view.isInProgress) {
                return SliverToBoxAdapter(
                  child: MaxWidth(
                    child: _InProgressView(
                      onEnd: cubit.endWorkout,
                      onDiscard: cubit.discardWorkout,
                    ),
                  ),
                );
              }
              return SliverFillRemaining(
                hasScrollBody: false,
                child: MaxWidth(
                  child: _IdleView(
                    onStart: () => _startWorkout(context),
                    onRestoreLast: cubit.restoreLastWorkout,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startWorkout(BuildContext context) async {
    final cubit = context.read<WorkoutCubit>();
    final repo = RepositoryScope.maybeOf(context);
    final gyms = (await repo?.gyms.getAll()) ?? const <Gym>[];
    if (!context.mounted) return;
    final gym = await promptGym(context, gyms);
    cubit.startWorkout(gym: gym);
  }
}

class _IdleView extends StatefulWidget {
  const _IdleView({required this.onStart, required this.onRestoreLast});

  final VoidCallback onStart;
  final Future<void> Function() onRestoreLast;

  @override
  State<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<_IdleView> {
  Timer? _windowTicker;

  @override
  void dispose() {
    _windowTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<WorkoutCubit>().state;
    // The discarded-restore window lapses with wall-clock time, which no cubit
    // state change announces. While the window is live, tick periodically so
    // the restore button disappears on time (and stays away afterwards).
    final windowLive = state.canRestoreSaved() || state.canRestoreDiscarded();
    _windowTicker?.cancel();
    _windowTicker = windowLive
        ? Timer.periodic(const Duration(seconds: 30), (_) {
            if (mounted) setState(() {});
          })
        : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(FLucideIcons.dumbbell, size: 48),
                const SizedBox(height: 12),
                const Text('No workout in progress'),
                const SizedBox(height: 16),
                FButton(
                  mainAxisSize: MainAxisSize.min,
                  onPress: widget.onStart,
                  prefix: const Icon(FLucideIcons.play),
                  child: const Text('Start Workout'),
                ),
              ],
            ),
          ),
          if (state.canRestoreSaved() || state.canRestoreDiscarded()) ...[
            FButton(
              mainAxisSize: MainAxisSize.min,
              variant: .outline,
              onPress: () => widget.onRestoreLast(),
              prefix: const Icon(FLucideIcons.rotateCcw),
              child: const Text('Restore last workout'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _WorkoutAction { save, discard, cancel }

class _InProgressView extends StatelessWidget {
  const _InProgressView({required this.onEnd, required this.onDiscard});

  final Future<void> Function() onEnd;
  final Future<void> Function() onDiscard;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<WorkoutCubit, WorkoutState, _WorkoutPresentation>(
      selector: _WorkoutPresentation.fromState,
      builder: (context, presentation) => Padding(
        // The bottom padding grows by the keyboard height plus the reveal gap
        // so the inline add-set form and the End Workout action can scroll
        // above the keyboard instead of being clipped by it (the shell
        // Scaffold no longer resizes for the keyboard).
        padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardClearanceOf(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _WorkoutHeader(presentation: presentation.header),
            const SizedBox(height: 16),
            if (presentation.plan.isEmpty)
              const _FreeFormPanel()
            else
              for (final entry in presentation.plan)
                _ExerciseLogCard(
                  key: ValueKey('plan-${entry.exercise.order}'),
                  orderNumber: entry.exercise.order,
                  title: entry.exercise.name,
                  sets: entry.sets,
                  plannedSets: entry.exercise.sets,
                  exerciseId: entry.exercise.exerciseId,
                  exerciseName: entry.exercise.name,
                ),
            const SizedBox(height: 24),
            FButton(
              variant: .destructive,
              onPress: () {
                // Leaving the focused set's row is what commits it, so
                // unfocus before the end flow - otherwise a just-typed row
                // would miss the save.
                FocusManager.instance.primaryFocus?.unfocus();
                _confirmEnd(
                  context,
                  presentation.setCount,
                  onDiscard: onDiscard,
                );
              },
              prefix: const Icon(FLucideIcons.squareStop),
              child: const Text('End Workout'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEnd(
    BuildContext context,
    int setCount, {
    required Future<void> Function() onDiscard,
  }) async {
    // Zero sets: prompt directly to discard
    if (setCount == 0) {
      final confirmDiscard = await _showDiscardConfirmation(
        context,
        noSets: true,
      );
      if (confirmDiscard && context.mounted) {
        await onDiscard();
      }
      return;
    }

    // Has sets: prompt to Save or Discard
    final action = await _showEndOptionsDialog(context, setCount);
    if (!context.mounted || action == _WorkoutAction.cancel) return;

    if (action == _WorkoutAction.discard) {
      final confirmDiscard = await _showDiscardConfirmation(
        context,
        noSets: false,
      );
      if (confirmDiscard && context.mounted) {
        await onDiscard();
      }
    } else if (action == _WorkoutAction.save) {
      await onEnd();
    }
  }

  Future<_WorkoutAction> _showEndOptionsDialog(
    BuildContext context,
    int setCount,
  ) async {
    return await showFDialog<_WorkoutAction>(
          context: context,
          builder: (dialogContext, _, _) => AppDialog(
            title: 'End workout?',
            // Discard sits top-right, vertically centered with the title.
            // The tooltip covers visual hover text; Semantics makes the bare
            // icon announce itself to screen readers too.
            titleTrailing: Semantics(
              label: 'Discard workout',
              button: true,
              child: AppIconButton(
                icon: FLucideIcons.trash2,
                tooltip: 'Discard workout',
                color: dialogContext.theme.colors.error,
                onPress: () =>
                    Navigator.pop(dialogContext, _WorkoutAction.discard),
              ),
            ),
            message:
                'Log ${plural('set', setCount)} and save this workout to history.',
            actionsGap: 16,
            actions: [
              FButton(
                variant: .outline,
                onPress: () =>
                    Navigator.pop(dialogContext, _WorkoutAction.cancel),
                child: const Text('Keep going'),
              ),
              FButton(
                onPress: () =>
                    Navigator.pop(dialogContext, _WorkoutAction.save),
                child: const Text('End & save'),
              ),
            ],
          ),
        ) ??
        _WorkoutAction.cancel;
  }

  Future<bool> _showDiscardConfirmation(
    BuildContext context, {
    bool noSets = false,
  }) {
    return showConfirmDialog(
      context,
      title: 'Discard workout?',
      message: noSets
          ? 'No sets have been logged. Do you want to discard this session?'
          : 'This will delete all progress for this session.',
      confirmLabel: 'Discard',
    );
  }
}

class _WorkoutPresentation {
  const _WorkoutPresentation({
    required this.header,
    required this.plan,
    required this.setCount,
  });

  final _WorkoutHeaderData header;
  final List<({PlanExercise exercise, List<ActiveSet> sets})> plan;
  final int setCount;

  static _WorkoutPresentation fromState(WorkoutState state) {
    return _WorkoutPresentation(
      header: _WorkoutHeaderData.fromState(state),
      plan: [
        for (final exercise in state.plan)
          (
            exercise: exercise,
            sets: state.setsByExercise[exercise.exerciseId] ?? const [],
          ),
      ],
      setCount: state.sets.length,
    );
  }
}

class _WorkoutHeaderData {
  const _WorkoutHeaderData({
    this.planTitle,
    this.gymName,
    this.startTime,
    required this.setCount,
    required this.workingVolume,
  });

  final String? planTitle;
  final String? gymName;
  final DateTime? startTime;
  final int setCount;
  final double workingVolume;

  static _WorkoutHeaderData fromState(WorkoutState state) => _WorkoutHeaderData(
    planTitle: state.planTitle,
    gymName: state.gymName,
    startTime: state.startTime,
    setCount: state.sets.length,
    workingVolume: state.workingVolume,
  );
}

class _WorkoutHeader extends StatelessWidget {
  const _WorkoutHeader({required this.presentation});

  final _WorkoutHeaderData presentation;

  @override
  Widget build(BuildContext context) {
    final started = presentation.startTime;
    final working = presentation.workingVolume;
    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  FLucideIcons.footprints,
                  color: context.theme.colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    presentation.planTitle ?? 'Free workout',
                    style: context.theme.typography.body.xl.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (presentation.gymName != null)
              Text('${presentation.gymName} · ${_fmtTime(started)}')
            else
              Text(_fmtTime(started)),
            const SizedBox(height: 8),
            Text(
              '${plural('set', presentation.setCount)} · ${formatWeight(context, working)} working volume',
              style: context.theme.typography.body.md,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    final t = dt.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return 'Started at $hh:$mm';
  }
}

/// One exercise block of the in-progress workout: title, plan summary, and
/// the inline [_SetEditor]. Every set - logged or upcoming - lives in an
/// always-editable weight/reps row; there is no separate rendered-set list.
/// Sets logged so far occupy the first rows, so retyping their values edits
/// them in place.
class _ExerciseLogCard extends StatelessWidget {
  const _ExerciseLogCard({
    super.key,
    this.orderNumber,
    required this.title,
    required this.sets,
    this.plannedSets = const [],
    this.exerciseId,
    this.exerciseName,
    this.exercises,
  });

  /// 0-based position in the plan; renders the "N." prefix when provided.
  final int? orderNumber;

  final String title;

  /// Sets logged for this exercise so far, in order. The first rows of the
  /// inline editor map onto them.
  final List<ActiveSet> sets;

  /// Planned sets from the split day this session follows, used to size the
  /// editor's rows (one per planned set) and show a summary. Empty for
  /// free-form.
  final List<PlannedSet> plannedSets;

  /// Passed through to [_SetEditor]: a fixed plan exercise ([exerciseId]
  /// with [exerciseName]), or a dropdown over [exercises] (free-form).
  final int? exerciseId;
  final String? exerciseName;
  final List<Exercise>? exercises;

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.theme.typography.body.md.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Padding(
      // The card's own 12px padding plus the page gutter keeps the row width
      // (and the swipe-to-delete geometry) what it was before the card.
      padding: const EdgeInsets.only(bottom: 12),
      child: FCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (orderNumber != null)
                    Text('${orderNumber! + 1}. ', style: titleStyle),
                  Expanded(child: Text(title, style: titleStyle)),
                ],
              ),
              const SizedBox(height: 12),
              _SetEditor(
                sets: sets,
                plannedSets: plannedSets,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                exercises: exercises,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Free-form logging (no split plan): loads the exercise list for the
/// dropdown, then renders a shared [_ExerciseLogCard] over all logged sets.
class _FreeFormPanel extends StatefulWidget {
  const _FreeFormPanel();

  @override
  State<_FreeFormPanel> createState() => _FreeFormPanelState();
}

class _FreeFormPanelState extends State<_FreeFormPanel> {
  List<Exercise> _exercises = const [];
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RepositoryScope is an inherited widget, so read it here (after initState)
    // rather than in initState.
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  Future<void> _load() async {
    final repo = RepositoryScope.maybeOf(context);
    final list = await repo?.exercises.getAll() ?? const <Exercise>[];
    if (!mounted) return;
    setState(() => _exercises = list);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutCubit, WorkoutState>(
      builder: (context, state) => _ExerciseLogCard(
        title: 'Log a set',
        sets: state.sets,
        exercises: _exercises,
      ),
    );
  }
}

/// Inline set sheet: every set - logged or upcoming - lives in an
/// always-editable weight/reps row. There is no separate rendered-set list and
/// no explicit submit: a row saves itself the moment focus leaves it (moving
/// to another field, tapping elsewhere, or the keyboard's done action all
/// count as leaving). A filled-but-invalid row surfaces its errors and stays
/// uncommitted; clearing every field of a logged set's row deletes it.
///
/// A planned exercise ([exerciseId] set) renders one row per planned set with
/// its rep target as the reps hint - retyping a logged set edits it in place.
/// A free-form workout renders one row per logged set plus trailing empty rows
/// (one is always available, more via Add set), an exercise dropdown for new
/// sets, and the warm-up toggle that applies to the next set.
class _SetEditor extends StatefulWidget {
  const _SetEditor({
    this.exerciseId,
    this.exerciseName,
    this.exercises,
    this.sets = const [],
    this.plannedSets = const [],
  });

  /// When set, the exercise is fixed (plan-driven) and no dropdown is shown.
  final int? exerciseId;
  final String? exerciseName;

  /// When provided with [exerciseId] null, a dropdown of [Exercise] is shown
  /// instead (free-form logging).
  final List<Exercise>? exercises;

  /// Sets logged for this exercise so far; row [i] below [sets.length] edits
  /// them in place.
  final List<ActiveSet> sets;

  /// The planned sets sizing the rows in plan-driven logging (empty
  /// free-form).
  final List<PlannedSet> plannedSets;

  @override
  State<_SetEditor> createState() => _SetEditorState();
}

/// One weight/reps row: its live validation errors, plus the last committed
/// set values so incoming cubit changes (deletes shifting rows, restored
/// sessions) can rewrite the row text without clobbering values the user just
/// committed themselves.
class _Row {
  final weight = TextEditingController();
  final reps = TextEditingController();
  String? weightError;
  String? repsError;
  double? lastWeightKg;
  double? lastReps;

  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

class _SetEditorState extends State<_SetEditor> {
  final List<_Row> _rows = [];
  bool _warmup = false;
  int? _selectedId;
  String? _exerciseError;

  /// Empty rows added with the Add set button beyond the always-present
  /// first one (free-form only).
  int _extraEmptyRows = 0;

  bool get _planned => widget.exerciseId != null;

  /// Empty trailing rows below the logged sets: one is always available.
  int get _emptyRowCount => _extraEmptyRows + 1;

  /// Rows the plan sizes on its own (one when there is no plan).
  int get _plannedBaseCount =>
      widget.plannedSets.isEmpty ? 1 : widget.plannedSets.length;

  /// Planned workouts keep one row per planned set (or per logged set, when
  /// more were logged), plus any extra rows added with Add set.
  int get _rowCount => _planned
      ? math.max(_plannedBaseCount, widget.sets.length) + _extraEmptyRows
      : widget.sets.length + _emptyRowCount;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.exerciseId;
    _reconcile();
  }

  @override
  void didUpdateWidget(covariant _SetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcile();
  }

  /// Match the row count to the plan / logged sets, then re-sync mapped rows:
  /// rows shifted by deletes or restored sessions rewrite their text to the
  /// stored values, while rows whose stored values still equal what this row
  /// last committed keep the user's typed text.
  void _reconcile() {
    while (_rows.length < _rowCount) {
      _rows.add(_Row());
    }
    while (_rows.length > _rowCount) {
      _rows.removeLast().dispose();
    }
    for (var i = 0; i < _rows.length; i++) {
      if (i >= widget.sets.length) continue;
      final row = _rows[i];
      final set = widget.sets[i];
      final untouched =
          row.lastWeightKg == null ||
          row.lastReps == null ||
          !_sameKg(row.lastWeightKg!, set.weight) ||
          row.lastReps != set.reps;
      if (untouched) {
        row.weight.text = formatDecimal(displayWeightOf(context, set.weight));
        row.reps.text = formatDecimal(set.reps);
        row.lastWeightKg = set.weight;
        row.lastReps = set.reps;
      }
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plannedRows = _planned && widget.plannedSets.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!_planned) ...[
          _exerciseDropdown(),
          if (_exerciseError != null)
            Text(
              _exerciseError!,
              style: context.theme.typography.body.sm.copyWith(
                color: context.theme.colors.error,
              ),
            ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < _rows.length; i++) ...[
          // The inter-row spacing lives outside the swipe wrapper so the
          // delete background it reveals matches the field row's height
          // exactly (no transparent padding strip above it).
          if (i > 0)
            const FDivider(
              style: .delta(
                padding: .value(EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          Focus(
            // The row commits when focus leaves any of its fields; the
            // wrapper must not capture focus or participate in traversal.
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (focused) {
              if (!focused) _commitRow(i);
            },
            child: !_planned
                ? _SwipeToDelete(
                    canDelete: _canSwipeDelete(i),
                    // An undeletable row reveals no red delete bar at all:
                    // the rubber-band is the only feedback.
                    onConfirm: () => _confirmSwipeDelete(i),
                    onConfirmed: () => _onSwipeDismissed(i),
                    child: _buildRow(context, i, plannedRows),
                  )
                : _buildRow(context, i, plannedRows),
          ),
        ],
        // Add set works in both modes; the warm-up toggle is free-form only,
        // because a planned workout follows the plan.
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            if (!_planned) ...[
              FCheckbox(
                label: const Text('Warm-up'),
                value: _warmup,
                onChange: (v) => setState(() => _warmup = v),
              ),
            ],
            const Spacer(),
            FButton(
              variant: .ghost,
              onPress: _addEmptyRow,
              prefix: const Icon(FLucideIcons.plus),
              child: const Text('Add set'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, int index, bool plannedRows) {
    final row = _rows[index];
    // In a plan-driven row the planned target (`10` / `8-12`) doubles as the
    // reps field's hint; free rows label themselves instead.
    final repHint = plannedRows && index < widget.plannedSets.length
        ? widget.plannedSets[index].repsLabel
        : 'Reps';
    return Row(
      children: <Widget>[
        // Logged sets show their set-type chip; open rows read "Set" in the same
        // slot, so the values line up across the whole list.
        SizedBox(
          width: 28,
          child: index < widget.sets.length
              ? Center(
                  child: SetTypeChip(isWarmup: widget.sets[index].isWarmup),
                )
              : Text(
                  'Set',
                  style: context.theme.typography.body.xs.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FTextField(
            control: FTextFieldControl.managed(controller: row.weight),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [DecimalInputFormatter(allowNegative: true)],
            hint: weightUnitOf(context).symbol,
            error: row.weightError == null ? null : Text(row.weightError!),
            // Free rows sit inside a Dismissible: turning the selection
            // affordances off keeps the text field from claiming horizontal
            // drags in the gesture arena, so the swipe-to-delete gesture
            // stays reachable. The values are short numbers nobody selects
            // by hand inside the row.
            enableInteractiveSelection: !_planned,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '×',
          style: context.theme.typography.body.sm.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FTextField(
            control: FTextFieldControl.managed(controller: row.reps),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter()],
            hint: repHint,
            error: row.repsError == null ? null : Text(row.repsError!),
            enableInteractiveSelection: !_planned,
            textInputAction: TextInputAction.done,
            // The keyboard's done action just moves focus away - which is
            // exactly what commits the row.
            onSubmit: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
      ],
    );
  }

  Widget _exerciseDropdown() {
    final exercises = widget.exercises ?? const <Exercise>[];
    return FSelect<int>(
      label: const Text('Exercise'),
      items: {for (final e in exercises) e.title: e.id},
      control: FSelectControl<int>.lifted(
        value: _selectedId,
        onChange: (v) => setState(() {
          _selectedId = v;
          _exerciseError = null;
        }),
      ),
      forceErrorText: _exerciseError,
    );
  }

  void _addEmptyRow() {
    setState(() {
      _extraEmptyRows++;
      // Materialize the row immediately: build() iterates _rows (not
      // _rowCount), so without this the blank row would only appear on the
      // next cubit emission, long after the tap.
      _rows.add(_Row());
    });
  }

  /// Whether the row at [index] may be swiped away at all. Logged sets and
  /// rows holding typed values can; a blank trailing row only when it is one
  /// of the extra rows from Add set. The always-available logging row (the
  /// last one when no extra rows exist) cannot be deleted, so it merely
  /// rubber-bands and never asks for confirmation.
  bool _canSwipeDelete(int index) {
    if (index < widget.sets.length) return true;
    final row = _rows[index];
    final hasContent =
        row.weight.text.trim().isNotEmpty || row.reps.text.trim().isNotEmpty;
    if (hasContent) return true;
    return _extraEmptyRows > 0;
  }

  /// Decides what a swipe on the row at [index] means. A row holding a logged
  /// set (or typed values) always asks through the destructive confirmation
  /// dialog first; a blank trailing row is discarded silently, except for the
  /// always-available logging row when no extra rows exist.
  Future<bool> _confirmSwipeDelete(int index) async {
    // Double guard: the gesture never reaches here for an undeletable row,
    // but a stale gesture must not remove one either.
    if (!_canSwipeDelete(index)) return false;
    final row = _rows[index];
    final mapped = index < widget.sets.length ? widget.sets[index] : null;
    final hasContent =
        row.weight.text.trim().isNotEmpty || row.reps.text.trim().isNotEmpty;
    if (mapped == null && !hasContent) {
      return true;
    }
    return showConfirmDialog(
      context,
      title: 'Delete this set?',
      message: 'This will remove the set from this workout.',
      confirmLabel: 'Delete',
      destructive: true,
    );
  }

  /// Finishes a confirmed swipe on the row at [index]: a logged set is
  /// removed from the workout, a trailing blank (or typed-free) row is just
  /// dropped. Rows are mapped by position, so deleting a set shifts the
  /// remaining sets up one row; the rows from [index] to the old last mapped
  /// one are cleared so the next reconcile rewrites the shifted sets into
  /// them (the last slot simply loses its mapping) instead of keeping the
  /// deleted set's values as stray typed text.
  void _onSwipeDismissed(int index) {
    final mapped = index < widget.sets.length ? widget.sets[index] : null;
    if (mapped != null) {
      for (var j = index; j < widget.sets.length; j++) {
        _rows[j]
          ..weight.clear()
          ..reps.clear()
          ..lastWeightKg = null
          ..lastReps = null;
      }
      context.read<WorkoutCubit>().removeSet(mapped.order);
      setState(() {});
      return;
    }
    setState(() {
      _rows.removeAt(index);
      if (_extraEmptyRows > 0) _extraEmptyRows--;
      // Typed values can live in the always-available row; dropping it must
      // not leave the form with no logging row at all.
      _reconcile();
    });
  }

  /// The exercise name for a new set: fixed by the plan, else looked up in
  /// the dropdown's list.
  String _nameFor(int id) {
    if (widget.exerciseName?.isNotEmpty ?? false) return widget.exerciseName!;
    for (final e in widget.exercises ?? const <Exercise>[]) {
      if (e.id == id) return e.title;
    }
    return '';
  }

  /// Commit the row's typed values on focus loss: update a logged set, add a
  /// new one, or delete the logged set when its fields were emptied. Invalid
  /// or partially typed rows surface errors instead of committing.
  Future<void> _commitRow(int index) async {
    final row = _rows[index];
    final mapped = index < widget.sets.length ? widget.sets[index] : null;

    final weightText = row.weight.text.trim();
    final repsText = row.reps.text.trim();
    if (weightText.isEmpty && repsText.isEmpty) {
      row.weightError = null;
      row.repsError = null;
      if (mapped != null) {
        // Both fields cleared on a logged set: editing doubles as removing.
        context.read<WorkoutCubit>().removeSet(mapped.order);
      }
      setState(() {});
      return;
    }

    // Values keep the typed digits (never rounded): the input formatter caps
    // both fields at two decimal places, and the parse truncates pasted or
    // hand-set values the same way.
    final weightDisplay = parseDecimal(weightText, allowNegative: true);
    final reps = parseDecimal(repsText);
    final weightError = requiredWeight(weightText);
    var repsError = requiredReps(repsText);
    if (reps != null && reps < 1) {
      // Below one rep is never a loggable set - surface an explicit error
      // instead of silently doing nothing.
      repsError = 'Must be at least 1';
    }
    if (weightError != null ||
        repsError != null ||
        weightDisplay == null ||
        reps == null) {
      setState(() {
        row.weightError = weightError;
        row.repsError = repsError;
      });
      return;
    }

    // New sets in a free workout need an exercise first.
    final id = mapped?.exerciseId ?? _selectedId;
    if (id == null || id <= 0) {
      setState(() => _exerciseError = 'Pick an exercise first');
      return;
    }

    final kilograms = kilogramsFromDisplay(context, weightDisplay);
    if (mapped != null &&
        _sameKg(mapped.weight, kilograms) &&
        mapped.reps == reps) {
      // Leaving the values untouched is not a new edit: no dialog, no write.
      setState(() {
        row.weightError = null;
        row.repsError = null;
      });
      return;
    }

    // Guard against typos around the heavy-weight threshold before anything
    // is written.
    final confirmed = await confirmWeightEntry(context, weightDisplay);
    if (!mounted || !confirmed) return;

    // The modal blocks other edits, but the session may still have been ended
    // or restored underneath: re-read the mapping before writing.
    final cubit = context.read<WorkoutCubit>();
    final target = index < widget.sets.length ? widget.sets[index] : null;
    if (target != null) {
      if (!_sameKg(target.weight, kilograms) || target.reps != reps) {
        cubit.updateSet(target.order, weight: kilograms, reps: reps);
      }
    } else {
      cubit.logSet(
        exerciseId: id,
        exerciseName: _nameFor(id),
        weight: kilograms,
        reps: reps,
        type: !_planned && _warmup ? SetType.warmup : SetType.working,
      );
      if (!_planned) {
        _warmup = false;
        if (_extraEmptyRows > 0) _extraEmptyRows--;
      } else if (index >= _plannedBaseCount && _extraEmptyRows > 0) {
        _extraEmptyRows--;
      }
    }
    // Remember the committed values so the next reconcile keeps the typed
    // text (kg is exact; in lb the display rounds to the stored value).
    row.weightError = null;
    row.repsError = null;
    row.lastWeightKg = kilograms;
    row.lastReps = reps;
    setState(() {});
  }
}

bool _sameKg(double stored, double committed) =>
    (stored - committed).abs() < 1e-9;

/// A hand-rolled variant of [Dismissible] for rows whose children - text
/// fields - win the horizontal drag in the gesture arena themselves, keeping
/// [Dismissible] from ever seeing the gesture. It bypasses the arena entirely
/// by working off raw [Listener] pointer events: the row follows the finger
/// leftwards (end-to-start) through a rubber-band resistance that tightens on
/// the approach to the delete gate (63.5% of the row's width). Pushing past
/// the gate arms the delete: the row snaps to the final deletion position, a
/// haptic fires, the trash icon shakes and the Delete label slides in.
/// Retreating below the gate disarms again and the row springs back onto the
/// finger. Releasing armed asks [onConfirm] whether the row actually goes;
/// [onConfirmed] removes it after the slide-out animation.
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({
    required this.canDelete,
    required this.onConfirm,
    required this.onConfirmed,
    required this.child,
  });

  /// Whether this row may actually be deleted. When false the row only
  /// rubber-bands under the finger: [onConfirm] is never invoked and no
  /// delete indicator is revealed.
  final bool canDelete;

  /// Invoked when the drag crosses the dismissal threshold, before anything
  /// is removed. Resolves to whether the row should actually be deleted.
  final Future<bool> Function() onConfirm;

  /// Invoked after the row slid out and [onConfirm] returned true: removes
  /// the row's data. The parent's rebuild then lands the new content in this
  /// slot, clearing the stale transform.
  final VoidCallback onConfirmed;

  final Widget child;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete>
    with TickerProviderStateMixin {
  static const double _slop = 18;

  /// Fraction of the delete distance that is rubber-banded. Past it the row
  /// tracks the finger 1:1 up to the gate.
  static const double _rubberBandZone = 0.75;

  /// Fraction of the row's width a swipe must cover to delete it. Anything
  /// shorter rubber-bands and springs back on release.
  static const double _dismissFraction = 0.635;

  /// How much of the finger's speed the row keeps where the rubber band ends
  /// (1 = none, 0 = fully stopped).
  static const double _rubberBandTail = 0.4;

  /// Extra resistance right before the gate: through the final stretch
  /// before the delete distance the row's tracking slope decays from 1:1
  /// down to 1 - [_gateStiffening], so the row is visibly "stretched" just
  /// before it snaps into the armed state.
  static const double _gateStiffening = 0.5;

  /// Rubber band for rows that cannot be deleted: the first pixels follow the
  /// finger so the touch is acknowledged, then the offset saturates as the
  /// square root of the finger travel, approaching [_rubberBandMax] but never
  /// reaching it - visibly "pulling against a band" rather than sliding.
  static const double _rubberBandNeck = 24;
  static const double _rubberBandMax = 56;
  static const double _rubberBandRange = 120;

  double _offset = 0;
  double _rowWidth = 0;

  /// Finger travel of the current gesture, used both for logging the swipe
  /// percentage and for deciding whether the row is deleted on release.
  double _fingerDistance = 0;

  /// Whether the delete is armed: the finger has crossed the gate and the
  /// row is parked at the armed position. Reset on pointer down.
  bool _armed = false;
  bool _horizontal = false;
  bool _vertical = false;
  bool _busy = false;

  /// During a confirm slide-out: the row collapses to zero height and fades
  /// out as it exits, so the gap closes during the animation instead of
  /// snapping shut when the parent rebuilds.
  bool _dismissing = false;

  /// Set once the slide-out animation finished and [onConfirmed] ran: the next
  /// parent rebuild lands the shifted content in this slot, and then the stale
  /// off-screen transform is cleared.
  bool _removed = false;
  Offset? _start;

  late final AnimationController _slider = AnimationController(
    vsync: this,
    duration: _springBackDuration,
  );

  /// Start of the running [_slider] animation.
  double _animateFrom = 0;

  /// End of the running [_slider] animation.
  double _animateTarget = 0;

  /// Easing of the running [_slider] animation.
  Curve _animateCurve = Curves.easeOutCubic;

  /// Called once the running [_slider] animation reaches [_animateTarget].
  VoidCallback? _animateDone;

  static const Duration _springBackDuration = Duration(milliseconds: 220);
  static const Duration _slideOutDuration = Duration(milliseconds: 160);

  /// Subtle wiggle of the trash icon when the gate is crossed.
  static const Duration _shakeDuration = Duration(milliseconds: 350);

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: _shakeDuration,
  );

  @override
  void initState() {
    super.initState();
    // Listeners live for the whole widget lifetime: adding them per animation
    // would let the controller's initial `dismissed` status (reported when it
    // is rewound to 0) run a freshly added end listener and snap the row to
    // its target instead of animating there.
    _slider
      ..addListener(_onAnimationTick)
      ..addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    _slider.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SwipeToDelete oldWidget) {
    super.didUpdateWidget(oldWidget);
    // After [onConfirmed] the parent's rebuild lands the shifted content in
    // this slot; clear the stale off-screen transform now, so the new row
    // renders in place. Rebuilds during the slide-out itself are ignored:
    // stopping the animation there would cancel the removal.
    if (_removed) {
      _removed = false;
      _busy = false;
      _dismissing = false;
      setState(_resetOffset);
    }
  }

  void _resetOffset() {
    _offset = 0;
    _fingerDistance = 0;
    _armed = false;
    _horizontal = false;
    _vertical = false;
  }

  /// Resists finger travel [dx] with a `sqrt` falloff for rows that cannot be
  /// deleted: `neck` pixels move 1:1, the rest gains ever less, bounded by
  /// [_rubberBandMax].
  double _rubberBand(double dx) {
    final travel = dx.abs();
    if (travel <= _rubberBandNeck) return dx;
    final overshoot = travel - _rubberBandNeck;
    final resisted =
        _rubberBandNeck +
        (_rubberBandMax - _rubberBandNeck) *
            math.sqrt(overshoot / (overshoot + _rubberBandRange));
    return dx.isNegative ? -resisted : resisted;
  }

  /// Travel of a deletable row for [dx] of finger travel. Through the first
  /// [_rubberBandZone] of the gate the row eases behind the finger - the
  /// rubber band - then tracks it 1:1, and through the final stretch before
  /// the gate it stiffens again (slope decaying towards
  /// 1 - [_gateStiffening]): the tug the user feels right as the delete arms.
  /// Past the gate the row keeps tracking with that same slope - no jump, the
  /// arming is communicated by the force and the haptic alone. The first ramp
  /// from 1:1 down to [_rubberBandTail] integrates to a quadratic falloff.
  double _deletableOffset(double dx) {
    if (dx == 0) return 0;
    final distance = dx.abs();
    final gate = _rowWidth * _dismissFraction;
    final bandEnd = gate * _rubberBandZone;
    if (bandEnd <= 0) return dx;
    final atBandEnd = bandEnd * (1 + _rubberBandTail) / 2;
    final zone = gate - bandEnd;
    final double travelled;
    if (distance <= bandEnd) {
      travelled =
          distance -
          (1 - _rubberBandTail) * distance * distance / (2 * bandEnd);
    } else if (distance <= gate) {
      final u = distance - bandEnd;
      // Slope decays linearly from 1 to 1 - [_gateStiffening] across the
      // approach; integrating that decay adds the quadratic term.
      travelled = atBandEnd + u - _gateStiffening * u * u / (2 * zone);
    } else {
      // Past the gate: continue at the slope the approach ended with.
      final atGate = atBandEnd + zone * (1 - _gateStiffening / 2);
      travelled = atGate + (1 - _gateStiffening) * (distance - gate);
    }
    return dx.isNegative ? -travelled : travelled;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_busy) return;
    if (_start != null) return; // ignore extra fingers
    // A new gesture takes over from a running spring-back immediately.
    _slider.stop();
    _start = event.position;
    _fingerDistance = 0;
    _armed = false;
    _horizontal = false;
    _vertical = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _start;
    if (start == null || _busy) return;
    final dx = event.position.dx - start.dx;
    final dy = event.position.dy - start.dy;

    if (!_horizontal && !_vertical) {
      // Wait for a clear direction: a vertical-leaning finger belongs to the
      // page scroll and must never be stolen by the swipe.
      if (dy.abs() > _slop && dy.abs() > dx.abs()) {
        _vertical = true;
        return;
      }
      if (dx.abs() < _slop) return;
      _horizontal = true;
    }
    if (_vertical) return;

    // End-to-start only: the row travels leftwards; overshoot to the right
    // rubber-bands at its rest position. Slow drags past the full row width
    // are clamped so the row never flips around. A row that cannot be
    // deleted never leaves its rest area: it only follows the finger through
    // the sqrt rubber band, with no delete background behind it. A deletable
    // row lags the finger for the first part of the swipe, then tracks it.
    // The finger distance itself is not clamped - it is what the delete rule
    // and the debug log measure, so dragging past the row reads over 100%.
    _fingerDistance = dx < 0 ? -dx : 0;
    final armed = widget.canDelete && _fingerDistance >= _dismissTarget;
    final wasArmed = _armed;
    _armed = armed;
    final travel = dx.clamp(-_rowWidth, 0).toDouble();
    setState(() {
      _offset = !widget.canDelete
          ? _rubberBand(travel)
          : _deletableOffset(travel);
    });
    // The gate itself is silent motion-wise: the row never jumps. Arming is
    // communicated by the stiffened pull of the band plus the haptic, the
    // icon wiggle and the Delete label sliding in.
    if (armed && !wasArmed) HapticFeedback.mediumImpact();
    _logSwipeProgress();
  }

  /// Finger distance at which the delete becomes armed.
  double get _dismissTarget => _rowWidth * _dismissFraction;

  /// Prints how much of the row's width the finger has swiped, in real time
  /// while it moves (debug builds only). This is the percentage the delete
  /// rule uses: under 63.5% of the row's width the swipe cancels on release,
  /// at 63.5% or past it the row is deleted.
  void _logSwipeProgress() {
    if (!kDebugMode || _rowWidth <= 0) return;
    final percent = _fingerDistance / _rowWidth * 100;
    debugPrint('Set row swipe: ${percent.toStringAsFixed(1)}%');
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    final horizontal = _horizontal;
    final swiped = _fingerDistance;
    _start = null;
    _fingerDistance = 0;
    if (_busy || _vertical || !horizontal) return;

    // Only a swipe covering 63.5% of the row's width deletes it; anything
    // shorter - however fast - rubber-bands and cancels. An undeletable row
    // never dismisses, however far it was dragged.
    final dismisses =
        widget.canDelete && swiped >= _rowWidth * _dismissFraction;
    if (!dismisses) {
      _animateTo(0);
      return;
    }

    // Keep the row translated while the dialog is up: cancelling animates it
    // back, confirming slides it fully out before the removal lands.
    _busy = true;
    final confirmed = await widget.onConfirm();
    if (!mounted) return;
    if (!confirmed) {
      _busy = false;
      _dismissing = false;
      _animateTo(0);
      return;
    }
    _dismissing = true;
    _animateTo(
      -_rowWidth,
      duration: _slideOutDuration,
      curve: Curves.easeInCubic,
      done: widget.onConfirmed,
    );
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _start = null;
    _fingerDistance = 0;
    if (_busy || _vertical || !_horizontal) return;
    _animateTo(0);
  }

  void _onAnimationTick() {
    if (!mounted) return;
    final t = _animateCurve.transform(_slider.value);
    setState(
      () => _offset = _animateFrom + (_animateTarget - _animateFrom) * t,
    );
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final done = _animateDone;
    _animateDone = null;
    if (!mounted) return;
    setState(() {
      _offset = _animateTarget;
      // A slide-out hands the removal to the parent; the rebuild that follows
      // clears the transform and re-enables gestures.
      _removed = done != null;
    });
    done?.call();
  }

  /// Animates the row from its current offset to [target]; [done] runs once it
  /// arrives. A cancelled swipe springs back to rest, a confirmed one slides
  /// out - both interpolate frame by frame instead of snapping.
  void _animateTo(
    double target, {
    Duration duration = _springBackDuration,
    Curve curve = Curves.easeOutCubic,
    VoidCallback? done,
  }) {
    _animateFrom = _offset;
    _animateTarget = target;
    _animateCurve = curve;
    _animateDone = done;
    _slider
      ..duration = duration
      ..stop()
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _rowWidth = constraints.maxWidth;
        // The red indicator never grows wider than the distance the finger
        // must travel to delete the row: it is pinned to the trailing edge
        // (where the reveal happens) and capped at the threshold width.
        final threshold = (_rowWidth * _dismissFraction).clamp(0.0, _rowWidth);
        // While a confirmed swipe slides the row out, collapse its height and
        // fade it so the gap closes during the exit instead of snapping shut
        // when the parent rebuilds.
        final dismissProgress = _dismissing ? _slider.value : 0.0;
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.deferToChild,
          child: Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              // Undeletable rows reveal nothing behind them: the rubber band
              // is the only feedback.
              if (widget.canDelete)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: threshold,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.theme.colors.destructive,
                      borderRadius: context.theme.style.borderRadius.md,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _ArmedIndicator(visible: _armed, shake: _shake),
                      ),
                    ),
                  ),
                ),
              // The translated row paints on top of the background; Stack's
              // default clipping keeps it from bleeding over neighbouring
              // rows while it slides. The row itself is opaque: its own
              // paddings (top spacing), the gap between the two fields and
              // the fields' rounded corners are otherwise transparent and
              // would let the red delete background bleed through at rest.
              // While a confirmed swipe slides the row out, collapse its height
              // and fade it so the gap closes during the exit instead of
              // snapping shut when the parent rebuilds.
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1 - dismissProgress,
                  child: Opacity(
                    opacity: 1 - dismissProgress,
                    child: Transform.translate(
                      offset: Offset(_offset, 0),
                      child: ColoredBox(
                        color: context.theme.colors.background,
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The trash icon and the Delete label revealed behind a swiped row. While the
/// swipe is under the gate only the icon peeks out; once the delete is armed
/// the label slides in next to it and the icon gives a subtle side-to-side
/// wiggle, reinforcing the haptic pulse.
class _ArmedIndicator extends StatelessWidget {
  const _ArmedIndicator({required this.visible, required this.shake});

  /// Slide-in of the Delete label beside the trash icon.
  static const Duration _labelDuration = Duration(milliseconds: 150);

  /// Whether the delete is armed: label fully slid in, icon wiggling.
  final bool visible;

  /// Drive for the icon wiggle.
  final AnimationController shake;

  @override
  Widget build(BuildContext context) {
    final foreground = context.theme.colors.destructiveForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // AnimatedSize keeps the surrounding red area from stretching while
        // the label is collapsed to zero width.
        AnimatedSize(
          duration: _labelDuration,
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.centerEnd,
          child: visible
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: Text(
                    'Delete',
                    style: context.theme.typography.body.sm.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        AnimatedBuilder(
          animation: shake,
          builder: (context, child) {
            // Two gentle damped cycles: rotate around the icon's center.
            final t = shake.value;
            final angle = math.sin(t * 2 * math.pi * 2) * 0.12 * (1 - t);
            return Transform.rotate(angle: angle, child: child);
          },
          child: Icon(FLucideIcons.trash2, color: foreground),
        ),
      ],
    );
  }
}
