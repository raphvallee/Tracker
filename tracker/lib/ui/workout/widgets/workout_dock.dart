import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/ui/max_width.dart';

/// The bar docked at the bottom of every workout screen. It holds the one
/// next step (Start, Log, Next, Finish), so that step is always in the same
/// place. [above] is a quiet line over the button: the gym, the rest clock.
class WorkoutDock extends StatelessWidget {
  const WorkoutDock({super.key, required this.child, this.above});

  final Widget child;
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: MaxWidth(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, above == null ? 10 : 4, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[?above, child],
          ),
        ),
      ),
    );
  }
}
