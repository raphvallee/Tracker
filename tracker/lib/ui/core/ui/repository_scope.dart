import 'package:flutter/widgets.dart';

import 'package:tracker/data/repositories/tracker_repository.dart';

class RepositoryScope extends InheritedWidget {
  const RepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final TrackerRepository repository;

  static TrackerRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'RepositoryScope not found above this context');
    return scope!.repository;
  }

  static TrackerRepository? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<RepositoryScope>()
        ?.repository;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) =>
      repository != oldWidget.repository;
}
