import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/ui/accent_button.dart';
import 'package:tracker/ui/core/ui/decimal_input_formatter.dart';

/// A key of [NumberKeypad]: a digit or '.', or one of the actions.
enum KeypadKey { digit, backspace, sign, next, hide }

/// Applies one keypad press to [controller]: the typed character replaces the
/// selection (the whole value right after focusing), backspace deletes, sign
/// flips a leading minus. The result passes through the same formatter as
/// typed input.
void applyKeypadKey(
  TextEditingController controller,
  KeypadKey key, {
  String digit = '',
  bool allowNegative = false,
}) {
  final old = controller.value;
  final text = old.text;
  final selection = old.selection.isValid
      ? old.selection
      : TextSelection.collapsed(offset: text.length);
  final start = selection.start;
  final end = selection.end;
  String next;
  int caret;
  switch (key) {
    case KeypadKey.digit:
      next = text.replaceRange(start, end, digit);
      caret = start + digit.length;
    case KeypadKey.backspace:
      if (start != end) {
        next = text.replaceRange(start, end, '');
        caret = start;
      } else if (start > 0) {
        next = text.replaceRange(start - 1, start, '');
        caret = start - 1;
      } else {
        return;
      }
    case KeypadKey.sign:
      if (!allowNegative) return;
      if (text.startsWith('-')) {
        next = text.substring(1);
        caret = (end - 1).clamp(0, next.length);
      } else {
        next = '-$text';
        caret = end + 1;
      }
    case KeypadKey.next:
    case KeypadKey.hide:
      return;
  }
  controller.value = DecimalInputFormatter(allowNegative: allowNegative)
      .formatEditUpdate(
        old,
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: caret),
        ),
      );
}

/// The in-app number keypad of the Keypad number entry: big keys, a sign key
/// for assisted machines, Next and a Log button that says what it saves.
class NumberKeypad extends StatelessWidget {
  const NumberKeypad({
    super.key,
    required this.caption,
    required this.onKey,
    required this.logLabel,
    required this.onLog,
    this.logTrailing,
    this.allowSign = true,
  });

  final String caption;
  final void Function(KeypadKey key, String digit) onKey;
  final String logLabel;

  /// The rating the set logs with, beside [logLabel].
  final String? logTrailing;
  final VoidCallback? onLog;
  final bool allowSign;

  /// Height of the panel without the bottom safe area, so pages can keep
  /// the focused row above it.
  static const double height = 340;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    Widget key(
      String label, {
      KeypadKey kind = KeypadKey.digit,
      IconData? icon,
      bool action = false,
      bool primary = false,
      bool enabled = true,
      String? semantics,
    }) {
      final background = primary
          ? colors.primary
          : action
          ? colors.background
          : colors.muted;
      final foreground = primary
          ? colors.primaryForeground
          : enabled
          ? colors.foreground
          : colors.mutedForeground;
      return FTappable(
        semanticsLabel: semantics ?? label,
        excludeSemantics: true,
        onPress: enabled ? () => onKey(kind, label) : null,
        builder: (context, states, child) => AnimatedOpacity(
          duration: const Duration(milliseconds: 80),
          opacity: states.contains(FTappableVariant.pressed) ? 0.6 : 1,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: action ? Border.all(color: colors.border) : null,
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, color: foreground, size: 20)
              : Text(
                  label,
                  style:
                      (action || primary
                              ? theme.typography.body.sm
                              : theme.typography.body.xl)
                          .copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                ),
        ),
      );
    }

    const gap = 6.0;
    const keyHeight = 48.0;
    Widget row(List<Widget> keys) => SizedBox(
      height: keyHeight,
      child: Row(
        children: <Widget>[
          for (final (i, k) in keys.indexed) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(flex: i == 3 ? 6 : 5, child: k),
          ],
        ],
      ),
    );

    return GestureDetector(
      // Swiping the panel down closes it, like the phone keyboard.
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 200) onKey(KeypadKey.hide, '');
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(top: BorderSide(color: colors.border)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, -6),
              spreadRadius: -12,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    caption,
                    style: theme.typography.body.xs.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
                row([
                  key('1'),
                  key('2'),
                  key('3'),
                  key(
                    '',
                    kind: KeypadKey.backspace,
                    icon: FLucideIcons.delete,
                    action: true,
                    semantics: 'Delete',
                  ),
                ]),
                const SizedBox(height: gap),
                row([
                  key('4'),
                  key('5'),
                  key('6'),
                  key(
                    '±',
                    kind: KeypadKey.sign,
                    action: true,
                    enabled: allowSign,
                    semantics: 'Negative weight',
                  ),
                ]),
                const SizedBox(height: gap),
                SizedBox(
                  height: keyHeight * 2 + gap,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        flex: 15,
                        child: Column(
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Expanded(child: key('7')),
                                  const SizedBox(width: gap),
                                  Expanded(child: key('8')),
                                  const SizedBox(width: gap),
                                  Expanded(child: key('9')),
                                ],
                              ),
                            ),
                            const SizedBox(height: gap),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Expanded(child: key('.')),
                                  const SizedBox(width: gap),
                                  Expanded(child: key('0')),
                                  const SizedBox(width: gap),
                                  Expanded(
                                    child: key(
                                      '',
                                      kind: KeypadKey.hide,
                                      icon: FLucideIcons.chevronDown,
                                      action: true,
                                      semantics: 'Close keypad',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: gap),
                      Expanded(
                        flex: 6,
                        child: key('Next', kind: KeypadKey.next, primary: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AccentButton(
                  large: true,
                  prefix: FLucideIcons.check,
                  label: logLabel,
                  trailing: logTrailing,
                  onPress: onLog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar the Phone keyboard number entry shows on top of the keyboard,
/// which covers the page's Log button: sign, Next and Log.
class KeyboardToolbar extends StatelessWidget {
  const KeyboardToolbar({
    super.key,
    required this.onSign,
    required this.onNext,
    required this.logLabel,
    required this.onLog,
    this.logTrailing,
  });

  final VoidCallback? onSign;
  final VoidCallback onNext;
  final String logLabel;

  /// The rating the set logs with, beside [logLabel].
  final String? logTrailing;
  final VoidCallback? onLog;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: <Widget>[
          FButton(
            variant: .outline,
            size: .sm,
            mainAxisSize: .min,
            onPress: onSign,
            semanticsTooltip: 'Negative weight',
            child: const Text('±'),
          ),
          const Spacer(),
          FButton(
            variant: .outline,
            size: .sm,
            mainAxisSize: .min,
            onPress: onNext,
            child: const Text('Next'),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: AccentButton(
              prefix: FLucideIcons.check,
              label: logLabel,
              trailing: logTrailing,
              onPress: onLog,
            ),
          ),
        ],
      ),
    );
  }
}
