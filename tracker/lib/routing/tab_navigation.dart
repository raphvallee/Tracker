import 'package:flutter/material.dart';

/// Visibility contract for pages hosted by the persistent tab navigators.
/// Inactive pages stay mounted to preserve their nested route stack, but should
/// pause live subscriptions and resume them when [isActive] becomes true.
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

  /// Tab name -> nested-navigator index. Only the forward direction is used
  /// (previously quiver's BiMap, which was overkill and the sole reason for
  /// the dependency).
  static const Map<TabName, int> _tabIndexes = {
    TabName.feed: 0,
    TabName.history: 1,
    TabName.currentWorkout: 2,
    TabName.editor: 3,
    TabName.exercises: 4,
  };

  void changeTab(TabName tabName) {
    final index = _tabIndexes[tabName];
    if (index != null) indexSetState?.call(index);
  }
}

enum TabName { feed, history, currentWorkout, editor, exercises }
