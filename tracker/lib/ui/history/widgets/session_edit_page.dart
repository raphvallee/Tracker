import 'dart:async';
import 'dart:math' as math;

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/exercise.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/number_entry.dart';
import 'package:tracker/domain/models/rep_limits.dart';
import 'package:tracker/domain/models/session_draft.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/session_changes.dart';
import 'package:tracker/domain/services/session_summary.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/animated_reveal.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/decimal_input_formatter.dart';
import 'package:tracker/ui/core/ui/draft_tag.dart';
import 'package:tracker/ui/core/ui/edit_sheet.dart';
import 'package:tracker/ui/core/ui/effort_format.dart';
import 'package:tracker/ui/core/ui/effort_sheet.dart';
import 'package:tracker/ui/core/ui/effort_strip.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/number_keypad.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/set_badge.dart';
import 'package:tracker/ui/core/ui/slide_up_panel.dart';
import 'package:tracker/ui/core/ui/swipe_to_delete.dart';
import 'package:tracker/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:tracker/ui/core/ui/weight_confirmation.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/workout/widgets/exercise_picker_page.dart';
import 'package:tracker/ui/workout/widgets/gym_picker.dart';
import 'package:tracker/utils/decimal_input.dart';
import 'package:tracker/utils/form_validators.dart';

/// What the edit page hands back when it closes on purpose.
sealed class SessionEditResult {
  const SessionEditResult();
}

/// The edits were saved: [session] is the workout as written.
final class SessionSaved extends SessionEditResult {
  const SessionSaved(this.session);

  final WorkoutSession session;
}

/// The workout was deleted.
final class SessionDeleted extends SessionEditResult {
  const SessionDeleted();
}

