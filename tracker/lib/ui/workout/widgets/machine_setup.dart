import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/ui/core/ui/edit_sheet.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';

/// How a machine is set up at the workout's gym ("Seat 4, back pad 2"),
/// under the exercise's name: a tap edits it. Without a note, a quiet line
/// offers to add one.
class MachineSetupLine extends StatelessWidget {
  const MachineSetupLine({
    super.key,
    required this.gymId,
    required this.gymName,
    required this.exerciseId,
    required this.exerciseName,
    this.note,
  });

  final int gymId;
  final String gymName;
  final int exerciseId;
  final String exerciseName;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final note = this.note;
    final muted = theme.colors.mutedForeground;
    return Semantics(
      button: true,
      label: note == null
          ? 'Add how $exerciseName is set up at $gymName'
          : 'Setup at $gymName: $note. Edit',
      excludeSemantics: true,
      child: FTappable(
        onPress: () => showMachineSetupSheet(
          context,
          gymId: gymId,
          gymName: gymName,
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          note: note,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  FLucideIcons.slidersHorizontal,
                  size: 15,
                  color: muted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note ?? 'Add how it\'s set up at $gymName',
                  style: theme.typography.body.xs.copyWith(
                    color: note == null ? muted : theme.colors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                note == null ? FLucideIcons.plus : FLucideIcons.pencil,
                size: 14,
                color: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edits how [exerciseName]'s machine is set up at [gymName]; an empty note
/// removes it.
Future<void> showMachineSetupSheet(
  BuildContext context, {
  required int gymId,
  required String gymName,
  required int exerciseId,
  required String exerciseName,
  String? note,
}) {
  return showEditSheet<void>(
    context,
    builder: (_) => MachineSetupSheet(
      gymId: gymId,
      gymName: gymName,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      note: note,
    ),
  );
}

class MachineSetupSheet extends StatefulWidget {
  const MachineSetupSheet({
    super.key,
    required this.gymId,
    required this.gymName,
    required this.exerciseId,
    required this.exerciseName,
    this.note,
  });

  final int gymId;
  final String gymName;
  final int exerciseId;
  final String exerciseName;
  final String? note;

  @override
  State<MachineSetupSheet> createState() => _MachineSetupSheetState();
}

class _MachineSetupSheetState extends State<MachineSetupSheet> {
  late final TextEditingController _note = TextEditingController(
    text: widget.note ?? '',
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await RepositoryScope.maybeOf(context)?.gyms
        .setMachineSetup(widget.gymId, widget.exerciseId, _note.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: '${widget.exerciseName} at ${widget.gymName}',
      description: 'Seat, pads and handles: shown here at this gym only.',
      onAction: _save,
      child: FTextField(
        control: FTextFieldControl.managed(controller: _note),
        autofocus: true,
        label: const Text('Setup'),
        hint: 'Seat 4, back pad 2',
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}
