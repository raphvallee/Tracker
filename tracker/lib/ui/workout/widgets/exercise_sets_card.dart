import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/decimal_input_formatter.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/set_type_chip.dart';
import 'package:tracker/ui/core/ui/weight_confirmation.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/utils/decimal_input.dart';
import 'package:tracker/utils/form_validators.dart';

/// One exercise in the Current Workout page: its title row, then its set rows.
///
/// Free and planned exercises share this layout. [planned] only switches what
/// the rows do: planned rows show their target reps and cannot be swiped away,
/// free rows toggle warm-up and delete by swipe. [onRemove] adds the remove
/// button to the title row.
class ExerciseSetsCard extends StatelessWidget {
  const ExerciseSetsCard({
    super.key,
    required this.orderNumber,
    required this.exerciseId,
    required this.exerciseName,
    required this.planned,
    required this.sets,
    this.plannedSets = const [],
    this.onRemove,
  });

  final int orderNumber;

  final int exerciseId;
  final String exerciseName;

  final bool planned;

  final List<ActiveSet> sets;

  final List<PlannedSet> plannedSets;

  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.theme.typography.body.md.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('${orderNumber + 1}. ', style: titleStyle),
                  Expanded(child: Text(exerciseName, style: titleStyle)),
                  // The slot is reserved on every card, so the name wraps at
                  // the same width whether or not this card can be removed.
                  Visibility(
                    visible: onRemove != null,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: AppIconButton(
                      icon: FLucideIcons.x,
                      tooltip: 'Remove exercise',
                      onPress: onRemove,
                      size: .sm,
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SetEditor(
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                planned: planned,
                sets: sets,
                plannedSets: plannedSets,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetEditor extends StatefulWidget {
  const _SetEditor({
    required this.exerciseId,
    required this.exerciseName,
    required this.planned,
    this.sets = const [],
    this.plannedSets = const [],
  });

  final int exerciseId;
  final String exerciseName;

  /// Planned cards follow their split day: one row per planned set with the
  /// target reps as hints. Free cards keep a blank row ready, toggle warm-up
  /// per row and delete rows by swiping.
  final bool planned;

  final List<ActiveSet> sets;

  final List<PlannedSet> plannedSets;

  @override
  State<_SetEditor> createState() => _SetEditorState();
}

class _Row {
  final weight = TextEditingController();
  final reps = TextEditingController();
  String? weightError;
  String? repsError;
  double? lastWeightKg;
  double? lastReps;

  /// The set type a blank free row logs with; a logged row shows its set's.
  bool warmup = false;

  void clear() {
    weight.clear();
    reps.clear();
    weightError = null;
    repsError = null;
    lastWeightKg = null;
    lastReps = null;
    warmup = false;
  }

  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

class _SetEditorState extends State<_SetEditor> {
  final List<_Row> _rows = [];

  int _extraEmptyRows = 0;

  int get _emptyRowCount => _extraEmptyRows + 1;

  int get _plannedBaseCount =>
      widget.plannedSets.isEmpty ? 1 : widget.plannedSets.length;

  int get _rowCount => widget.planned
      ? math.max(_plannedBaseCount, widget.sets.length) + _extraEmptyRows
      : widget.sets.length + _emptyRowCount;

  /// The exercise's sets as the cubit holds them right now. Handlers read
  /// these rather than [_SetEditor.sets]: the blur a tap causes can log a
  /// set before this card is rebuilt with it.
  List<ActiveSet> get _liveSets =>
      context.read<WorkoutCubit>().state.setsByExercise[widget.exerciseId] ??
      const [];

  @override
  void initState() {
    super.initState();
    _reconcile();
  }

  @override
  void didUpdateWidget(covariant _SetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcile();
  }

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
    final plannedRows = widget.planned && widget.plannedSets.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
          // Keyed by the row itself: a commit can move its row up to the
          // slot the new set lands in, and the fields (focus included) must
          // move along with it.
          KeyedSubtree(
            key: ObjectKey(_rows[i]),
            child: _rowFrame(context, i, plannedRows),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
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

  Widget _rowFrame(BuildContext context, int index, bool plannedRows) {
    final row = _rows[index];
    return Focus(
      // The row commits when focus leaves any of its fields; the
      // wrapper must not capture focus or participate in traversal.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!focused) _commitRow(row);
      },
      child: widget.planned
          ? _buildRow(context, index, plannedRows)
          : _SwipeToDelete(
              canDelete: _canSwipeDelete(index),
              onConfirm: () => _confirmSwipeDelete(row),
              onConfirmed: () => _onSwipeDismissed(row),
              child: _buildRow(context, index, plannedRows),
            ),
    );
  }

  Widget _buildRow(BuildContext context, int index, bool plannedRows) {
    final row = _rows[index];
    final repHint = plannedRows && index < widget.plannedSets.length
        ? widget.plannedSets[index].repsLabel
        : 'Reps';
    final times = Text(
      '×',
      style: context.theme.typography.body.sm.copyWith(
        color: context.theme.colors.mutedForeground,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: widget.planned
                  ? index < widget.sets.length
                        ? Center(
                            child: SetTypeChip(
                              isWarmup: widget.sets[index].isWarmup,
                            ),
                          )
                        : Text(
                            'Set',
                            style: context.theme.typography.body.xs.copyWith(
                              color: context.theme.colors.mutedForeground,
                            ),
                          )
                  : _setTypeToggle(index),
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
                // The empty error turns the border red without taking any space:
                // the message is drawn under its field by _rowErrors.
                error: row.weightError == null ? null : const SizedBox(),
                style: const .delta(errorPadding: .value(EdgeInsets.zero)),
                // Free rows sit inside the swipe-to-delete wrapper: turning the
                // selection affordances off keeps a horizontal swipe from also
                // dragging a selection across the field. The values are short
                // numbers nobody selects by hand inside the row.
                enableInteractiveSelection: false,
              ),
            ),
            const SizedBox(width: 6),
            times,
            const SizedBox(width: 6),
            Expanded(
              child: FTextField(
                control: FTextFieldControl.managed(controller: row.reps),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [DecimalInputFormatter()],
                hint: repHint,
                error: row.repsError == null ? null : const SizedBox(),
                style: const .delta(errorPadding: .value(EdgeInsets.zero)),
                enableInteractiveSelection: false,
                textInputAction: TextInputAction.done,
                onSubmit: (_) => FocusScope.of(context).unfocus(),
              ),
            ),
          ],
        ),
        _rowErrors(context, row, times),
      ],
    );
  }

  /// Each error sits under its own field, in a row that mirrors the field
  /// row's columns. It lives outside the field row: a field that grows to
  /// show its own error would pull the pair out of line.
  Widget _rowErrors(BuildContext context, _Row row, Widget times) {
    if (row.weightError == null && row.repsError == null) {
      return const SizedBox.shrink();
    }
    final style = context.theme.textFieldStyles.md.errorTextStyle.base;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(width: 28 + 8),
          Expanded(
            child: row.weightError == null
                ? const SizedBox.shrink()
                : Text(row.weightError!, style: style),
          ),
          const SizedBox(width: 6),
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: times,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: row.repsError == null
                ? const SizedBox.shrink()
                : Text(row.repsError!, style: style),
          ),
        ],
      ),
    );
  }

  /// The free row's W/S chip doubles as its warm-up toggle. A blank row's
  /// chip is dimmed: it previews the type the row will log with.
  Widget _setTypeToggle(int index) {
    final row = _rows[index];
    final logged = index < widget.sets.length ? widget.sets[index] : null;
    final chip = SetTypeChip(isWarmup: logged?.isWarmup ?? row.warmup);
    return FTooltip(
      tipBuilder: (_, _) => const Text('Toggle warm-up'),
      child: Semantics(
        button: true,
        label: 'Toggle warm-up',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleWarmup(row),
            child: Center(
              child: logged == null ? Opacity(opacity: 0.5, child: chip) : chip,
            ),
          ),
        ),
      ),
    );
  }

  void _toggleWarmup(_Row row) {
    final index = _rows.indexOf(row);
    if (index < 0) return;
    // A mouse click blurs the typed row first, and that blur may already
    // have logged it: then the toggle flips the logged set's type.
    final sets = _liveSets;
    if (index < sets.length) {
      final set = sets[index];
      context.read<WorkoutCubit>().updateSet(
        set.order,
        type: set.isWarmup ? SetType.working : SetType.warmup,
      );
      return;
    }
    setState(() => row.warmup = !row.warmup);
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

  bool _canSwipeDelete(int index) {
    if (index < widget.sets.length) return true;
    final row = _rows[index];
    final hasContent =
        row.weight.text.trim().isNotEmpty || row.reps.text.trim().isNotEmpty;
    if (hasContent) return true;
    return _extraEmptyRows > 0;
  }

  Future<bool> _confirmSwipeDelete(_Row row) async {
    final index = _rows.indexOf(row);
    // Double guard: the gesture never reaches here for an undeletable row,
    // but a stale gesture must not remove one either.
    if (index < 0 || !_canSwipeDelete(index)) return false;
    final sets = _liveSets;
    final mapped = index < sets.length ? sets[index] : null;
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

  void _onSwipeDismissed(_Row row) {
    final index = _rows.indexOf(row);
    if (index < 0) return;
    final sets = _liveSets;
    final mapped = index < sets.length ? sets[index] : null;
    if (mapped != null) {
      _removeLoggedSet(index, sets, mapped);
      return;
    }
    setState(() {
      _rows.removeAt(index);
      // The row's fields unmount with the next frame; release them after.
      WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
      if (_extraEmptyRows > 0) _extraEmptyRows--;
      // Typed values can live in the always-available row; dropping it must
      // not leave the form with no logging row at all.
      _reconcile();
    });
  }

  /// Rows map to sets by position, so removing a logged set shifts every
  /// later set up one row. Clear the rows from [index] on, so the next
  /// reconcile refills them from the shifted sets instead of leaving the
  /// last one behind as a stale copy of the set it held.
  void _removeLoggedSet(int index, List<ActiveSet> sets, ActiveSet mapped) {
    for (var j = index; j < sets.length; j++) {
      _rows[j].clear();
    }
    context.read<WorkoutCubit>().removeSet(mapped.order);
    setState(() {});
  }

  Future<void> _commitRow(_Row row) async {
    var index = _rows.indexOf(row);
    if (index < 0) return;
    var sets = _liveSets;
    final mapped = index < sets.length ? sets[index] : null;

    final weightText = row.weight.text.trim();
    final repsText = row.reps.text.trim();
    if (weightText.isEmpty && repsText.isEmpty) {
      row.weightError = null;
      row.repsError = null;
      if (mapped != null) {
        _removeLoggedSet(index, sets, mapped);
      } else {
        setState(() {});
      }
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

    final confirmed = await confirmWeightEntry(context, weightDisplay);
    if (!mounted || !confirmed) return;

    // The modal blocks other edits, but the session may still have been ended
    // or restored underneath: re-read the mapping before writing.
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
      // The new set is appended after the logged ones. Move a row typed
      // further down up to that slot, or the set would show in the first
      // blank row and leave this one behind as a stale copy.
      if (index > sets.length) {
        _rows.insert(sets.length, _rows.removeAt(index));
      }
      cubit.logSet(
        exerciseId: widget.exerciseId,
        exerciseName: widget.exerciseName,
        weight: kilograms,
        reps: reps,
        type: !widget.planned && row.warmup ? SetType.warmup : SetType.working,
      );
      row.warmup = false;
      if (!widget.planned) {
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

  final bool canDelete;

  final Future<bool> Function() onConfirm;

  final VoidCallback onConfirmed;

  final Widget child;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete>
    with TickerProviderStateMixin {
  static const double _slop = 18;

  static const double _rubberBandZone = 0.75;

  static const double _dismissFraction = 0.635;

  static const double _rubberBandTail = 0.4;

  static const double _gateStiffening = 0.5;

  static const double _rubberBandNeck = 24;
  static const double _rubberBandMax = 56;
  static const double _rubberBandRange = 120;

  double _offset = 0;
  double _rowWidth = 0;

  double _fingerDistance = 0;

  bool _armed = false;
  bool _horizontal = false;
  bool _vertical = false;
  bool _busy = false;

  bool _dismissing = false;

  bool _removed = false;
  Offset? _start;

  late final AnimationController _slider = AnimationController(
    vsync: this,
    duration: _springBackDuration,
  );

  double _animateFrom = 0;

  double _animateTarget = 0;

  Curve _animateCurve = Curves.easeOutCubic;

  VoidCallback? _animateDone;

  static const Duration _springBackDuration = Duration(milliseconds: 220);
  static const Duration _slideOutDuration = Duration(milliseconds: 160);

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
      travelled = atBandEnd + u - _gateStiffening * u * u / (2 * zone);
    } else {
      final atGate = atBandEnd + zone * (1 - _gateStiffening / 2);
      travelled = atGate + (1 - _gateStiffening) * (distance - gate);
    }
    return dx.isNegative ? -travelled : travelled;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_busy) return;
    if (_start != null) return;
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
    if (armed && !wasArmed) HapticFeedback.mediumImpact();
    _logSwipeProgress();
  }

  double get _dismissTarget => _rowWidth * _dismissFraction;

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

    final dismisses =
        widget.canDelete && swiped >= _rowWidth * _dismissFraction;
    if (!dismisses) {
      _animateTo(0);
      return;
    }

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
      _removed = done != null;
    });
    done?.call();
  }

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
        final threshold = (_rowWidth * _dismissFraction).clamp(0.0, _rowWidth);
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
                      // Matches the FCard surface the rows sit on.
                      child: ColoredBox(
                        color: context.theme.colors.card,
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

class _ArmedIndicator extends StatelessWidget {
  const _ArmedIndicator({required this.visible, required this.shake});

  static const Duration _labelDuration = Duration(milliseconds: 150);

  final bool visible;

  final AnimationController shake;

  @override
  Widget build(BuildContext context) {
    final foreground = context.theme.colors.destructiveForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
