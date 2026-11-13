import 'dart:async';

import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/number_keypad.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

/// What the set target sheet hands back: a new target (for this set, or
/// every set of its type), or a request to delete the set.
class SetTargetResult {
  const SetTargetResult(this.target, {this.applyToAll = false})
    : delete = false;

  const SetTargetResult.delete()
    : target = null,
      applyToAll = false,
      delete = true;

  final SetTarget? target;
  final bool applyToAll;
  final bool delete;
}

/// Edits the planned set at [index] of an exercise's [sets]: fixed reps or
/// a range, nudged with steppers or typed with the chosen number entry, and
/// whether it is a warm-up ([allowWarmup] false hides that choice).
/// [saveOnClose] keeps the edit when the sheet is swiped away or tapped
/// outside, as long as it is a valid target; otherwise only Done keeps it.
Future<SetTargetResult?> showSetTargetSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<SetTarget> sets,
  required int index,
  bool allowWarmup = true,
  bool saveOnClose = false,
}) async {
  final settings = SettingsCubit.maybeOf(context)?.state ?? SettingsState();
  SetTargetResult? edited;
  final result = await showFSheet<SetTargetResult>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.9,
    builder: builtOnce(
      (_) => _SetTargetSheet(
        title: title,
        subtitle: subtitle,
        sets: sets,
        index: index,
        allowWarmup: allowWarmup,
        entry: settings.numberEntry,
        defaultRangeMax: settings.defaultRepRangeMax,
        onEdit: saveOnClose ? (target) => edited = target : null,
      ),
    ),
  );
  return result ?? edited;
}

enum _Bound { min, max }

class _SetTargetSheet extends StatefulWidget {
  const _SetTargetSheet({
    required this.title,
    required this.subtitle,
    required this.sets,
    required this.index,
    required this.allowWarmup,
    required this.entry,
    required this.defaultRangeMax,
    this.onEdit,
  });

  final String title;
  final String subtitle;
  final List<SetTarget> sets;
  final int index;
  final bool allowWarmup;
  final NumberEntry entry;
  final int defaultRangeMax;

  /// Told the target after every change; null while it is not valid.
  final ValueChanged<SetTargetResult?>? onEdit;

  SetTarget get target => sets[index];

  @override
  State<_SetTargetSheet> createState() => _SetTargetSheetState();
}

class _SetTargetSheetState extends State<_SetTargetSheet> {
  late bool _range = widget.target.isRange;
  late final _min = TextEditingController(text: '${widget.target.minReps}');
  late final _max = TextEditingController(
    text: '${widget.target.maxReps ?? _rangeMaxFor(widget.target.minReps)}',
  );
  final _minFocus = FocusNode();
  final _maxFocus = FocusNode();
  late bool _warmup = widget.target.warmup;
  bool _applyToAll = false;
  String? _error;
  Timer? _repeat;

  /// The last valid range max, restored when switching back to a range.
  int? _rememberedMax;

  @override
  void initState() {
    super.initState();
    _minFocus.addListener(_onFocus);
    _maxFocus.addListener(_onFocus);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.onEdit?.call(_current);
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _min.dispose();
    _max.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    super.dispose();
  }

