import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/split_draft.dart';
import 'package:tracker/domain/models/workout_split.dart';
import 'package:tracker/domain/services/split_diff.dart';
import 'package:tracker/domain/services/split_rotation.dart';
import 'package:tracker/ui/core/ui/animated_reveal.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/custom_route.dart';
import 'package:tracker/ui/core/ui/icon_button.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/peek.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/sliding_column.dart';
import 'package:tracker/ui/core/ui/swipe_to_delete.dart';
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

class _SplitsPageState extends State<SplitsPage>
    with SingleTickerProviderStateMixin {
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Space past the last split, made while a menu needs it to scroll clear
  /// of the bottom bar.
  late final AnimationController _room = AnimationController.unbounded(
    vsync: this,
  );

  /// Each split menu's last row, by split id: measured when the menu opens.
  final Map<int, GlobalKey> _menuEnds = {};

  /// The room's box: its top is where the splits end.
  final GlobalKey _roomKey = GlobalKey(debugLabel: 'splits room');
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
    _room.dispose();
    super.dispose();
  }

  /// A split's menu opens below its button and the page knows nothing of it:
  /// once it has grown in (the menu reports shown after its entrance), scroll
  /// the page up until its last row clears the bottom of the list, making
  /// room past the last split when that is short.
  void _revealMenu(BuildContext section, GlobalKey menuEnd) {
    // Measured once this frame lays the menu out at full size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !section.mounted) return;
      final scrollable = Scrollable.maybeOf(section);
      final viewport = scrollable?.context.findRenderObject();
      final row = _tileBox(menuEnd.currentContext);
      if (scrollable == null || viewport is! RenderBox || row == null) return;
      final menuBottom =
          row.localToGlobal(Offset(0, row.size.height)).dy + _menuMargin;
      final visibleBottom = viewport
          .localToGlobal(Offset(0, viewport.size.height))
          .dy;
      final overflow = menuBottom - visibleBottom;
      if (overflow <= 0) return;
      final position = scrollable.position;
      final target = position.pixels + overflow;
      void scroll() {
        if (!position.hasPixels) return;
        position.animateTo(
          target.clamp(position.minScrollExtent, position.maxScrollExtent),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }

      if (target <= position.maxScrollExtent) return scroll();
      // Enough room for the end of the splits to scroll [overflow] up and
      // still reach the bottom of the list. Measured from where they end:
      // splits that fill less than a screen leave a gap no scroll can use.
      final room = _roomKey.currentContext?.findRenderObject();
      if (room is! RenderBox || !room.hasSize) return;
      final splitsEnd = room.localToGlobal(Offset.zero).dy;
      _room.value = math.max(_room.value, visibleBottom + overflow - splitsEnd);
      // The room lays out with the next frame: scroll after it.
      WidgetsBinding.instance.addPostFrameCallback((_) => scroll());
    });
  }

  /// The menu closed: let the room it made shrink away.
  void _releaseRoom() {
    if (_room.value <= 0) return;
    _room.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// Below the menu's last row: its group's padding and some air.
  static const _menuMargin = 16.0;

  static RenderBox? _tileBox(BuildContext? context) {
    RenderBox? box;
    context?.visitAncestorElements((element) {
      if (element.widget is! FTile) return true;
      final object = element.findRenderObject();
      if (object is RenderBox && object.hasSize) box = object;
      return false;
    });
    return box;
  }

  @override
  Widget build(BuildContext context) {
    final splits = _splits;
    final visits = _visits;
    // Room to scroll a name being typed above the keyboard.
    final keyboard = keyboardInsetOf(context) > 0
        ? keyboardClearanceOf(context)
        : 0.0;
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
              padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + keyboard),
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
                                      lastDone: lastDoneByDay(split, visits),
                                      names: _names,
                                      menuEnd: _menuEnds.putIfAbsent(
                                        split.id,
                                        GlobalKey.new,
                                      ),
                                      onMenuShown: _revealMenu,
                                      onMenuHidden: _releaseRoom,
                                    ),
                                ],
                              );
                            },
                          ),
                    ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AnimatedBuilder(
            animation: _room,
            builder: (context, _) =>
                SizedBox(key: _roomKey, height: _room.value),
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

enum _SplitAction { makeCurrent, duplicate, delete }

class _SplitSection extends StatelessWidget {
  const _SplitSection({
    super.key,
    required this.split,
    required this.currentId,
    required this.lastTrained,
    required this.lastDone,
    required this.names,
    required this.menuEnd,
    required this.onMenuShown,
    required this.onMenuHidden,
  });

  final WorkoutSplit split;

  /// The current split's id.
  final int currentId;
  final DateTime? lastTrained;

  /// When each saved day (by position) was last trained.
  final Map<int, DateTime> lastDone;
  final Map<int, String> names;

  /// Keys the menu's last row, so the page can scroll it into view.
  final GlobalKey menuEnd;
  final void Function(BuildContext section, GlobalKey menuEnd) onMenuShown;
  final VoidCallback onMenuHidden;

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
            _SplitHeader(
              title: draft.title,
              onRename: (title) => drafts.edit(
                split,
                (current) => current.copyWith(title: title),
                fallback: fallback,
              ),
              menu: (rename) => _menu(context, draft, rename),
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
            AnimatedReveal(
              child: diff.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DraftStrip(
                        count: diff.count,
                        onReview: () => showReviewChangesSheet(
                          context,
                          split: split,
                          names: names,
                        ),
                      ),
                    ),
            ),
            _DayList(
              split: split,
              draft: draft,
              base: base,
              diff: diff,
              fallback: fallback,
              lastDone: lastDone,
              names: names,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, SplitDraft draft, VoidCallback rename) {
    final destructive = context.theme.colors.destructive;
    return FPopoverMenu.tiles(
      control: .managed(
        onChange: (shown) =>
            shown ? onMenuShown(context, menuEnd) : onMenuHidden(),
      ),
      menuAnchor: .topRight,
      childAnchor: .bottomRight,
      menuBuilder: (menuContext, controller, _) => [
        .group(
          children: [
            .tile(
              prefix: const Icon(FLucideIcons.pencil),
              title: const Text('Rename'),
              // Once the menu is gone, so the name keeps the focus.
              onPress: () async {
                await controller.hide();
                rename();
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
              title: Text(
                'Delete',
                key: menuEnd,
                style: TextStyle(color: destructive),
              ),
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
    switch (action) {
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
    required this.lastDone,
    required this.names,
  });

  final WorkoutSplit split;
  final SplitDraft draft;
  final SplitDraft base;
  final SplitDiff diff;
  final SetTarget fallback;
  final Map<int, DateTime> lastDone;
  final Map<int, String> names;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final drafts = context.read<SplitDraftsCubit>();
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
                _DayRow(
                  key: ValueKey(
                    'split-day-${split.id}-${day.origin ?? 'new'}-$i',
                  ),
                  split: split,
                  index: i,
                  day: day,
                  tag: diff.newDays.contains(i)
                      ? 'New'
                      : diff.changedDays.contains(i)
                      ? 'Edited'
                      : null,
                  lastDone: day.origin == null ? null : lastDone[day.origin],
                  names: names,
                  onDelete: () => drafts.edit(
                    split,
                    (current) => current.removeDay(i),
                    fallback: fallback,
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

/// The split's name with its menu. Rename turns the name itself into the
/// field: a field grows out around it (the name never moves), the keyboard
/// comes up with the name selected, and the menu gives way to Done.
class _SplitHeader extends StatefulWidget {
  const _SplitHeader({
    required this.title,
    required this.onRename,
    required this.menu,
  });

  final String title;
  final ValueChanged<String> onRename;

  /// The split's menu; its Rename calls the callback it is given.
  final Widget Function(VoidCallback rename) menu;

  @override
  State<_SplitHeader> createState() => _SplitHeaderState();
}

class _SplitHeaderState extends State<_SplitHeader>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode(debugLabel: 'split name');
  late final AnimationController _field = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final CurvedAnimation _grow = CurvedAnimation(
    parent: _field,
    curve: Curves.easeOutCubic,
  );
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    // Leaving the field saves, as Done does.
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish();
    });
  }

  @override
  void dispose() {
    _grow.dispose();
    _field.dispose();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _rename() {
    if (_editing || !mounted) return;
    _controller.text = widget.title;
    setState(() => _editing = true);
    _field.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) return;
      _focus.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  /// A blank name keeps the old one.
  void _finish({bool save = true}) {
    if (!_editing) return;
    final name = _controller.text.trim();
    setState(() => _editing = false);
    _field.reverse();
    if (_focus.hasFocus) _focus.unfocus();
    if (save && name.isNotEmpty && name != widget.title) {
      widget.onRename(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final base = theme.typography.body.md;
    // Spelled out, so the field draws the name exactly where the text did.
    final style = base.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: base.letterSpacing ?? 0,
      wordSpacing: base.wordSpacing ?? 0,
      color: theme.colors.foreground,
    );
    final name = widget.title.isEmpty ? 'Untitled split' : widget.title;
    return Row(
      children: <Widget>[
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              AnimatedBuilder(
                animation: _grow,
                builder: (context, _) {
                  final t = _grow.value;
                  if (t == 0) return const SizedBox.shrink();
                  return Positioned(
                    left: -10 * t,
                    right: -10 * t,
                    top: -7 * t,
                    bottom: -7 * t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colors.muted.withValues(alpha: t),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colors.primary.withValues(
                            alpha: 0.55 * t,
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_editing)
                Material(
                  type: MaterialType.transparency,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): () =>
                          _finish(save: false),
                    },
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      style: style,
                      maxLines: null,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.words,
                      cursorColor: theme.colors.primary,
                      onSubmitted: (_) => _finish(),
                      onTapOutside: (_) => _focus.unfocus(),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Split name',
                        hintStyle: style.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: _editing
              ? AppIconButton(
                  key: const ValueKey('done'),
                  icon: FLucideIcons.check,
                  tooltip: 'Done renaming',
                  onPress: _finish,
                )
              : KeyedSubtree(
                  key: const ValueKey('menu'),
                  child: widget.menu(_rename),
                ),
        ),
      ],
    );
  }
}

/// A day of the split: a tap edits it; holding it (or hovering it with a
/// mouse) peeks at what it holds; two swipes left delete it.
class _DayRow extends StatefulWidget {
  const _DayRow({
    super.key,
    required this.split,
    required this.index,
    required this.day,
    required this.tag,
    required this.lastDone,
    required this.names,
    required this.onDelete,
  });

  final WorkoutSplit split;
  final int index;
  final DayDraft day;

  /// "New" or "Edited" while it has unsaved changes.
  final String? tag;
  final DateTime? lastDone;
  final Map<int, String> names;
  final VoidCallback onDelete;

  @override
  State<_DayRow> createState() => _DayRowState();
}

class _DayRowState extends State<_DayRow> {
  bool _hovered = false;
  Timer? _hoverTimer;
  Peek? _peek;
  bool _hoverPeek = false;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _peek?.close();
    super.dispose();
  }

  void _showPeek({required bool modal}) {
    _peek?.close();
    if (!mounted) return;
    _hoverPeek = !modal;
    final day = widget.day;
    _peek = Peek.show(
      context,
      modal: modal,
      builder: (_) => _DayPeekCard(
        day: day,
        tag: widget.tag,
        lastDone: widget.lastDone,
        names: widget.names,
      ),
    );
  }

  void _onHover(bool hovered) {
    setState(() => _hovered = hovered);
    _hoverTimer?.cancel();
    if (hovered) {
      _hoverTimer = Timer(
        const Duration(milliseconds: 450),
        () => _showPeek(modal: false),
      );
    } else if (_hoverPeek) {
      _peek?.close();
    }
  }

  void _open() {
    _hoverTimer?.cancel();
    _peek?.close();
    pushTo<void>(
      context,
      SplitDayEditorPage(splitId: widget.split.id, dayIndex: widget.index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final day = widget.day;
    final tag = widget.tag;
    return SwipeToDelete(
      canDelete: true,
      onDelete: widget.onDelete,
      surface: theme.colors.background,
      // Over the grip, a drag reorders instead.
      ignoreFromStart: 40,
      child: Material(
        type: MaterialType.transparency,
        child: FTappable(
          onPress: _open,
          onLongPress: () {
            _hoverTimer?.cancel();
            HapticFeedback.selectionClick();
            _showPeek(modal: true);
          },
          onHoverChange: _onHover,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? theme.colors.secondary
                  : theme.colors.background,
              border: Border(bottom: BorderSide(color: theme.colors.border)),
            ),
            child: Row(
              children: <Widget>[
                ReorderableDragStartListener(
                  index: widget.index,
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
                            day.title.isEmpty ? 'Untitled day' : day.title,
                            style: theme.typography.body.sm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (tag != null) DraftTag(tag),
                        ],
                      ),
                      Text(
                        '${plural('exercise', day.exercises.length)}, '
                        '${plural('set', day.setCount)}',
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
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
    );
  }
}

/// What a day holds, at a glance: its exercises with their planned sets,
/// and when it was last trained.
class _DayPeekCard extends StatelessWidget {
  const _DayPeekCard({
    required this.day,
    required this.tag,
    required this.lastDone,
    required this.names,
  });

  final DayDraft day;
  final String? tag;
  final DateTime? lastDone;
  final Map<int, String> names;

  /// Exercises listed before "and N more".
  static const _listed = 6;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final exercises = day.exercises;
    final last = lastDone;
    final tag = this.tag;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        decoration: BoxDecoration(
          color: theme.colors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    day.title.isEmpty ? 'Untitled day' : day.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (tag != null) DraftTag(tag),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${plural('exercise', exercises.length)}, '
              '${plural('set', day.setCount)} · '
              '${last == null ? 'not done yet' : 'last done ${agoLabel(last)}'}',
              style: muted,
            ),
            if (day.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                day.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ],
            const SizedBox(height: 10),
            if (exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'No exercises yet. Tap the day to add some.',
                  style: muted,
                ),
              )
            else ...[
              for (final exercise in exercises.take(_listed))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        names[exercise.exerciseId] ??
                            'Exercise ${exercise.exerciseId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.sm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(setsSummary(exercise.sets), style: muted),
                    ],
                  ),
                ),
              if (exercises.length > _listed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'and ${exercises.length - _listed} more',
                    style: muted,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
