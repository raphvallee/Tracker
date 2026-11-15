import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:tracker/ui/core/ui/effort_sheet.dart';
import 'package:tracker/ui/core/ui/effort_strip.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/number_keypad.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/row_motion.dart';
import 'package:tracker/ui/core/ui/motion.dart';
import 'package:tracker/ui/core/ui/slide_up_panel.dart';
import 'package:tracker/ui/core/ui/swipe_to_delete.dart';
import 'package:tracker/ui/core/ui/weight_confirmation.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/utils/decimal_input.dart';
import 'package:tracker/utils/form_validators.dart';

import 'elapsed_clock.dart';
import 'finish_workout.dart';
import 'plan_bar.dart';
import 'set_comparison.dart';
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

  /// The row tapped, which has no focus to follow.
  _Row? _selected;

  OverlayEntry? _overlay;

  /// The keypad is sliding away; its entry goes once it is out of sight.
  bool _overlayClosing = false;
  final _panelKey = GlobalKey<SlideUpPanelState>();

  /// The panel last shown, kept on screen while it slides away.
  Widget? _lastPanel;
  Timer? _repeat;

  /// The field to lift above the keypad once the page has made room.
  GlobalKey? _pendingReveal;

  /// The dock: an opening row keeps clear of it.
  final _dockKey = GlobalKey(debugLabel: 'exercise dock');

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
          if (widget.entryMode.usesKeypad) _pendingReveal = field;
        }
        if (kind == _Kind.weight) {
          row.hadWeightFocus = focused;
        } else {
          row.hadRepsFocus = focused;
        }
      }
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
        media.size.height -
        NumberKeypad.heightOf(widget.entryMode) -
        media.padding.bottom;
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

  /// Where the page stops being seen, in global coordinates: the keypad's
  /// top while it is up (or on its way up), the phone keyboard's bar, else
  /// the dock's top.
  double _visibleBottom() {
    final size = MediaQuery.sizeOf(context);
    if (_focused != null) {
      if (widget.entryMode.usesKeypad) {
        return size.height -
            NumberKeypad.heightOf(widget.entryMode) -
            MediaQuery.paddingOf(context).bottom;
      }
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      if (keyboard > 0) return size.height - keyboard - _keyboardBarHeight;
    }
    final dock = _dockKey.currentContext?.findRenderObject();
    if (dock is RenderBox && dock.attached && dock.hasSize) {
      return dock.localToGlobal(Offset.zero).dy;
    }
    return size.height;
  }

  /// About the height of the bar on top of the phone keyboard.
  static const _keyboardBarHeight = 56.0;

  /// Keeps a row that is opening clear of the dock or the keypad.
  void _followOpening(BuildContext rowContext, double share) {
    if (!mounted) return;
    followOpening(rowContext, share, visibleBottom: _visibleBottom());
  }

  void _syncOverlay() {
    if (_focused == null) {
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
      bottom: widget.entryMode.usesKeypad
          ? 0
          : MediaQuery.viewInsetsOf(overlayContext).bottom,
      child: IgnorePointer(
        ignoring: _overlayClosing,
        child: SlideUpPanel(key: _panelKey, child: panel),
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
    // A new set crossfades the Log label; typing updates it in place.
    final logKey = (logged ? 'done' : 'log', focused.row);
    // The keypad covers the dock: the rest clock comes along beside Log.
    final lastSetAt = context.read<WorkoutCubit>().state.lastSetAt;
    final restClock = lastSetAt == null ? null : _RestClock(since: lastSetAt);
    final restTime = lastSetAt == null
        ? null
        : _RestClock(since: lastSetAt, compact: true);
    final isWeight = focused.kind == _Kind.weight;
    if (widget.entryMode.usesKeypad) {
      final unit = weightUnitOf(context).symbol;
      return NumberKeypad(
        caption: isWeight
            ? 'Set ${badges[index]} weight, in $unit'
            : 'Set ${badges[index]} reps',
        allowSign: isWeight,
        logLabel: logLabel,
        logTrailing: logTrailing,
        logKey: logKey,
        logLeading: restClock,
        onLog: onLog,
        onKey: (key, digit) => _onKey(focused, key, digit),
        steps: _keypadSteps(focused, index, ghosts[index]),
      );
    }
    return KeyboardToolbar(
      onSign: isWeight ? () => _onKey(focused, KeypadKey.sign, '') : null,
      onNext: () => _onKey(focused, KeypadKey.next, ''),
      logLabel: logLabel,
      logTrailing: logTrailing,
      logKey: logKey,
      leading: restTime,
      onLog: onLog,
    );
  }

  /// The keypad's steppers for [field] at row [index], in the number
  /// entries that have them.
  KeypadSteps? _keypadSteps(
    ({_Row row, _Kind kind}) field,
    int index,
    SetGhost ghost,
  ) {
    final entry = widget.entryMode;
    if (!entry.usesKeypad) return null;
    final ruler = entry == NumberEntry.keypadRuler;
    final value = _stepBase(field.row, field.kind, ghost);
    void onStep(int direction) => _step(field.row, field.kind, direction);
    final previous = widget.previous?.sets;
    final last = previous == null || index >= previous.length
        ? null
        : previous[index];
    return field.kind == _Kind.weight
        ? KeypadSteps.weight(
            ruler: ruler,
            value: value,
            unit: weightUnitOf(context),
            last: last == null ? null : displayWeightOf(context, last.weight),
            onStep: onStep,
          )
        : KeypadSteps.reps(
            ruler: ruler,
            value: value,
            last: last?.reps,
            onStep: onStep,
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
    // Logged from the keypad (or the keyboard): it stays up and moves on to
    // the next set's weight, so that set is typed without a tap to bring the
    // keypad back. After the last set it goes down.
    final typing = row.hasFocus;
    await _commitRow(row, explicit: true);
    if (!mounted) return;
    final sets = _liveSets;
    if (_rows.indexOf(row) >= sets.length) return;
    final next = sets.length < _rows.length ? _rows[sets.length] : null;
    if (typing && next != null) {
      _selected = next;
      next.weightFocus.requestFocus();
      setState(() {});
    } else {
      _unfocus();
    }
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

  /// The value a step starts from: what is typed, else the placeholder.
  double _stepBase(_Row row, _Kind kind, SetGhost ghost) => kind == _Kind.weight
      ? parseDecimal(row.weight.text, allowNegative: true) ??
            (ghost.weight == null
                ? 0.0
                : displayWeightOf(context, ghost.weight!))
      : parseDecimal(row.reps.text) ?? ghost.reps ?? 0;

  void _step(_Row row, _Kind kind, int direction) {
    final index = _rows.indexOf(row);
    if (index < 0) return;
    final current = _stepBase(row, kind, _ghostAt(index));
    if (kind == _Kind.weight) {
      final step = weightUnitOf(context) == WeightUnit.kilograms ? 2.5 : 5.0;
      final next = (current + step * direction).clamp(
        minimumWeight,
        maximumWeight,
      );
      row.weight.text = formatDecimal(next.toDouble());
    } else {
      // Stepping never goes below one rep, or below a partial rep typed in.
      final next = (current + direction).clamp(
        math.min(1.0, math.max(current, minimumReps)),
        maximumReps,
      );
      row.reps.text = formatDecimal(next.toDouble());
    }
    final controller = row.controllerOf(kind);
    if (widget.entryMode.usesKeypad && row.focusOf(kind).hasFocus) {
      // The next key typed starts the value over, as after focusing.
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
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
    final keypadOpen = widget.entryMode.usesKeypad && _focused != null;
    final reveal = _pendingReveal;
    if (keypadOpen && reveal != null) {
      _pendingReveal = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealAboveKeypad(reveal),
      );
    }
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottomRoom = keypadOpen
        ? NumberKeypad.heightOf(widget.entryMode) + 24
        : keyboard > 0
        ? keyboard + 80
        : 96.0;

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
                  child: AnimatedPadding(
                    // The room for the keypad opens at once, so the focused
                    // row can be scrolled above it, and closes as the keypad
                    // slides away, so rows scrolled to the end settle down
                    // instead of jumping.
                    duration:
                        keypadOpen ||
                            keyboard > 0 ||
                            MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : Motion.panelOut,
                    curve: Motion.exit,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
            child: KeyedSubtree(
              key: _dockKey,
              child: _dock(context, sets, ghosts, badges, current),
            ),
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
              PlanBar(segments: planSegments(entries, current: widget.index)),
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
    final warmup = _isWarmup(index, sets, ghosts);
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
        // The gap to the next row folds away with a deleted row.
        padding: const EdgeInsets.only(bottom: 6),
        // Switching the set being done folds one row and opens the other in
        // one motion: the frame, the numbers and the labels each move from
        // one look to the other. The fields keep their keys, so they never
        // jump or lose their focus.
        child: _RowMotion(
          open: isCurrent,
          logged: index < sets.length,
          comparison: isCurrent
              ? _comparison(index, ghosts[index], warmup: warmup)
              : null,
          onOpening: _followOpening,
          builder: (context, motion) => _setRow(
            context,
            index,
            sets: sets,
            ghosts: ghosts,
            badges: badges,
            open: isCurrent,
            motion: motion,
          ),
        ),
      ),
    );
  }

  /// The row at [index], [motion] of the way between its folded look (a
  /// line: badge, weight × reps, rating, tick) and its open one (the set
  /// being done: outlined in blue, its set and target on the outline,
  /// bigger numbers, the rating strip under them). Both share the line, so
  /// the numbers glide into place while the badge, rating and tick fold
  /// away to the sides and the rest grows in under them.
  Widget _setRow(
    BuildContext context,
    int index, {
    required List<ActiveSet> sets,
    required List<SetGhost> ghosts,
    required List<String> badges,
    required bool open,
    required _RowMotionValues motion,
  }) {
    final row = _rows[index];
    final logged = index < sets.length;
    final accents = TrackerAccents.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final ghost = ghosts[index];
    final badge = badges[index];
    final warmup = _isWarmup(index, sets, ghosts);
    final rpe = _rpeAt(index, sets);
    final t = motion.open;
    // The open row's own parts are there while it is open or on its way.
    final shown = open || t > 0;
    final comparison = motion.comparison;
    final compare = comparison == null ? 0.0 : motion.compare;

    Widget cell(_Kind kind) => _withError(
      context,
      _valueCell(
        context,
        index,
        kind,
        ghost: ghost,
        logged: logged,
        open: open,
        t: t,
      ),
      kind == _Kind.weight ? row.weightError : row.repsError,
    );

    final line = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _fold(
          1 - t,
          AlignmentDirectional.centerEnd,
          _leaving(
            open,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _badge(context, row, badge, warmup),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        Expanded(child: cell(_Kind.weight)),
        _times(context, height: _lerp(40, 52, t)),
        Expanded(child: cell(_Kind.reps)),
        _fold(
          1 - t,
          AlignmentDirectional.centerStart,
          _leaving(
            open,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(width: 6),
                // A waiting set has nothing to rate or tick yet.
                if (logged || rpe != null)
                  _effortCell(
                    context,
                    row,
                    rpe: rpe,
                    badge: badge,
                    logged: logged,
                  )
                else
                  const SizedBox(width: _effortWidth),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  height: 40,
                  // The tick grows in as the set is logged.
                  child: logged
                      ? Opacity(
                          opacity: motion.logged,
                          child: Transform.scale(
                            scale: 0.6 + 0.4 * motion.logged,
                            child: _loggedMark(context, badge),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    // A set reads its state from its row: a waiting one is outlined in grey,
    // the one being done in blue (the open row), a logged one filled in.
    final hasError = row.weightError != null || row.repsError != null;
    final rest = hasError ? colors.error : colors.border;
    final foldedBorder = rest.withValues(alpha: rest.a * (1 - motion.logged));
    final frame = Container(
      constraints: const BoxConstraints(minHeight: 54),
      // The outline starts below the labels' midline, and ends above the
      // comparison's.
      margin: EdgeInsets.only(top: 8 * t, bottom: 8 * t * compare),
      padding: EdgeInsets.fromLTRB(
        8,
        _lerp(7, 16, t),
        8,
        _lerp(7, 8 + 4 * compare, t),
      ),
      decoration: BoxDecoration(
        color: Color.lerp(colors.background, accents.liveSoft, motion.logged),
        borderRadius: BorderRadius.circular(_lerp(12, 14, t)),
        border: Border.all(
          color: Color.lerp(foldedBorder, accents.live, t)!,
          width: _lerp(1, 2, t),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          line,
          if (shown)
            _leaving(
              !open,
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: t,
                  // Fades with the room it takes, so that room never
                  // opens empty.
                  child: Opacity(
                    opacity: ((t - 0.3) / 0.7).clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _effortStrip(context, row, rpe: rpe, badge: badge),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final planned = _plannedAt(index);
    final target = planned == null ? null : SetTarget.fromPlanned(planned);
    final note = logged
        ? 'Logged'
        : target != null
        ? 'Aim for ${target.label} ${target.unit}'
        : null;
    final label = theme.typography.body.xs.copyWith(
      fontWeight: FontWeight.w700,
      color: accents.live,
    );
    // The labels ride on the outline as it moves, and rise the last 4px
    // into place as they fade in.
    final rise = 4 * (1 - motion.labels);
    final top = 8 * t - 8 + rise;
    Widget legend(Widget child, {double opacity = 1}) => Opacity(
      opacity: motion.labels * opacity,
      child: _legend(context, child),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // A folded row is a target as a whole: a tap anywhere makes it the set
      // being done. The badge, the rating and the fields keep their own taps.
      onTap: open ? null : () => _onRowTap(row),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          frame,
          if (shown)
            Positioned(
              top: top,
              left: 12,
              child: _leaving(
                !open,
                Semantics(
                  button: true,
                  label: warmup
                      ? 'Warm-up set, tap for a working set'
                      : 'Set $badge, tap for a warm-up',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleWarmup(row),
                    child: legend(
                      Text(warmup ? 'Warm-up' : 'Set $badge', style: label),
                    ),
                  ),
                ),
              ),
            ),
          if (shown && note != null)
            Positioned(
              top: top,
              right: 12,
              child: _leaving(
                !open,
                legend(
                  Text(
                    note,
                    maxLines: 1,
                    style: theme.typography.body.xs.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          if (shown && comparison != null && (motion.comparing || compare > 0))
            Positioned(
              left: 12,
              right: 12,
              bottom: 8 * t * compare - 8 - rise,
              child: _leaving(
                !open,
                Center(
                  child: IntrinsicWidth(
                    child: legend(
                      opacity: compare,
                      Text(
                        comparison.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.xs.copyWith(
                          fontWeight: FontWeight.w600,
                          color: comparison.isAhead
                              ? accents.live
                              : colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A tap on a folded row makes it the set being done. While a field is
  /// typed in, the keypad (or keyboard) stays up and moves on to the row's
  /// weight; the row left saves as its focus goes.
  void _onRowTap(_Row row) {
    if (_focused != null) {
      _selected = row;
      row.weightFocus.requestFocus();
      return;
    }
    _select(row);
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

  /// The open row's rating in one tap (see [EffortStrip]).
  Widget _effortStrip(
    BuildContext context,
    _Row row, {
    required double? rpe,
    required String badge,
  }) => EffortStrip(
    scale: widget.effort,
    rpe: rpe,
    who: badge == 'W' ? 'warm-up' : 'set $badge',
    onRate: (rpe) => _rate(row, rpe),
    onMore: () => _pickEffort(row),
  );

  /// A label sitting on the open row's outline.
  /// How the open row at [index] compares with the same set last time, from
  /// what is typed or prefilled. Null when there is no such set, when it was
  /// of the other kind (warm-up against working), or nothing differs.
  SetComparison? _comparison(
    int index,
    SetGhost ghost, {
    required bool warmup,
  }) {
    final sets = widget.previous?.sets;
    if (sets == null || index >= sets.length) return null;
    final last = sets[index];
    if (last.isWarmup != warmup) return null;
    final row = _rows[index];
    final weight =
        parseDecimal(row.weight.text, allowNegative: true) ??
        (ghost.weight == null ? null : displayWeightOf(context, ghost.weight!));
    final reps = parseDecimal(row.reps.text) ?? ghost.reps;
    if (weight == null || reps == null) return null;
    return compareWithLast(
      weight: weight,
      reps: reps,
      lastWeight: displayWeightOf(context, last.weight),
      lastReps: last.reps,
      unit: weightUnitOf(context).symbol,
    );
  }

  Widget _legend(BuildContext context, Widget child) => Container(
    height: 16,
    color: context.theme.colors.background,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    child: child,
  );

  Widget _times(BuildContext context, {double height = 40}) => SizedBox(
    width: 18,
    height: height,
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

  /// [child] at [factor] of its width, clipped and faded with it: the parts
  /// of a row that come and go as it opens or folds.
  Widget _fold(double factor, AlignmentGeometry alignment, Widget child) {
    if (factor <= 0) return const SizedBox.shrink();
    if (factor >= 1) return child;
    return ClipRect(
      child: Align(
        alignment: alignment,
        widthFactor: factor,
        child: Opacity(opacity: factor, child: child),
      ),
    );
  }

  /// [child] while it is on its way out ([gone]): no taps, no semantics.
  Widget _leaving(bool gone, Widget child) => IgnorePointer(
    ignoring: gone,
    child: ExcludeSemantics(excluding: gone, child: child),
  );

  /// The [kind] value of the row at [index], [t] of the way from its folded
  /// look (the number alone, last time's under it when the placeholder is
  /// not it already) to its open one (outlined and bigger, last time's value
  /// or the unit under it, and with the phone keyboard, steppers on either
  /// side). It is one field throughout, so the number moves into place
  /// instead of being swapped, and keeps its focus.
  Widget _valueCell(
    BuildContext context,
    int index,
    _Kind kind, {
    required SetGhost ghost,
    required bool logged,
    required bool open,
    required double t,
  }) {
    final row = _rows[index];
    final theme = context.theme;
    final colors = theme.colors;
    // With the steppers in the keypad the box is the number alone, outlined
    // while the keypad types into it.
    final bare = widget.entryMode.usesKeypad;
    final error = kind == _Kind.weight ? row.weightError : row.repsError;
    final outline = error != null
        ? colors.error
        : bare && row.focusOf(kind).hasFocus
        ? TrackerAccents.of(context).live
        : colors.border;

    final style = _lastStyle(context);
    Text line(String text) =>
        Text(text, textAlign: TextAlign.center, maxLines: 1, style: style);
    // A waiting row's placeholder is usually last time's value already.
    final folded = _lastValue(index, kind, ghost: logged ? null : ghost);
    final last = _lastValue(index, kind);
    final opened = last == null
        ? (kind == _Kind.weight ? weightUnitOf(context).symbol : 'reps')
        : 'last $last';
    final Widget caption;
    if (folded == null) {
      // Nothing under the folded number: the line's room opens with the row.
      caption = t == 0
          ? const SizedBox.shrink()
          : ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: t,
                child: Opacity(opacity: t, child: line(opened)),
              ),
            );
    } else if (t == 0) {
      caption = line(folded);
    } else if (t == 1) {
      caption = line(opened);
    } else {
      caption = Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Opacity(opacity: 1 - t, child: line(folded)),
          Opacity(opacity: t, child: line(opened)),
        ],
      );
    }

    final small = theme.typography.body.sm.fontSize ?? 14;
    final steppers = !bare && (open || t > 0);
    Widget stepper(int direction) => _fold(
      t,
      // Each one comes out from behind the number.
      direction < 0
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      _leaving(!open, _stepButton(context, row, kind, direction)),
    );
    final group = Container(
      constraints: const BoxConstraints(minHeight: 40),
      alignment: Alignment.center,
      padding: EdgeInsets.all(3 * t),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: colors.background.a * t),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: outline.withValues(alpha: outline.a * t)),
      ),
      child: Row(
        children: <Widget>[
          if (steppers) stepper(-1),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  // Its own line height folded, 32 open.
                  height: t == 0 ? null : _lerp(small * 1.15, 32, t),
                  child: _valueField(context, row, kind, ghost, t: t),
                ),
                caption,
              ],
            ),
          ),
          if (steppers) stepper(1),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: open && bare ? () => row.focusOf(kind).requestFocus() : null,
      child: group,
    );
  }

  Widget _stepButton(
    BuildContext context,
    _Row row,
    _Kind kind,
    int direction,
  ) {
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
          width: 34,
          height: 40,
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
    required double t,
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
    // [t] of the way from the folded row's number to the open row's.
    final textStyle =
        TextStyle.lerp(
          theme.typography.body.sm,
          theme.typography.body.xl.copyWith(fontSize: 22),
          t,
        )!.copyWith(
          fontWeight: FontWeight.lerp(FontWeight.w600, FontWeight.w700, t),
          height: 1.15,
          color: theme.colors.foreground,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final hintStyle = textStyle.copyWith(color: theme.colors.mutedForeground);

    final keypad = widget.entryMode.usesKeypad;
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
        bottom: keypad
            ? NumberKeypad.heightOf(widget.entryMode) + 40
            : keyboard + 120,
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
    final lastSetAt = widget.lastSetAt;
    final Widget button;
    if (current != null && current >= sets.length) {
      final rating = _rows[current].rpe;
      button = AccentButton(
        large: true,
        // The rest clock takes its share of the row: the label keeps the
        // room.
        prefix: lastSetAt == null ? FLucideIcons.check : null,
        label: _logLabel(current, ghosts, badges),
        // A new set crossfades the label; typing updates it in place.
        labelKey: ('log', _rows[current]),
        // The rating rides along on the side: weight and reps lead.
        trailing: rating == null ? null : effortLabel(widget.effort, rating),
        onPress: () => _logRow(_rows[current]),
      );
    } else if (current != null) {
      button = AccentButton(
        large: true,
        label: 'Done',
        labelKey: ('done', _rows[current]),
        onPress: _unfocus,
      );
    } else if (widget.next case final next?) {
      button = AccentButton(
        large: true,
        label: 'Next: ${next.exercise.name}',
        labelKey: ('next', next.exercise.exerciseId),
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
        labelKey: 'finish',
        // An open exercise picked in the sheet takes this page's place.
        onPress: () => finishWorkout(
          context,
          openExercise: (id) {
            if (id == widget.entry.exercise.exerciseId) return;
            replaceWith<void>(context, ExercisePage(exerciseId: id));
          },
        ),
      );
    } else {
      // A free workout grows one exercise at a time from its list.
      button = AccentButton(
        large: true,
        label: 'Back to workout',
        labelKey: 'back',
        onPress: () => Navigator.of(context).maybePop(),
      );
    }
    return WorkoutDock(
      leading: lastSetAt == null ? null : _RestClock(since: lastSetAt),
      child: button,
    );
  }
}

/// How long since the workout's last set, beside the next step: counts up,
/// nothing to set. [compact] is the time alone, for the bar on the phone
/// keyboard.
class _RestClock extends StatelessWidget {
  const _RestClock({required this.since, this.compact = false});

  final DateTime since;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    if (compact) {
      return Semantics(
        label: 'Resting',
        child: ElapsedClock(
          start: since,
          style: theme.typography.body.sm.copyWith(
            color: accents.live,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 52),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ElapsedClock(
            start: since,
            style: theme.typography.body.lg.copyWith(
              color: accents.live,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          Text(
            'Resting',
            style: theme.typography.body.xs.copyWith(
              fontSize: 11,
              height: 1.2,
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

bool _sameKg(double stored, double committed) =>
    (stored - committed).abs() < 1e-9;

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Where a set row's motion stands (see [_RowMotion]).
class _RowMotionValues {
  const _RowMotionValues({
    required this.open,
    required this.labels,
    required this.logged,
    required this.compare,
    required this.comparing,
    required this.comparison,
  });

  /// 0 folded, 1 open: the frame, the numbers and the room the row takes.
  final double open;

  /// How far the labels on the open row's outline have faded in.
  final double labels;

  /// 0 waiting, 1 logged: the tint and the tick.
  final double logged;

  /// How much of the comparison under the outline is there.
  final double compare;

  /// Whether the row has a comparison now, rather than one on its way out.
  final bool comparing;

  /// The comparison shown, kept while it leaves.
  final SetComparison? comparison;
}

/// Moves a set row between its looks over 220 ms. Folding mirrors opening
/// (the same curve, backwards), so when the set being done switches, what
/// one row gives up the other takes at every frame and the rows below stay
/// put. The open row's labels go in the first 30 % of its folding and come
/// in over the last 60 % of its opening, so it reads as one set closing,
/// then the next opening. Logging tints the row and grows its tick in over
/// 220 ms. With reduced motion every change is immediate.
class _RowMotion extends StatefulWidget {
  const _RowMotion({
    required this.open,
    required this.logged,
    required this.comparison,
    required this.builder,
    this.onOpening,
  });

  final bool open;
  final bool logged;
  final SetComparison? comparison;
  final Widget Function(BuildContext context, _RowMotionValues motion) builder;

  /// Called each frame the row opens, with the row's context and the share
  /// of what was left of the way that frame covered: 1 once it is open, on
  /// the frame after, against the final layout.
  final void Function(BuildContext context, double share)? onOpening;

  @override
  State<_RowMotion> createState() => _RowMotionState();
}

class _RowMotionState extends State<_RowMotion> with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.open ? 1 : 0,
  );
  // Each runs backwards on the way back: easing in, backwards, eases out,
  // and easeInCubic is easeOutCubic flipped, so a folding row loses height
  // exactly as fast as an opening one gains it.
  late final CurvedAnimation _openness = CurvedAnimation(
    parent: _open,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final CurvedAnimation _labels = CurvedAnimation(
    parent: _open,
    curve: const Interval(0.4, 1, curve: Curves.easeOut),
    reverseCurve: const Interval(0.7, 1),
  );
  late final AnimationController _logged = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.logged ? 1 : 0,
  );
  late final CurvedAnimation _loggedness = CurvedAnimation(
    parent: _logged,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final AnimationController _compare = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.comparison == null ? 0 : 1,
  );
  late final CurvedAnimation _compared = CurvedAnimation(
    parent: _compare,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Listenable _all = Listenable.merge([_open, _logged, _compare]);

  SetComparison? _comparison;

  /// How open the row was on the last frame [_RowMotion.onOpening] saw.
  double _followed = 0;

  @override
  void initState() {
    super.initState();
    _comparison = widget.comparison;
    _open
      ..addListener(_onOpenFrame)
      ..addStatusListener(_onOpenStatus);
  }

  void _onOpenFrame() {
    if (_open.status != AnimationStatus.forward) return;
    final now = _openness.value;
    final left = 1 - _followed;
    if (left > 0) {
      widget.onOpening?.call(
        context,
        ((now - _followed) / left).clamp(0.0, 1.0),
      );
    }
    _followed = now;
  }

  void _onOpenStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      _followed = _openness.value;
    } else if (status == AnimationStatus.completed &&
        widget.onOpening != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.open) widget.onOpening?.call(context, 1);
      });
    }
  }

  @override
  void didUpdateWidget(_RowMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final instant = MediaQuery.disableAnimationsOf(context);
    if (widget.open != oldWidget.open) _drive(_open, widget.open, instant);
    if (widget.logged != oldWidget.logged) {
      _drive(_logged, widget.logged, instant);
    }
    final comparison = widget.comparison;
    if (comparison != null) _comparison = comparison;
    if ((comparison == null) != (oldWidget.comparison == null)) {
      _drive(_compare, comparison != null, instant);
    }
  }

  void _drive(AnimationController controller, bool on, bool instant) {
    if (instant) {
      controller.value = on ? 1 : 0;
    } else if (on) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  @override
  void dispose() {
    _openness.dispose();
    _labels.dispose();
    _loggedness.dispose();
    _compared.dispose();
    _open.dispose();
    _logged.dispose();
    _compare.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _all,
    builder: (context, _) => widget.builder(
      context,
      _RowMotionValues(
        open: _openness.value,
        labels: _labels.value,
        logged: _loggedness.value,
        compare: _compared.value,
        comparing: widget.comparison != null,
        comparison: _comparison,
      ),
    ),
  );
}
