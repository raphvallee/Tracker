import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/rep_limits.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/set_prefill.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/accent_button.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/decimal_input_formatter.dart';
import 'package:tracker/ui/core/ui/effort_format.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/swipe_to_delete.dart';
import 'package:tracker/ui/core/ui/weight_confirmation.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/utils/decimal_input.dart';
import 'package:tracker/utils/form_validators.dart';

import 'effort_sheet.dart';
import 'elapsed_clock.dart';
import 'finish_workout.dart';
import 'number_entry.dart';
import 'workout_dock.dart';
import 'workout_entries.dart';

/// One exercise of the running workout on its own page: where it sits in the
/// workout, a row per set with weight and reps side by side (last time's
/// values small under each), the set being done opened up with steppers and
/// its rating, and the next step docked in thumb reach: Log, then Next, then
/// Finish.
class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  PreviousPerformance? _previous;
  bool _didLoad = false;
  bool _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    RepositoryScope.maybeOf(context)?.sessions
        .getPreviousPerformance(widget.exerciseId)
        .then((previous) {
          if (mounted && previous != null) setState(() => _previous = previous);
        });
  }

  /// The exercise left the workout, or the workout ended: leave its page.
  void _close() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutCubit, WorkoutState>(
      builder: (context, state) {
        final entries = state.isInProgress
            ? workoutEntries(state)
            : const <WorkoutEntry>[];
        final index = entries.indexWhere(
          (entry) => entry.exercise.exerciseId == widget.exerciseId,
        );
        if (index < 0) {
          _close();
          return const SizedBox.shrink();
        }
        Widget body(SettingsState settings) => _ExerciseBody(
          entry: entries[index],
          index: index,
          entries: entries,
          next: nextEntryAfter(entries, index),
          title: state.planTitle ?? 'Free workout',
          isPlan: state.planTitle != null,
          startTime: state.startTime ?? DateTime.now(),
          lastSetAt: state.lastSetAt,
          previous: _previous,
          prefill: settings.prefillSets,
          entryMode: settings.numberEntry,
          effort: settings.effortScale,
        );
        if (SettingsCubit.maybeOf(context) == null) {
          return body(SettingsState());
        }
        return BlocBuilder<SettingsCubit, SettingsState>(
          buildWhen: (a, b) =>
              a.prefillSets != b.prefillSets ||
              a.numberEntry != b.numberEntry ||
              a.effortScale != b.effortScale ||
              a.unit != b.unit,
          builder: (context, settings) => body(settings),
        );
      },
    );
  }
}

enum _Kind { weight, reps }

class _Row {
  final weight = TextEditingController();
  final reps = TextEditingController();
  final weightFocus = FocusNode(debugLabel: 'set weight');
  final repsFocus = FocusNode(debugLabel: 'set reps');

  // The fields keep their state (focus included) while their row switches
  // between the compact and the opened layout.
  final weightKey = GlobalKey(debugLabel: 'set weight field');
  final repsKey = GlobalKey(debugLabel: 'set reps field');

  String? weightError;
  String? repsError;
  double? lastWeightKg;
  double? lastReps;

  /// The set type a pending row logs with; null follows its plan or
  /// placeholder.
  bool? warmup;

  /// The rating (RPE) a pending row logs with.
  double? rpe;

  /// A commit is waiting on a dialog: a second one must not log twice.
  bool busy = false;

  bool hadWeightFocus = false;
  bool hadRepsFocus = false;

  bool get hasFocus => weightFocus.hasFocus || repsFocus.hasFocus;

  bool get hasText =>
      weight.text.trim().isNotEmpty || reps.text.trim().isNotEmpty;

  TextEditingController controllerOf(_Kind kind) =>
      kind == _Kind.weight ? weight : reps;

  FocusNode focusOf(_Kind kind) =>
      kind == _Kind.weight ? weightFocus : repsFocus;

  void clear() {
    weight.clear();
    reps.clear();
    weightError = null;
    repsError = null;
    lastWeightKg = null;
    lastReps = null;
    warmup = null;
    rpe = null;
  }

  void dispose() {
    weight.dispose();
    reps.dispose();
    weightFocus.dispose();
    repsFocus.dispose();
  }
}

class _ExerciseBody extends StatefulWidget {
  const _ExerciseBody({
    required this.entry,
    required this.index,
    required this.entries,
    required this.next,
    required this.title,
    required this.isPlan,
    required this.startTime,
    required this.lastSetAt,
    required this.previous,
    required this.prefill,
    required this.entryMode,
    required this.effort,
  });

  final WorkoutEntry entry;

  /// [entry]'s place in [entries], the running workout's exercises.
  final int index;
  final List<WorkoutEntry> entries;

  /// The exercise to move on to: the next one with sets left.
  final WorkoutEntry? next;

  /// The day's name ("Free workout" without a plan).
  final String title;
  final bool isPlan;
  final DateTime startTime;

  /// When the workout's last set was logged: the rest clock counts from it.
  final DateTime? lastSetAt;

  final PreviousPerformance? previous;
  final bool prefill;
  final NumberEntry entryMode;
  final EffortScale effort;

  @override
  State<_ExerciseBody> createState() => _ExerciseBodyState();
}

class _ExerciseBodyState extends State<_ExerciseBody> {
  final List<_Row> _rows = [];

  /// Rows added with Add set beyond the base rows.
  int _extraRows = 0;

  /// Base rows swiped away before they were logged.
  int _removedBaseRows = 0;

  /// The row tapped in Steppers mode, which has no focus to follow.
  _Row? _selected;

  /// The field held to type into, in Steppers mode.
  ({_Row row, _Kind kind})? _typing;

  OverlayEntry? _overlay;

  /// The keypad is sliding away; its entry goes once it is out of sight.
  bool _overlayClosing = false;
  final _panelKey = GlobalKey<_SlidePanelState>();

  /// The panel last shown, kept on screen while it slides away.
  Widget? _lastPanel;
  Timer? _repeat;

  /// The field to lift above the keypad once the page has made room.
  GlobalKey? _pendingReveal;
  double _scrubbed = 0;

  int get _exerciseId => widget.entry.exercise.exerciseId;

  /// The exercise's sets as the cubit holds them right now. Handlers read
  /// these rather than the widget's: the blur a tap causes can log a set
  /// before this page is rebuilt with it.
  List<ActiveSet> get _liveSets =>
      context.read<WorkoutCubit>().state.setsByExercise[_exerciseId] ??
      const [];

