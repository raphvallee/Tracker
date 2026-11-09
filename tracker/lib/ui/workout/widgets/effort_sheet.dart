import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/domain/models/effort_scale.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/sheet_surface.dart';

/// What the effort sheet hands back: the rating picked, as RPE, or null to
/// clear it.
class EffortChoice {
  const EffortChoice(this.rpe);

  final double? rpe;
}

/// Asks how hard a set was on [scale], from 0 to 10: one tap picks and
/// closes. [rpe] is the set's rating so far. Null when dismissed.
Future<EffortChoice?> showEffortSheet(
  BuildContext context, {
  required String title,
  required EffortScale scale,
  double? rpe,
}) {
  return showFSheet<EffortChoice>(
    context: context,
    side: .btt,
    useRootNavigator: true,
    mainAxisMaxRatio: 0.85,
    builder: (sheetContext) =>
        _EffortSheet(title: title, scale: scale, rpe: rpe),
  );
}

class _EffortSheet extends StatelessWidget {
  const _EffortSheet({required this.title, required this.scale, this.rpe});

  final String title;
  final EffortScale scale;
  final double? rpe;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final muted = theme.typography.body.xs.copyWith(
      color: theme.colors.mutedForeground,
    );
    final current = rpe == null ? null : scale.fromRpe(rpe!);

    Widget value(int n) {
      final selected = current == n;
      return FTappable(
        semanticsLabel: '${scale.label} $n',
        selected: selected,
        onPress: () =>
            Navigator.of(context).pop(EffortChoice(scale.toRpe(n.toDouble()))),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accents.live : theme.colors.muted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$n',
            style: theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? accents.liveForeground : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }

    // Six even columns: 0 to 5, then 6 to 10 nearer the thumb.
    Widget row(int from, int to) => Row(
      children: <Widget>[
        for (var n = from; n < from + 6; n++) ...[
          if (n > from) const SizedBox(width: 6),
          Expanded(child: n <= to ? value(n) : const SizedBox.shrink()),
        ],
      ],
    );

    return SheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: theme.typography.body.lg.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text('${scale.title}, from 0 to 10', style: muted),
          const SizedBox(height: 14),
          row(0, 5),
          const SizedBox(height: 6),
          row(6, 10),
          const SizedBox(height: 12),
          Text(
            scale == EffortScale.rpe
                ? '10 is a set taken to failure. 8 leaves about 2 reps in '
                      'the tank.'
                : 'How many more reps you had in you. 0 is a set taken to '
                      'failure.',
            style: muted,
          ),
          if (rpe != null) ...[
            const SizedBox(height: 10),
            FButton(
              variant: .ghost,
              onPress: () =>
                  Navigator.of(context).pop(const EffortChoice(null)),
              child: const Text('Clear rating'),
            ),
          ],
        ],
      ),
    );
  }
}
