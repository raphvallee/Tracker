import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/themes/accents.dart';

/// The unsaved accent's dot: there are edits that are not saved yet.
class DraftDot extends StatelessWidget {
  const DraftDot({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: TrackerAccents.of(context).draft,
    ),
  );
}

/// A tag beside a day, an exercise or a set: "New" or "Edited".
class DraftTag extends StatelessWidget {
  const DraftTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accents = TrackerAccents.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: accents.draftSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.theme.typography.body.xs3.copyWith(
          color: accents.draftInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