  List<PlannedSet> get _plan => widget.entry.exercise.sets;

  /// Rows ahead of the first planned one (see [leadingWarmupRows]).
  int get _lead =>
      leadingWarmupRows(_plan, widget.prefill ? widget.previous : null);

  PlannedSet? _plannedAt(int index) => plannedForRow(index, _plan, lead: _lead);

  /// Rows the page starts with: one per planned set, warm-ups included (plus
  /// last session's opening warm-ups when prefilling a plan without any); a
  /// free exercise gets last session's row count, or one blank row.
  int get _baseRows {
    if (_plan.isNotEmpty) return _plan.length + _lead;
    final previous = widget.prefill ? widget.previous : null;
    final count = previous?.sets.length ?? 0;
    return count > 0 ? count : 1;
  }

  int _rowCountFor(int logged) =>
      math.max(math.max(_baseRows - _removedBaseRows, 0), logged) + _extraRows;

  @override
  void initState() {
    super.initState();
    _reconcile();
  }

  @override
  void didUpdateWidget(covariant _ExerciseBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcile();
    if (oldWidget.entryMode != widget.entryMode) _typing = null;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _removeOverlay();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  _Row _newRow() {
    final row = _Row();
    row.weightFocus.addListener(_onFocusChange);
    row.repsFocus.addListener(_onFocusChange);
    return row;
  }

  void _disposeLater(_Row row) {
    // Its fields unmount with the next frame; release them after.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _reconcile() {
    final sets = widget.entry.sets;
    final count = _rowCountFor(sets.length);
    while (_rows.length < count) {
      _rows.add(_newRow());
    }
    while (_rows.length > count) {
      final removed = _rows.removeLast();
      if (identical(removed, _selected)) _selected = null;
      _disposeLater(removed);
    }
    for (var i = 0; i < _rows.length && i < sets.length; i++) {
      final row = _rows[i];
      final set = sets[i];
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

  // Placeholders --------------------------------------------------------

  List<SetGhost> _ghosts(List<ActiveSet> sets) {
    final ghosts = <SetGhost>[];
    final lead = _lead;
    double? previousWeight;
    double? previousReps;
    for (var i = 0; i < _rows.length; i++) {
      if (i < sets.length) {
        ghosts.add(SetGhost.none);
        previousWeight = sets[i].weight;
        previousReps = sets[i].reps;
        continue;
      }
      final row = _rows[i];
      final ghost = widget.prefill
          ? ghostForRow(
              index: i,
              previous: widget.previous,
              planned: _plan,
              lead: lead,
              previousWeight: previousWeight,
              previousReps: previousReps,
            )
          : SetGhost.none;
      ghosts.add(ghost);
      final typedWeight = parseDecimal(row.weight.text, allowNegative: true);
      previousWeight = typedWeight == null
          ? ghost.weight ?? previousWeight
          : kilogramsFromDisplay(context, typedWeight);
      previousReps = parseDecimal(row.reps.text) ?? ghost.reps ?? previousReps;
    }
    return ghosts;
  }

  SetGhost _ghostAt(int index) {
    final ghosts = _ghosts(_liveSets);
    return index >= 0 && index < ghosts.length ? ghosts[index] : SetGhost.none;
  }

  /// A logged set's type; a pending row's toggle, else its planned set's,
  /// else its placeholder's (prefill off: the plan still decides).
  bool _isWarmup(int index, List<ActiveSet> sets, List<SetGhost> ghosts) =>
      index < sets.length
      ? sets[index].isWarmup
      : (_rows[index].warmup ??
            _plannedAt(index)?.isWarmup ??
            ghosts[index].warmup);

  double? _rpeAt(int index, List<ActiveSet> sets) =>
      index < sets.length ? sets[index].rpe : _rows[index].rpe;

  List<String> _badges(List<ActiveSet> sets, List<SetGhost> ghosts) {
    var working = 0;
    return [
      for (var i = 0; i < _rows.length; i++)
        _isWarmup(i, sets, ghosts) ? 'W' : '${++working}',
    ];
  }

  // Focus and number entry ---------------------------------------------

  ({_Row row, _Kind kind})? get _focused {
    for (final row in _rows) {
      if (row.weightFocus.hasFocus) return (row: row, kind: _Kind.weight);
      if (row.repsFocus.hasFocus) return (row: row, kind: _Kind.reps);
    }
    return null;
  }

  void _onFocusChange() {
    if (!mounted) return;
    for (final row in _rows) {
      for (final kind in _Kind.values) {
        final focused = row.focusOf(kind).hasFocus;
        final had = kind == _Kind.weight
            ? row.hadWeightFocus
            : row.hadRepsFocus;
        if (focused && !had) {
          // Typing replaces the value: select it once the tap that focused
          // the field has placed its caret.
          final controller = row.controllerOf(kind);
          final field = kind == _Kind.weight ? row.weightKey : row.repsKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!row.focusOf(kind).hasFocus) return;
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          });
          if (widget.entryMode == NumberEntry.keypad) _pendingReveal = field;
        }
        if (kind == _Kind.weight) {
          row.hadWeightFocus = focused;
        } else {
          row.hadRepsFocus = focused;
        }
      }
    }
    final typing = _typing;
    if (typing != null && !typing.row.focusOf(typing.kind).hasFocus) {
      _typing = null;
    }
    setState(() {});
    _syncOverlay();
  }

