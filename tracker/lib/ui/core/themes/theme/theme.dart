import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

part 'colors.dart';
part 'icons.dart';
part 'style.dart';
part 'typography.dart';

FThemeData get lightTheme {
  const touch = true;

  final colors = lightColors;

  final typography = _typography(colors: colors, touch: touch);

  final icons = _icons();

  final style = _style(colors: colors, typography: typography, touch: touch);

  return FThemeData(
    colors: colors,
    typography: typography,
    icons: icons,
    style: style,
    touch: touch,
  );
}

FThemeData get darkTheme {
  const touch = true;

  final colors = darkColors;

  final typography = _typography(colors: colors, touch: touch);

  final icons = _icons();

  final style = _style(colors: colors, typography: typography, touch: touch);

  return FThemeData(
    colors: colors,
    typography: typography,
    icons: icons,
    style: style,
    touch: touch,
  );
}
