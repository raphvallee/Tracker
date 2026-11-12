import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/effort_format.dart';

/// An open set row's rating in one tap: the usual values in a strip, the
/// rest behind its last chip ([onMore], the full sheet). Tapping the picked
/// value again clears it. It stays quiet: the numbers are what the row is
/// about.
class EffortStrip extends StatelessWidget {
  const EffortStrip({
    super.key,
    required this.scale,
    required this.rpe,
    required this.who,
    required this.onRate,
    required this.onMore,
    this.live = true,
  });

  final EffortScale scale;

  /// The set's rating so far, as RPE.
  final double? rpe;

  /// Whose rating it is, for screen readers: "set 2", "warm-up".
  final String who;

  /// A value picked (as RPE), or null to clear the rating.
  final ValueChanged<double?> onRate;
  final VoidCallback onMore;

  /// The picked value in the live accent, on a running workout; false
  /// marks it in ink.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final picked = rpe == null ? null : scale.fromRpe(rpe!);
    // RPE 6 to 10 (RIR 4 to 0) cover nearly every set worth rating.
    final common = scale == EffortScale.rpe
        ? const [6, 7, 8, 9, 10]
        : const [0, 1, 2, 3, 4];
    final rarePicked = picked != null && !common.any((v) => v == picked);
    final selectedFill = live ? accents.liveSoft : theme.colors.foreground;
    final selectedText = live ? accents.live : theme.colors.background;

    Widget chip(
      String label, {
      required bool selected,
      required String semantics,
      required VoidCallback onTap,
    }) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: semantics,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? selectedFill : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? selectedFill : theme.colors.border,
              ),
            ),
            child: Text(
              label,
              style: theme.typography.body.xs.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? selectedText : theme.colors.mutedForeground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );

    final rare = chip(
      rarePicked
          ? formatEffort(scale, rpe!)
          : (scale == EffortScale.rpe ? '<6' : '5+'),
      selected: rarePicked,
      semantics: 'Rate $who, other ${scale.label} values',
      onTap: onMore,
    );
    final chips = <Widget>[
      for (final value in common)
        chip(
          '$value',
          selected: picked == value,
          semantics: 'Rate $who ${scale.label} $value',
          onTap: () =>
              onRate(picked == value ? null : scale.toRpe(value.toDouble())),
        ),
    ];
    return Row(
      children: <Widget>[
        SizedBox(
          width: 34,
          child: Text(
            scale.label,
            style: theme.typography.body.xs3.copyWith(
              color: theme.colors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final (i, item) in [
          if (scale == EffortScale.rpe) rare,
          ...chips,
          if (scale == EffortScale.rir) rare,
        ].indexed) ...[if (i > 0) const SizedBox(width: 5), item],
      ],
    );
  }
}