  /// The keypad is an overlay the scroll view cannot see: scroll the field's
  /// row into the space above it. Runs after the frame that made the room.
  void _revealAboveKeypad(GlobalKey field) {
    final fieldContext = field.currentContext;
    final box = fieldContext?.findRenderObject();
    if (fieldContext == null || box is! RenderBox || !box.attached) return;
    final scrollable = Scrollable.maybeOf(fieldContext);
    if (scrollable == null) return;
    final media = MediaQuery.of(fieldContext);
    final keypadTop =
        media.size.height - NumberKeypad.height - media.padding.bottom;
    // Leave the rest of the opened row (unit labels, its padding) in view.
    final rowBottom = box.localToGlobal(Offset(0, box.size.height)).dy + 40;
    final overlap = rowBottom - keypadTop;
    if (overlap <= 0) return;
    final position = scrollable.position;
    position.animateTo(
      (position.pixels + overlap).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  bool get _usesPhoneKeyboard =>
      widget.entryMode == NumberEntry.phoneKeyboard ||
      (widget.entryMode == NumberEntry.steppers && _typing != null);

  void _syncOverlay() {
    final wanted =
        _focused != null &&
        (widget.entryMode == NumberEntry.keypad || _usesPhoneKeyboard);
    if (!wanted) {
      _hideOverlay();
      return;
    }
    if (_overlay == null) {
      _overlay = OverlayEntry(builder: _buildOverlay);
      Overlay.of(context, rootOverlay: true).insert(_overlay!);
    } else {
      if (_overlayClosing) {
        // Focus came back while it slid away: bring it back up.
        _overlayClosing = false;
        _panelKey.currentState?.show();
      }
      _overlay!.markNeedsBuild();
    }
  }

  /// Slides the panel away, then removes its entry.
  void _hideOverlay() {
    final entry = _overlay;
    if (entry == null || _overlayClosing) return;
    final panel = _panelKey.currentState;
    if (panel == null) {
      _removeOverlay();
      return;
    }
    _overlayClosing = true;
    entry.markNeedsBuild();
    panel.hide().then((_) {
      if (_overlayClosing && identical(_overlay, entry)) _removeOverlay();
    });
  }

  void _removeOverlay() {
    _overlayClosing = false;
    _lastPanel = null;
    _overlay?.remove();
    _overlay?.dispose();
    _overlay = null;
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final focused = _focused;
    if (focused != null && mounted && !_overlayClosing) {
      _lastPanel = _panel(focused);
    }
    final panel = _lastPanel;
    if (panel == null) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      // The keyboard bar rides on the phone's keyboard.
      bottom: widget.entryMode == NumberEntry.keypad
          ? 0
          : MediaQuery.viewInsetsOf(overlayContext).bottom,
      child: IgnorePointer(
        ignoring: _overlayClosing,
        child: _SlidePanel(key: _panelKey, child: panel),
      ),
    );
  }

  Widget _panel(({_Row row, _Kind kind}) focused) {
    final sets = _liveSets;
    final index = _rows.indexOf(focused.row);
    final ghosts = _ghosts(sets);
    final badges = _badges(sets, ghosts);
    final logged = index < sets.length;
    final logLabel = logged ? 'Done' : _logLabel(index, ghosts, badges);
    final rating = logged ? null : focused.row.rpe;
    final logTrailing = rating == null
        ? null
        : effortLabel(widget.effort, rating);
    final onLog = logged ? _unfocus : () => _logRow(focused.row);
    final isWeight = focused.kind == _Kind.weight;
    if (widget.entryMode == NumberEntry.keypad) {
      final unit = weightUnitOf(context).symbol;
      return NumberKeypad(
        caption: isWeight
            ? 'Set ${badges[index]} weight, in $unit'
            : 'Set ${badges[index]} reps',
        allowSign: isWeight,
        logLabel: logLabel,
        logTrailing: logTrailing,
        onLog: onLog,
        onKey: (key, digit) => _onKey(focused, key, digit),
      );
    }
    return KeyboardToolbar(
      onSign: isWeight ? () => _onKey(focused, KeypadKey.sign, '') : null,
      onNext: () => _onKey(focused, KeypadKey.next, ''),
      logLabel: logLabel,
      logTrailing: logTrailing,
      onLog: onLog,
    );
  }

  void _onKey(({_Row row, _Kind kind}) field, KeypadKey key, String digit) {
    switch (key) {
      case KeypadKey.next:
        if (field.kind == _Kind.weight) {
          field.row.repsFocus.requestFocus();
        } else {
          final index = _rows.indexOf(field.row);
          if (index >= 0 && index + 1 < _rows.length) {
            _rows[index + 1].weightFocus.requestFocus();
          } else {
            _unfocus();
          }
        }
      case KeypadKey.hide:
        _unfocus();
      case KeypadKey.digit:
      case KeypadKey.backspace:
      case KeypadKey.sign:
        applyKeypadKey(
          field.row.controllerOf(field.kind),
          key,
          digit: digit,
          allowNegative: field.kind == _Kind.weight,
        );
        setState(() {});
        _overlay?.markNeedsBuild();
    }
  }

  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    _selected = null;
    if (mounted) setState(() {});
  }

  // Logging -------------------------------------------------------------

  String _logLabel(int index, List<SetGhost> ghosts, List<String> badges) {
    if (index < 0 || index >= _rows.length) return 'Log set';
    final row = _rows[index];
    final ghost = ghosts[index];
    final weight =
        parseDecimal(row.weight.text, allowNegative: true) ??
        (ghost.weight == null ? null : displayWeightOf(context, ghost.weight!));
    final reps = parseDecimal(row.reps.text) ?? ghost.reps;
    if (weight == null || reps == null) {
      return badges[index] == 'W' ? 'Log warm-up' : 'Log set ${badges[index]}';
    }
    return 'Log ${formatDecimal(weight)} ${weightUnitOf(context).symbol} × '
        '${formatDecimal(reps)}';
  }

  Future<void> _logRow(_Row row) async {
    await _commitRow(row, explicit: true);
    if (!mounted) return;
    if (_rows.indexOf(row) < _liveSets.length) _unfocus();
  }

