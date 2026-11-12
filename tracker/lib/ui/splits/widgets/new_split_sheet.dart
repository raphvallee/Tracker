import 'dart:math' as math;

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/data/repositories/tracker_repository.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/models/workout_split_templates.dart';
import 'package:tracker/ui/core/ui/edit_sheet.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/utils/form_validators.dart';

const _blank = Object();

/// Asks how to start a split (blank, or from a template) and creates it
/// straight away: it shows up in the Splits tab ready for its days.
Future<void> showNewSplitSheet(BuildContext context) async {
  final repo = RepositoryScope.maybeOf(context);
  final choice = await showFSheet<Object>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.85,
    builder: (sheetContext) {
      final theme = sheetContext.theme;
      return SheetSurface(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'New split',
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Start blank or from a template. You can change everything '
              'after.',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            ItemCard(
              divider: .full,
              children: <FItem>[
                FItem(
                  prefix: const Icon(FLucideIcons.plus),
                  title: const Text('Blank split'),
                  subtitle: const Text('Name it, then add your days'),
                  onPress: () => Navigator.of(sheetContext).pop(_blank),
                ),
                for (final template in workoutSplitTemplates)
                  FItem(
                    prefix: const Icon(FLucideIcons.layoutList),
                    title: Text(template.title),
                    subtitle: Text(template.days.join(', ')),
                    onPress: () => Navigator.of(sheetContext).pop(template),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
  if (choice == null || repo == null || !context.mounted) return;
  final String title;
  final List<WorkoutSplitDay> days;
  if (choice is WorkoutSplitTemplate) {
    title = choice.title;
    days = choice.createDays();
  } else {
    final named = await editSplitDetails(
      context,
      title: 'New split',
      confirmLabel: 'Create',
    );
    if (named == null || !context.mounted) return;
    title = named.title;
    days = [];
  }
  try {
    await createSplit(repo, title: title, days: days);
  } catch (error, stackTrace) {
    AppLog.error('new-split', error, stackTrace);
    if (context.mounted) {
      showFToast(
        context: context,
        title: const Text('Could not create the split.'),
        duration: const Duration(seconds: 4),
      );
    }
  }
}

/// Saves a new split after the existing ones.
Future<int> createSplit(
  TrackerRepository repo, {
  required String title,
  String description = '',
  required List<WorkoutSplitDay> days,
}) async {
  final all = await repo.splits.getAll();
  final order = all.isEmpty ? 0 : all.map((s) => s.order).reduce(math.max) + 1;
  return repo.splits.put(
    WorkoutSplit(
      title: title,
      description: description,
      splitDays: days,
      order: order,
    ),
  );
}

/// A sheet for a split's name and description; null when cancelled.
Future<({String title, String description})?> editSplitDetails(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String name = '',
  String description = '',
}) {
  return showEditSheet<({String title, String description})>(
    context,
    builder: (_) => _SplitDetailsSheet(
      title: title,
      confirmLabel: confirmLabel,
      name: name,
      description: description,
    ),
  );
}

class _SplitDetailsSheet extends StatefulWidget {
  const _SplitDetailsSheet({
    required this.title,
    required this.confirmLabel,
    required this.name,
    required this.description,
  });

  final String title;
  final String confirmLabel;
  final String name;
  final String description;

  @override
  State<_SplitDetailsSheet> createState() => _SplitDetailsSheetState();
}

class _SplitDetailsSheetState extends State<_SplitDetailsSheet> {
  late final _name = TextEditingController(text: widget.name);
  late final _description = TextEditingController(text: widget.description);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _confirm() {
    final error = requiredText(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context)
        .pop((title: _name.text.trim(), description: _description.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return EditSheet(
      title: widget.title,
      actionLabel: widget.confirmLabel,
      onAction: _confirm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FTextField(
            control: FTextFieldControl.managed(
              controller: _name,
              onChange: (_) => setState(() => _error = null),
            ),
            label: const Text('Split name'),
            autofocus: true,
            error: _error == null ? null : Text(_error!),
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: _description),
            label: const Text('Description (optional)'),
            minLines: 1,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
