import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/decimal_input_formatter.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/set_type_chip.dart';
import 'package:tracker/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:tracker/ui/core/ui/weight_confirmation.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/utils/decimal_input.dart';
import 'package:tracker/utils/form_validators.dart';

/// Editor for a completed past [WorkoutSession], reached from the session
/// detail page's Edit action.
///
/// Focused form over the session's own fields (title, gym, start time) and
/// every logged set (weight, reps, warm-up/working type); the in-progress
/// workout flow is untouched. The page only builds a draft and pops with it -
/// the caller persists it through the session repository.
class SessionEditPage extends StatefulWidget {
  const SessionEditPage({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<SessionEditPage> createState() => _SessionEditPageState();
}

class _SessionEditPageState extends State<SessionEditPage> {
  late final TextEditingController _title;
  late DateTime _start;
  late DateTime? _end;
  late List<WorkoutSet> _sets;

  /// The gym saved with the session. Seeded from the session itself, so saving
  /// before [_gym] resolves keeps the original gym; only the picker changes it.
  int? _gymId;
  Gym? _gym;
  bool _gymLoaded = false;
  String? _titleError;
  Map<int, String> _exerciseNames = const {};
  bool _didLoad = false;

  /// Snapshot of the session as loaded; compared against the live draft to
  /// detect unsaved changes when the user tries to leave without saving.
  _SessionDraftSnapshot? _initial;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.session.title)
      ..addListener(_clearTitleError);
    _start = widget.session.startTime;
    _end = widget.session.endTime;
    _gymId = widget.session.gymId;
    _sets = List.of(widget.session.sets);
    // Rebuild on edits so the PopScope discard guard tracks changes.
    _title.addListener(() => setState(() {}));
    _initial = _snapshot(gymId: widget.session.gymId);
  }

  void _clearTitleError() {
    if (_titleError != null) setState(() => _titleError = null);
  }

