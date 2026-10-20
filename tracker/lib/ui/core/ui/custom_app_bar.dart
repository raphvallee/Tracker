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
    return SliverAppBar(
      pinned: true,
      snap: false,
      floating: false,
      toolbarHeight: 48,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          if (ModalRoute.isFirstOf(context) == false) ...[
            FButton(
              variant: .ghost,
              onPress: () => Navigator.maybePop(context),
              child: const Icon(FLucideIcons.chevronLeft),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (actionButton != null)
            FButton(
              variant: .ghost,
              onPress: actionButton!.onPressed,
              child: Text(actionButton!.title),
            ),
        ],
      ),
    );
  }
}
