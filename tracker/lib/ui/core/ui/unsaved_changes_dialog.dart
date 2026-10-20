import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Confirmation shown when leaving a split/split-day editor with unsaved
/// changes. Returns true when the user chose to discard; false (or null,
/// e.g. from dismissing the barrier) means stay on the editor.
Future<bool> confirmDiscardUnsavedChanges(BuildContext context) async {
  final confirmed = await showFDialog<bool>(
    context: context,
    builder: (dialogContext, _, _) => FDialog(
      builder: (context, style) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Discard changes?', style: style.titleTextStyle),
          const SizedBox(height: 8),
          Text('Your changes have not been saved.', style: style.bodyTextStyle),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              FButton(
                variant: .outline,
                onPress: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FButton(
                onPress: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}
