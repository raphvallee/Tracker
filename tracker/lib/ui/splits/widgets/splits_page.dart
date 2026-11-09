import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/split_diff.dart';
import 'package:tracker/domain/services/split_rotation.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/sliding_column.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';
import 'package:tracker/ui/splits/view_models/split_drafts_cubit.dart';
import 'package:tracker/ui/workout/widgets/start_workout.dart';

import 'draft_marks.dart';
import 'new_split_sheet.dart';
import 'review_changes_sheet.dart';
import 'split_day_editor_page.dart';

/// The Splits tab: plans only, edited in place. Every edit lands in a draft
/// that survives the app closing; nothing here starts a workout.
class SplitsPage extends StatefulWidget {
  const SplitsPage({super.key});

  @override
  State<SplitsPage> createState() => _SplitsPageState();
}

class _SplitsPageState extends State<SplitsPage> {
  final List<StreamSubscription<Object?>> _subscriptions = [];
  List<WorkoutSplit>? _splits;

  /// Null until first loaded: they order the list, which would otherwise
  /// slide into place on every open.
  List<SplitDayVisit>? _visits;
  Map<int, String> _names = const {};
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) {
      _splits = const [];
      _visits = const [];
      return;
    }
    _subscriptions
      ..add(
        repo.splits.watchAll().listen(
          (splits) => setState(
            () =>
                _splits = [...splits]
                  ..sort((a, b) => a.order.compareTo(b.order)),
          ),
        ),
      )
      ..add(
        repo.exercises.watchAll().listen(
          (exercises) => setState(
            () => _names = {
              for (final exercise in exercises) exercise.id: exercise.title,
            },
          ),
        ),
      )
      ..add(repo.sessions.watchChanges().listen((_) => _loadVisits()));
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    final visits = await RepositoryScope.maybeOf(context)?.sessions
        .getSplitVisits();
    if (!mounted || visits == null) return;
    setState(() => _visits = visits);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final splits = _splits;
    final visits = _visits;
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(
          context,
          title: 'Splits',
          trailing: AppIconButton(
            icon: FLucideIcons.plus,
            tooltip: 'New split',
            onPress: () => showNewSplitSheet(context),
          ),
        ),
        SliverToBoxAdapter(
          child: MaxWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: splits == null || visits == null
                  ? const SizedBox.shrink()
                  : splits.isEmpty
                  ? const _NoSplits()
                  : _withSettings(
                      (settings) =>
                          BlocBuilder<SplitDraftsCubit, SplitDraftsState>(
                            builder: (context, drafts) {
                              final ordered = splitsByLastUsed(
                                splits,
                                visits,
                                currentSplitId: settings?.currentSplitId,
                                usedAt: settings?.splitsUsedAt ?? const {},
                              );
                              final lastTrained = lastTrainedBySplit(visits);
                              // The current split leads; switching slides the
                              // new one up and the old one right below it.
                              return SlidingColumn(
                                children: <Widget>[
                                  for (final split in ordered)
                                    _SplitSection(
                                      key: ValueKey('split-${split.id}'),
                                      split: split,
                                      currentId: ordered.first.id,
                                      lastTrained: lastTrained[split.id],
                                      names: _names,
                                    ),
                                ],
                              );
                            },
                          ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _withSettings(Widget Function(SettingsState? settings) builder) {
    if (SettingsCubit.maybeOf(context) == null) return builder(null);
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) => builder(settings),
    );
  }
}

class _NoSplits extends StatelessWidget {
  const _NoSplits();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'No splits yet',
            style: theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A split is your training plan, broken into days like Push, '
            'Pull and Legs. Start one from a template or from scratch.',
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          FButton(
            onPress: () => showNewSplitSheet(context),
            prefix: const Icon(FLucideIcons.plus),
            child: const Text('New split'),
          ),
        ],
      ),
    );
  }
}

enum _SplitAction { rename, makeCurrent, duplicate, delete }

class _SplitSection extends StatelessWidget {
  const _SplitSection({
    super.key,
    required this.split,
    required this.currentId,
    required this.lastTrained,
    required this.names,
  });

  final WorkoutSplit split;

  /// The current split's id.
  final int currentId;
  final DateTime? lastTrained;
  final Map<int, String> names;

  bool get isCurrent => split.id == currentId;

