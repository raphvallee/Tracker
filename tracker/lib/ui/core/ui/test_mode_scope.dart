import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Whether the app runs on test mode's sample data, and how to switch it
/// or start the sample data over. Absent in tests and before startup.
class TestModeScope extends InheritedWidget {
  const TestModeScope({
    super.key,
    required this.enabled,
    required this.busy,
    required this.setEnabled,
    required this.reset,
    required super.child,
  });

  final bool enabled;

  /// A switch or reset is under way.
  final bool busy;

  final Future<void> Function(bool enabled) setEnabled;
  final Future<void> Function() reset;

  static TestModeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TestModeScope>();

  @override
  bool updateShouldNotify(TestModeScope oldWidget) =>
      enabled != oldWidget.enabled || busy != oldWidget.busy;
}

/// The strip over every screen while test mode is on, so sample data is
/// never mistaken for real training.
class TestModeBanner extends StatelessWidget {
  const TestModeBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (TestModeScope.maybeOf(context)?.enabled != true) return child;
    final theme = context.theme;
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: <Widget>[
        ColoredBox(
          color: theme.colors.foreground,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, top + 3, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  FLucideIcons.flaskConical,
                  size: 13,
                  color: theme.colors.background,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Test mode: sample data, reset on every launch',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.xs.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colors.background,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