/// A past workout opened as a draft: its name, gym and times in a card, and
/// every set under its exercise, edited in place. Nothing is written until
/// Save; an amber bar counts what would change. Delete lives in the menu,
/// behind a confirmation: History keeps everything unless asked twice.
class SessionEditPage extends StatefulWidget {
  const SessionEditPage({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<SessionEditPage> createState() => _SessionEditPageState();
}

enum _Field { weight, reps }

class _SessionEditPageState extends State<SessionEditPage> {
  late SessionDraft _draft = SessionDraft.of(widget.session);

  /// A stable id per draft set, in the same order: rows keep their state
  /// while sets are added and removed around them.
  late List<int> _rowIds;
  int _nextRowId = 0;

  /// The set row opened up for editing.
  int? _openId;

  List<Gym> _gyms = const [];
  Map<int, String> _names = {};
  bool _didLoad = false;

  /// Saving or deleting: the page waits on the repository.
  bool _busy = false;

  // The open row's values, as typed.
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  final _weightFocus = FocusNode(debugLabel: 'edit set weight');
  final _repsFocus = FocusNode(debugLabel: 'edit set reps');
  bool _hadWeightFocus = false;
  bool _hadRepsFocus = false;
  String? _weightError;
  String? _repsError;

  Timer? _repeat;

  /// A step is asking to confirm its value.
  bool _asking = false;

  OverlayEntry? _overlay;

  /// The keypad is sliding away; its entry goes once it is out of sight.
  bool _overlayClosing = false;
  final _panelKey = GlobalKey<SlideUpPanelState>();
  Widget? _lastPanel;
  final _openRowKey = GlobalKey(debugLabel: 'open set row');
  bool _pendingReveal = false;

  @override
  void initState() {
    super.initState();
    _rowIds = _freshRowIds();
    _weightFocus.addListener(_onFocusChange);
    _repsFocus.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    // A handful of names and gyms, read at once: the first frame shows them.
    final repo = RepositoryScope.maybeOf(context);
    _names = {
      ...?repo?.exercises.getTitlesSync(
        widget.session.sets.map((set) => set.exerciseId),
      ),
    };
    try {
      _gyms = repo?.gyms.getAllSync() ?? const [];
    } on Object catch (error, stackTrace) {
      AppLog.error('history-edit', error, stackTrace);
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _removeOverlay();
    _weight.dispose();
    _reps.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  List<int> _freshRowIds() => [for (final _ in _draft.sets) _nextRowId++];

  NumberEntry get _entry =>
      SettingsCubit.maybeOf(context)?.state.numberEntry ??
      NumberEntry.keypadSteppers;

  int get _changes => sessionChangeCount(widget.session, _draft);

  String _nameOf(int exerciseId) =>
      _names[exerciseId] ?? 'Exercise $exerciseId';

  String get _gymLabel {
    final id = _draft.gymId;
    if (id == null) return 'Other gym';
    for (final gym in _gyms) {
      if (gym.id == id) return gym.name;
    }
    return 'Unknown gym';
  }

  int? get _openIndex {
    final id = _openId;
    if (id == null) return null;
    final index = _rowIds.indexOf(id);
    return index < 0 ? null : index;
  }

  String _displayWeight(double kilograms) =>
      formatDecimal(displayWeightOf(context, kilograms));

  void _change(SessionDraft Function(SessionDraft draft) change) =>
      setState(() => _draft = change(_draft));

  // Workout fields ------------------------------------------------------

  Future<void> _editName() async {
    final name = await showEditSheet<String>(
      context,
      builder: (_) => _NameSheet(initial: _draft.title),
    );
    if (!mounted || name == null) return;
    _change((draft) => draft.copyWith(title: name));
  }

  Future<void> _pickGym() async {
    final picked = await showGymPicker(
      context,
      _gyms,
      title: 'Which gym?',
      currentId: _draft.gymId,
      includeNoGym: true,
      noGymLabel: 'Other gym',
      live: false,
    );
    if (!mounted || picked == null) return;
    if (picked is Gym && !_gyms.any((gym) => gym.id == picked.id)) {
      // Added from the sheet.
      _gyms = [..._gyms, picked];
    }
    _change((draft) => draft.copyWith(gymId: picked is Gym ? picked.id : null));
  }

  Future<void> _pickStart() async {
    final picked = await showEditSheet<DateTime>(
      context,
      builder: (_) => _TimeSheet(
        title: 'Started',
        initial: _draft.startTime,
        check: (time) {
          final end = _draft.endTime;
          return end != null && time.isAfter(end)
              ? 'It cannot start after it ended, at ${timeLabel(end)}.'
              : null;
        },
      ),
    );
    if (!mounted || picked == null) return;
    _change((draft) => draft.copyWith(startTime: picked));
  }

  Future<void> _pickEnd() async {
    final picked = await showEditSheet<DateTime>(
      context,
      builder: (_) => _TimeSheet(
        title: 'Ended',
        initial: _draft.endTime ?? _draft.startTime,
        check: (time) => time.isBefore(_draft.startTime)
            ? 'It cannot end before it started, at '
                  '${timeLabel(_draft.startTime)}.'
            : null,
      ),
    );
    if (!mounted || picked == null) return;
    _change((draft) => draft.copyWith(endTime: picked));
  }

  String get _endLabel {
    final end = _draft.endTime;
    if (end == null) return 'Not set';
    final start = _draft.startTime;
    final sameDay =
        end.year == start.year &&
        end.month == start.month &&
        end.day == start.day;
    return sameDay ? timeLabel(end) : dateTimeLabel(end);
  }

  // Sets ----------------------------------------------------------------

  /// Opens the row of [rowId]: its values move into the fields. Values typed
  /// into the row being left are saved to it first.
  void _openRow(int rowId) {
    final previous = _openId;
    if (previous == rowId) return;
    if (previous != null) {
      unawaited(
        _commitField(_Field.weight, rowId: previous, text: _weight.text),
      );
      unawaited(_commitField(_Field.reps, rowId: previous, text: _reps.text));
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final index = _rowIds.indexOf(rowId);
    if (index < 0) return;
    final set = _draft.sets[index];
    setState(() {
      _openId = rowId;
      _weight.text = _displayWeight(set.weight);
      _reps.text = formatReps(set.reps);
      _weightError = null;
      _repsError = null;
    });
  }

  void _closeRow() {
    final open = _openId;
    if (open == null) return;
    unawaited(_commitField(_Field.weight, rowId: open, text: _weight.text));
    unawaited(_commitField(_Field.reps, rowId: open, text: _reps.text));
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _openId = null);
  }

  void _toggleWarmup(int rowId) {
    final index = _rowIds.indexOf(rowId);
    if (index < 0) return;
    _change(
      (draft) =>
          draft.updateSet(index, (set) => set.copyWith(warmup: !set.warmup)),
    );
  }

  void _rate(int rowId, double? rpe) {
    final index = _rowIds.indexOf(rowId);
    if (index < 0) return;
    _change((draft) => draft.updateSet(index, (set) => set.copyWith(rpe: rpe)));
  }

  Future<void> _pickEffort(int rowId, String label) async {
    final index = _rowIds.indexOf(rowId);
    if (index < 0) return;
    final choice = await showEffortSheet(
      context,
      title: label == 'W' ? 'Warm-up effort' : 'Set $label effort',
      scale: effortScaleOf(context),
      rpe: _draft.sets[index].rpe,
      live: false,
    );
    if (choice == null || !mounted) return;
    _rate(rowId, choice.rpe);
  }

  void _removeSet(int rowId) {
    final index = _rowIds.indexOf(rowId);
    if (index < 0) return;
    if (_openId == rowId) {
      FocusManager.instance.primaryFocus?.unfocus();
      _openId = null;
    }
    setState(() {
      _draft = _draft.removeSet(index);
      _rowIds.removeAt(index);
    });
  }

  void _addSet(int exerciseId, {double weight = 0, double reps = 1}) {
    final at = _draft.addedSetIndex(exerciseId);
    final rowId = _nextRowId++;
    setState(() {
      _draft = _draft.addSet(exerciseId, weight: weight, reps: reps);
      _rowIds.insert(at, rowId);
    });
    _openRow(rowId);
  }

  Future<void> _addExercise() async {
    _closeRow();
    final repo = RepositoryScope.maybeOf(context);
    final settings = SettingsCubit.maybeOf(context)?.state;
    final exercise = await pushTo<Exercise>(
      context,
      const ExercisePickerPage(),
    );
    if (exercise == null || !mounted) return;
    _names[exercise.id] = exercise.title;
    if (_draft.sets.any((set) => set.exerciseId == exercise.id)) {
      _addSet(exercise.id);
      return;
    }
    // Start from last time's top set, so the new set needs a nudge at most.
    final previous = await repo?.sessions.getPreviousPerformance(exercise.id);
    if (!mounted) return;
    final top = previous?.topSet;
    _addSet(
      exercise.id,
      weight: top?.weight ?? 0,
      reps: top?.reps ?? (settings?.defaultReps ?? 8).toDouble(),
    );
  }

  // Typed values ----------------------------------------------------------

  /// Commits under way, by field: the blur of a field and a Save can both
  /// commit the same value, and must not ask about it twice.
  final Map<_Field, ({int rowId, String text, Future<bool> result})> _commits =
      {};

  /// Writes the typed [text] of [field] to the set of [rowId], once it is a
  /// valid value. A weight or a rep count out of the ordinary asks first, as
  /// in a workout. Completes with false while the text is not a valid value,
  /// or when the value was turned down.
  Future<bool> _commitField(
    _Field field, {
    required int rowId,
    required String text,
  }) {
    final trimmed = text.trim();
    final pending = _commits[field];
    if (pending != null && pending.rowId == rowId && pending.text == trimmed) {
      return pending.result;
    }
    final result = _commit(field, rowId, trimmed);
    _commits[field] = (rowId: rowId, text: trimmed, result: result);
    result.whenComplete(() {
      if (identical(_commits[field]?.result, result)) _commits.remove(field);
    });
    return result;
  }

  Future<bool> _commit(_Field field, int rowId, String text) async {
    final index = _rowIds.indexOf(rowId);
    if (index < 0) return true;
    final set = _draft.sets[index];
    final isOpen = _openId == rowId;
    if (field == _Field.weight) {
      final error = requiredWeight(text);
      if (isOpen) setState(() => _weightError = error);
      if (error != null) return false;
      final displayed = parseDecimal(text, allowNegative: true)!;
      if (formatDecimal(displayed) == _displayWeight(set.weight)) return true;
      final confirmed = await confirmWeightEntry(context, displayed);
      if (!mounted) return false;
      if (!confirmed) {
        _refill(rowId);
        return false;
      }
      _setWeight(rowId, displayed);
    } else {
      final error = requiredReps(text);
      if (isOpen) setState(() => _repsError = error);
      if (error != null) return false;
      final reps = parseDecimal(text)!;
      if (reps == set.reps) return true;
      final confirmed = await confirmRepsEntry(context, reps);
      if (!mounted) return false;
      if (!confirmed) {
        _refill(rowId);
        return false;
      }
      _setReps(rowId, reps);
    }
    return true;
  }

  /// Puts the set's values back in the open row's fields.
  void _refill(int rowId) {
    final index = _rowIds.indexOf(rowId);
    if (index < 0 || _openId != rowId) return;
    final set = _draft.sets[index];
    setState(() {
      _weight.text = _displayWeight(set.weight);
      _reps.text = formatReps(set.reps);
    });
  }

  /// Sets [displayed] (in the shown unit) as the weight of [rowId]'s set. The
  /// stored kilograms stay exactly as saved unless the shown value moved
  /// away from them: converting a rounded pounds value back would drift.
  void _setWeight(int rowId, double displayed) {
    final index = _rowIds.indexOf(rowId);
    if (index < 0) return;
    final set = _draft.sets[index];
    final saved = savedSetOf(widget.session, set);
    final kilograms =
        saved != null &&
            _displayWeight(saved.weight) == formatDecimal(displayed)
        ? saved.weight
        : kilogramsFromDisplay(context, displayed);
    _change(
      (draft) =>
          draft.updateSet(index, (set) => set.copyWith(weight: kilograms)),
    );
  }

  void _setReps(int rowId, double reps) {
    final index = _rowIds.indexOf(rowId);
    if (index < 0) return;
    _change(
      (draft) => draft.updateSet(index, (set) => set.copyWith(reps: reps)),
    );
  }

  /// Saves what the open row's fields hold. False when one is not a valid
  /// value (its error shows and the row stays open) or was turned down.
  Future<bool> _commitOpen() async {
    final open = _openId;
    if (open == null) return true;
    final weight = _weight.text;
    final reps = _reps.text;
    // One after the other: each may ask about its value.
    final weightOk = await _commitField(
      _Field.weight,
      rowId: open,
      text: weight,
    );
    if (!mounted) return false;
    final repsOk = await _commitField(_Field.reps, rowId: open, text: reps);
    return weightOk && repsOk;
  }

  /// The value a step of [field] starts from: what is typed, else the
  /// set's.
  double _stepBase(_Field field) {
    final set = _draft.sets[_openIndex!];
    return field == _Field.weight
        ? parseDecimal(_weight.text, allowNegative: true) ??
              displayWeightOf(context, set.weight)
        : parseDecimal(_reps.text) ?? set.reps;
  }

  /// Asks [ask] for a step, keeping the steps after it (a hold, a drag on
  /// the ruler) from asking again meanwhile.
  Future<bool> _confirmStep(Future<bool> Function() ask) async {
    _asking = true;
    try {
      return await ask() && mounted;
    } finally {
      _asking = false;
    }
  }

  /// After a step from the keypad, the next key typed starts over.
  void _selectForKeypad(_Field field) {
    if (!_entry.usesKeypad || !_focusOf(field).hasFocus) return;
    final controller = _controllerOf(field);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  Future<void> _step(_Field field, int direction) async {
    final rowId = _openId;
    final index = _openIndex;
    if (rowId == null || index == null || _asking) return;
    final current = _stepBase(field);
    if (field == _Field.weight) {
      final unit = weightUnitOf(context);
      final step = unit == WeightUnit.kilograms ? 2.5 : 5.0;
      final next = (current + step * direction)
          .clamp(minimumWeight, maximumWeight)
          .toDouble();
      // Ask once, as the weight crosses into what needs a second look.
      final threshold = unit.heavyWeightThreshold;
      if ((current >= 0 && next < 0) ||
          (current <= threshold && next > threshold)) {
        _stopRepeat();
        if (!await _confirmStep(() => confirmWeightEntry(context, next))) {
          return;
        }
      }
      setState(() {
        _weight.text = formatDecimal(next);
        _weightError = null;
      });
      _selectForKeypad(field);
      _setWeight(rowId, next);
    } else {
      // Stepping never goes below one rep, or below a partial rep typed in.
      final next = (current + direction)
          .clamp(math.min(1.0, math.max(current, minimumReps)), maximumReps)
          .toDouble();
      if (current <= highRepsThreshold && next > highRepsThreshold) {
        _stopRepeat();
        if (!await _confirmStep(() => confirmRepsEntry(context, next))) return;
      }
      setState(() {
        _reps.text = formatReps(next);
        _repsError = null;
      });
      _selectForKeypad(field);
      _setReps(rowId, next);
    }
  }

  void _startRepeat(_Field field, int direction) {
    _repeat?.cancel();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _step(field, direction),
    );
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  // Focus and number entry ------------------------------------------------

  TextEditingController _controllerOf(_Field field) =>
      field == _Field.weight ? _weight : _reps;

  FocusNode _focusOf(_Field field) =>
      field == _Field.weight ? _weightFocus : _repsFocus;

  _Field? get _focused => _weightFocus.hasFocus
      ? _Field.weight
      : _repsFocus.hasFocus
      ? _Field.reps
      : null;

  void _onFocusChange() {
    if (!mounted) return;
    for (final field in _Field.values) {
      final focused = _focusOf(field).hasFocus;
      final had = field == _Field.weight ? _hadWeightFocus : _hadRepsFocus;
      if (focused && !had) {
        // Typing replaces the value: select it once the tap that focused the
        // field has placed its caret.
        final controller = _controllerOf(field);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_focusOf(field).hasFocus) return;
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        });
        if (_entry.usesKeypad) _pendingReveal = true;
      } else if (!focused && had && _openId != null) {
        unawaited(
          _commitField(field, rowId: _openId!, text: _controllerOf(field).text),
        );
      }
      if (field == _Field.weight) {
        _hadWeightFocus = focused;
      } else {
        _hadRepsFocus = focused;
      }
    }
    setState(() {});
    _syncOverlay();
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
      bottom: _entry.usesKeypad
          ? 0
          : MediaQuery.viewInsetsOf(overlayContext).bottom,
      child: IgnorePointer(
        ignoring: _overlayClosing,
        child: SlideUpPanel(key: _panelKey, child: panel),
      ),
    );
  }

  Widget _panel(_Field field) {
    final isWeight = field == _Field.weight;
    final index = _openIndex;
    final label = index == null ? '' : _labelOf(index);
    final who = label == 'W' ? 'Warm-up' : 'Set $label';
    if (_entry.usesKeypad) {
      return NumberKeypad(
        caption: isWeight
            ? '$who weight, in ${weightUnitOf(context).symbol}'
            : '$who reps',
        allowSign: isWeight,
        logLabel: 'Done',
        live: false,
        onLog: _unfocus,
        onKey: (key, digit) => _onKey(field, key, digit),
        steps: _keypadSteps(field),
      );
    }
    return KeyboardToolbar(
      onSign: isWeight ? () => _onKey(field, KeypadKey.sign, '') : null,
      onNext: () => _onKey(field, KeypadKey.next, ''),
      logLabel: 'Done',
      live: false,
      onLog: _unfocus,
    );
  }

  /// The keypad's steppers for [field], in the number entries that have
  /// them.
  KeypadSteps? _keypadSteps(_Field field) {
    final entry = _entry;
    if (!entry.usesKeypad || _openIndex == null) return null;
    final ruler = entry == NumberEntry.keypadRuler;
    final value = _stepBase(field);
    void onStep(int direction) => _step(field, direction);
    return field == _Field.weight
        ? KeypadSteps.weight(
            ruler: ruler,
            value: value,
            unit: weightUnitOf(context),
            onStep: onStep,
          )
        : KeypadSteps.reps(ruler: ruler, value: value, onStep: onStep);
  }

  void _onKey(_Field field, KeypadKey key, String digit) {
    switch (key) {
      case KeypadKey.next:
        if (field == _Field.weight) {
          _repsFocus.requestFocus();
        } else {
          _unfocus();
        }
      case KeypadKey.hide:
        _unfocus();
      case KeypadKey.digit:
      case KeypadKey.backspace:
      case KeypadKey.sign:
        applyKeypadKey(
          _controllerOf(field),
          key,
          digit: digit,
          allowNegative: field == _Field.weight,
        );
        setState(() {});
        _overlay?.markNeedsBuild();
    }
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  /// The keypad is an overlay the scroll view cannot see: scroll the open
  /// row into the space above it. Runs after the frame that made the room.
  void _revealAboveKeypad() {
    final rowContext = _openRowKey.currentContext;
    final box = rowContext?.findRenderObject();
    if (rowContext == null || box is! RenderBox || !box.attached) return;
    final scrollable = Scrollable.maybeOf(rowContext);
    if (scrollable == null) return;
    final media = MediaQuery.of(rowContext);
    final keypadTop =
        media.size.height -
        NumberKeypad.heightOf(_entry) -
        media.padding.bottom;
    final rowBottom = box.localToGlobal(Offset(0, box.size.height)).dy + 12;
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

  // Saving, discarding, deleting -------------------------------------------

  void _discard() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _draft = SessionDraft.of(widget.session);
      _rowIds = _freshRowIds();
      _openId = null;
      _weightError = null;
      _repsError = null;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    // A value still in its field is part of the draft: commit it first (it
    // may ask about it), and keep the page open while it is not valid.
    if (!await _commitOpen() || !mounted) return;
    final updated = _draft.applyTo(widget.session);
    final repo = RepositoryScope.maybeOf(context);
    setState(() => _busy = true);
    try {
      await repo?.sessions.put(updated);
    } catch (error, stackTrace) {
      AppLog.error('history-edit', error, stackTrace);
      if (!mounted) return;
      setState(() => _busy = false);
      showFToast(
        context: context,
        title: const Text('Could not save the changes.'),
        duration: const Duration(seconds: 4),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(SessionSaved(updated));
  }

  Future<void> _delete() async {
    if (_busy) return;
    final session = widget.session;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this workout?',
      message:
          '${session.title}, ${shortDateLabel(session.startTime)}, with all '
          'its sets. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final repo = RepositoryScope.maybeOf(context);
    setState(() => _busy = true);
    try {
      if (repo != null && !await repo.sessions.delete(session.id)) {
        throw StateError('session ${session.id} was not found');
      }
    } catch (error, stackTrace) {
      AppLog.error('history-delete', error, stackTrace);
      if (!mounted) return;
      setState(() => _busy = false);
      showFToast(
        context: context,
        title: const Text('Could not delete the workout.'),
        duration: const Duration(seconds: 4),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(const SessionDeleted());
  }

  // Build -----------------------------------------------------------------

  /// The badge of the set at [index]: its number among its exercise's
  /// working sets, or W.
  String _labelOf(int index) {
    final set = _draft.sets[index];
    if (set.warmup) return 'W';
    var working = 0;
    for (var i = 0; i <= index; i++) {
      final other = _draft.sets[i];
      if (other.exerciseId == set.exerciseId && !other.warmup) working++;
    }
    return '$working';
  }

  @override
  Widget build(BuildContext context) {
    if (!TabVisibilityScope.isActiveOf(context) && _focused != null) {
      // Another tab is showing: put the keypad away with the focus.
      WidgetsBinding.instance.addPostFrameCallback((_) => _unfocus());
    }
    final changes = _changes;
    final keypadOpen = _entry.usesKeypad && _focused != null;
    if (keypadOpen && _pendingReveal) {
      _pendingReveal = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealAboveKeypad());
    }
    final bottomRoom = keypadOpen
        ? NumberKeypad.heightOf(_entry) + 24
        : keyboardClearanceOf(context);
    return PopScope(
      canPop: changes == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscardUnsavedChanges(context) && mounted) {
          navigator.pop();
        }
      },
      // The value fields are Material text fields; the page paints nothing.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: <Widget>[
            CustomScrollView(
              slivers: <Widget>[
                CustomAppBar(
                  context,
                  title: 'Edit workout',
                  trailing: _menu(context),
                ),
                SliverToBoxAdapter(
                  child: MaxWidth(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomRoom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _fieldsCard(context),
                          ..._exercises(context),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _AddButton(
                              label: 'Add exercise',
                              onPress: _addExercise,
                            ),
                          ),
                          // Room to scroll clear of the save bar, opening
                          // and closing with it.
                          AnimatedReveal(
                            fade: false,
                            child: changes == 0
                                ? null
                                : const SizedBox(height: 76),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Slides up from the bottom edge while there are unsaved
            // changes, and back down once they are saved or discarded.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedReveal(
                fade: false,
                child: changes == 0
                    ? null
                    : _SaveBar(
                        count: changes,
                        busy: _busy,
                        onDiscard: _discard,
                        onSave: _save,
                      ),
              ),
            ),
          ],
        ),
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
                'Delete workout',
                style: TextStyle(color: destructive),
              ),
              onPress: () {
                controller.hide();
                _delete();
              },
            ),
          ],
        ),
      ],
      builder: (_, controller, _) => AppIconButton(
        icon: FLucideIcons.ellipsis,
        tooltip: 'Workout options',
        onPress: controller.toggle,
      ),
    );
  }

  Widget _fieldsCard(BuildContext context) {
    final saved = widget.session;
    return ItemCard(
      divider: .full,
      children: <FItemMixin>[
        _valueRow(
          context,
          title: 'Name',
          value: _draft.title,
          changed: _draft.title.trim() != saved.title,
          onPress: _editName,
        ),
        _valueRow(
          context,
          title: 'Gym',
          value: _gymLabel,
          changed: _draft.gymId != saved.gymId,
          onPress: _pickGym,
        ),
        _valueRow(
          context,
          title: 'Started',
          value: dateTimeLabel(_draft.startTime),
          changed: !_draft.startTime.isAtSameMomentAs(saved.startTime),
          onPress: _pickStart,
        ),
        _valueRow(
          context,
          title: 'Ended',
          value: _endLabel,
          changed: _draft.endTime != saved.endTime,
          onPress: _pickEnd,
        ),
      ],
    );
  }

  /// A row with its value and a chevron; a changed value is marked amber.
  FItem _valueRow(
    BuildContext context, {
    required String title,
    required String value,
    required bool changed,
    required VoidCallback onPress,
  }) {
    final theme = context.theme;
    final muted = theme.colors.mutedForeground;
    return FItem.raw(
      onPress: onPress,
      child: Row(
        children: <Widget>[
          Text(title),
          if (changed) ...[const SizedBox(width: 8), const DraftDot()],
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(color: muted),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            FLucideIcons.chevronRight,
            color: muted,
            size: theme.typography.body.md.fontSize,
          ),
        ],
      ),
    );
  }

  List<Widget> _exercises(BuildContext context) {
    final theme = context.theme;
    final groups = <int, List<int>>{};
    for (final (i, set) in _draft.sets.indexed) {
      (groups[set.exerciseId] ??= <int>[]).add(i);
    }
    return [
      for (final MapEntry(key: exerciseId, value: indices)
          in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _nameOf(exerciseId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                setCountsLabel(
                  indices.where((i) => !_draft.sets[i].warmup).length,
                  indices.where((i) => _draft.sets[i].warmup).length,
                ),
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        for (final index in indices) _setRow(context, index),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _AddButton(
            label: 'Add set',
            onPress: () {
              _closeRow();
              _addSet(exerciseId);
            },
          ),
        ),
      ],
    ];
  }

  Widget _setRow(BuildContext context, int index) {
    final rowId = _rowIds[index];
    final set = _draft.sets[index];
    final saved = savedSetOf(widget.session, set);
    final edited = saved != null && set.differsFrom(saved);
    final label = _labelOf(index);
    final open = rowId == _openId;
    final tag = set.isNew ? 'New' : (edited ? 'Edited' : null);
    final was = edited ? _wasLine(context, saved, set) : null;
    return SwipeToDelete(
      key: ValueKey('edit-set-$rowId'),
      canDelete: true,
      onDelete: () => _removeSet(rowId),
      surface: context.theme.colors.background,
      padding: const EdgeInsets.only(bottom: 6),
      // Opening one row and folding another: both glide to their height.
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: open
            ? KeyedSubtree(
                key: _openRowKey,
                child: _openRowView(context, rowId, set, label, tag, was),
              )
            : _compactRow(context, rowId, set, label, tag, was),
      ),
    );
  }

  /// "Was 80 kg × 8, RPE 8.5": the saved set, its values struck through.
  Widget _wasLine(BuildContext context, WorkoutSet saved, SetDraft set) {
    final theme = context.theme;
    final rpe = saved.rpe;
    final type = saved.isWarmup == set.warmup
        ? ''
        : (saved.isWarmup ? ', a warm-up' : ', a working set');
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          const TextSpan(text: 'Was '),
          TextSpan(
            text:
                '${formatWeight(context, saved.weight)} × '
                '${formatReps(saved.reps)}',
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
          if (rpe != null)
            TextSpan(text: ', ${effortLabel(effortScaleOf(context), rpe)}'),
          TextSpan(text: type),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.body.xs.copyWith(
        color: theme.colors.mutedForeground,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _badge(String label, bool warmup, int rowId) => Semantics(
    button: true,
    label: warmup
        ? 'Warm-up set, tap for a working set'
        : 'Set $label, tap for a warm-up',
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleWarmup(rowId),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: SetBadge(label: label, warmup: warmup),
        ),
      ),
    ),
  );

  Widget _compactRow(
    BuildContext context,
    int rowId,
    SetDraft set,
    String label,
    String? tag,
    Widget? was,
  ) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final muted = theme.colors.mutedForeground;
    const tabular = [FontFeature.tabularFigures()];
    final number = theme.typography.body.sm.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: tabular,
    );
    final quiet = theme.typography.body.xs.copyWith(
      color: muted,
      fontFeatures: tabular,
    );
    final rpe = set.rpe;
    return Semantics(
      button: true,
      hint: 'Opens the set to edit it',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openRow(rowId),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          decoration: BoxDecoration(
            color: theme.colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: tag == null ? theme.colors.border : accents.draftLine,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _badge(label, set.warmup, rowId),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: _displayWeight(set.weight),
                            style: number,
                          ),
                          TextSpan(
                            text: ' ${weightUnitOf(context).symbol} × ',
                            style: quiet,
                          ),
                          TextSpan(text: formatReps(set.reps), style: number),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tag != null) ...[const SizedBox(width: 8), DraftTag(tag)],
                  if (rpe != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      effortLabel(effortScaleOf(context), rpe),
                      style: quiet,
                    ),
                  ],
                ],
              ),
              if (was != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(38, 0, 0, 2),
                  child: was,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _openRowView(
    BuildContext context,
    int rowId,
    SetDraft set,
    String label,
    String? tag,
    Widget? was,
  ) {
    final theme = context.theme;
    final unit = weightUnitOf(context).symbol;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 10),
      decoration: BoxDecoration(
        color: theme.colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colors.foreground, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _badge(label, set.warmup, rowId),
              const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  button: true,
                  hint: 'Closes the set',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeRow,
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              set.warmup ? 'Warm-up' : 'Set $label',
                              style: theme.typography.body.xs.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (tag != null) DraftTag(tag),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _withError(
                    context,
                    _stepperGroup(context, _Field.weight, unit),
                    _weightError,
                  ),
                ),
                SizedBox(
                  width: 18,
                  height: 52,
                  child: Center(
                    child: Text(
                      '×',
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _withError(
                    context,
                    _stepperGroup(context, _Field.reps, 'reps'),
                    _repsError,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: EffortStrip(
              scale: effortScaleOf(context),
              rpe: set.rpe,
              who: label == 'W' ? 'warm-up' : 'set $label',
              live: false,
              onRate: (rpe) => _rate(rowId, rpe),
              onMore: () => _pickEffort(rowId, label),
            ),
          ),
          if (was != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 0, 0),
              child: was,
            ),
        ],
      ),
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

  Widget _stepperGroup(BuildContext context, _Field field, String caption) {
    final theme = context.theme;
    final error = field == _Field.weight ? _weightError : _repsError;
    final focused = _focusOf(field).hasFocus;
    // With the steppers in the keypad the box is the number alone.
    final bare = _entry.usesKeypad;
    final group = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: error != null
              ? theme.colors.error
              : focused
              ? theme.colors.foreground
              : theme.colors.border,
        ),
      ),
      child: Row(
        children: <Widget>[
          if (!bare) _stepButton(context, field, -1),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: 30, child: _valueField(context, field)),
                Text(
                  caption,
                  maxLines: 1,
                  style: theme.typography.body.xs3.copyWith(
                    color: theme.colors.mutedForeground,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (!bare) _stepButton(context, field, 1),
        ],
      ),
    );
    if (!bare) return group;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focusOf(field).requestFocus(),
      child: group,
    );
  }

  Widget _stepButton(BuildContext context, _Field field, int direction) {
    final theme = context.theme;
    final what = field == _Field.weight ? 'weight' : 'reps';
    return Semantics(
      button: true,
      label: direction > 0 ? 'Increase $what' : 'Decrease $what',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _step(field, direction),
        onLongPressStart: (_) => _startRepeat(field, direction),
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

  Widget _valueField(BuildContext context, _Field field) {
    final theme = context.theme;
    final isWeight = field == _Field.weight;
    final controller = _controllerOf(field);
    final style = theme.typography.body.xl.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.15,
      color: theme.colors.foreground,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final entry = _entry;
    final keypad = entry.usesKeypad;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return TextField(
      controller: controller,
      focusNode: _focusOf(field),
      keyboardType: keypad
          ? TextInputType.none
          : TextInputType.numberWithOptions(decimal: true, signed: isWeight),
      inputFormatters: [DecimalInputFormatter(allowNegative: isWeight)],
      textAlign: TextAlign.center,
      textAlignVertical: TextAlignVertical.center,
      style: style,
      cursorColor: theme.colors.foreground,
      showCursor: true,
      // The rows sit inside the swipe-to-delete wrapper: no selection
      // handles, so a horizontal swipe never drags a selection instead.
      enableInteractiveSelection: false,
      textInputAction: isWeight ? TextInputAction.next : TextInputAction.done,
      onSubmitted: (_) => isWeight ? _repsFocus.requestFocus() : _unfocus(),
      onChanged: (_) {
        setState(() {
          if (isWeight) {
            _weightError = null;
          } else {
            _repsError = null;
          }
        });
        _overlay?.markNeedsBuild();
      },
      scrollPadding: EdgeInsets.only(
        bottom: keypad ? NumberKeypad.heightOf(entry) + 40 : keyboard + 120,
      ),
      decoration: const InputDecoration.collapsed(hintText: ''),
    );
  }
}

/// A quiet button that adds something: a set, an exercise.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPress});

  final String label;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) => FButton(
    variant: .ghost,
    size: .sm,
    mainAxisSize: .min,
    onPress: onPress,
    prefix: const Icon(FLucideIcons.plus),
    child: Text(label),
  );
}