  void _onFocus() {
    for (final bound in _Bound.values) {
      if (_focusOf(bound).hasFocus) {
        final controller = _controllerOf(bound);
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
    }
    setState(() {});
  }

  TextEditingController _controllerOf(_Bound bound) =>
      bound == _Bound.min ? _min : _max;

  FocusNode _focusOf(_Bound bound) =>
      bound == _Bound.min ? _minFocus : _maxFocus;

  int? _valueOf(_Bound bound) => int.tryParse(_controllerOf(bound).text.trim());

  bool _warmupAt(int i) => i == widget.index ? _warmup : widget.sets[i].warmup;

  /// The sets "Use for all" reaches: this one's type, once it is saved.
  int get _sameType => [
    for (var i = 0; i < widget.sets.length; i++)
      if (_warmupAt(i) == _warmup) i,
  ].length;

  String get _applyToAllLabel {
    final count = _sameType;
    final mixed = _sameType < widget.sets.length;
    if (!mixed) return 'Use for all $count sets';
    return _warmup
        ? 'Use for all $count warm-ups'
        : 'Use for all $count working sets';
  }

  int _rangeMaxFor(int min) {
    final remembered = _rememberedMax;
    if (remembered != null && remembered > min) return remembered;
    final fallback = widget.defaultRangeMax;
    return fallback > min ? fallback : min + 2;
  }

  void _setRange(bool range) {
    if (range == _range) return;
    final min = _valueOf(_Bound.min) ?? widget.target.minReps;
    setState(() {
      if (_range) {
        final max = _valueOf(_Bound.max);
        if (max != null && max > min) _rememberedMax = max;
      } else {
        _max.text = '${_rangeMaxFor(min)}';
      }
      _range = range;
      _error = null;
    });
  }

  void _step(_Bound bound, int direction) {
    final min = _valueOf(_Bound.min) ?? 1;
    final max = _valueOf(_Bound.max) ?? min + 1;
    setState(() {
      _error = null;
      if (bound == _Bound.min) {
        final next = (min + direction).clamp(1, 999);
        _min.text = '$next';
        // Keep a range a range: the max moves up with the min.
        if (_range && max <= next) _max.text = '${next + 1}';
      } else {
        _max.text = '${(max + direction).clamp(min + 1, 999)}';
      }
    });
    final controller = _controllerOf(bound);
    if (widget.entry.usesKeypad && _focusOf(bound).hasFocus) {
      // The next key typed starts the value over, as after focusing.
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    }
  }

  /// The keypad's steppers for [bound], in the number entries that have
  /// them.
  KeypadSteps? _keypadSteps(_Bound bound) {
    if (!widget.entry.usesKeypad) return null;
    final min = _valueOf(_Bound.min) ?? 1;
    final value = bound == _Bound.min ? min : _valueOf(_Bound.max) ?? min + 1;
    return KeypadSteps.reps(
      ruler: widget.entry == NumberEntry.keypadRuler,
      value: value.toDouble(),
      what: bound == _Bound.min ? (_range ? 'min reps' : 'reps') : 'max reps',
      onStep: (direction) => _step(bound, direction),
    );
  }

  void _onKey(_Bound bound, KeypadKey key, String digit) {
    switch (key) {
      case KeypadKey.next:
        if (bound == _Bound.min && _range) {
          _maxFocus.requestFocus();
        } else {
          FocusScope.of(context).unfocus();
        }
      case KeypadKey.hide:
        FocusScope.of(context).unfocus();
      case KeypadKey.digit:
        if (digit == '.') return;
        applyKeypadKey(_controllerOf(bound), key, digit: digit);
        setState(() => _error = null);
      case KeypadKey.backspace:
        applyKeypadKey(_controllerOf(bound), key);
        setState(() => _error = null);
      case KeypadKey.sign:
        return;
    }
  }

  /// The target as it stands, or null while the reps do not make one.
  SetTargetResult? get _current {
    final min = _valueOf(_Bound.min);
    final max = _range ? _valueOf(_Bound.max) : null;
    if (min == null || min < 1) return null;
    if (_range && (max == null || max <= min)) return null;
    return SetTargetResult(
      SetTarget(min, max).withWarmup(_warmup),
      applyToAll: _applyToAll && _sameType > 1,
    );
  }

  void _done() {
    final min = _valueOf(_Bound.min);
    final max = _range ? _valueOf(_Bound.max) : null;
    if (min == null || min < 1) {
      setState(() => _error = 'Reps must be at least 1.');
      return;
    }
    if (_range && (max == null || max <= min)) {
      setState(() => _error = 'The max must be above the min.');
      return;
    }
    Navigator.of(context).pop(
      SetTargetResult(
        SetTarget(min, max).withWarmup(_warmup),
        applyToAll: _applyToAll && _sameType > 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final focused = _minFocus.hasFocus
        ? _Bound.min
        : _maxFocus.hasFocus
        ? _Bound.max
        : null;
    final keypadOpen = widget.entry.usesKeypad && focused != null;
    final sheet = SheetSurface(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.title,
            style: theme.typography.body.lg.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.subtitle,
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          _Segmented(range: _range, onChanged: _setRange),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(child: _group(context, _Bound.min)),
              if (_range) ...[
                SizedBox(
                  width: 28,
                  child: Text(
                    'to',
                    textAlign: TextAlign.center,
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
                Expanded(child: _group(context, _Bound.max)),
              ],
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.error,
                ),
              ),
            ),
          if (widget.allowWarmup)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FTappable(
                onPress: () => setState(() => _warmup = !_warmup),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Warm-up set',
                              style: theme.typography.body.sm,
                            ),
                            Text(
                              'Not counted with the working sets',
                              style: theme.typography.body.xs.copyWith(
                                color: theme.colors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FSwitch(
                        value: _warmup,
                        onChange: (value) => setState(() => _warmup = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_sameType > 1)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FTappable(
                onPress: () => setState(() => _applyToAll = !_applyToAll),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _applyToAllLabel,
                          style: theme.typography.body.sm,
                        ),
                      ),
                      FSwitch(
                        value: _applyToAll,
                        onChange: (value) =>
                            setState(() => _applyToAll = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (keypadOpen)
            NumberKeypad(
              caption: focused == _Bound.min
                  ? (_range ? 'Fewest reps' : 'Reps')
                  : 'Most reps',
              allowSign: false,
              logLabel: 'Done',
              onLog: _done,
              onKey: (key, digit) => _onKey(focused, key, digit),
              steps: _keypadSteps(focused),
            )
          else ...[
            FButton(onPress: _done, child: const Text('Done')),
            if (widget.sets.length > 1) ...[
              const SizedBox(height: 6),
              FButton(
                variant: .ghost,
                onPress: () =>
                    Navigator.of(context).pop(const SetTargetResult.delete()),
                prefix: Icon(
                  FLucideIcons.trash2,
                  color: theme.colors.destructive,
                ),
                child: Text(
                  'Delete set',
                  style: TextStyle(color: theme.colors.destructive),
                ),
              ),
            ],
          ],
        ],
      ),
    );
    // The values are Material text fields; the sheet paints its own surface.
    return Material(type: MaterialType.transparency, child: sheet);
  }

  Widget _group(BuildContext context, _Bound bound) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final controller = _controllerOf(bound);
    final style = theme.typography.body.xl.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.15,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final label = bound == _Bound.min ? (_range ? 'min' : 'reps') : 'max';
    final value = TextField(
      controller: controller,
      focusNode: _focusOf(bound),
      keyboardType: widget.entry.usesKeypad
          ? TextInputType.none
          : TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      textAlign: TextAlign.center,
      style: style,
      cursorColor: accents.live,
      showCursor: true,
      enableInteractiveSelection: false,
      onChanged: (_) => setState(() => _error = null),
      decoration: const InputDecoration.collapsed(hintText: ''),
    );
    Widget stepper(int direction) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _step(bound, direction),
      onLongPressStart: (_) {
        _repeat?.cancel();
        _repeat = Timer.periodic(
          const Duration(milliseconds: 120),
          (_) => _step(bound, direction),
        );
      },
      onLongPressEnd: (_) => _repeat?.cancel(),
      child: Semantics(
        button: true,
        label: '${direction > 0 ? 'More' : 'Fewer'} $label',
        child: Container(
          width: 44,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colors.muted,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            direction > 0 ? FLucideIcons.plus : FLucideIcons.minus,
            size: 18,
          ),
        ),
      ),
    );
    // With the steppers in the keypad the box is the number alone.
    final bare = widget.entry.usesKeypad;
    final group = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focusOf(bound).hasFocus ? accents.live : theme.colors.border,
        ),
      ),
      child: Row(
        children: <Widget>[
          if (!bare) stepper(-1),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: 34, child: value),
                Text(
                  label,
                  style: theme.typography.body.xs3.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (!bare) stepper(1),
        ],
      ),
    );
    if (!bare) return group;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focusOf(bound).requestFocus(),
      child: group,
    );
  }
}

/// Fixed reps or a rep range.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.range, required this.onChanged});

  final bool range;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    Widget segment(String label, bool value) {
      final selected = value == range;
      return Expanded(
        child: FTappable(
          semanticsLabel: label,
          selected: selected,
          onPress: () => onChanged(value),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? theme.colors.background : null,
              borderRadius: BorderRadius.circular(6),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: theme.typography.body.xs.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? theme.colors.foreground
                    : theme.colors.mutedForeground,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          segment('Fixed reps', false),
          segment('Rep range', true),
        ],
      ),
    );
  }
}