  Future<void> _commitRow(_Row row, {bool explicit = false}) async {
    if (row.busy) return;
    var index = _rows.indexOf(row);
    if (index < 0) return;
    var sets = _liveSets;
    final mapped = index < sets.length ? sets[index] : null;

    var weightText = row.weight.text.trim();
    var repsText = row.reps.text.trim();
    if (weightText.isEmpty && repsText.isEmpty && !explicit) {
      row.weightError = null;
      row.repsError = null;
      if (mapped != null) {
        _removeLoggedSet(index, sets, mapped);
      } else {
        setState(() {});
      }
      return;
    }

    if (mapped == null) {
      // Blanks take the row's placeholder: when logging on purpose, or when
      // one value was typed and the row was left.
      final ghost = _ghostAt(index);
      if (weightText.isEmpty && ghost.weight != null) {
        row.weight.text = formatDecimal(
          displayWeightOf(context, ghost.weight!),
        );
        weightText = row.weight.text;
      }
      if (repsText.isEmpty && ghost.reps != null) {
        row.reps.text = formatDecimal(ghost.reps!);
        repsText = row.reps.text;
      }
    }

    // Values keep the typed digits (never rounded): the input formatter caps
    // both fields at two decimal places, and the parse truncates pasted or
    // hand-set values the same way.
    final weightDisplay = parseDecimal(weightText, allowNegative: true);
    final reps = parseDecimal(repsText);
    final weightError = requiredWeight(weightText);
    final repsError = requiredReps(repsText);
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

    final kilograms = kilogramsFromDisplay(context, weightDisplay);
    if (mapped != null &&
        _sameKg(mapped.weight, kilograms) &&
        mapped.reps == reps) {
      setState(() {
        row.weightError = null;
        row.repsError = null;
      });
      return;
    }

    final warmup = _isWarmup(index, sets, _ghosts(sets));
    row.busy = true;
    final confirmed =
        await confirmWeightEntry(context, weightDisplay) &&
        mounted &&
        (mapped?.reps == reps || await confirmRepsEntry(context, reps));
    row.busy = false;
    if (!mounted || !confirmed) return;

    // The modal blocks other edits, but the session may still have been
    // ended or restored underneath: re-read the mapping before writing.
    index = _rows.indexOf(row);
    if (index < 0) return;
    final cubit = context.read<WorkoutCubit>();
    sets = _liveSets;
    final target = index < sets.length ? sets[index] : null;
    if (target != null) {
      if (!_sameKg(target.weight, kilograms) || target.reps != reps) {
        cubit.updateSet(target.order, weight: kilograms, reps: reps);
      }
    } else {
      // The new set is appended after the logged ones. Move a row filled
      // further down up to that slot, or the set would show in the first
      // open row and leave this one behind as a stale copy.
      if (index > sets.length) {
        _rows.insert(sets.length, _rows.removeAt(index));
      }
      final rowsBefore = _rowCountFor(sets.length);
      cubit.logSet(
        exerciseId: _exerciseId,
        exerciseName: widget.entry.exercise.name,
        weight: kilograms,
        reps: reps,
        type: warmup ? SetType.warmup : SetType.working,
        rpe: row.rpe,
      );
      // Logging into a row past the base rows keeps the row count.
      if (_rowCountFor(sets.length + 1) > rowsBefore && _extraRows > 0) {
        _extraRows--;
      }
      row.warmup = null;
      row.rpe = null;
      if (identical(_selected, row)) _selected = null;
    }
    // Remember the committed values so the next reconcile keeps the typed
    // text (kg is exact; in lb the display rounds to the stored value).
    row.weightError = null;
    row.repsError = null;
    row.lastWeightKg = kilograms;
    row.lastReps = reps;
    setState(() {});
    _overlay?.markNeedsBuild();
  }

  /// Rows map to sets by position, so removing a logged set shifts every
  /// later set up one row. Clear the rows from [index] on, so the next
  /// reconcile refills them from the shifted sets instead of leaving the
  /// last one behind as a stale copy of the set it held.
  void _removeLoggedSet(int index, List<ActiveSet> sets, ActiveSet mapped) {
    for (var j = index; j < sets.length && j < _rows.length; j++) {
      _rows[j].clear();
    }
    context.read<WorkoutCubit>().removeSet(mapped.order);
    setState(() {});
  }

  // Row actions ---------------------------------------------------------

  void _toggleWarmup(_Row row) {
    final index = _rows.indexOf(row);
    if (index < 0) return;
    // A tap can blur the typed row first, and that blur may already have
    // logged it: then the toggle flips the logged set's type.
    final sets = _liveSets;
    if (index < sets.length) {
      final set = sets[index];
      context.read<WorkoutCubit>().updateSet(
        set.order,
        type: set.isWarmup ? SetType.working : SetType.warmup,
      );
      return;
    }
    final ghosts = _ghosts(sets);
    setState(() => row.warmup = !(row.warmup ?? ghosts[index].warmup));
  }

  Future<void> _pickEffort(_Row row) async {
    final index = _rows.indexOf(row);
    if (index < 0) return;
    final sets = _liveSets;
    final badge = _badges(sets, _ghosts(sets))[index];
    final choice = await showEffortSheet(
      context,
      title: badge == 'W' ? 'Warm-up effort' : 'Set $badge effort',
      scale: widget.effort,
      rpe: _rpeAt(index, sets),
    );
    if (choice == null || !mounted) return;
    _rate(row, choice.rpe);
  }

  /// Rates [row]'s set ([rpe] null clears it). The tap that rated it can
  /// blur the row, and that blur may have logged it since: re-read where the
  /// rating goes.
  void _rate(_Row row, double? rpe) {
    final at = _rows.indexOf(row);
    if (at < 0) return;
    final live = _liveSets;
    if (at < live.length) {
      context.read<WorkoutCubit>().setRpe(live[at].order, rpe);
    } else {
      setState(() => row.rpe = rpe);
      _overlay?.markNeedsBuild();
    }
  }

  void _addRow() {
    setState(() {
      _extraRows++;
      // Materialize the row now: build() walks _rows, so without this the
      // blank row would only appear on the next cubit emission.
      _rows.add(_newRow());
    });
  }

  bool _canDelete(int index) {
    if (index < widget.entry.sets.length) return true;
    return _rows[index].hasText || _rows.length > 1;
  }

  /// The row's second swipe (or its Delete tap) removes it; the first only
  /// slid it open, so no dialog asks again.
  void _onDeleted(_Row row) {
    final index = _rows.indexOf(row);
    // A stale gesture must not remove a row that can no longer go.
    if (index < 0 || !_canDelete(index)) return;
    final sets = _liveSets;
    if (index < sets.length) {
      _removeLoggedSet(index, sets, sets[index]);
      return;
    }
    setState(() {
      _rows.removeAt(index);
      if (identical(_selected, row)) _selected = null;
      _disposeLater(row);
      if (_extraRows > 0) {
        _extraRows--;
      } else {
        _removedBaseRows++;
      }
      _reconcile();
    });
  }

  void _step(_Row row, _Kind kind, int direction) {
    final index = _rows.indexOf(row);
    if (index < 0) return;
    final ghost = _ghostAt(index);
    if (kind == _Kind.weight) {
      final step = weightUnitOf(context) == WeightUnit.kilograms ? 2.5 : 5.0;
      final current =
          parseDecimal(row.weight.text, allowNegative: true) ??
          (ghost.weight == null
              ? 0.0
              : displayWeightOf(context, ghost.weight!));
      final next = (current + step * direction).clamp(
        minimumWeight,
        maximumWeight,
      );
      row.weight.text = formatDecimal(next.toDouble());
    } else {
      final current = parseDecimal(row.reps.text) ?? ghost.reps ?? 0;
      // Stepping never goes below one rep, or below a partial rep typed in.
      final next = (current + direction).clamp(
        math.min(1.0, math.max(current, minimumReps)),
        maximumReps,
      );
      row.reps.text = formatDecimal(next.toDouble());
    }
    setState(() {});
    _overlay?.markNeedsBuild();
    // A logged set saves right away; a pending one waits for Log, or for
    // its row to be left when a field holds the focus.
    if (index < _liveSets.length && !row.hasFocus) _commitRow(row);
  }