/// The unsaved edits: how many, and Discard or Save, in the unsaved accent.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.count,
    required this.busy,
    required this.onDiscard,
    required this.onSave,
  });

  final int count;
  final bool busy;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accents.draftSoft,
        border: Border(top: BorderSide(color: accents.draftLine)),
      ),
      child: MaxWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: <Widget>[
              const DraftDot(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plural('unsaved change', count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.xs.copyWith(
                    color: accents.draftInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FButton(
                variant: .ghost,
                size: .sm,
                mainAxisSize: .min,
                onPress: busy ? null : onDiscard,
                child: const Text('Discard'),
              ),
              const SizedBox(width: 6),
              FButton(
                size: .sm,
                mainAxisSize: .min,
                onPress: busy ? null : onSave,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renames the workout: one field, Save keeps it.
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});

  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final error = requiredText(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) => EditSheet(
    title: 'Name',
    description: 'What the workout is called in History',
    onAction: _save,
    child: FTextField(
      control: FTextFieldControl.managed(
        controller: _name,
        onChange: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      error: _error == null ? null : Text(_error!),
      onSubmit: (_) => _save(),
    ),
  );
}

/// Moves a start or end time: a date and time picker, checked by [check]
/// before Save keeps it.
class _TimeSheet extends StatefulWidget {
  const _TimeSheet({
    required this.title,
    required this.initial,
    required this.check,
  });

  final String title;
  final DateTime initial;

  /// Why a picked time cannot be kept, or null when it can.
  final String? Function(DateTime time) check;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late DateTime _picked = widget.initial;
  String? _error;

  void _save() {
    final error = widget.check(_picked);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return EditSheet(
      title: widget.title,
      onAction: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 200,
            child: FDateTimePicker(
              control: .managed(
                initial: widget.initial,
                onChange: (value) => setState(() {
                  _picked = value;
                  _error = null;
                }),
              ),
            ),
          ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
