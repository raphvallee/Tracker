import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// The opaque, top-rounded surface a bottom sheet's content sits on, with a
/// grab handle: showFSheet paints no surface of its own. [scrollable] lets
/// tall content scroll inside the sheet's height cap.
class SheetSurface extends StatelessWidget {
  const SheetSurface({super.key, required this.child, this.scrollable = false});

  final Widget child;
  final bool scrollable;

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
              Flexible(child: SingleChildScrollView(child: padded))
            else
              padded,
          ],
        ),
      ),
    );
  }
}
