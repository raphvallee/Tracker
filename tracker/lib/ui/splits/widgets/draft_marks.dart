import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/themes/accents.dart';
import 'package:tracker/ui/core/ui/draft_tag.dart';
import 'package:tracker/ui/core/ui/weight_format.dart';

export 'package:tracker/ui/core/ui/draft_tag.dart';

/// "5 unsaved changes" with a Review button, in the unsaved accent.
class DraftStrip extends StatelessWidget {
  const DraftStrip({super.key, required this.count, required this.onReview});

  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final accents = TrackerAccents.of(context);
    final text = context.theme.typography.body.xs.copyWith(
      color: accents.draftInk,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: accents.draftSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const DraftDot(),
          const SizedBox(width: 8),
          Expanded(child: Text(plural('unsaved change', count), style: text)),
          FTappable(
            onPress: onReview,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: accents.draftLine),
              ),
              child: Text('Review', style: text),
            ),
          ),
        ],
      ),
    );
  }
}

/// A day or exercise removed in the draft, struck through until the draft
/// is saved, with a way back.
class RemovedRow extends StatelessWidget {
  const RemovedRow({
    super.key,
    required this.label,
    required this.onRestore,
    this.boxed = false,
  });

  final String label;
  final VoidCallback onRestore;

  /// Its own outlined box, instead of a divided row inside a list.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final muted = theme.colors.mutedForeground;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        borderRadius: boxed ? BorderRadius.circular(12) : null,
        border: boxed
            ? Border.all(color: theme.colors.border)
            : Border(bottom: BorderSide(color: theme.colors.border)),
      ),
      child: Row(
        children: <Widget>[
          Icon(FLucideIcons.minus, size: 16, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const TextSpan(text: '  removed'),
                ],
              ),
              style: theme.typography.body.xs.copyWith(color: muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FButton(
            variant: .ghost,
            size: .sm,
            mainAxisSize: .min,
            onPress: onRestore,
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
