import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/workout/view_models/workout_cubit.dart';
import 'package:tracker/routing/tab_navigation.dart';

import 'package:tracker/ui/exercises/widgets/exercises_page.dart';
import 'package:tracker/ui/feed/widgets/feed_page.dart';
import 'package:tracker/ui/history/widgets/history_page.dart';
import 'package:tracker/ui/workout/widgets/editor_page.dart';
import 'package:tracker/ui/workout/widgets/workout_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    5,
    (index) => GlobalKey<NavigatorState>(),
  );
  final Set<int> _visited = {0};
  final List<_TabPopObserver> _popObservers = List.generate(
    5,
    (index) => _TabPopObserver(),
  );
  bool _poppingActiveTab = false;

  Future<bool> _handlePop() async {
    final navigator = _navigatorKeys[_currentIndex].currentState;
    if (navigator != null && await navigator.maybePop()) return true;
    return false;
  }

  Future<void> _selectTab(int index) async {
    if (index != _currentIndex) {
      _setCurrentIndex(index);
      return;
    }
    // Re-tapping the active tab pops it back to its root. Use maybePop so
    // PopScope guards (e.g. the editor's unsaved-changes dialog) can veto
    // each pop instead of being bypassed by popUntil. maybePop reports true
    // both when a pop happens and when a guard refuses one (leaving its
    // dialog open), so actual pops are counted via the observer: the loop
    // stops as soon as an iteration pops nothing.
    if (_poppingActiveTab) return;
    _poppingActiveTab = true;
    try {
      final navigator = _navigatorKeys[index].currentState;
      final observer = _popObservers[index];
      while (navigator != null && navigator.canPop()) {
        final popsBefore = observer.popCount;
        final popped = await navigator.maybePop();
        if (!popped || observer.popCount == popsBefore) break;
      }
    } finally {
      _poppingActiveTab = false;
    }
  }

  void _setCurrentIndex(int index) {
    if (index < 0 || index >= _navigatorKeys.length) return;
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  Widget _buildOffstageNavigator(int index, Widget child) {
    final isActive = _currentIndex == index;
    return Offstage(
      offstage: !isActive,
      child: TabVisibilityScope(
        index: index,
        isActive: isActive,
        child: Navigator(
          key: _navigatorKeys[index],
          observers: [_popObservers[index]],
          onGenerateRoute: (settings) =>
              MaterialPageRoute(builder: (context) => child),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    HomePageSingleton().indexSetState = indexSetState;
  }

  @override
  void dispose() {
    if (HomePageSingleton().indexSetState == indexSetState) {
      HomePageSingleton().indexSetState = null;
    }
    super.dispose();
  }

  void indexSetState(int index) {
    if (!mounted || index < 0 || index >= _navigatorKeys.length) return;
    _setCurrentIndex(index);
  }

  Widget _pageFor(int index) => switch (index) {
    0 => const FeedPage(),
    1 => const HistoryPage(),
    2 => const WorkoutPage(),
    3 => const EditorPage(),
    4 => const ExercisesPage(),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    final visited = _visited.toList()..sort();
    // Never resize the shell for the on-screen keyboard: the default (true)
    // compressed the whole tab shell (app bar, list, bottom nav) every time an
    // input was focused. With `false` the keyboard simply overlays the shell
    // while pages pad their scrollable content by MediaQuery.viewInsets so the
    // focused field and primary actions stay reachable above the keyboard.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _handlePop()) return;

        SystemNavigator.pop();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            for (final index in visited)
              _buildOffstageNavigator(index, _pageFor(index)),
          ],
        ),
        bottomNavigationBar: FBottomNavigationBar(
          index: _currentIndex,
          onChange: _selectTab,
          children: <Widget>[
            const FBottomNavigationBarItem(
              key: ValueKey('feed-tab'),
              icon: Icon(FLucideIcons.house),
              label: Text('Feed'),
              semanticsLabel: 'Feed',
            ),
            const FBottomNavigationBarItem(
              key: ValueKey('history-tab'),
              icon: Icon(FLucideIcons.history),
              label: Text('History'),
              semanticsLabel: 'History',
            ),
            BlocBuilder<WorkoutCubit, WorkoutState>(
              builder: (context, state) => FBottomNavigationBarItem(
                key: const ValueKey('workout-tab'),
                icon: Transform.translate(
                  offset: const Offset(0, -6),
                  child: const Icon(FLucideIcons.dumbbell),
                ),
                label: const Text('Workout'),
                semanticsLabel: state.isInProgress
                    ? 'Workout in progress'
                    : 'Workout',
              ),
            ),
            const FBottomNavigationBarItem(
              key: ValueKey('editor-tab'),
              icon: Icon(FLucideIcons.notebookText),
              label: Text('Editor'),
              semanticsLabel: 'Editor',
            ),
            const FBottomNavigationBarItem(
              key: ValueKey('exercises-tab'),
              icon: Icon(FLucideIcons.personStanding),
              label: Text('Exercises'),
              semanticsLabel: 'Exercises',
            ),
          ],
        ),
      ),
    );
  }
}

/// Counts actual route pops on a tab's nested navigator. Used by
/// [_selectTab] to tell a successful maybePop apart from a PopScope guard
/// refusing one (both report true), so the pop-to-root loop cannot spin
/// forever while a guard dialog is open.
class _TabPopObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
  }
}
