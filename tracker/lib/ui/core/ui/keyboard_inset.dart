import 'package:flutter/widgets.dart';

/// Height of the on-screen keyboard (the bottom view inset).
///
/// Both shell Scaffolds (`main.dart` FScaffold and the HomePage Scaffold)
/// opt out of `resizeToAvoidBottomInset`, so the shell (app bar, tab bar,
/// backgrounds) never jumps when the keyboard opens; the keyboard simply
/// overlays it. Scrollables that host text fields
/// instead add this inset to their bottom padding, so the focused field and
/// trailing actions can always scroll above the keyboard. Flutter auto-scrolls
/// a focused field into view, which only lands above the keyboard once this
/// padding exists.
double keyboardInsetOf(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom;
