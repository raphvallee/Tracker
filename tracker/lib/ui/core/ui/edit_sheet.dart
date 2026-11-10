import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';

// Values are edited in bottom sheets, never in dialogs: dialogs only ask to
// confirm. A sheet keeps the page in view, lifts above the keyboard and
// closes with a swipe down, which cancels the edit.

/// Opens [builder]'s [EditSheet] from the bottom, over the tab bar.
Future<T?> showEditSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showFSheet<T>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.9,
    builder: builtOnce(builder),
  );
}

/// A sheet that edits values: a title, an optional line on what is edited,
/// the fields, and one button that saves them.
class EditSheet extends StatelessWidget {
  const EditSheet({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.actionLabel = 'Save',
    required this.onAction,
  });

  final String title;
  final String? description;
  final Widget child;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // The fields are Material text fields; the sheet paints its own surface.
    return Material(
      type: MaterialType.transparency,
      child: SheetSurface(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (description case final description?) ...[
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 20),
            FButton(onPress: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
