import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/ui/core/ui/animated_reveal.dart';
import 'package:tracker/ui/core/ui/max_width.dart';

/// The bar docked at the bottom of every workout screen. It holds the one
/// next step (Start, Log, Next, Finish), so that step is always in the same
/// place. [above] is a quiet line over the button (the gym); [leading]
/// sits beside it (the rest clock), so it costs the page no height. It
/// grows in from the side as it arrives, the button making room for it.
class WorkoutDock extends StatelessWidget {
  const WorkoutDock({super.key, required this.child, this.above, this.leading});

  final Widget child;
  final Widget? above;
  final Widget? leading;

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
            children: <Widget>[
              ?above,
              Row(
                children: <Widget>[
                  AnimatedReveal(
                    axis: Axis.horizontal,
                    child: leading == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: leading,
                          ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