  String get _gymLabel {
    final gym = _gym;
    if (gym != null) return gym.name;
    if (_gymId == null) return 'No gym';
    return _gymLoaded ? 'Unknown gym' : 'Loading...';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RepositoryScope is an inherited widget, so read it after initState.
    if (!_didLoad) {
      _didLoad = true;
      _loadGym();
      _loadExerciseNames();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// A normalized copy of the current draft, used as the dirty-check
  /// baseline. Normalization mirrors [_save] (trimmed title) so only
  /// content differences read as unsaved changes.
  ///
  /// The draft's gym id comes from [_gym], which resolves asynchronously;
  /// the baseline is therefore taken with the session's own [gymId].
  _SessionDraftSnapshot _snapshot({int? gymId}) => _SessionDraftSnapshot(
    title: _title.text.trim(),
    start: _start,
    end: _end,
    gymId: gymId ?? _gym?.id,
    sets: [
      for (final s in _sets)
        WorkoutSet(
          exerciseId: s.exerciseId,
          weight: s.weight,
          reps: s.reps,
          type: s.type,
          order: s.order,
        ),
    ],
  );

  /// True when the draft differs from what was loaded (see [_initial]):
  /// title, start/end times, gym, or any set's fields.
  bool get _hasUnsavedChanges {
    final initial = _initial;
    if (initial == null) return false;
    if (initial.title != _title.text.trim()) return true;
    if (initial.start != _start) return true;
    if (initial.end != _end) return true;
    if (initial.gymId != _gym?.id) return true;
    if (initial.sets.length != _sets.length) return true;
    for (var i = 0; i < _sets.length; i++) {
      if (_setDiffers(initial.sets[i], _sets[i])) return true;
    }
    return false;
  }

  bool _setDiffers(WorkoutSet a, WorkoutSet b) =>
      a.exerciseId != b.exerciseId ||
      a.weight != b.weight ||
      a.reps != b.reps ||
      a.type != b.type ||
      a.order != b.order;

  Future<void> _loadGym() async {
    final gymId = _gymId;
    if (gymId == null) return;
    final gym = await RepositoryScope.maybeOf(context)?.gyms.getById(gymId);
    // A gym picked while the lookup was in flight wins over the stored one.
    if (!mounted || _gymLoaded) return;
    setState(() {
      _gym = gym;
      _gymLoaded = true;
    });
  }

  Future<void> _loadExerciseNames() async {
    final repo = RepositoryScope.maybeOf(context);
    final exercises = await repo?.exercises.getAll() ?? const [];
    if (!mounted) return;
    setState(() {
      _exerciseNames = {for (final e in exercises) e.id: e.title};
    });
  }

  /// Applies the picked start time and keeps the logged duration stable by
  /// shifting the end time by the same delta.
  void _applyStart(DateTime picked) {
    setState(() {
      final delta = picked.difference(_start);
      _start = picked;
      final end = _end;
      if (end != null) {
        _end = end.add(delta);
      }
    });
  }

  Future<void> _pickStart() async {
    final picked = await _pickStartDateTime(context, _start);
    if (!mounted || picked == null) return;
    _applyStart(picked);
  }

  Future<void> _pickGym() async {
    final repo = RepositoryScope.maybeOf(context);
    final gyms = await repo?.gyms.getAll() ?? const <Gym>[];
    if (!mounted) return;
    final picked = await _pickGymSheet(context, gyms);
    if (!mounted || picked == null) return;
    setState(() {
      _gymLoaded = true;
      _gym = picked is Gym ? picked : null;
      _gymId = picked is Gym ? picked.id : null;
    });
  }

  Future<void> _editSet(int index) async {
    final updated = await _editSetDialog(context, set: _sets[index]);
    if (!mounted || updated == null) return;
    setState(() => _sets[index] = updated);
  }

  void _save() {
    final titleError = requiredText(_title.text);
    if (titleError != null) {
      setState(() => _titleError = titleError);
      return;
    }
    final session = WorkoutSession(
      title: _title.text.trim(),
      startTime: _start,
      endTime: _end,
      gymId: _gymId,
      sets: List.of(_sets),
    )..id = widget.session.id;
    Navigator.of(context).pop(session);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return PopScope(
      // Guard back navigation (app-bar chevron and system back) so an edit
      // with unsaved changes asks before being thrown away. Save pops with a
      // result through _save, which is not intercepted.
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscardUnsavedChanges(context) && mounted) {
          navigator.pop();
        }
      },
      child: CustomScrollView(
        slivers: <Widget>[
          CustomAppBar(
            context,
            title: 'Edit session',
            actionButton: (title: 'Save', onPressed: _save),
          ),
          SliverToBoxAdapter(
            child: MaxWidth(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  keyboardClearanceOf(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _SessionFieldsCard(
                      title: _title,
                      titleError: _titleError,
                      start: _start,
                      onPickGym: _pickGym,
                      onPickStart: _pickStart,
                      gymLabel: _gymLabel,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sets',
                      style: theme.typography.body.md.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a set to edit its weight, reps or type.',
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_sets.isEmpty)
                      const Text('No sets were logged in this session.')
                    else
                      for (var i = 0; i < _sets.length; i++)
                        _EditSetRow(
                          name:
                              _exerciseNames[_sets[i].exerciseId] ??
                              'Exercise ${_sets[i].exerciseId}',
                          set: _sets[i],
                          onEdit: () => _editSet(i),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionFieldsCard extends StatelessWidget {
  const _SessionFieldsCard({
    required this.title,
    required this.titleError,
    required this.gymLabel,
    required this.start,
    required this.onPickGym,
    required this.onPickStart,
  });

  final TextEditingController title;
  final String? titleError;
  final String gymLabel;
  final DateTime start;
  final VoidCallback onPickGym;
  final VoidCallback onPickStart;

  @override
  Widget build(BuildContext context) {
    final d = start.toLocal();
    // The hint lives under the card (not inside it): inside, it sat flush
    // against the card's bottom edge and read as a clipped divider line.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FTextField(
                  control: FTextFieldControl.managed(controller: title),
                  label: const Text('Title'),
                  error: titleError == null ? null : Text(titleError!),
                ),
                const SizedBox(height: 8),
                FItem(
                  prefix: const Icon(FLucideIcons.dumbbell),
                  title: const Text('Gym'),
                  subtitle: Text(gymLabel),
                  suffix: const Icon(FLucideIcons.chevronRight),
                  onPress: onPickGym,
                ),
                FItem(
                  prefix: const Icon(FLucideIcons.calendar),
                  title: const Text('Started'),
                  subtitle: Text(
                    '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}',
                  ),
                  suffix: const Icon(FLucideIcons.chevronRight),
                  onPress: onPickStart,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Editing the start time keeps the session duration.',
          style: context.theme.typography.body.xs.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }

  String _p(int v) => v.toString().padLeft(2, '0');
}

/// Set row in the editor; tapping opens the per-set dialog.
class _EditSetRow extends StatelessWidget {
  const _EditSetRow({
    required this.name,
    required this.set,
    required this.onEdit,
  });

  final String name;
  final WorkoutSet set;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FItem(
        onPress: onEdit,
        prefix: SetTypeChip(isWarmup: set.isWarmup),
        title: Text(name),
        subtitle: Text(
          '${formatWeight(context, set.weight)} × ${formatReps(set.reps)}',
        ),
        suffix: const Icon(FLucideIcons.chevronRight),
      ),
    );
  }
}

/// Marker returned by the gym sheet when the user explicitly clears the gym
/// (a bare `null` pop means the sheet was dismissed without a choice).
class _NoGym {
  const _NoGym();
}

/// Immutable snapshot of the editor's draft, used as the dirty-check
/// baseline (mirrors new_split_page.dart). Sets are deep copies so later
/// edits cannot mutate the snapshot.
final class _SessionDraftSnapshot {
  const _SessionDraftSnapshot({
    required this.title,
    required this.start,
    required this.end,
    required this.gymId,
    required this.sets,
  });

  final String title;
  final DateTime start;
  final DateTime? end;
  final int? gymId;
  final List<WorkoutSet> sets;
}

/// Bottom sheet over the gyms plus an explicit "No gym" entry; returns the
/// picked [Gym], `[_NoGym]` to clear, or null on dismiss.
Future<Object?> _pickGymSheet(BuildContext context, List<Gym> gyms) {
  return showModalBottomSheet<Object>(
    context: context,
    backgroundColor: context.theme.colors.background,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Which gym?',
                style: sheetContext.theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final gym in gyms)
              FItem(
                prefix: Icon(
                  gym.isPrimary ? FLucideIcons.house : FLucideIcons.dumbbell,
                ),
                title: Text(gym.name),
                subtitle: gym.isPrimary ? const Text('Primary gym') : null,
                onPress: () => Navigator.of(sheetContext).pop(gym),
              ),
            FItem(
              prefix: const Icon(FLucideIcons.ban),
              title: const Text('No gym'),
              onPress: () => Navigator.of(sheetContext).pop(const _NoGym()),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Date + time wheels in a dialog; returns the picked [DateTime] or null on
/// cancel. Captures wheel changes in a local, so Save just pops with it.
Future<DateTime?> _pickStartDateTime(BuildContext context, DateTime initial) {
  var picked = initial;
  return showFDialog<DateTime>(
    context: context,
    builder: (dialogContext, _, _) => AppDialog(
      title: 'Start time',
      headerGap: 12,
      actionsGap: 16,
      scrollable: true,
      actions: [
        FButton(
          variant: .outline,
          onPress: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FButton(
          onPress: () => Navigator.pop(dialogContext, picked),
          child: const Text('Save'),
        ),
      ],
      child: SizedBox(
        height: 200,
        child: FDateTimePicker(
          control: .managed(
            initial: initial,
            onChange: (value) => picked = value,
          ),
        ),
      ),
    ),
  );
}

/// Weight/reps/type editor for one logged set; returns the updated [WorkoutSet]
/// or null on cancel.
Future<WorkoutSet?> _editSetDialog(
  BuildContext context, {
  required WorkoutSet set,
}) {
  return showFDialog<WorkoutSet>(
    context: context,
    builder: (dialogContext, _, _) => _EditSetDialog(initial: set),
  );
}

class _EditSetDialog extends StatefulWidget {
  const _EditSetDialog({required this.initial});

  final WorkoutSet initial;

  @override
  State<_EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<_EditSetDialog> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  late final String _prefilledWeight;
  late bool _warmup;
  String? _weightError;
  String? _repsError;

  @override
  void initState() {
    super.initState();
    // context.read inside SettingsCubit.maybeOf works here, so the display-unit
    // conversion is safe before the first frame.
    _prefilledWeight = formatDecimal(
      displayWeightOf(context, widget.initial.weight),
    );
    _weight = TextEditingController(text: _prefilledWeight);
    _reps = TextEditingController(text: formatReps(widget.initial.reps));
    _warmup = widget.initial.isWarmup;
    _weight.addListener(() => setState(() => _weightError = null));
    _reps.addListener(() => setState(() => _repsError = null));
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scrollable like the app's reference EditGymDialog: weight/reps errors
    // push content taller and the keyboard must not clip the actions.
    return AppDialog(
      title: 'Edit set',
      headerGap: 16,
      scrollable: true,
      actions: [
        FButton(
          variant: .outline,
          onPress: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FButton(onPress: _save, child: const Text('Save')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: <Widget>[
              Expanded(
                child: FTextField(
                  control: FTextFieldControl.managed(controller: _weight),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [DecimalInputFormatter(allowNegative: true)],
                  label: Text('Weight (${weightUnitOf(context).symbol})'),
                  error: _weightError == null ? null : Text(_weightError!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FTextField(
                  control: FTextFieldControl.managed(controller: _reps),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [DecimalInputFormatter()],
                  label: const Text('Reps'),
                  error: _repsError == null ? null : Text(_repsError!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FCheckbox(
            label: const Text('Warm-up'),
            value: _warmup,
            onChange: (v) => setState(() => _warmup = v),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final weightError = requiredWeight(_weight.text);
    final displayed = parseDecimal(_weight.text, allowNegative: true);
    final reps = parseDecimal(_reps.text);
    if (weightError != null || displayed == null || reps == null || reps < 1) {
      setState(() {
        _weightError = weightError;
        _repsError = reps == null || reps < 1 ? 'Must be at least 1' : null;
      });
      return;
    }
    final confirmed = await confirmWeightEntry(context, displayed);
    if (!mounted || !confirmed) return;
    // The prefilled text is the rounded display value, so converting it back
    // would drift the stored weight. Keep the original unless the user edited it.
    final weightEdited = _weight.text.trim() != _prefilledWeight;
    Navigator.of(context).pop(
      WorkoutSet(
        exerciseId: widget.initial.exerciseId,
        // The field holds display units; storage stays canonical kilograms.
        weight: weightEdited
            ? kilogramsFromDisplay(context, displayed)
            : widget.initial.weight,
        reps: reps,
        type: _warmup ? SetType.warmup : SetType.working,
        order: widget.initial.order,
      ),
    );
  }
}
