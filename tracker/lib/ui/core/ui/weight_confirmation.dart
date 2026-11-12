import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/rep_limits.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/ui/settings/view_models/settings_cubit.dart';

Future<bool> confirmWeightEntry(BuildContext context, double displayed) async {
  if (displayed < 0) {
    final assisted = await showFDialog<bool>(
      context: context,
      builder: (_, _, _) => FDialog(
        builder: (dialogContext, style) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Assisted machine?', style: style.titleTextStyle),
            const SizedBox(height: 8),
            Text(
              'A negative weight means the machine helps you lift, like an '
              'assisted pull-up. Is this an assisted machine?',
              style: style.bodyTextStyle,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FButton(
                  variant: .outline,
                  onPress: () => Navigator.pop(dialogContext, false),
                  child: const Text('Go back'),
                ),
                FButton(
                  onPress: () => Navigator.pop(dialogContext, true),
                  child: const Text('Yes, log it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return assisted ?? false;
  }

  final unit = weightUnitOf(context);
  final settings = SettingsCubit.maybeOf(context);
  final warningOn = settings?.state.showHeavyWeightWarning ?? true;
  if (!warningOn || displayed <= unit.heavyWeightThreshold) return true;

  final choice = await showFDialog<({bool use, bool dontShowAgain})>(
    context: context,
    builder: (_, _, _) => _HeavyWeightDialog(
      displayed: displayed,
      unit: unit,
      offerDontShowAgain: settings?.state.heavyWeightConfirmed ?? false,
    ),
  );
  if (choice == null || !choice.use) return false;
  settings?.confirmHeavyWeight();
  if (choice.dontShowAgain) settings?.setShowHeavyWeightWarning(false);
  return true;
}

/// Above [highRepsThreshold] reps, asks to confirm the count: a slip of the
/// thumb (250 for 25) is far likelier than the set. True to log it.
Future<bool> confirmRepsEntry(BuildContext context, double reps) async {
  if (reps <= highRepsThreshold) return true;
  final confirmed = await showFDialog<bool>(
    context: context,
    builder: (_, _, _) => FDialog(
      builder: (dialogContext, style) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("That's a lot of reps", style: style.titleTextStyle),
            const SizedBox(height: 8),
            Text(
              '${formatDecimal(reps)} reps is above '
              '${formatDecimal(highRepsThreshold)}. Check the count before '
              'logging it.',
              style: style.bodyTextStyle,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FButton(
                  variant: .outline,
                  onPress: () => Navigator.pop(dialogContext, false),
                  child: const Text('Go back'),
                ),
                FButton(
                  onPress: () => Navigator.pop(dialogContext, true),
                  child: const Text('Use these reps'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

class _HeavyWeightDialog extends StatefulWidget {
  const _HeavyWeightDialog({
    required this.displayed,
    required this.unit,
    required this.offerDontShowAgain,
  });

  final double displayed;
  final WeightUnit unit;

  /// Whether the checkbox is offered; only after a first confirmed heavy
  /// weight, so a one-off accidental entry is not turned into a permanent
  /// silence on the very first prompt.
  final bool offerDontShowAgain;

  @override
  State<_HeavyWeightDialog> createState() => _HeavyWeightDialogState();
}

class _HeavyWeightDialogState extends State<_HeavyWeightDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final symbol = widget.unit.symbol;
    return FDialog(
      // FDialog paints no internal padding (the builder's child is the
      // surface), so the body pads itself.
      builder: (dialogContext, style) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("That's a lot of weight", style: style.titleTextStyle),
            const SizedBox(height: 8),
            Text(
              '${formatDecimal(widget.displayed)} $symbol is above '
              '${formatDecimal(widget.unit.heavyWeightThreshold)} $symbol. '
              'Confirm if you are really that strong.',
              style: style.bodyTextStyle,
            ),
            const SizedBox(height: 16),
            if (widget.offerDontShowAgain)
              FCheckbox(
                label: const Text("Don't show this again"),
                value: _dontShowAgain,
                onChange: (value) => setState(() => _dontShowAgain = value),
              ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FButton(
                  variant: .outline,
                  onPress: () => Navigator.pop(dialogContext),
                  child: const Text('Go back'),
                ),
                FButton(
                  onPress: () => Navigator.pop(dialogContext, (
                    use: true,
                    dontShowAgain: _dontShowAgain,
                  )),
                  child: const Text('Use this weight'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
