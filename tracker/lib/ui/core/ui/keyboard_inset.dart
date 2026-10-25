import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Breathing room kept between a revealed widget and the keyboard's top edge.
///
/// Used twice, on purpose with the same value: a focused field's caret reveal
/// overshoots by this much ([keyboardAwareFieldReveal] grows the field's
/// scroll padding), and scrollables pad their content by it
/// ([keyboardClearanceOf]) so the reveal always has the scroll room to reach
/// that gap - even for the last item, where the scroll offset would otherwise
/// clamp and leave the widget flush against the keyboard.
///
/// 32 leaves the text line 32px above the keyboard and the input box itself
/// roughly 20px above it (the field's internal bottom padding eats into the
/// visual gap), which reads as clearly separated rather than touching.
const double kKeyboardRevealGap = 40;

/// Height of the on-screen keyboard (the bottom view inset).
///
/// Both shell Scaffolds (`main.dart` FScaffold and the HomePage Scaffold)
/// opt out of `resizeToAvoidBottomInset`, so the shell (app bar, tab bar,
/// backgrounds) never jumps when the keyboard opens; the keyboard simply
/// overlays it. Scrollables that host text fields instead pad their content
/// by [keyboardClearanceOf], so the focused field and trailing actions have
/// the scroll room to move above the keyboard.
double keyboardInsetOf(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom;

/// Bottom padding a scrollable should add for keyboard clearance: the
/// keyboard's height plus [kKeyboardRevealGap], so content never rests
/// directly against the keyboard's top edge.
double keyboardClearanceOf(BuildContext context) =>
    keyboardInsetOf(context) + kKeyboardRevealGap;

/// Returns [theme] with every text field's scroll padding grown by the
/// keyboard height plus [kKeyboardRevealGap].
///
/// When a field gains focus (or the keyboard opens under it), Flutter reveals
/// the caret by scrolling only until the caret clears the scrollable's own
/// bounds. Since the shell does not resize for the keyboard, those bounds
/// still end at the screen bottom, so the default 20px reveal margin leaves
/// the field hidden behind the keyboard. Growing the field's
/// `scrollPadding.bottom` by the keyboard height plus the gap makes the
/// reveal overshoot by exactly that much, landing the field [kKeyboardRevealGap]
/// above the keyboard. The matching padding from [keyboardClearanceOf] on the
/// page's scrollables supplies the scroll room the overshoot needs.
///
/// Applied app-wide in `MyApp`'s builder so every route (tab roots, pushed
/// pages, bottom sheets) inherits it without each field opting in. Dialogs
/// don't need it (FDialog already keeps their content above the keyboard);
/// there the larger padding can at worst scroll a focused field a little
/// higher than necessary inside a tall, scrollable dialog.
FThemeData keyboardAwareFieldReveal(FThemeData theme, double keyboardInset) {
  if (keyboardInset <= 0) return theme;
  return theme.copyWith(
    textFieldStyles: theme.textFieldStyles.apply([
      .all(
        .delta(
          scrollPadding: EdgeInsetsDelta.add(
            bottom: keyboardInset + kKeyboardRevealGap,
          ),
        ),
      ),
    ]),
  );
}
