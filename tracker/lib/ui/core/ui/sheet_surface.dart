import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// The opaque, top-rounded surface a bottom sheet's content sits on, with a
/// grab handle: showFSheet paints no surface of its own. [scrollable] lets
/// tall content scroll inside the sheet's height cap; [footer] stays docked
/// under it, over a line.
class SheetSurface extends StatelessWidget {
  const SheetSurface({
    super.key,
    required this.child,
    this.scrollable = false,
    this.footer,
    this.controller,
  });

  final Widget child;
  final bool scrollable;
  final Widget? footer;

  /// Scrolls [child] when [scrollable].
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: child,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 14),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (scrollable)
              Flexible(
                child: SingleChildScrollView(
                  controller: controller,
                  child: padded,
                ),
              )
            else
              padded,
            if (footer case final footer?)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: footer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// [builder], called the first time only. The sheet calls its builder again
/// on every frame of the keyboard animation; the same widget back keeps its
/// fields from rebuilding with it.
WidgetBuilder builtOnce(WidgetBuilder builder) {
  Widget? built;
  return (context) => built ??= builder(context);
}
