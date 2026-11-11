import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/edit_sheet.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/utils/form_validators.dart';

class NoGym {
  const NoGym();
}

/// The gym sheet: every gym, a check on the one in use ([currentId]) and a
/// row to add one. Resolves to the [Gym] picked, a [NoGym] for the
/// [includeNoGym] row, or null when it closes without a choice.
///
/// [oneWorkoutOnly] adds the note that another gym counts for one workout
/// and the next starts at home again: true where a workout's gym is picked.
/// [live] checks the gym in use in the live accent; false checks it in ink,
/// for a workout that is over.
Future<Object?> showGymPicker(
  BuildContext context,
  List<Gym> gyms, {
  String title = 'Training at',
  int? currentId,
  bool includeNoGym = false,
  String noGymLabel = 'No gym',
  bool oneWorkoutOnly = false,
  bool live = true,
}) {
  return showFSheet<Object>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.85,
    builder: (sheetContext) {
      final theme = sheetContext.theme;
      final accents = TrackerAccents.of(sheetContext);
      Gym? home;
      for (final gym in gyms) {
        if (gym.isPrimary) home = gym;
      }
      return SheetSurface(
        scrollable: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ItemCard(
              divider: .full,
              children: <FItem>[
                for (final gym in gyms)
                  FItem(
                    prefix: Icon(
                      gym.isPrimary
                          ? FLucideIcons.house
                          : FLucideIcons.dumbbell,
                    ),
                    title: Text(gym.name, overflow: TextOverflow.ellipsis),
                    subtitle: gym.isPrimary ? const Text('Home gym') : null,
                    suffix: gym.id == currentId
                        ? Icon(
                            FLucideIcons.check,
                            color: live ? accents.live : null,
                          )
                        : null,
                    selected: gym.id == currentId,
                    onPress: () => Navigator.of(sheetContext).pop(gym),
                  ),
                if (includeNoGym)
                  FItem(
                    prefix: const Icon(FLucideIcons.ban),
                    title: Text(noGymLabel),
                    onPress: () =>
                        Navigator.of(sheetContext).pop(const NoGym()),
                  ),
                FItem(
                  prefix: const Icon(FLucideIcons.plus),
                  title: const Text('Add a gym'),
                  onPress: () async {
                    final added = await promptAddGym(sheetContext, gyms);
                    if (added != null && sheetContext.mounted) {
                      Navigator.of(sheetContext).pop(added);
                    }
                  },
                ),
              ],
            ),
            if (oneWorkoutOnly && home != null && gyms.length > 1) ...[
              const SizedBox(height: 12),
              Text(
                'Another gym counts for this workout only. The next one '
                'starts at ${home.name}.',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// Adds a gym from the gym sheet, asking for its name only: the weight
/// multiplier is estimated when a workout there ends, and Settings edits
/// the rest.
Future<Gym?> promptAddGym(BuildContext context, List<Gym> gyms) async {
  final repo = RepositoryScope.maybeOf(context);
  var nextOrder = 0;
  if (gyms.isNotEmpty) {
    nextOrder = gyms.map((g) => g.order).reduce((a, b) => a > b ? a : b) + 1;
  }
  final created = await editGymSheet(
    context,
    title: 'New gym',
    initial: Gym(name: '', order: nextOrder, isPrimary: gyms.isEmpty),
    getExistingGyms: repo?.gyms.getAll,
    nameOnly: true,
  );
  if (created != null && repo != null) {
    await repo.gyms.put(created);
  }
  return created;
}

String? _gymNameError(String value) => requiredText(value);

String? _gymMultiplierError(String value, {required bool isPrimary}) =>
    isPrimary ? null : requiredDouble(value);

String _normalizeGymField(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

bool sameGymName(Gym first, Gym second) =>
    _normalizeGymField(first.name) == _normalizeGymField(second.name) &&
    _normalizeGymField(first.description ?? '') ==
        _normalizeGymField(second.description ?? '');

String _fmtGym(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toStringAsFixed(2);

String fmtGym(double v) => _fmtGym(v);

class EditGymSheet extends StatefulWidget {
  const EditGymSheet({
    super.key,
    required this.title,
    required this.initial,
    this.getExistingGyms,
    this.nameOnly = false,
  });

  final String title;
  final Gym initial;
  final Future<List<Gym>> Function()? getExistingGyms;

  /// Asks for the name alone, leaving the description and multiplier as
  /// [initial] has them.
  final bool nameOnly;

  @override
  State<EditGymSheet> createState() => _EditGymSheetState();
}

class _EditGymSheetState extends State<EditGymSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _multiplier;

  String? _nameError;
  String? _multiplierError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _description = TextEditingController(
      text: widget.initial.description ?? '',
    );
    _multiplier = TextEditingController(
      text: widget.initial.isPrimary
          ? '1.0'
          : _fmtGym(widget.initial.multiplier),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _multiplier.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameText = _name.text.trim();
    final multiplierError = widget.nameOnly
        ? null
        : _gymMultiplierError(
            _multiplier.text,
            isPrimary: widget.initial.isPrimary,
          );
    final nameError = _gymNameError(nameText);
    if (nameError != null || multiplierError != null) {
      setState(() {
        _nameError = nameError;
        _multiplierError = multiplierError;
      });
      return;
    }
    final candidate = Gym(
      name: nameText,
      description: _description.text.trim(),
      isPrimary: widget.initial.isPrimary,
      order: widget.initial.order,
      multiplier: widget.initial.isPrimary
          ? 1.0
          : double.tryParse(_multiplier.text.trim()) ?? 1.0,
    )..id = widget.initial.id;

    final existing = await widget.getExistingGyms?.call() ?? const <Gym>[];
    if (existing.any(
      (gym) => gym.id != widget.initial.id && sameGymName(gym, candidate),
    )) {
      if (mounted) {
        showFToast(
          context: context,
          title: const Text('A gym with this name already exists'),
        );
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(candidate);
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: widget.title,
      onAction: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FTextField(
            control: FTextFieldControl.managed(
              controller: _name,
              onChange: (_) => setState(() => _nameError = null),
            ),
            label: const Text('Gym name'),
            error: _nameError == null ? null : Text(_nameError!),
          ),
          if (!widget.nameOnly) ...[
            const SizedBox(height: 12),
            FTextField(
              control: FTextFieldControl.managed(controller: _description),
              label: const Text('Description (optional)'),
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 12),
            FTextField(
              control: FTextFieldControl.managed(
                controller: _multiplier,
                onChange: (_) => setState(() => _multiplierError = null),
              ),
              enabled: !widget.initial.isPrimary,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              label: Text(
                widget.initial.isPrimary
                    ? 'Multiplier (primary = ×1.0)'
                    : 'Weight multiplier',
              ),
              description: Text(
                widget.initial.isPrimary
                    ? 'The primary gym is the fixed baseline.'
                    : 'Scales logged weights to the primary gym.',
              ),
              error: _multiplierError == null ? null : Text(_multiplierError!),
            ),
          ],
        ],
      ),
    );
  }
}

Future<Gym?> editGymSheet(
  BuildContext context, {
  required String title,
  required Gym initial,
  Future<List<Gym>> Function()? getExistingGyms,
  bool nameOnly = false,
}) {
  return showEditSheet<Gym>(
    context,
    builder: (_) => EditGymSheet(
      title: title,
      initial: initial,
      getExistingGyms: getExistingGyms,
      nameOnly: nameOnly,
    ),
  );
}
