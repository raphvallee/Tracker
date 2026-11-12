import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/split_diff.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';

/// Every unsaved change of [split], grouped by day with old and new values,
/// and the buttons that save or discard them all.
Future<void> showReviewChangesSheet(
  BuildContext context, {
  required WorkoutSplit split,
  required Map<int, String> names,
}) {
  return showFSheet<void>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.9,
    builder: (sheetContext) => BlocProvider.value(
      value: context.read<SplitDraftsCubit>(),
      child: _ReviewChanges(split: split, names: names),
    ),
  );
}

/// Why [draft] cannot be saved yet, or null when it can.
String? draftProblem(SplitDraft draft) {
  if (draft.title.trim().isEmpty) return 'Give the split a name to save it.';
  if (draft.days.any((day) => day.title.trim().isEmpty)) {
    return 'Name every day to save the split.';
  }
  return null;
}

class _ReviewChanges extends StatefulWidget {
  const _ReviewChanges({required this.split, required this.names});

  final WorkoutSplit split;
  final Map<int, String> names;

  @override
  State<_ReviewChanges> createState() => _ReviewChangesState();
}

class _ReviewChangesState extends State<_ReviewChanges> {
  bool _saving = false;

  String _nameOf(int id) => widget.names[id] ?? 'Exercise $id';

  Future<void> _save(SplitDraftsCubit drafts) async {
    setState(() => _saving = true);
    try {
      await drafts.save(widget.split.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppLog.error('split-save', error, stackTrace);
      if (!mounted) return;
      setState(() => _saving = false);
      showFToast(
        context: context,
        title: const Text('Could not save the changes. They are still here.'),
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _discard(SplitDraftsCubit drafts, int count) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard ${plural('change', count)}?',
      message:
          '${widget.split.title} goes back to how it was last saved. This '
          'cannot be undone.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    drafts.discard(widget.split.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return BlocBuilder<SplitDraftsCubit, SplitDraftsState>(
      builder: (context, state) {
        final drafts = context.read<SplitDraftsCubit>();
        final entry = state.entries[widget.split.id];
        if (entry == null) {
          return SheetSurface(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No unsaved changes.',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          );
        }
        final diff = diffSplit(entry.base, entry.draft, nameOf: _nameOf);
        final problem = draftProblem(entry.draft);
        final groups = <String?, List<SplitChange>>{};
        for (final change in diff.changes) {
          (groups[change.group] ??= []).add(change);
        }
        return SheetSurface(
          scrollable: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Review changes',
                style: theme.typography.body.lg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${entry.draft.title.isEmpty ? widget.split.title : entry.draft.title}, '
                '${plural('change', diff.count)}',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              for (final MapEntry(key: group, value: changes)
                  in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Text(
                    group ?? 'Split',
                    style: theme.typography.body.xs.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
                ItemCard(
                  children: <FItem>[
                    for (final change in changes) _changeItem(context, change),
                  ],
                ),
              ],
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    problem,
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FButton(
                onPress: _saving || problem != null
                    ? null
                    : () => _save(drafts),
                child: Text('Save ${plural('change', diff.count)}'),
              ),
              const SizedBox(height: 8),
              FButton(
                variant: .outline,
                onPress: _saving ? null : () => _discard(drafts, diff.count),
                child: Text(
                  'Discard changes',
                  style: TextStyle(color: theme.colors.destructive),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One change: what changed, old struck through and new in bold.
FItem _changeItem(BuildContext context, SplitChange change) {
  final theme = context.theme;
  final accents = TrackerAccents.of(context);
  final colors = theme.colors;
  final (icon, background, foreground) = switch (change.kind) {
    SplitChangeKind.added => (
      FLucideIcons.plus,
      colors.muted,
      colors.foreground,
    ),
    SplitChangeKind.removed => (
      FLucideIcons.minus,
      colors.destructive.withValues(alpha: 0.12),
      colors.destructive,
    ),
    SplitChangeKind.changed => (
      FLucideIcons.pencil,
      accents.draftSoft,
      accents.draftInk,
    ),
    SplitChangeKind.moved => (
      FLucideIcons.arrowUpDown,
      colors.muted,
      colors.foreground,
    ),
  };
  final small = theme.typography.body.xs.copyWith(
    color: colors.mutedForeground,
  );
  return FItem(
    prefix: Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: Icon(icon, size: 14, color: foreground),
    ),
    title: _wrapping(change.title),
    subtitle: change.before != null && change.after != null
        ? Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: <Widget>[
              _wrapping(
                change.before!,
                style: small.copyWith(decoration: TextDecoration.lineThrough),
              ),
              Icon(
                FLucideIcons.arrowRight,
                size: 14,
                color: colors.mutedForeground,
              ),
              _wrapping(
                change.after!,
                style: theme.typography.body.xs.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (change.detail != null)
                _wrapping(change.detail!, style: small),
            ],
          )
        : change.detail == null
        ? null
        : _wrapping(change.detail!),
  );
}

/// FItem cuts its text at one line; a change shows in full.
Widget _wrapping(String text, {TextStyle? style}) =>
    Text(text, softWrap: true, overflow: TextOverflow.visible, style: style);
