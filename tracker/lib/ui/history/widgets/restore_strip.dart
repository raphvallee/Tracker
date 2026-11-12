import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/relative_dates.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

/// A discarded workout that can still come back: what it was, when it was
/// discarded and what it had logged. Restore is in the live accent: it makes
/// the workout the running one again.
class RestoreStrip extends StatelessWidget {
  const RestoreStrip({
    super.key,
    required this.title,
    required this.discardedAt,
    required this.sets,
    required this.onRestore,
  });

  final String title;
  final DateTime discardedAt;

  /// Sets it had logged, warm-ups included.
  final int sets;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final accents = TrackerAccents.of(context);
    final day = dayLabel(discardedAt);
    final when =
        '${day[0].toUpperCase()}${day.substring(1)} at '
        '${timeLabel(discardedAt)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: accents.liveSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accents.live.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$title was discarded',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$when, ${plural('set', sets)} logged',
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FTappable(
            semanticsLabel: 'Restore $title',
            onPress: onRestore,
            builder: (context, states, child) => AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: states.contains(FTappableVariant.pressed) ? 0.85 : 1,
              child: child,
            ),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: accents.live,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    FLucideIcons.rotateCcw,
                    size: 15,
                    color: accents.liveForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Restore',
                    style: theme.typography.body.xs.copyWith(
                      color: accents.liveForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