  void _startRepeat(_Row row, _Kind kind, int direction) {
    _repeat?.cancel();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _step(row, kind, direction),
    );
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  void _scrub(_Row row, _Kind kind, double dy) {
    // Dragging up adds, dragging down subtracts, one step per 14 pixels.
    _scrubbed += dy;
    while (_scrubbed <= -14) {
      _scrubbed += 14;
      _step(row, kind, 1);
    }
    while (_scrubbed >= 14) {
      _scrubbed -= 14;
      _step(row, kind, -1);
    }
  }

  void _startTyping(_Row row, _Kind kind) {
    setState(() => _typing = (row: row, kind: kind));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.focusOf(kind).requestFocus();
    });
  }

  void _select(_Row row) {
    if (identical(_selected, row)) return;
    setState(() => _selected = row);
  }

  Future<void> _removeExercise() async {
    final cubit = context.read<WorkoutCubit>();
    final sets = widget.entry.sets;
    if (sets.isNotEmpty) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Remove ${widget.entry.exercise.name}?',
        message:
            'This will delete its ${plural('set', sets.length)} from this '
            'workout.',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    cubit.removeExercise(_exerciseId);
  }

  // Build ---------------------------------------------------------------

  int? _currentIndex(List<ActiveSet> sets) {
    for (var i = 0; i < _rows.length; i++) {
      if (_rows[i].hasFocus) return i;
    }
    final selected = _selected == null ? -1 : _rows.indexOf(_selected!);
    if (selected >= 0) return selected;
    return sets.length < _rows.length ? sets.length : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!TabVisibilityScope.isActiveOf(context) && _focused != null) {
      // Another tab is showing: put the keypad away with the focus.
      WidgetsBinding.instance.addPostFrameCallback((_) => _unfocus());
    }
    final sets = widget.entry.sets;
    final ghosts = _ghosts(sets);
    final badges = _badges(sets, ghosts);
    final current = _currentIndex(sets);
    final keypadOpen =
        widget.entryMode == NumberEntry.keypad && _focused != null;
    final reveal = _pendingReveal;
    if (keypadOpen && reveal != null) {
      _pendingReveal = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealAboveKeypad(reveal),
      );
    }
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottomRoom = keypadOpen
        ? NumberKeypad.height + 24
        : keyboard > 0
        ? keyboard + 80
        : (widget.lastSetAt == null ? 96.0 : 128.0);

    // The value fields are Material text fields; the page paints nothing.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          CustomScrollView(
            slivers: <Widget>[
              CustomAppBar(
                context,
                title: widget.entry.exercise.name,
                trailing: _menu(context),
              ),
              SliverToBoxAdapter(
                child: MaxWidth(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomRoom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _position(context),
                        _columnHeader(context),
                        for (var i = 0; i < _rows.length; i++)
                          KeyedSubtree(
                            // Keyed by the row itself: a commit can move its
                            // row up to the slot the new set lands in, and the
                            // fields (focus included) must move along with it.
                            key: ObjectKey(_rows[i]),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                              child: _rowFrame(
                                context,
                                i,
                                sets: sets,
                                ghosts: ghosts,
                                badges: badges,
                                isCurrent: i == current,
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FButton(
                              variant: .ghost,
                              mainAxisSize: .min,
                              onPress: _addRow,
                              prefix: const Icon(FLucideIcons.plus),
                              child: const Text('Add set'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _dock(context, sets, ghosts, badges, current),
          ),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final destructive = context.theme.colors.destructive;
    return FPopoverMenu.tiles(
      menuAnchor: .topRight,
      childAnchor: .bottomRight,
      menuBuilder: (menuContext, controller, _) => [
        .group(
          children: [
            .tile(
              prefix: Icon(FLucideIcons.trash2, color: destructive),
              title: Text(
                'Remove from workout',
                style: TextStyle(color: destructive),
              ),
              onPress: () {
                controller.hide();
                _removeExercise();
              },
            ),
          ],
        ),
      ],
      builder: (_, controller, _) => AppIconButton(
        icon: FLucideIcons.ellipsis,
        tooltip: 'Exercise options',
        onPress: controller.toggle,
      ),
    );
  }

  /// Where this exercise sits in the workout: the day, its place, the
  /// workout clock and one segment per exercise. A tap goes back to the list.
  Widget _position(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final entries = widget.entries;
    return Semantics(
      button: true,
      hint: 'Back to the workout list',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${widget.title}, exercise ${widget.index + 1} of '
                      '${entries.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElapsedClock(
                    start: widget.startTime,
                    style: theme.typography.body.xs.copyWith(
                      color: accents.live,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  for (final (i, entry) in entries.indexed) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: entry.progress,
                          color: accents.live,
                          backgroundColor: theme.colors.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Last session's value for the row at [index], small under the number:
  /// null when there is none, or when [ghost] already shows it as the
  /// placeholder.
  String? _lastValue(int index, _Kind kind, {SetGhost? ghost}) {
    final sets = widget.previous?.sets;
    if (sets == null || index >= sets.length) return null;
    final set = sets[index];
    final value = kind == _Kind.weight
        ? formatDecimal(displayWeightOf(context, set.weight))
        : formatReps(set.reps);
    if (ghost != null) {
      final shown = kind == _Kind.weight
          ? (ghost.weight == null
                ? null
                : formatDecimal(displayWeightOf(context, ghost.weight!)))
          : (ghost.reps == null ? null : formatReps(ghost.reps!));
      if (shown == value) return null;
    }
    return value;
  }

  TextStyle _lastStyle(BuildContext context) =>
      context.theme.typography.body.xs3.copyWith(
        color: context.theme.colors.mutedForeground,
        fontWeight: FontWeight.w500,
        height: 1.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  Widget _columnHeader(BuildContext context) {
    final theme = context.theme;
    final style = theme.typography.body.xs3.copyWith(
      color: theme.colors.mutedForeground,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Row(
        children: <Widget>[
          SizedBox(width: 28, child: Text('Set', style: style)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              weightUnitOf(context).symbol,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text('Reps', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: _effortWidth,
            child: Text(
              widget.effort.label,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _rowFrame(
    BuildContext context,
    int index, {
    required List<ActiveSet> sets,
    required List<SetGhost> ghosts,
    required List<String> badges,
    required bool isCurrent,
  }) {
    final row = _rows[index];
    final colors = context.theme.colors;
    final content = isCurrent
        ? _openRow(context, index, sets, ghosts, badges)
        : _compactRow(context, index, sets, ghosts, badges);
    return Focus(
      // The row commits when focus leaves any of its fields; the wrapper
      // must not capture focus or join traversal.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!focused) _commitRow(row);
      },
      child: SwipeToDelete(
        canDelete: _canDelete(index),
        onDelete: () => _onDeleted(row),
        // The page color under the row's own rounded tint: the delete
        // background never shows at rest, the corners stay round.
        surface: colors.background,
        // Switching the set being done opens one row and folds the other:
        // both glide to their new height. The fields keep their keys, so
        // the two layouts never overlap.
        child: AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: content,
        ),
      ),
    );
  }

  Widget _compactRow(
    BuildContext context,
    int index,
    List<ActiveSet> sets,
    List<SetGhost> ghosts,
    List<String> badges,
  ) {
    final row = _rows[index];
    final logged = index < sets.length;
    final accents = TrackerAccents.of(context);
    final theme = context.theme;
    final ghost = ghosts[index];
    final rpe = _rpeAt(index, sets);
    Widget box(_Kind kind) {
      final field = _valueField(context, row, kind, ghost, big: false);
      // A waiting row's placeholder is usually last time's value already.
      final last = _lastValue(index, kind, ghost: logged ? null : ghost);
      return Container(
        height: 40,
        alignment: Alignment.center,
        child: last == null
            ? field
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  field,
                  Text(
                    last,
                    textAlign: TextAlign.center,
                    style: _lastStyle(context),
                  ),
                ],
              ),
      );
    }

    final hasError = row.weightError != null || row.repsError != null;
    // A set reads its state from its row: a waiting one is outlined in grey,
    // the one being done in blue (the open row), a logged one filled in.
    // The numbers sit in the same columns in all three.
    final frame = Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: logged ? accents.liveSoft : theme.colors.background,
        borderRadius: BorderRadius.circular(12),
        border: logged
            ? null
            : Border.all(
                color: hasError ? theme.colors.error : theme.colors.border,
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _badge(context, row, badges[index], _isWarmup(index, sets, ghosts)),
          const SizedBox(width: 8),
          Expanded(
            child: _withError(context, box(_Kind.weight), row.weightError),
          ),
          _times(context),
          Expanded(child: _withError(context, box(_Kind.reps), row.repsError)),
          const SizedBox(width: 6),
          // A waiting set has nothing to rate or tick yet.
          if (logged || rpe != null)
            _effortCell(
              context,
              row,
              rpe: rpe,
              badge: badges[index],
              logged: logged,
            )
          else
            const SizedBox(width: _effortWidth),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 40,
            child: logged ? _loggedMark(context, badges[index]) : null,
          ),
        ],
      ),
    );
    // The whole row is the target: a tap anywhere makes it the set being
    // done. The badge, the rating and the fields keep their own taps.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Another row being typed in saves as its focus leaves.
        if (_focused != null) FocusManager.instance.primaryFocus?.unfocus();
        _select(row);
      },
      child: frame,
    );
  }

  /// [field] with its error right under it, in its own column.
  Widget _withError(BuildContext context, Widget field, String? error) {
    if (error == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        field,
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: context.theme.typography.body.xs3.copyWith(
              color: context.theme.colors.error,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  static const _effortWidth = 38.0;

  String _effortSemantics(String badge, double? rpe) {
    final who = badge == 'W' ? 'Warm-up' : 'Set $badge';
    final scale = widget.effort;
    return rpe == null
        ? '$who ${scale.label}, not rated'
        : '$who ${effortLabel(scale, rpe)}';
  }

  /// The set's rating in its own column: a tap opens the 0 to 10 picker.
  Widget _effortCell(
    BuildContext context,
    _Row row, {
    required double? rpe,
    required String badge,
    required bool logged,
  }) {
    final theme = context.theme;
    final style = theme.typography.body.sm.copyWith(
      fontWeight: FontWeight.w600,
      color: rpe == null ? theme.colors.mutedForeground : null,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      button: true,
      label: _effortSemantics(badge, rpe),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pickEffort(row),
        child: Container(
          width: _effortWidth,
          height: 40,
          alignment: Alignment.center,
          decoration: logged
              ? null
              : BoxDecoration(
                  color: theme.colors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colors.border),
                ),
          child: Text(
            rpe == null ? '-' : formatEffort(widget.effort, rpe),
            style: style,
          ),
        ),
      ),
    );
  }

  /// The open row's rating in one tap: the usual values in a strip, the rest
  /// behind its last chip in the full sheet. Tapping the picked value again
  /// clears it. It stays quiet: the numbers are what the row is about.
  Widget _effortStrip(
    BuildContext context,
    _Row row, {
    required double? rpe,
    required String badge,
  }) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final scale = widget.effort;
    final who = badge == 'W' ? 'warm-up' : 'set $badge';
    final picked = rpe == null ? null : scale.fromRpe(rpe);
    // RPE 6 to 10 (RIR 4 to 0) cover nearly every set worth rating.
    final common = scale == EffortScale.rpe
        ? const [6, 7, 8, 9, 10]
        : const [0, 1, 2, 3, 4];
    final rarePicked = picked != null && !common.any((v) => v == picked);

    Widget chip(
      String label, {
      required bool selected,
      required String semantics,
      required VoidCallback onTap,
    }) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: semantics,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? accents.liveSoft : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? accents.liveSoft : theme.colors.border,
              ),
            ),
            child: Text(
              label,
              style: theme.typography.body.xs.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? accents.live : theme.colors.mutedForeground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );

    final rare = chip(
      rarePicked
          ? formatEffort(scale, rpe!)
          : (scale == EffortScale.rpe ? '<6' : '5+'),
      selected: rarePicked,
      semantics: 'Rate $who, other ${scale.label} values',
      onTap: () => _pickEffort(row),
    );
    final chips = <Widget>[
      for (final value in common)
        chip(
          '$value',
          selected: picked == value,
          semantics: 'Rate $who ${scale.label} $value',
          onTap: () => _rate(
            row,
            picked == value ? null : scale.toRpe(value.toDouble()),
          ),
        ),
    ];
    return Row(
      children: <Widget>[
        SizedBox(
          width: 34,
          child: Text(
            scale.label,
            style: theme.typography.body.xs3.copyWith(
              color: theme.colors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final (i, item) in [
          if (scale == EffortScale.rpe) rare,
          ...chips,
          if (scale == EffortScale.rir) rare,
        ].indexed) ...[if (i > 0) const SizedBox(width: 5), item],
      ],
    );
  }

  /// A label sitting on the open row's outline.
  Widget _legend(BuildContext context, Widget child) => Container(
    height: 16,
    color: context.theme.colors.background,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    child: child,
  );

  Widget _openRow(
    BuildContext context,
    int index,
    List<ActiveSet> sets,
    List<SetGhost> ghosts,
    List<String> badges,
  ) {
    final row = _rows[index];
    final logged = index < sets.length;
    final accents = TrackerAccents.of(context);
    final theme = context.theme;
    final ghost = ghosts[index];
    final steppers = widget.entryMode == NumberEntry.steppers;
    final unit = weightUnitOf(context).symbol;
    final badge = badges[index];
    final warmup = _isWarmup(index, sets, ghosts);
    final planned = _plannedAt(index);
    final target = planned == null ? null : SetTarget.fromPlanned(planned);
    final note = logged
        ? 'Logged'
        : target != null
        ? 'Aim for ${target.label} ${target.unit}'
        : steppers
        ? 'Hold a number to type it'
        : null;
    String caption(_Kind kind, String fallback) {
      final last = _lastValue(index, kind);
      return last == null ? fallback : 'last $last';
    }

    final values = steppers
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _withError(
                  context,
                  _verticalStepper(
                    context,
                    row,
                    _Kind.weight,
                    ghost,
                    caption(_Kind.weight, unit),
                  ),
                  row.weightError,
                ),
              ),
              SizedBox(height: 144, child: _times(context)),
              Expanded(
                child: _withError(
                  context,
                  _verticalStepper(
                    context,
                    row,
                    _Kind.reps,
                    ghost,
                    caption(_Kind.reps, 'reps'),
                  ),
                  row.repsError,
                ),
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _withError(
                  context,
                  _stepperGroup(
                    context,
                    row,
                    _Kind.weight,
                    ghost,
                    caption(_Kind.weight, unit),
                  ),
                  row.weightError,
                ),
              ),
              SizedBox(height: 52, child: _times(context)),
              Expanded(
                child: _withError(
                  context,
                  _stepperGroup(
                    context,
                    row,
                    _Kind.reps,
                    ghost,
                    caption(_Kind.reps, 'reps'),
                  ),
                  row.repsError,
                ),
              ),
            ],
          );
    final label = theme.typography.body.xs.copyWith(
      fontWeight: FontWeight.w700,
      color: accents.live,
    );
    final opened = Stack(
      children: <Widget>[
        Container(
          // The outline starts below the labels' midline.
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          decoration: BoxDecoration(
            color: logged ? accents.liveSoft : theme.colors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accents.live, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              values,
              const SizedBox(height: 8),
              _effortStrip(
                context,
                row,
                rpe: _rpeAt(index, sets),
                badge: badge,
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 12,
          child: Semantics(
            button: true,
            label: warmup
                ? 'Warm-up set, tap for a working set'
                : 'Set $badge, tap for a warm-up',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleWarmup(row),
              child: _legend(
                context,
                Text(warmup ? 'Warm-up' : 'Set $badge', style: label),
              ),
            ),
          ),
        ),
        if (note != null)
          Positioned(
            top: 0,
            right: 12,
            child: _legend(
              context,
              Text(
                note,
                maxLines: 1,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          ),
      ],
    );
    // Fades up as it opens, while the row around it grows into place.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) =>
          Opacity(opacity: 0.35 + 0.65 * t, child: child),
      child: opened,
    );
  }

  Widget _times(BuildContext context) => SizedBox(
    width: 18,
    height: 40,
    child: Center(
      child: Text(
        '×',
        textAlign: TextAlign.center,
        style: context.theme.typography.body.xs.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      ),
    ),
  );

  Widget _stepperGroup(
    BuildContext context,
    _Row row,
    _Kind kind,
    SetGhost ghost,
    String caption,
  ) {
    final theme = context.theme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              (kind == _Kind.weight ? row.weightError : row.repsError) == null
              ? theme.colors.border
              : theme.colors.error,
        ),
      ),
      child: Row(
        children: <Widget>[
          _stepButton(context, row, kind, -1),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 32,
                  child: _valueField(context, row, kind, ghost, big: true),
                ),
                Text(caption, maxLines: 1, style: _lastStyle(context)),
              ],
            ),
          ),
          _stepButton(context, row, kind, 1),
        ],
      ),
    );
  }

  Widget _verticalStepper(
    BuildContext context,
    _Row row,
    _Kind kind,
    SetGhost ghost,
    String caption,
  ) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _stepButton(context, row, kind, 1, wide: true),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: _valueField(context, row, kind, ghost, big: true, huge: true),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              FLucideIcons.chevronsUpDown,
              size: 12,
              color: theme.colors.mutedForeground,
            ),
            const SizedBox(width: 2),
            Text(caption, maxLines: 1, style: _lastStyle(context)),
          ],
        ),
        const SizedBox(height: 4),
        _stepButton(context, row, kind, -1, wide: true),
      ],
    );
  }

  Widget _stepButton(
    BuildContext context,
    _Row row,
    _Kind kind,
    int direction, {
    bool wide = false,
  }) {
    final theme = context.theme;
    final what = kind == _Kind.weight ? 'weight' : 'reps';
    return Semantics(
      button: true,
      label: direction > 0 ? 'Increase $what' : 'Decrease $what',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _step(row, kind, direction),
        onLongPressStart: (_) => _startRepeat(row, kind, direction),
        onLongPressEnd: (_) => _stopRepeat(),
        onLongPressCancel: _stopRepeat,
        child: Container(
          width: wide ? null : 34,
          height: wide ? 42 : 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colors.muted,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            direction > 0 ? FLucideIcons.plus : FLucideIcons.minus,
            size: 18,
            color: theme.colors.foreground,
          ),
        ),
      ),
    );
  }

  Widget _valueField(
    BuildContext context,
    _Row row,
    _Kind kind,
    SetGhost ghost, {
    required bool big,
    bool huge = false,
  }) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final isWeight = kind == _Kind.weight;
    final controller = row.controllerOf(kind);
    final hint = isWeight
        ? (ghost.weight == null
              ? weightUnitOf(context).symbol
              : formatDecimal(displayWeightOf(context, ghost.weight!)))
        : (ghost.reps == null ? 'Reps' : formatDecimal(ghost.reps!));
    final textStyle =
        (big ? theme.typography.body.xl : theme.typography.body.sm).copyWith(
          fontSize: huge ? 28 : (big ? 22 : null),
          fontWeight: big ? FontWeight.w700 : FontWeight.w600,
          height: 1.15,
          color: theme.colors.foreground,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final hintStyle = textStyle.copyWith(color: theme.colors.mutedForeground);

    final typing = _typing;
    final steppersOnly =
        widget.entryMode == NumberEntry.steppers &&
        !(typing != null && identical(typing.row, row) && typing.kind == kind);
    if (steppersOnly) {
      final text = controller.text.trim();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(row),
        onLongPress: () => _startTyping(row, kind),
        onVerticalDragStart: (_) {
          _select(row);
          _scrubbed = 0;
        },
        onVerticalDragUpdate: (details) => _scrub(row, kind, details.delta.dy),
        child: Center(
          child: Text(
            text.isEmpty ? hint : text,
            style: text.isEmpty ? hintStyle : textStyle,
            maxLines: 1,
          ),
        ),
      );
    }

    final keypad = widget.entryMode == NumberEntry.keypad;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return TextField(
      key: isWeight ? row.weightKey : row.repsKey,
      controller: controller,
      focusNode: row.focusOf(kind),
      keyboardType: keypad
          ? TextInputType.none
          : TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [DecimalInputFormatter(allowNegative: isWeight)],
      textAlign: TextAlign.center,
      textAlignVertical: TextAlignVertical.center,
      style: textStyle,
      cursorColor: accents.live,
      showCursor: true,
      // The rows sit inside the swipe-to-delete wrapper: no selection
      // handles, so a horizontal swipe never drags a selection instead.
      enableInteractiveSelection: false,
      textInputAction: isWeight ? TextInputAction.next : TextInputAction.done,
      onSubmitted: (_) => isWeight
          ? row.repsFocus.requestFocus()
          : FocusScope.of(context).unfocus(),
      onChanged: (_) {
        setState(() {});
        _overlay?.markNeedsBuild();
      },
      scrollPadding: EdgeInsets.only(
        bottom: keypad ? NumberKeypad.height + 40 : keyboard + 120,
      ),
      decoration: InputDecoration.collapsed(
        hintText: hint,
        hintStyle: hintStyle,
      ),
    );
  }

  Widget _badge(BuildContext context, _Row row, String label, bool warmup) {
    final theme = context.theme;
    return Semantics(
      button: true,
      label: warmup
          ? 'Warm-up set, tap for a working set'
          : 'Set $label, tap for a warm-up',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleWarmup(row),
        child: SizedBox(
          width: 28,
          height: 40,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colors.muted,
              ),
              child: Text(
                label,
                style: theme.typography.body.xs.copyWith(
                  fontWeight: FontWeight.w700,
                  color: warmup
                      ? theme.colors.mutedForeground
                      : theme.colors.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A logged set's tick. Only the dock logs, so a stray tap on a waiting
  /// row never saves it.
  Widget _loggedMark(BuildContext context, String label) {
    final accents = TrackerAccents.of(context);
    return Semantics(
      label: label == 'W' ? 'Warm-up logged' : 'Set $label logged',
      excludeSemantics: true,
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accents.live,
          ),
          child: Icon(
            FLucideIcons.check,
            size: 16,
            color: accents.liveForeground,
          ),
        ),
      ),
    );
  }

  Widget _dock(
    BuildContext context,
    List<ActiveSet> sets,
    List<SetGhost> ghosts,
    List<String> badges,
    int? current,
  ) {
    final Widget button;
    if (current != null && current >= sets.length) {
      final rating = _rows[current].rpe;
      button = AccentButton(
        large: true,
        prefix: FLucideIcons.check,
        label: _logLabel(current, ghosts, badges),
        // The rating rides along on the side: weight and reps lead.
        trailing: rating == null ? null : effortLabel(widget.effort, rating),
        onPress: () => _logRow(_rows[current]),
      );
    } else if (current != null) {
      button = AccentButton(large: true, label: 'Done', onPress: _unfocus);
    } else if (widget.next case final next?) {
      button = AccentButton(
        large: true,
        label: 'Next: ${next.exercise.name}',
        suffix: FLucideIcons.chevronRight,
        onPress: () => replaceWith<void>(
          context,
          ExercisePage(exerciseId: next.exercise.exerciseId),
        ),
      );
    } else if (widget.isPlan) {
      button = AccentButton(
        large: true,
        label: 'Finish workout',
        onPress: () => finishWorkout(context),
      );
    } else {
      // A free workout grows one exercise at a time from its list.
      button = AccentButton(
        large: true,
        label: 'Back to workout',
        onPress: () => Navigator.of(context).maybePop(),
      );
    }
    final lastSetAt = widget.lastSetAt;
    return WorkoutDock(
      above: lastSetAt == null ? null : _RestLine(since: lastSetAt),
      child: button,
    );
  }
}

/// How long since the workout's last set: counts up, nothing to set.
class _RestLine extends StatelessWidget {
  const _RestLine({required this.since});

  final DateTime since;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SizedBox(
      height: 30,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Resting',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
          ElapsedClock(
            start: since,
            style: theme.typography.body.xs.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

bool _sameKg(double stored, double committed) =>
    (stored - committed).abs() < 1e-9;

/// Slides its child up from the bottom edge when it first shows; [hide]
/// slides it back down. Instant when the platform asks for less motion.
class _SlidePanel extends StatefulWidget {
  const _SlidePanel({super.key, required this.child});

  final Widget child;

  @override
  State<_SlidePanel> createState() => _SlidePanelState();
}

class _SlidePanelState extends State<_SlidePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 170),
  );

  late final Animation<Offset> _offset = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  ).drive(Tween(begin: const Offset(0, 1), end: Offset.zero));

  bool get _instant => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed && !_controller.isAnimating) show();
  }

  void show() {
    if (_instant) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  Future<void> hide() {
    if (_instant) {
      _controller.value = 0;
      return Future<void>.value();
    }
    return _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SlideTransition(position: _offset, child: widget.child);
}
