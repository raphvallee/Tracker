import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/data/services/app_log.dart';
import 'package:tracker/domain/models/exercises_layout.dart';
import 'package:tracker/domain/services/exercise_library.dart';
import 'package:tracker/routing/tab_navigation.dart';
import 'package:tracker/ui/core/ui/custom_app_bar.dart';
import 'package:tracker/ui/core/ui/item_card.dart';
import 'package:tracker/ui/core/ui/keyboard_inset.dart';
import 'package:tracker/ui/core/ui/max_width.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/exercises/widgets/library_open_tiles.dart';
import 'package:tracker/ui/exercises/widgets/library_parts.dart';
import 'package:tracker/ui/exercises/widgets/library_rows.dart';
import 'package:tracker/ui/exercises/widgets/library_tiles.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

/// The Exercises tab: a search field over the library, then the library in
/// the layout picked in Settings (a list of groups, tiles by muscle, or
/// tiles that open in place). Every layout shows when each exercise was
/// last trained, how many of each group's exercises the current split
/// plans, and the split's days.
class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key, this.initialLibrary});

  /// The library to show before (or instead of, without a repository) the
  /// first read.
  final ExerciseLibrary? initialLibrary;

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  late final ValueNotifier<ExerciseLibrary> _library = ValueNotifier(
    widget.initialLibrary ??
        ExerciseLibrary(exercises: const [], now: DateTime.now()),
  );
  final _query = TextEditingController();
  final List<StreamSubscription<void>> _subs = [];
  late bool _loaded = widget.initialLibrary != null;
  bool _started = false;
  bool _isActive = true;
  int _reads = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TabVisibilityScope.isActiveOf(context);
    if (!_started) {
      _started = true;
      _isActive = isActive;
      if (isActive) _subscribe();
    } else if (isActive != _isActive) {
      _isActive = isActive;
      if (isActive) {
        _subscribe();
      } else {
        _unsubscribe();
      }
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    _library.dispose();
    _query.dispose();
    super.dispose();
  }

  void _subscribe() {
    if (_subs.isNotEmpty) return;
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) {
      _loaded = true;
      return;
    }
    void onError(Object error, StackTrace stack) =>
        AppLog.error('exercises', error, stack);
    // The exercise watcher fires at once, which makes the first read.
    _subs
      ..add(repo.exercises.watchAll().listen((_) => _read(), onError: onError))
      ..add(
        repo.sessions.watchChanges().listen((_) => _read(), onError: onError),
      )
      ..add(repo.splits.watchAll().listen((_) => _read(), onError: onError));
    // Making another split current changes what is in the split.
    if (SettingsCubit.maybeOf(context) case final settings?) {
      _subs.add(
        settings.stream
            .map((state) => state.currentSplitId)
            .distinct()
            .listen((_) => _read()),
      );
    }
  }

  void _unsubscribe() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
  }

  /// Reads the library, every workout and the splits again; a read
  /// overtaken by a newer one is dropped.
  Future<void> _read() async {
    final repo = RepositoryScope.maybeOf(context);
    if (repo == null) return;
    final read = ++_reads;
    try {
      final (exercises, sessions, splits) = await (
        repo.exercises.getAll(),
        repo.sessions.getAll(),
        repo.splits.getAll(),
      ).wait;
      if (!mounted || read != _reads) return;
      _library.value = ExerciseLibrary.read(
        exercises: exercises,
        sessions: sessions,
        splits: splits,
        currentSplitId: SettingsCubit.maybeOf(context)?.state.currentSplitId,
        now: DateTime.now(),
      );
      setState(() => _loaded = true);
    } catch (error, stack) {
      AppLog.error('exercises', error, stack);
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = _library.value;
    final searching = _query.text.trim().isNotEmpty;
    return CustomScrollView(
      slivers: <Widget>[
        CustomAppBar(
          context,
          title: 'Exercises',
          actionButton: (
            title: 'New',
            onPressed: () => openNewExercise(context),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            32 + (searching ? keyboardClearanceOf(context) : 0),
          ),
          sliver: SliverToBoxAdapter(
            child: MaxWidth(
              child: !_loaded
                  ? const SizedBox.shrink()
                  : library.isEmpty
                  ? const _EmptyLibrary()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        FTextField(
                          key: const ValueKey<String>('exercise-search'),
                          control: FTextFieldControl.managed(
                            controller: _query,
                            onChange: (_) => setState(() {}),
                          ),
                          hint: 'Search ${library.exercises.length} exercises',
                          textInputAction: TextInputAction.search,
                          prefixBuilder: (context, style, variants) =>
                              FTextField.prefixIconBuilder(
                                context,
                                style,
                                variants,
                                const Icon(FLucideIcons.search),
                              ),
                          clearable: (value) => value.text.isNotEmpty,
                        ),
                        if (searching)
                          _SearchResults(
                            library: library,
                            query: _query.text,
                            onClear: () => setState(_query.clear),
                          )
                        else
                          _layout(context),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _layout(BuildContext context) {
    final layout = SettingsCubit.maybeOf(context) == null
        ? SettingsState().exercisesLayout
        : context.select<SettingsCubit, ExercisesLayout>(
            (cubit) => cubit.state.exercisesLayout,
          );
    return switch (layout) {
      ExercisesLayout.rows => LibraryRows(source: _library),
      ExercisesLayout.tiles => LibraryTiles(source: _library),
      ExercisesLayout.openTiles => LibraryOpenTiles(source: _library),
    };
  }
}

/// What a search finds, names that match first; or what to do when it
/// finds nothing.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.library,
    required this.query,
    required this.onClear,
  });

  final ExerciseLibrary library;
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final found = library.search(query);
    if (found.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          children: <Widget>[
            Icon(
              FLucideIcons.searchX,
              size: 28,
              color: theme.colors.mutedForeground,
            ),
            const SizedBox(height: 10),
            Text(
              'No exercises match',
              style: theme.typography.body.md.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try another name, a muscle or a piece of equipment, or add '
              'it as a new exercise.',
              textAlign: TextAlign.center,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FButton(
                  variant: .outline,
                  size: .sm,
                  onPress: onClear,
                  child: const Text('Clear search'),
                ),
                FButton(
                  size: .sm,
                  onPress: () => openNewExercise(context),
                  child: const Text('New exercise'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              found.length == 1 ? '1 exercise' : '${found.length} exercises',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
          ItemCard(
            divider: .full,
            children: [
              for (final exercise in found)
                exerciseItem(context, library, exercise),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: <Widget>[
          Icon(
            FLucideIcons.personStanding,
            size: 28,
            color: theme.colors.mutedForeground,
          ),
          const SizedBox(height: 10),
          Text(
            'No exercises in the library yet',
            style: theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add the exercises you train. Each one keeps its own history '
            'and best sets.',
            textAlign: TextAlign.center,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          FButton(
            size: .sm,
            onPress: () => openNewExercise(context),
            child: const Text('New exercise'),
          ),
        ],
      ),
    );
  }
}