  String _nameOf(int id) => names[id] ?? 'Exercise $id';

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final drafts = context.read<SplitDraftsCubit>();
    final fallback = defaultSetTargetOf(context);
    final entry = drafts.state.entries[split.id];
    final draft = entry?.draft ?? drafts.draftOf(split, fallback: fallback);
    final base = entry?.base ?? draft;
    final diff = diffSplit(base, draft, nameOf: _nameOf);
    final last = lastTrained;
    // Opaque: sections pass over each other while the order slides.
    return ColoredBox(
      color: theme.colors.background,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    draft.title.isEmpty ? 'Untitled split' : draft.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _menu(context, draft),
              ],
            ),
            Row(
              children: <Widget>[
                if (isCurrent) ...[
                  FBadge(child: const Text('Current')),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    '${plural('day', draft.days.length)}, '
                    '${last == null ? 'not trained yet' : 'trained ${agoLabel(last)}'}',
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!diff.isEmpty) ...[
              DraftStrip(
                count: diff.count,
                onReview: () =>
                    showReviewChangesSheet(context, split: split, names: names),
              ),
              const SizedBox(height: 8),
            ],
            _DayList(
              split: split,
              draft: draft,
              base: base,
              diff: diff,
              fallback: fallback,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, SplitDraft draft) {
    final destructive = context.theme.colors.destructive;
    return FPopoverMenu.tiles(
      menuAnchor: .topRight,
      childAnchor: .bottomRight,
      menuBuilder: (menuContext, controller, _) => [
        .group(
          children: [
            .tile(
              prefix: const Icon(FLucideIcons.pencil),
              title: const Text('Rename'),
              onPress: () {
                controller.hide();
                _onAction(context, _SplitAction.rename, draft);
              },
            ),
            if (!isCurrent)
              .tile(
                prefix: const Icon(FLucideIcons.pin),
                title: const Text('Make current'),
                onPress: () {
                  controller.hide();
                  _onAction(context, _SplitAction.makeCurrent, draft);
                },
              ),
            .tile(
              prefix: const Icon(FLucideIcons.copy),
              title: const Text('Duplicate'),
              onPress: () {
                controller.hide();
                _onAction(context, _SplitAction.duplicate, draft);
              },
            ),
            .tile(
              prefix: Icon(FLucideIcons.trash2, color: destructive),
              title: Text('Delete', style: TextStyle(color: destructive)),
              onPress: () {
                controller.hide();
                _onAction(context, _SplitAction.delete, draft);
              },
            ),
          ],
        ),
      ],
      builder: (_, controller, _) => AppIconButton(
        icon: FLucideIcons.ellipsis,
        tooltip: 'Split options',
        onPress: controller.toggle,
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    _SplitAction action,
    SplitDraft draft,
  ) async {
    final drafts = context.read<SplitDraftsCubit>();
    final settings = SettingsCubit.maybeOf(context);
    final repo = RepositoryScope.maybeOf(context);
    final fallback = defaultSetTargetOf(context);
    switch (action) {
      case _SplitAction.rename:
        final details = await editSplitDetails(
          context,
          title: 'Rename split',
          confirmLabel: 'Done',
          name: draft.title,
          description: draft.description,
        );
        if (details == null) return;
        drafts.edit(
          split,
          (current) => current.copyWith(
            title: details.title,
            description: details.description,
          ),
          fallback: fallback,
        );
      case _SplitAction.makeCurrent:
        settings?.setCurrentSplit(split.id, previous: currentId);
        // Follow it to the top of the list.
        final position = Scrollable.maybeOf(context)?.position;
        if (position != null && position.pixels > position.minScrollExtent) {
          unawaited(
            position.animateTo(
              position.minScrollExtent,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeInOutCubic,
            ),
          );
        }
      case _SplitAction.duplicate:
        if (repo == null) return;
        try {
          final copy = WorkoutSplit();
          draft.writeTo(copy);
          await createSplit(
            repo,
            title: '${draft.title} copy',
            description: copy.description,
            days: copy.splitDays,
          );
        } catch (error, stackTrace) {
          AppLog.error('split-duplicate', error, stackTrace);
        }
      case _SplitAction.delete:
        final confirmed = await showConfirmDialog(
          context,
          title: 'Delete ${split.title}?',
          message:
              'This removes the split and its days. Workouts you logged '
              'stay in History.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!confirmed || repo == null) return;
        await repo.splits.delete(split.id);
        drafts.discard(split.id);
        settings?.forgetSplit(split.id);
    }
  }
}

class _DayList extends StatelessWidget {
  const _DayList({
    required this.split,
    required this.draft,
    required this.base,
    required this.diff,
    required this.fallback,
  });

  final WorkoutSplit split;
  final SplitDraft draft;
  final SplitDraft base;
  final SplitDiff diff;
  final SetTarget fallback;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final drafts = context.read<SplitDraftsCubit>();
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final divider = BorderSide(color: theme.colors.border);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      // Over the rows, which paint their own background.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) => drafts.edit(
              split,
              (current) => current.reorderDay(oldIndex, newIndex),
              fallback: fallback,
            ),
            children: <Widget>[
              for (final (i, day) in draft.days.indexed)
                Material(
                  key: ValueKey(
                    'split-day-${split.id}-${day.origin ?? 'new'}-$i',
                  ),
                  color: theme.colors.background,
                  child: FTappable(
                    onPress: () => pushTo<void>(
                      context,
                      SplitDayEditorPage(splitId: split.id, dayIndex: i),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 58),
                      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: divider),
                      ),
                      child: Row(
                        children: <Widget>[
                          ReorderableDragStartListener(
                            index: i,
                            child: SizedBox(
                              width: 36,
                              height: 40,
                              child: Icon(
                                FLucideIcons.gripVertical,
                                size: 18,
                                color: theme.colors.mutedForeground,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  children: <Widget>[
                                    Text(
                                      day.title.isEmpty
                                          ? 'Untitled day'
                                          : day.title,
                                      style: theme.typography.body.sm.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (diff.newDays.contains(i))
                                      const DraftTag('New')
                                    else if (diff.changedDays.contains(i))
                                      const DraftTag('Edited'),
                                  ],
                                ),
                                Text(
                                  '${plural('exercise', day.exercises.length)}, '
                                  '${plural('set', day.setCount)}',
                                  style: muted,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            FLucideIcons.chevronRight,
                            size: 18,
                            color: theme.colors.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final origin in diff.removedDays)
            RemovedRow(
              label: base.days[origin].title,
              onRestore: () => drafts.edit(
                split,
                (current) => current.restoreDay(base, origin),
                fallback: fallback,
              ),
            ),
          FTappable(
            onPress: () {
              final index = draft.days.length;
              drafts.edit(
                split,
                (current) => current.addDay('Day ${index + 1}'),
                fallback: fallback,
              );
              pushTo<void>(
                context,
                SplitDayEditorPage(splitId: split.id, dayIndex: index),
              );
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: <Widget>[
                  Icon(
                    FLucideIcons.plus,
                    size: 18,
                    color: theme.colors.mutedForeground,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Add day',
                    style: theme.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
