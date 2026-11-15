import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/weight_unit.dart';
import 'package:tracker/domain/models/workout_set.dart';
import 'package:tracker/domain/services/gym_equivalence.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

import 'exercise_at_gym.dart';
import 'gym_factor_sheet.dart';
import 'gym_picker.dart';

/// Last time's top set at another gym and what it comes to here: the weight
/// converted by the machine's factors, the range it likely sits in, where
/// the factor comes from, and Adjust to set it by hand.
class GymConversionCard extends StatelessWidget {
  const GymConversionCard({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.top,
    required this.date,
    required this.conversion,
    this.homeName,
  });

  final int exerciseId;
  final String exerciseName;

  /// Last time's top set, as logged at [GymConversion.from].
  final WorkoutSet top;
  final DateTime date;
  final GymConversion conversion;
  final String? homeName;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final unit = weightUnitOf(context);
    final label = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    String shown(double kilograms) =>
        formatDecimal(unit.fromKilograms(kilograms));
    final here = convertedLoad(conversion, top.weight, unit);
    final range = conversion.rangeOf(top.weight);
    final low = roundToLoad(range.low, unit);
    final high = roundToLoad(range.high, unit);
    return Semantics(
      container: true,
      label:
          'Last time ${shown(top.weight)} ${unit.symbol} at '
          '${conversion.from.name}, about ${shown(here)} ${unit.symbol} here',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: accents.liveSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Last time', style: label),
                        const SizedBox(height: 2),
                        Text(
                          '${shown(top.weight)} ${unit.symbol} × '
                          '${formatReps(top.reps)}',
                          style: theme.typography.body.md.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          '${conversion.from.name}, ${dayLabel(date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: label,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 18, 10, 0),
                    child: Icon(
                      FLucideIcons.arrowRight,
                      size: 18,
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Here', style: label),
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '≈ ',
                                style: theme.typography.body.lg.copyWith(
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                              TextSpan(
                                text: shown(here),
                                style: theme.typography.body.xl2.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              TextSpan(
                                text: ' ${unit.symbol}',
                                style: theme.typography.body.sm,
                              ),
                            ],
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (low < high)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ExcludeSemantics(
                  child: _RangeBar(
                    low: shown(low),
                    value: shown(here),
                    high: shown(high),
                    at: high == low ? 0.5 : ((here - low) / (high - low)),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    conversionSourceLabel(conversion),
                    style: theme.typography.body.xs,
                  ),
                ),
                const SizedBox(width: 8),
                FButton(
                  variant: .outline,
                  size: .sm,
                  mainAxisSize: .min,
                  onPress: () => showGymFactorSheet(
                    context,
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    conversion: conversion,
                    fromKilograms: top.weight,
                    homeName: homeName,
                  ),
                  child: const Text('Adjust'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the factor a conversion hangs on comes from: "Hotel gym ×0.90,
/// from 6 workouts", "set by you", or the gym's overall factor.
String conversionSourceLabel(GymConversion conversion) {
  final factor = conversion.basis;
  final gym = conversion.basisGym.name;
  final value = '×${fmtGym(factor.value)}';
  return switch (factor.source) {
    FactorSource.manual => '$gym $value, set by you',
    FactorSource.estimated =>
      factor.samples == 0
          ? '$gym $value, estimated'
          : '$gym $value, from ${plural('workout', factor.samples)}',
    FactorSource.gym =>
      factor.value == 1
          ? 'Nothing to compare at $gym yet'
          : '$gym $value, its overall factor',
    FactorSource.home => gym,
  };
}

/// The likely range, its ends and the guess marked on a track.
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.low,
    required this.value,
    required this.high,
    required this.at,
  });

  final String low;
  final String value;
  final String high;

  /// Where the guess sits between the ends, 0 to 1.
  final double at;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final tick = theme.typography.body.xs3.copyWith(
      color: theme.colors.mutedForeground,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // The band takes the middle 40% of the track, the guess inside it.
    const start = 0.3;
    const span = 0.4;
    return SizedBox(
      height: 32,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          Widget label(String text, double x, TextStyle style) => Positioned(
            left: x * width - 30,
            width: 60,
            top: 16,
            child: Text(text, textAlign: TextAlign.center, style: style),
          );
          final dot = start + span * at.clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: 5,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accents.live.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                left: start * width,
                width: span * width,
                top: 3,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accents.live.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: dot * width - 7,
                top: 0,
                width: 14,
                height: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accents.live,
                    shape: BoxShape.circle,
                    border: Border.all(color: accents.liveSoft, width: 2),
                  ),
                ),
              ),
              label(low, start, tick),
              label(
                value,
                dot,
                tick.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              label(high, start + span, tick),
            ],
          );
        },
      ),
    );
  }
}
