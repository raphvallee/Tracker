import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// The two accents layered on the neutral Forui theme, each with one job:
/// blue marks a live workout and the actions that start one, amber marks
/// split edits that are not saved yet.
class TrackerAccents {
  const TrackerAccents._({
    required this.live,
    required this.liveForeground,
    required this.liveSoft,
    required this.draft,
    required this.draftSoft,
    required this.draftInk,
    required this.draftLine,
  });

  /// Fills (Start, Log, checks), the timer and the current-set outline.
  final Color live;

  /// Text and icons on [live].
  final Color liveForeground;

  /// Background of logged set rows.
  final Color liveSoft;

  /// Dots and outlines of changed set chips.
  final Color draft;

  /// Background of "Edited" tags, changed chips and the unsaved strip.
  final Color draftSoft;

  /// Text on [draftSoft].
  final Color draftInk;

  /// Border of edited exercise blocks.
  final Color draftLine;

  static const _light = TrackerAccents._(
    live: Color(0xFF1E4FD6),
    liveForeground: Color(0xFFFFFFFF),
    liveSoft: Color(0xFFEBF0FD),
    draft: Color(0xFFD97706),
    draftSoft: Color(0xFFFEF3C7),
    draftInk: Color(0xFF92400E),
    draftLine: Color(0xFFF1CD83),
  );

  static const _dark = TrackerAccents._(
    live: Color(0xFF7096FF),
    liveForeground: Color(0xFF0A0A0A),
    liveSoft: Color(0xFF16213D),
    draft: Color(0xFFF59E0B),
    draftSoft: Color(0xFF3A2A0C),
    draftInk: Color(0xFFFCD34D),
    draftLine: Color(0xFF6B4E16),
  );

  static TrackerAccents of(BuildContext context) =>
      context.theme.colors.brightness == Brightness.dark ? _dark : _light;
}
