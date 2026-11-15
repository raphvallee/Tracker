import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/services/gym_equivalence.dart';
import 'package:tracker/ui/core/ui/edit_sheet.dart';
import 'package:tracker/ui/core/ui/repository_scope.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';
import 'package:tracker/utils/decimal_input.dart';

import 'gym_picker.dart';

/// Sets [exerciseName]'s factor at the gym [conversion] hangs on, by hand:
/// as two weights that feel the same at both gyms rather than as a ratio.
/// It starts from [fromKilograms] at the gym it comes from and what that
/// converts to. With a factor already set by hand, it can go back to the
/// estimate. Saved to the gym; swiping the sheet away changes nothing.
Future<void> showGymFactorSheet(
  BuildContext context, {
  required int exerciseId,
  required String exerciseName,
  required GymConversion conversion,
  required double fromKilograms,
  String? homeName,
}) {
  return showEditSheet<void>(
    context,
    builder: (_) => GymFactorSheet(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      conversion: conversion,
      fromKilograms: fromKilograms,
      homeName: homeName,
    ),
  );
}

class GymFactorSheet extends StatefulWidget {
  const GymFactorSheet({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.conversion,
    required this.fromKilograms,
    this.homeName,
  });

  final int exerciseId;
  final String exerciseName;
  final GymConversion conversion;
  final double fromKilograms;

  /// The primary gym's name, for the line on what the factor means.
  final String? homeName;

  @override
  State<GymFactorSheet> createState() => _GymFactorSheetState();
}

class _GymFactorSheetState extends State<GymFactorSheet> {
  late final TextEditingController _from;
  late final TextEditingController _to;
  String? _error;
  bool _didInit = false;

  GymConversion get _conversion => widget.conversion;

  @override
  void initState() {
    super.initState();
    _from = TextEditingController();
    _to = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final unit = weightUnitOf(context);
    final to = _conversion.convert(widget.fromKilograms);
    _from.text = formatDecimal(unit.fromKilograms(widget.fromKilograms));
    _to.text = formatDecimal(
      unit.fromKilograms(
        to == widget.fromKilograms ? to : roundToLoad(to, unit),
      ),
    );
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  /// The factor the two weights make; null while either is not a weight.
  double? get _factor {
    final unit = weightUnitOf(context);
    final from = parseDecimal(_from.text);
    final to = parseDecimal(_to.text);
    if (from == null || to == null || from <= 0 || to <= 0) return null;
    return _conversion.factorFor(
      fromKilograms: unit.toKilograms(from),
      toKilograms: unit.toKilograms(to),
    );
  }

  Future<void> _save() async {
    final factor = _factor;
    if (factor == null) {
      setState(() => _error = 'Enter both weights.');
      return;
    }
    if (factor < minGymFactor || factor > maxGymFactor) {
      setState(
        () => _error = 'One is more than twice the other. Check the weights.',
      );
      return;
    }
    await RepositoryScope.maybeOf(context)?.gyms
        .setExerciseFactor(_conversion.basisGym.id, widget.exerciseId, factor);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _useEstimate() async {
    await RepositoryScope.maybeOf(context)?.gyms
        .clearExerciseFactor(_conversion.basisGym.id, widget.exerciseId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final unit = weightUnitOf(context).symbol;
    final basis = _conversion.basis;
    final estimate = basis.estimate;
    final factor = _factor;
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    Widget field(TextEditingController controller, String label) => FTextField(
      control: FTextFieldControl.managed(
        controller: controller,
        onChange: (_) => setState(() => _error = null),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      suffixBuilder: (context, style, variants) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: Text(unit, style: muted),
      ),
    );

    return EditSheet(
      title: '${widget.exerciseName} at ${_conversion.basisGym.name}',
      description: 'Which weights feel the same at both gyms?',
      onAction: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: field(_from, 'At ${_conversion.from.name}')),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text('=', style: muted),
              ),
              Expanded(child: field(_to, 'At ${_conversion.to.name}')),
            ],
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 6),
            Text(
              error,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.destructive,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (factor != null)
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '×${fmtGym(factor)}  ',
                    style: theme.typography.body.lg.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: factorMeaning(
                      factor,
                      gym: _conversion.basisGym.name,
                      home: widget.homeName,
                      unit: weightUnitOf(context),
                    ),
                    style: theme.typography.body.sm,
                  ),
                ],
              ),
            ),
          if (basis.source == FactorSource.manual && estimate != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FButton(
                variant: .outline,
                size: .sm,
                mainAxisSize: .min,
                onPress: _useEstimate,
                child: Text('Use the estimate, ×${fmtGym(estimate)}'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Workouts at ${_conversion.basisGym.name} won\'t change a '
            'factor you set.',
            style: muted,
          ),
        ],
      ),
    );
  }
}

/// What [factor] at [gym] means, in weights: "100 kg at Hotel gym counts
/// as 90 kg at Iron Temple".
String factorMeaning(
  double factor, {
  required String gym,
  String? home,
  required WeightUnit unit,
}) {
  final hundred = unit == WeightUnit.kilograms ? 100.0 : 200.0;
  final symbol = unit.symbol;
  final atHome = formatDecimal((hundred * factor * 10).round() / 10);
  return '${formatDecimal(hundred)} $symbol at $gym counts as $atHome '
      '$symbol at ${home ?? 'your primary gym'}.';
}
