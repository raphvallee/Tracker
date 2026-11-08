import 'package:flutter/material.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';

Future<bool> confirmDiscardUnsavedChanges(BuildContext context) =>
    showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your changes have not been saved.',
      confirmLabel: 'Discard',
    );
