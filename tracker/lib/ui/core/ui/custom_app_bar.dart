import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class CustomAppBar extends StatelessWidget {
  const CustomAppBar(
    BuildContext context, {
    super.key,
    required this.title,
    this.actionButton,
  });

  final String title;
  final ({String title, VoidCallback onPressed})? actionButton;

  @override
  Widget build(BuildContext context) {
    final style = context.theme.headerStyles.nested;
    final topInset = MediaQuery.paddingOf(context).top;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedHeaderDelegate(
        // FHeader is a plain widget, so it needs a pinned sliver wrapper to
        // keep the old SliverAppBar's pin-while-scrolling behavior. The extra
        // extent covers the status-bar inset that FHeader's internal SafeArea
        // consumes.
        extent: style.constraints.minHeight + topInset,
        background: context.theme.colors.background,
        child: FHeader.nested(
          titleAlignment: .centerLeft,
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          prefixes: [
            if (ModalRoute.isFirstOf(context) == false)
              FButton(
                variant: .ghost,
                onPress: () => Navigator.maybePop(context),
                child: const Icon(FLucideIcons.chevronLeft),
              ),
          ],
          suffixes: [
            if (actionButton != null)
              FButton(
                variant: .ghost,
                onPress: actionButton!.onPressed,
                child: Text(actionButton!.title),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHeaderDelegate({
    required this.extent,
    required this.background,
    required this.child,
  });

  final double extent;
  final Color background;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: background, child: child);

  @override
  bool shouldRebuild(_PinnedHeaderDelegate old) =>
      extent != old.extent ||
      background != old.background ||
      child != old.child;
}
