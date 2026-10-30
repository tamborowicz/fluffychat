// SPDX-FileCopyrightText: 2026 tamborowicz (fork patch: terminal skin)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Fork patch (terminal skin): the theme implementation lives here instead of in
// lib/config/themes.dart. Upstream's file keeps a single delegating line, which
// keeps merges with new FluffyChat releases cheap.

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/theme_palettes.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

abstract class TerminalTheme {
  static ThemeData buildTheme(BuildContext context, Brightness brightness) {
    // Fork patch (terminal skin): palette is selectable in settings and its own
    // polarity wins over ThemeMode - a terminal skin is about matching a real
    // terminal (dark), so a light system theme no longer flips it.
    final palette = ThemePalettes.byId(AppSettings.themePalette.value);
    final colorScheme = _paletteColorScheme(palette);
    final isColumnMode = FluffyThemes.isColumnMode(context);
    final dividerColor = brightness == Brightness.dark
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainer;
    return ThemeData(
      visualDensity: VisualDensity.standard,
      useMaterial3: true,
      brightness: colorScheme.brightness,
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
          statusBarIconBrightness: (brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark),
          statusBarBrightness: brightness,
          systemNavigationBarIconBrightness: (brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark),
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

  /// Fork patch (terminal skin): builds the ColorScheme from the palette the
  /// user picked in settings (ThemePalettes). Seed-based roles still come from
  /// the palette accent so every derived M3 token keeps a sensible value.
  static ColorScheme _paletteColorScheme(ThemePalette palette) {
    final surface = palette.surface;
    final accent = palette.accent;
    final dark = palette.dark;
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    final shade = dark ? Colors.black : Colors.white;
    return base.copyWith(
      surface: surface,
      onSurface: palette.ink,
      onSurfaceVariant: palette.muted,
      surfaceContainerLowest: _mix(surface, shade, dark ? .20 : .05),
      surfaceContainerLow: _mix(surface, shade, dark ? .08 : .03),
      surfaceContainer: _mix(surface, accent, .05),
      surfaceContainerHigh: _mix(surface, accent, .09),
      surfaceContainerHighest: _mix(surface, palette.border, .35),
      primary: accent,
      onPrimary: surface,
      // Own message bubbles.
      primaryContainer: _mix(surface, accent, dark ? .20 : .22),
      onPrimaryContainer: palette.ink,
      secondary: palette.amber,
      onSecondary: surface,
      secondaryContainer: _mix(surface, accent, .10),
      onSecondaryContainer: palette.ink,
      // Other people's bubbles stay close to the terminal background.
      tertiary: palette.muted,
      tertiaryContainer: _mix(surface, accent, dark ? .06 : .08),
      onTertiaryContainer: palette.ink,
      outline: palette.border,
      outlineVariant: _mix(surface, palette.border, .30),
      error: const Color(0xFFFF5F56),
      onError: surface,
    );
  }

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
}
