import 'package:tracker/ui/core/ui/weight_format.dart';

/// How a set compares with the same set last time.
class SetComparison {
  const SetComparison(this.text, {required this.isAhead});

  /// "2.5 kg and 1 rep more than last time".
  final String text;

  /// Nothing went down: the set matches or beats last time on both counts.
  final bool isAhead;
}

/// Compares a set with the one at its place last time. Weights are in the
/// displayed unit, named by [unit]. Null when both values are the same.
SetComparison? compareWithLast({
  required double weight,
  required double reps,
  required double lastWeight,
  required double lastReps,
  required String unit,
}) {
  // Two decimals is all the fields hold: no float dust in the difference.
  double diff(double now, double last) =>
      ((now - last) * 100).roundToDouble() / 100;
  final byWeight = diff(weight, lastWeight);
  final byReps = diff(reps, lastReps);
  if (byWeight == 0 && byReps == 0) return null;

  final weightPart = '${formatDecimal(byWeight.abs())} $unit';
  final repsPart =
      '${formatDecimal(byReps.abs())} ${byReps.abs() == 1 ? 'rep' : 'reps'}';
  final String text;
  if (byReps == 0) {
    text = '$weightPart ${byWeight > 0 ? 'more' : 'less'} than last time';
  } else if (byWeight == 0) {
    text = '$repsPart ${byReps > 0 ? 'more' : 'fewer'} than last time';
  } else if (byWeight > 0 == byReps > 0) {
    text =
        '$weightPart and $repsPart ${byWeight > 0 ? 'more' : 'less'} '
        'than last time';
  } else {
    text =
        '$weightPart ${byWeight > 0 ? 'more' : 'less'}, '
        '$repsPart ${byReps > 0 ? 'more' : 'fewer'} than last time';
  }
  return SetComparison(text, isAhead: byWeight >= 0 && byReps >= 0);
}
