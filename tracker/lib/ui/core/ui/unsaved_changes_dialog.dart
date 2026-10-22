import 'package:flutter/material.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';

/// Confirmation shown when leaving a split/split-day editor with unsaved
/// changes. Returns true when the user chose to discard; false (or null,
/// e.g. from dismissing the barrier) means stay on the editor.
Future<bool> confirmDiscardUnsavedChanges(BuildContext context) =>
    showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your changes have not been saved.',
      confirmLabel: 'Discard',
    );
