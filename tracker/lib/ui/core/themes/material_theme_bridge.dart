import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:tracker/ui/core/themes/accents.dart';

extension FThemeMaterialBridge on FThemeData {
  ThemeData toCustomMaterialTheme() {
    final textTheme = TextTheme(
      displayLarge: typography.display.xl4.copyWith(
        height: 1,
        textBaseline: typography.display.xl4.textBaseline ?? .alphabetic,
      ),
      displayMedium: typography.display.xl3.copyWith(
        height: 1,
        textBaseline: typography.display.xl3.textBaseline ?? .alphabetic,
      ),
      displaySmall: typography.display.xl2.copyWith(
        height: 1,
        textBaseline: typography.display.xl2.textBaseline ?? .alphabetic,
      ),
      headlineLarge: typography.display.xl3.copyWith(
        height: 1,
        textBaseline: typography.display.xl3.textBaseline ?? .alphabetic,
      ),
      headlineMedium: typography.display.xl2.copyWith(
        height: 1,
        textBaseline: typography.display.xl2.textBaseline ?? .alphabetic,
      ),
      headlineSmall: typography.display.xl.copyWith(
        height: 1,
        textBaseline: typography.display.xl.textBaseline ?? .alphabetic,
      ),
      titleLarge: typography.body.lg.copyWith(
        height: 1,
        textBaseline: typography.body.lg.textBaseline ?? .alphabetic,
      ),
      titleMedium: typography.body.md.copyWith(
        height: 1,
        textBaseline: typography.body.md.textBaseline ?? .alphabetic,
      ),
      titleSmall: typography.body.sm.copyWith(
        height: 1,
        textBaseline: typography.body.sm.textBaseline ?? .alphabetic,
      ),
      labelLarge: typography.body.md.copyWith(
        height: 1,
        textBaseline: typography.body.md.textBaseline ?? .alphabetic,
      ),
      labelMedium: typography.body.sm.copyWith(
        height: 1,
        textBaseline: typography.body.sm.textBaseline ?? .alphabetic,
      ),
      labelSmall: typography.body.xs.copyWith(
        height: 1,
        textBaseline: typography.body.xs.textBaseline ?? .alphabetic,
      ),
      bodyLarge: typography.body.md.copyWith(
        height: 1,
        textBaseline: typography.body.md.textBaseline ?? .alphabetic,
      ),
      bodyMedium: typography.body.sm.copyWith(
        height: 1,
        textBaseline: typography.body.sm.textBaseline ?? .alphabetic,
      ),
      bodySmall: typography.body.xs.copyWith(
        height: 1,
        textBaseline: typography.body.xs.textBaseline ?? .alphabetic,
      ),
    )..apply(bodyColor: colors.foreground, displayColor: colors.foreground);
    return ThemeData(
      colorScheme: ColorScheme(
        brightness: colors.brightness,
        primary: colors.primary,
        onPrimary: colors.primaryForeground,
        secondary: colors.secondary,
        onSecondary: colors.secondaryForeground,
        error: colors.error,
        onError: colors.errorForeground,
        surface: colors.background,
        onSurface: colors.foreground,
        secondaryContainer: colors.secondary,
        onSecondaryContainer: colors.secondaryForeground,
      ),
      fontFamily: typography.body.fontFamily,
      fontFamilyFallback: typography.body.fontFamilyFallback,
      typography: Typography(
        black: textTheme,
        white: textTheme,
        englishLike: textTheme,
        dense: textTheme,
        tall: textTheme,
      ),
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      useMaterial3: true,
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedSuperellipseBorder(
          borderRadius: style.borderRadius.md,
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        indicatorShape: RoundedSuperellipseBorder(
          borderRadius: style.borderRadius.md,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorShape: RoundedSuperellipseBorder(
          borderRadius: style.borderRadius.md,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedSuperellipseBorder(
          borderRadius: style.borderRadius.md,
          side: BorderSide(color: colors.border, width: style.borderWidth),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: textFieldStyles.md.descriptionTextStyle.base,
        floatingLabelStyle: textFieldStyles.md.labelTextStyle.base,
        hintStyle: textFieldStyles.md.hintTextStyle.base,
        errorStyle: textFieldStyles.md.errorTextStyle.base,
        helperStyle: textFieldStyles.md.descriptionTextStyle.base,
        counterStyle: textFieldStyles.md.counterTextStyle.base,
        contentPadding: textFieldStyles.md.contentPadding,
      ),
      datePickerTheme: DatePickerThemeData(
        shape: RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
        dayShape: .all(
          RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
        ),
        rangePickerShape: RoundedSuperellipseBorder(
          borderRadius: style.borderRadius.md,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        hourMinuteTextColor: colors.secondaryForeground,
        hourMinuteColor: colors.secondary,
        hourMinuteShape: RoundedSuperellipseBorder(
          borderRadius: style.borderRadius.md,
        ),
        dayPeriodTextColor: colors.foreground,
        dayPeriodColor: colors.secondary,
        dayPeriodBorderSide: BorderSide(color: colors.border),
        dayPeriodShape: RoundedSuperellipseBorder(
          borderRadius: style.borderRadius.md,
        ),
        dialBackgroundColor: colors.secondary,
        shape: RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: sliderStyles.horizontal.activeColor.base,
        inactiveTrackColor: sliderStyles.horizontal.inactiveColor.base,
        disabledActiveTrackColor: sliderStyles.horizontal.activeColor.resolve({
          FSliderVariant.disabled,
        }),
        disabledInactiveTrackColor: sliderStyles.horizontal.inactiveColor
            .resolve({FSliderVariant.disabled}),
        activeTickMarkColor: sliderStyles.horizontal.markStyle.tickColor.base,
        inactiveTickMarkColor: sliderStyles.horizontal.markStyle.tickColor.base,
        disabledActiveTickMarkColor: sliderStyles.horizontal.markStyle.tickColor
            .resolve({FSliderVariant.disabled}),
        disabledInactiveTickMarkColor: sliderStyles
            .horizontal
            .markStyle
            .tickColor
            .resolve({FSliderVariant.disabled}),
        thumbColor: sliderStyles.horizontal.thumbStyle.borderColor.base,
        disabledThumbColor: sliderStyles.horizontal.thumbStyle.borderColor
            .resolve({FSliderVariant.disabled}),
        valueIndicatorColor:
            sliderStyles.horizontal.tooltipStyle.decoration.color,
        valueIndicatorTextStyle: sliderStyles.horizontal.tooltipStyle.textStyle,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: .resolveWith(
          (states) => switchStyle.thumbColor.resolve(toVariants(states)),
        ),
        trackColor: .resolveWith(
          (states) => switchStyle.trackColor.resolve(toVariants(states)),
        ),
        trackOutlineColor: .resolveWith(
          (states) => switchStyle.trackColor.resolve(toVariants(states)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          textStyle: .resolveWith(
            (states) => buttonStyles.secondary.base.contentStyle.textStyle
                .resolve(toVariants(states)),
          ),
          backgroundColor: .resolveWith(
            (states) =>
                buttonStyles.secondary.base.decoration
                    .resolve(toVariants(states))
                    .color ??
                colors.secondary,
          ),
          foregroundColor: .resolveWith(
            (states) =>
                buttonStyles.secondary.base.contentStyle.textStyle
                    .resolve(toVariants(states))
                    .color ??
                colors.secondaryForeground,
          ),
          padding: .all(buttonStyles.secondary.base.contentStyle.padding),
          shape: .all(
            RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          textStyle: .resolveWith(
            (states) => buttonStyles.primary.base.contentStyle.textStyle
                .resolve(toVariants(states)),
          ),
          backgroundColor: .resolveWith(
            (states) =>
                buttonStyles.primary.base.decoration
                    .resolve(toVariants(states))
                    .color ??
                colors.secondary,
          ),
          foregroundColor: .resolveWith(
            (states) =>
                buttonStyles.secondary.base.contentStyle.textStyle
                    .resolve(toVariants(states))
                    .color ??
                colors.secondaryForeground,
          ),
          padding: .all(buttonStyles.primary.base.contentStyle.padding),
          shape: .all(
            RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          textStyle: .resolveWith(
            (states) => buttonStyles.outline.base.contentStyle.textStyle
                .resolve(toVariants(states)),
          ),
          backgroundColor: .resolveWith(
            (states) =>
                buttonStyles.outline.base.decoration
                    .resolve(toVariants(states))
                    .color ??
                Colors.transparent,
          ),
          foregroundColor: .resolveWith(
            (states) =>
                buttonStyles.outline.base.contentStyle.textStyle
                    .resolve(toVariants(states))
                    .color ??
                Colors.transparent,
          ),
          padding: .all(buttonStyles.outline.base.contentStyle.padding),
          side: .resolveWith((states) {
            final border = buttonStyles.outline.base.decoration
                .resolve(toVariants(states))
                .border;
            final side = switch (border) {
              OutlinedBorder(:final side) || BoxBorder(top: final side) => side,
              _ => null,
            };
            return BorderSide(
              color:
                  side?.color ??
                  switch (states) {
                    _ when states.contains(WidgetState.disabled) =>
                      colors.disable(colors.border),
                    _ when states.contains(WidgetState.hovered) => colors.hover(
                      colors.border,
                    ),
                    _ => colors.border,
                  },
              width: side?.width ?? style.borderWidth,
            );
          }),
          shape: .resolveWith(
            (states) => switch (buttonStyles.outline.base.decoration
                .resolve(toVariants(states))
                .border) {
              final OutlinedBorder border => border,
              _ => RoundedSuperellipseBorder(
                borderRadius: style.borderRadius.md,
              ),
            },
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          textStyle: .resolveWith(
            (states) => buttonStyles.ghost.base.contentStyle.textStyle.resolve(
              toVariants(states),
            ),
          ),
          backgroundColor: .resolveWith(
            (states) =>
                buttonStyles.ghost.base.decoration
                    .resolve(toVariants(states))
                    .color ??
                Colors.transparent,
          ),
          foregroundColor: .resolveWith(
            (states) =>
                buttonStyles.ghost.base.contentStyle.textStyle
                    .resolve(toVariants(states))
                    .color ??
                colors.secondaryForeground,
          ),
          shape: .resolveWith(
            (states) => switch (buttonStyles.ghost.base.decoration
                .resolve(toVariants(states))
                .border) {
              final OutlinedBorder border => border,
              _ => RoundedSuperellipseBorder(
                borderRadius: style.borderRadius.md,
              ),
            },
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonStyles.primary.base.decoration.base.color,
        foregroundColor:
            buttonStyles.primary.base.contentStyle.textStyle.base.color,
        hoverColor: buttonStyles.primary.base.decoration.resolve({
          FTappableVariant.hovered,
        }).color,
        disabledElevation: 0,
        shape: switch (buttonStyles.primary.base.decoration.base.border) {
          final OutlinedBorder border => border,
          _ => RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
        },
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          backgroundColor: .resolveWith(
            (states) =>
                buttonStyles.ghost.base.decoration
                    .resolve(toVariants(states))
                    .color ??
                Colors.transparent,
          ),
          foregroundColor: .resolveWith(
            (states) =>
                buttonStyles.ghost.base.contentStyle.textStyle
                    .resolve(toVariants(states))
                    .color ??
                colors.secondaryForeground,
          ),
          shape: .resolveWith(
            (states) => switch (buttonStyles.ghost.base.decoration
                .resolve(toVariants(states))
                .border) {
              final OutlinedBorder border => border,
              _ => RoundedSuperellipseBorder(
                borderRadius: style.borderRadius.md,
              ),
            },
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: .resolveWith(
            (states) => buttonStyles.ghost.base.contentStyle.textStyle.resolve(
              toVariants(states),
            ),
          ),
          backgroundColor: .resolveWith(
            (states) =>
                buttonStyles.ghost.base.decoration
                    .resolve(toVariants(states))
                    .color ??
                Colors.transparent,
          ),
          foregroundColor: .resolveWith(
            (states) =>
                buttonStyles.ghost.base.contentStyle.textStyle
                    .resolve(toVariants(states))
                    .color ??
                colors.secondaryForeground,
          ),
          shape: .resolveWith(
            (states) => switch (buttonStyles.ghost.base.decoration
                .resolve(toVariants(states))
                .border) {
              final OutlinedBorder border => border,
              _ => RoundedSuperellipseBorder(
                borderRadius: style.borderRadius.md,
              ),
            },
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
      ),
      snackBarTheme: SnackBarThemeData(
        shape: RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedSuperellipseBorder(borderRadius: style.borderRadius.md),
      ),
      dividerTheme: DividerThemeData(
        color: dividerStyles.horizontal.color,
        thickness: dividerStyles.horizontal.width,
      ),
      iconTheme: IconThemeData(color: colors.primary, size: 20),
    );
  }
}

/// Bottom nav labels readable at rest, and the selected tab in the blue
/// accent: the only colored tab is the one showing.
FThemeData strengthenNavLabels(FThemeData data) {
  final inactive = data.colors.brightness == Brightness.light
      ? const Color(0xFF525252)
      : const Color(0xFFD4D4D4);
  final selected = TrackerAccents.forBrightness(data.colors.brightness).live;
  final itemStyle = data.bottomNavigationBarStyle.itemStyle;
  return data.copyWith(
    bottomNavigationBarStyle: data.bottomNavigationBarStyle.copyWith(
      itemStyle: itemStyle.copyWith(
        iconStyle: itemStyle.iconStyle.apply([
          FVariantOperation.base(IconThemeDataDelta.delta(color: inactive)),
          FVariantOperation.match({
            FTappableVariant.selected,
          }, IconThemeDataDelta.delta(color: selected)),
        ]),
        textStyle: itemStyle.textStyle.apply([
          FVariantOperation.base(TextStyleDelta.delta(color: inactive)),
          FVariantOperation.match({
            FTappableVariant.selected,
          }, TextStyleDelta.delta(color: selected)),
        ]),
      ),
    ),
  );
}
