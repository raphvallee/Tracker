import 'package:material_ui/material_ui.dart';

class TabVisibilityScope extends InheritedWidget {
  const TabVisibilityScope({
    required this.index,
    required this.isActive,
    required super.child,
    super.key,
  });

  final int index;
  final bool isActive;

  static bool isActiveOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<TabVisibilityScope>()
          ?.isActive ??
      true;

  @override
  bool updateShouldNotify(TabVisibilityScope oldWidget) =>
      isActive != oldWidget.isActive || index != oldWidget.index;
}

class HomePageSingleton {
  factory HomePageSingleton() => _singleton;

  HomePageSingleton._internal();

  static final HomePageSingleton _singleton = HomePageSingleton._internal();

  Function? indexSetState;

  /// The nested navigator of a tab (by index), once that tab has been built.
  NavigatorState? Function(int index)? navigatorOf;

  static const Map<TabName, int> _tabIndexes = {
    TabName.feed: 0,
    TabName.history: 1,
    TabName.currentWorkout: 2,
    TabName.splits: 3,
    TabName.exercises: 4,
  };

  void changeTab(TabName tabName) {
    final index = _tabIndexes[tabName];
    if (index != null) indexSetState?.call(index);
  }

  /// Switches to [tabName] and pushes [route] on its navigator. A tab opened
  /// for the first time builds its navigator in the next frame, so the push
  /// waits for it.
  void pushInTab(TabName tabName, Route<void> route) {
    final index = _tabIndexes[tabName];
    if (index == null) return;
    indexSetState?.call(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorOf?.call(index)?.push(route);
    });
  }
}

enum TabName { feed, history, currentWorkout, splits, exercises }
