import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Shared layout for the app's dialogs: a title, an optional message or custom
/// content, and a row of actions aligned to the end. Dialogs are still opened
/// with [showFDialog]; this widget only builds the body.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.titleTrailing,
    this.message,
    this.child,
    this.headerGap = 8,
    this.actionsGap = 24,
    this.scrollable = false,
    required this.actions,
  });

  final String title;

  /// Widget placed at the end of the title row, such as an icon button.
  final Widget? titleTrailing;

  /// Body text shown under the title.
  final String? message;

  /// Body content shown under the title, for forms and pickers.
  final Widget? child;

  /// Space between the title and the message or child.
  final double headerGap;

  /// Space between the body and the actions.
  final double actionsGap;

  /// Wraps the body in a scroll view so the keyboard can't clip the actions.
  final bool scrollable;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return FDialog(
      builder: (context, style) {
        final titleText = Text(title, style: style.titleTextStyle);
        final body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleTrailing == null
                ? titleText
                : Row(
                    children: [
                      Expanded(child: titleText),
                      titleTrailing!,
                    ],
                  ),
            if (message != null) ...[
              SizedBox(height: headerGap),
              Text(message!, style: style.bodyTextStyle),
            ],
            if (child != null) ...[SizedBox(height: headerGap), child!],
            SizedBox(height: actionsGap),
            // Wrap (not Row + Spacer): the dialog is only ~240px wide at the
            // minimum desktop window size, and a fixed row overflows.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: actions,
            ),
          ],
        );
        return scrollable ? SingleChildScrollView(child: body) : body;
      },
    );
  }
}

/// Confirm/cancel dialog. Resolves to true when confirmed; cancel, or
/// dismissing the barrier, resolves to false.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showFDialog<bool>(
    context: context,
    builder: (dialogContext, _, _) => AppDialog(
      title: title,
      message: message,
      actions: [
        FButton(
          variant: .outline,
          onPress: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FButton(
          variant: destructive ? .destructive : .primary,
          onPress: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
