import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// How far a row's pressed or selected highlight sits inside its card and
/// from the dividers.
const double itemHighlightInset = 4;

/// A card of rows. The card clips its rows inside its outline: they paint
/// a background that would hide it otherwise. Each row is inset by the same
/// gap on every side, so a highlight never touches a divider.
class ItemCard extends StatelessWidget {
  const ItemCard({super.key, this.divider = .indented, required this.children});

  final FItemDivider divider;
  final List<FItemMixin> children;

  @override
  Widget build(BuildContext context) => FCard(
    clipBehavior: Clip.antiAlias,
    child: FItemGroup(
      divider: divider,
      style: .delta(
        spacing: 0,
        itemStyles: .delta([
          .all(
            const .delta(padding: .value(EdgeInsets.all(itemHighlightInset))),
          ),
        ]),
      ),
      children: children,
    ),
  );
}
