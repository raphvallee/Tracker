import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/ui/app_dialog.dart';
import 'package:tracker/utils/form_validators.dart';

/// Asks for the default reps of a fixed set; null when cancelled.
///
/// The field lives in a dialog, not on the Settings page, so opening Settings
/// builds no text field: they dominated the page's first frame.
Future<int?> editDefaultRepsDialog(
  BuildContext context, {
  required int initial,
}) {
  return showFDialog<int>(
    context: context,
    builder: (context, _, _) => DefaultRepsDialog(initial: initial),
  );
}

/// Asks for the default rep range as `(min, max)`; null when cancelled.
Future<(int, int)?> editDefaultRepRangeDialog(
  BuildContext context, {
  required int min,
  required int max,
}) {
  return showFDialog<(int, int)>(
    context: context,
    builder: (context, _, _) => DefaultRepRangeDialog(min: min, max: max),
  );
}

class DefaultRepsDialog extends StatefulWidget {
  const DefaultRepsDialog({super.key, required this.initial});

  final int initial;

  @override
  State<DefaultRepsDialog> createState() => _DefaultRepsDialogState();
}

class _DefaultRepsDialogState extends State<DefaultRepsDialog> {
  late final TextEditingController _reps = TextEditingController(
    text: '${widget.initial}',
  );
  String? _error;

  @override
  void dispose() {
    _reps.dispose();
    super.dispose();
  }

  void _save() {
    final error = requiredInt(_reps.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(int.parse(_reps.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Default reps',
      headerGap: 16,
      scrollable: true,
      actions: [
        FButton(
          variant: .outline,
          onPress: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FButton(onPress: _save, child: const Text('Save')),
      ],
      child: FTextField(
        control: FTextFieldControl.managed(
          controller: _reps,
          onChange: (_) => setState(() => _error = null),
        ),
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmit: (_) => _save(),
        label: const Text('Reps'),
        error: _error == null ? null : Text(_error!),
      ),
    );
  }
}

class DefaultRepRangeDialog extends StatefulWidget {
  const DefaultRepRangeDialog({
    super.key,
    required this.min,
    required this.max,
  });

  final int min;
  final int max;

  @override
  State<DefaultRepRangeDialog> createState() => _DefaultRepRangeDialogState();
}

class _DefaultRepRangeDialogState extends State<DefaultRepRangeDialog> {
  late final TextEditingController _min = TextEditingController(
    text: '${widget.min}',
  );
  late final TextEditingController _max = TextEditingController(
    text: '${widget.max}',
  );
  String? _minError;
  String? _maxError;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _save() {
    final minError = requiredInt(_min.text);
    var maxError = requiredInt(_max.text);
    final min = int.tryParse(_min.text.trim());
    final max = int.tryParse(_max.text.trim());
    if (minError == null && maxError == null && min! > max!) {
      maxError = 'Must be at least the min';
    }
    if (minError != null || maxError != null) {
      setState(() {
        _minError = minError;
        _maxError = maxError;
      });
      return;
    }
    Navigator.of(context).pop((min!, max!));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Default rep range',
      headerGap: 16,
      scrollable: true,
      actions: [
        FButton(
          variant: .outline,
          onPress: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FButton(onPress: _save, child: const Text('Save')),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FTextField(
              control: FTextFieldControl.managed(
                controller: _min,
                onChange: (_) => setState(() => _minError = null),
              ),
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              label: const Text('Min'),
              error: _minError == null ? null : Text(_minError!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FTextField(
              control: FTextFieldControl.managed(
                controller: _max,
                onChange: (_) => setState(() => _maxError = null),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmit: (_) => _save(),
              label: const Text('Max'),
              error: _maxError == null ? null : Text(_maxError!),
            ),
          ),
        ],
      ),
    );
  }
}
