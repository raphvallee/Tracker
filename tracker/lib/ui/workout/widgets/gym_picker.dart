import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/gym.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/utils/form_validators.dart';

/// Explicit "clear gym" marker returned by the picker when the user selects
/// "No gym". Use `picked is NoGym` to detect it.
class NoGym {
  const NoGym();
}

/// Resolves which [Gym] a workout should be logged at (Plan.md §2.2).
///
/// - No gyms configured → returns `null` (workout proceeds gym-less).
/// - Exactly one gym → returned directly (no prompt).
/// - Several gyms → the user is asked to pick one via a modal bottom sheet;
///   dismissing leaves the selection `null`. The sheet also offers "Add Gym"
///   to create a new gym and select it right away.
Future<Gym?> promptGym(BuildContext context, List<Gym> gyms) async {
  if (gyms.length <= 1) {
    return gyms.isEmpty ? null : gyms.first;
  }
  return showGymPicker(
    context,
    gyms,
    isDismissible: false,
  ).then((r) => r is Gym ? r : null);
}

Future<Object?> showGymPicker(
  BuildContext context,
  List<Gym> gyms, {
  String title = 'Where are you training?',
  bool includeNoGym = false,
  bool isDismissible = true,
  String noGymLabel = 'No gym',
}) {
  return showModalBottomSheet<Object>(
    context: context,
    isDismissible: isDismissible,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: sheetContext.theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  FButton(
                    variant: .outline,
                    onPress: () async {
                      final added = await promptAddGym(sheetContext, gyms);
                      if (added != null && sheetContext.mounted) {
                        Navigator.of(sheetContext).pop(added);
                      }
                    },
                    child: const Text('Add Gym'),
                  ),
                ],
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
            if (includeNoGym)
              FItem(
                prefix: const Icon(FLucideIcons.ban),
                title: Text(noGymLabel),
                onPress: () => Navigator.of(sheetContext).pop(const NoGym()),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Opens the new-gym dialog, persists the result, and returns the created
/// [Gym] (or null on cancel). Mirrors the settings add-gym flow so a freshly
/// created gym can be selected right away from any gym picker.
Future<Gym?> promptAddGym(BuildContext context, List<Gym> gyms) async {
  final repo = RepositoryScope.maybeOf(context);
  var nextOrder = 0;
  if (gyms.isNotEmpty) {
    nextOrder = gyms.map((g) => g.order).reduce((a, b) => a > b ? a : b) + 1;
  }
  final created = await editGymDialog(
    context,
    title: 'New Gym',
    initial: Gym(name: '', order: nextOrder, isPrimary: gyms.isEmpty),
    getExistingGyms: repo?.gyms.getAll,
  );
  if (created != null && repo != null) {
    await repo.gyms.put(created);
  }
  return created;
}

// ---------------------------------------------------------------------------
// Shared add/edit gym dialog (moved here from gyms_page.dart so any gym
// picker can offer "Add Gym"). editGymDialog returns the [Gym] to persist
// or null on cancel.
// ---------------------------------------------------------------------------

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

/// Formats a gym multiplier for display.
String fmtGym(double v) => _fmtGym(v);

class EditGymDialog extends StatefulWidget {
  const EditGymDialog({
    super.key,
    required this.title,
    required this.initial,
    this.getExistingGyms,
  });

  final String title;
  final Gym initial;
  final Future<List<Gym>> Function()? getExistingGyms;

  @override
  State<EditGymDialog> createState() => _EditGymDialogState();
}

class _EditGymDialogState extends State<EditGymDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _multiplier;

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

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      headerGap: 16,
      scrollable: true,
      actions: [
        FButton(
          variant: .outline,
          onPress: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FButton(
          onPress: () async {
            final nameText = _name.text.trim();
            final multiplierError = _gymMultiplierError(
              _multiplier.text,
              isPrimary: widget.initial.isPrimary,
            );
            if (_gymNameError(nameText) != null || multiplierError != null) {
              setState(() {});
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

            final existing =
                await widget.getExistingGyms?.call() ?? const <Gym>[];
            if (existing.any(
              (gym) =>
                  gym.id != widget.initial.id && sameGymName(gym, candidate),
            )) {
              if (context.mounted) {
                showFToast(
                  context: context,
                  title: const Text('A gym with this name already exists'),
                );
              }
              return;
            }
            if (context.mounted) Navigator.of(context).pop(candidate);
          },
          child: const Text('Save'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FTextField(
            control: FTextFieldControl.managed(
              controller: _name,
              onChange: (_) => setState(() {}),
            ),
            label: const Text('Gym name'),
            error: _gymNameError(_name.text) == null
                ? null
                : Text(_gymNameError(_name.text)!),
          ),
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
              onChange: (_) => setState(() {}),
            ),
            enabled: !widget.initial.isPrimary,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            error:
                _gymMultiplierError(
                      _multiplier.text,
                      isPrimary: widget.initial.isPrimary,
                    ) ==
                    null
                ? null
                : Text(
                    _gymMultiplierError(
                      _multiplier.text,
                      isPrimary: widget.initial.isPrimary,
                    )!,
                  ),
          ),
        ],
      ),
    );
  }
}

Future<Gym?> editGymDialog(
  BuildContext context, {
  required String title,
  required Gym initial,
  Future<List<Gym>> Function()? getExistingGyms,
}) {
  return showFDialog<Gym>(
    context: context,
    builder: (context, _, _) => EditGymDialog(
      title: title,
      initial: initial,
      getExistingGyms: getExistingGyms,
    ),
  );
}
