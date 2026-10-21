import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_session.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/reps_input_formatter.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
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

  Gym? _gym;
  Map<int, String> _exerciseNames = const {};
  bool _didLoad = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.session.title);
    _start = widget.session.startTime;
    _end = widget.session.endTime;
    _sets = List.of(widget.session.sets);
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

  Future<void> _loadGym() async {
    final gymId = widget.session.gymId;
    if (gymId == null) return;
    final gym = await RepositoryScope.maybeOf(context)?.gyms.getById(gymId);
    if (!mounted || gym == null) return;
    setState(() => _gym = gym);
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
    setState(() => _gym = picked is Gym ? picked : null);
  }

  Future<void> _editSet(int index) async {
    final updated = await _editSetDialog(context, set: _sets[index]);
    if (!mounted || updated == null) return;
    setState(() => _sets[index] = updated);
  }

  void _save() {
    final session = WorkoutSession(
      title: _title.text.trim(),
      startTime: _start,
      endTime: _end,
      gymId: _gym?.id,
      sets: List.of(_sets),
    )..id = widget.session.id;
    Navigator.of(context).pop(session);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return CustomScrollView(
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
                32 + keyboardInsetOf(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SessionFieldsCard(
                    title: _title,
                    gym: _gym,
                    start: _start,
                    onPickGym: _pickGym,
                    onPickStart: _pickStart,
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
    );
  }
}

class _SessionFieldsCard extends StatelessWidget {
  const _SessionFieldsCard({
    required this.title,
    required this.gym,
    required this.start,
    required this.onPickGym,
    required this.onPickStart,
  });

  final TextEditingController title;
  final Gym? gym;
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
                ),
                const SizedBox(height: 8),
                FItem(
                  prefix: const Icon(FLucideIcons.dumbbell),
                  title: const Text('Gym'),
                  subtitle: Text(gym?.name ?? 'No gym'),
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
        prefix: _TypeChip(isWarmup: set.isWarmup),
        title: Text(name),
        subtitle: Text(
          '${formatWeight(context, set.weight)} × ${formatReps(set.reps)}',
        ),
        suffix: const Icon(FLucideIcons.chevronRight),
      ),
    );
  }
}

/// W / S chip mirroring the detail page's indicator.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.isWarmup});

  final bool isWarmup;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final fill = isWarmup ? theme.colors.muted : theme.colors.primary;
    final textColor = isWarmup
        ? theme.colors.mutedForeground
        : theme.colors.primary;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isWarmup ? fill : fill.withValues(alpha: 0.15),
      ),
      child: Text(
        isWarmup ? 'W' : 'S',
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Marker returned by the gym sheet when the user explicitly clears the gym
/// (a bare `null` pop means the sheet was dismissed without a choice).
class _NoGym {
  const _NoGym();
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
    builder: (dialogContext, _, _) => FDialog(
      builder: (context, style) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Start time', style: style.titleTextStyle),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: FDateTimePicker(
                control: .managed(
                  initial: initial,
                  onChange: (value) => picked = value,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
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
            ),
          ],
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
  late bool _warmup;
  String? _weightError;
  String? _repsError;

  @override
  void initState() {
    super.initState();
    // context.read inside SettingsCubit.maybeOf works here, so the display-unit
    // conversion is safe before the first frame.
    _weight = TextEditingController(
      text: _weightText(displayWeightOf(context, widget.initial.weight)),
    );
    _reps = TextEditingController(text: _weightText(widget.initial.reps));
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
    return FDialog(
      builder: (context, style) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit set', style: style.titleTextStyle),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: FTextField(
                    control: FTextFieldControl.managed(controller: _weight),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    inputFormatters: [RepsInputFormatter()],
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
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FButton(
                  variant: .outline,
                  onPress: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FButton(onPress: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final displayed = double.tryParse(_weight.text.trim());
    final reps = double.tryParse(_reps.text.trim().replaceAll(',', '.'));
    final weightError = requiredDouble(_weight.text);
    if (weightError != null || displayed == null || reps == null) {
      setState(() {
        _weightError = weightError;
        _repsError = reps == null ? 'Must be at least 1' : null;
      });
      return;
    }
    if (reps < 1) {
      setState(() => _repsError = 'Must be at least 1');
      return;
    }
    Navigator.of(context).pop(
      WorkoutSet(
        exerciseId: widget.initial.exerciseId,
        // The field holds display units; storage stays canonical kilograms.
        weight: kilogramsFromDisplay(context, displayed),
        reps: reps,
        type: _warmup ? SetType.warmup : SetType.working,
        order: widget.initial.order,
      ),
    );
  }

  String _weightText(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
