// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

abstract class FluffyThemes {
  static const double columnWidth = 380.0;

  static const double maxTimelineWidth = columnWidth * 2;

  static const double navRailWidth = 80.0;

  static bool isColumnModeByWidth(double width) =>
      width > columnWidth * 2 + navRailWidth;

  static bool isColumnMode(BuildContext context) =>
      isColumnModeByWidth(MediaQuery.sizeOf(context).width);

  static bool isThreeColumnMode(BuildContext context) =>
      MediaQuery.sizeOf(context).width > FluffyThemes.columnWidth * 3.5;

  static LinearGradient backgroundGradient(BuildContext context, int alpha) {
    final colorScheme = Theme.of(context).colorScheme;
    return LinearGradient(
      begin: Alignment.topCenter,
      colors: [
        colorScheme.primaryContainer.withAlpha(alpha),
        colorScheme.secondaryContainer.withAlpha(alpha),
        colorScheme.tertiaryContainer.withAlpha(alpha),
        colorScheme.primaryContainer.withAlpha(alpha),
      ],
    );
  }

  static const Duration animationDuration = Duration(milliseconds: 250);
  static const Curve animationCurve = Curves.easeInOut;

  static ThemeData buildTheme(
    BuildContext context,
    Brightness brightness, [
    Color? seed,
  ]) {
    final colorScheme = _terminalColorScheme(brightness);
    final isColumnMode = FluffyThemes.isColumnMode(context);
    final dividerColor = brightness == Brightness.dark
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainer;
    return ThemeData(
      visualDensity: VisualDensity.standard,
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      // Fork patch (terminal skin): monospace chrome. Message bodies override
      // this back to a proportional face (AppConfig.bodyFont) and code blocks
      // keep the mono face - that is the "mono chrome" variant.
      fontFamily: AppConfig.monospaceFont,
      dividerColor: dividerColor,
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          iconColor: colorScheme.onSurface,
          disabledIconColor: colorScheme.onSurface,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: colorScheme.onSurface.withAlpha(128),
        selectionHandleColor: colorScheme.secondary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        backgroundColor: colorScheme.surfaceContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: isColumnMode ? 72 : 56,
        // Fork patch (terminal skin): flat app bar - no M3 surface tint.
        surfaceTintColor: Colors.transparent,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actionsPadding: isColumnMode
            ? const EdgeInsets.symmetric(horizontal: 16.0)
            : null,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness.reversed,
          statusBarBrightness: brightness,
          systemNavigationBarIconBrightness: brightness.reversed,
          systemNavigationBarColor: colorScheme.surface,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(width: 1, color: colorScheme.primary),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colorScheme.primary),
            borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        strokeCap: StrokeCap.round,
        color: colorScheme.primary,
        refreshBackgroundColor: colorScheme.primaryContainer,
      ),
      snackBarTheme: isColumnMode
          ? const SnackBarThemeData(
              showCloseIcon: true,
              behavior: SnackBarBehavior.floating,
              width: FluffyThemes.columnWidth * 1.5,
            )
          : const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          elevation: 0,
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  /// Fork patch (terminal skin): palette taken from the owner's Termux setup -
  /// Tokyo Night Dark background (#1a1b26, what the phone actually renders)
  /// with the gold accents of the Hermes CLI "default" skin (#FFBF00). The
  /// seed-based roles are kept from a gold scheme so every derived surface
  /// token (surfaceContainerHigh, secondaryContainer, ...) still has a value.
  ///
  /// The `seed` argument of buildTheme is intentionally ignored: the palette is
  /// fixed, so the colour picker in settings no longer repaints the app.
  static ColorScheme _terminalColorScheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFFBF00),
      brightness: brightness,
    );
    if (brightness == Brightness.light) {
      return base.copyWith(
        surface: const Color(0xFFF5F0E8),
        onSurface: const Color(0xFF2C1810),
        onSurfaceVariant: const Color(0xFF8B7355),
        primary: const Color(0xFF8B4513),
        onPrimary: const Color(0xFFFFF8DC),
        primaryContainer: const Color(0xFFEAD9BE),
        onPrimaryContainer: const Color(0xFF2C1810),
        secondary: const Color(0xFF8B6914),
        tertiaryContainer: const Color(0xFFE7E1D3),
        onTertiaryContainer: const Color(0xFF2C1810),
        outline: const Color(0xFF8B6914),
        outlineVariant: const Color(0xFFD6C9B4),
      );
    }
    return base.copyWith(
      surface: const Color(0xFF1A1B26),
      onSurface: const Color(0xFFFFF8DC),
      onSurfaceVariant: const Color(0xFFC9A227),
      surfaceContainerLowest: const Color(0xFF131420),
      surfaceContainerLow: const Color(0xFF171824),
      surfaceContainer: const Color(0xFF1F2335),
      surfaceContainerHigh: const Color(0xFF23263A),
      surfaceContainerHighest: const Color(0xFF2A2F45),
      primary: const Color(0xFFFFBF00),
      onPrimary: const Color(0xFF1A1B26),
      primaryContainer: const Color(0xFF3A2F10),
      onPrimaryContainer: const Color(0xFFFFE9A8),
      secondary: const Color(0xFFE0AF68),
      onSecondary: const Color(0xFF1A1B26),
      secondaryContainer: const Color(0xFF2A2416),
      onSecondaryContainer: const Color(0xFFFFE0A8),
      tertiary: const Color(0xFF9AA5CE),
      tertiaryContainer: const Color(0xFF23263A),
      onTertiaryContainer: const Color(0xFFE6E8F2),
      outline: const Color(0xFFCD7F32),
      outlineVariant: const Color(0xFF2A2F45),
      error: const Color(0xFFFF5F56),
      onError: const Color(0xFF1A1B26),
    );
  }
}

extension on Brightness {
  Brightness get reversed =>
      this == Brightness.dark ? Brightness.light : Brightness.dark;
}

extension BubbleColorTheme on ThemeData {
  Color get bubbleColor => brightness == Brightness.light
      ? colorScheme.primary
      : colorScheme.primaryContainer;

  Color get onBubbleColor => brightness == Brightness.light
      ? colorScheme.onPrimary
      : colorScheme.onPrimaryContainer;

  Color get secondaryBubbleColor => HSLColor.fromColor(
    brightness == Brightness.light
        ? colorScheme.tertiary
        : colorScheme.tertiaryContainer,
  ).withSaturation(0.5).toColor();
}
