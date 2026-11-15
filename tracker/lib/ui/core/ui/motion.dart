import 'package:flutter/widgets.dart';

/// The app's shared timings and curves (`docs/MOTION.md`, M11) and its
/// reduced-motion switch (M12). Two things that answer the same action use
/// the same row.
abstract final class Motion {
  /// Press feedback: a tapped control dims or tints.
  static const press = Duration(milliseconds: 120);

  /// A label crossfading to its next words.
  static const label = Duration(milliseconds: 150);

  /// A state change in place: a row opens or folds, a tint, a tick.
  static const state = Duration(milliseconds: 220);

  /// A panel sliding in (the keypad, a sheet, a page).
  static const panelIn = Duration(milliseconds: 240);

  /// A panel sliding out.
  static const panelOut = Duration(milliseconds: 170);

  /// Room opening for something that arrives.
  static const roomIn = Duration(milliseconds: 320);

  /// Room closing behind something that leaves.
  static const roomOut = Duration(milliseconds: 240);

  /// What arrives eases into place.
  static const Curve enter = Curves.easeOutCubic;

  /// What leaves speeds up on its way out. On the reverse of a controller
  /// it is [enter] backwards, so a folding thing loses room exactly as fast
  /// as an opening one gains it.
  static const Curve exit = Curves.easeInCubic;

  /// Whether the platform asks for no animation.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or no time at all when the platform asks for no animation.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
