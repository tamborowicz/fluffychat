// SPDX-FileCopyrightText: 2026 tamborowicz (fork patch: terminal skin)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Fork patch: selectable palettes for the terminal skin. Values are the real
// hexes of the Hermes CLI skins (hermes_cli/skin_engine.py) placed on the
// Tokyo Night Dark background the owner's Termux renders on the Titan 2.
// "hermes-tokyo" is the default: Hermes gold on Tokyo Night.

import 'package:flutter/widgets.dart';

class ThemePalette {
  final String id;
  final String label;
  final bool dark;

  /// App background (the terminal background).
  final Color surface;

  /// Primary text colour.
  final Color ink;

  /// Secondary text, icons, timestamps.
  final Color muted;

  /// Accent: headings, links, unread, own message bubbles.
  final Color accent;

  /// Warning / mention colour.
  final Color amber;

  /// Borders and outlines.
  final Color border;

  const ThemePalette({
    required this.id,
    required this.label,
    required this.dark,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.amber,
    required this.border,
  });
}

abstract class ThemePalettes {
  static const String defaultId = 'hermes-tokyo';

  static const List<ThemePalette> all = [
    ThemePalette(
      id: 'hermes-tokyo',
      label: 'Hermes default × Tokyo',
      dark: true,
      surface: Color(0xFF1A1B26),
      ink: Color(0xFFFFF8DC),
      muted: Color(0xFFC9A227),
      accent: Color(0xFFFFBF00),
      amber: Color(0xFFFFA726),
      border: Color(0xFF50392A),
    ),
    ThemePalette(
      id: 'tokyo',
      label: 'Tokyo Night (Termux)',
      dark: true,
      surface: Color(0xFF1A1B26),
      ink: Color(0xFFC0CAF5),
      muted: Color(0xFF9AA5CE),
      accent: Color(0xFF7AA2F7),
      amber: Color(0xFFE0AF68),
      border: Color(0xFF2A2F45),
    ),
    ThemePalette(
      id: 'fluffy',
      label: 'obecny FluffyChat',
      dark: true,
      surface: Color(0xFF1B1530),
      ink: Color(0xFFECE4FF),
      muted: Color(0xFFA495C9),
      accent: Color(0xFFCBB6FF),
      amber: Color(0xFFFFB0D0),
      border: Color(0xFF382C58),
    ),
    ThemePalette(
      id: 'default',
      label: 'default',
      dark: true,
      surface: Color(0xFF1A1A2E),
      ink: Color(0xFFFFF8DC),
      muted: Color(0xFFB8860B),
      accent: Color(0xFFFFBF00),
      amber: Color(0xFFFFA726),
      border: Color(0xFF6B4730),
    ),
    ThemePalette(
      id: 'ares',
      label: 'ares',
      dark: true,
      surface: Color(0xFF2A1212),
      ink: Color(0xFFF1E6CF),
      muted: Color(0xFF905151),
      accent: Color(0xFFDD4A3A),
      amber: Color(0xFFFFA726),
      border: Color(0xFF632121),
    ),
    ThemePalette(
      id: 'mono',
      label: 'mono',
      dark: true,
      surface: Color(0xFF1F1F1F),
      ink: Color(0xFFC9D1D9),
      muted: Color(0xFF606060),
      accent: Color(0xFFAAAAAA),
      amber: Color(0xFF999999),
      border: Color(0xFF3B3B3B),
    ),
    ThemePalette(
      id: 'slate',
      label: 'slate',
      dark: true,
      surface: Color(0xFF151C2F),
      ink: Color(0xFFC9D1D9),
      muted: Color(0xFF545E6B),
      accent: Color(0xFF7EB8F6),
      amber: Color(0xFFE6A855),
      border: Color(0xFF293F7F),
    ),
    ThemePalette(
      id: 'daylight',
      label: 'daylight',
      dark: false,
      surface: Color(0xFFE5EDF8),
      ink: Color(0xFF111827),
      muted: Color(0xFF475569),
      accent: Color(0xFF2563EB),
      amber: Color(0xFFB45309),
      border: Color(0xFFABC4F4),
    ),
    ThemePalette(
      id: 'warm-lightmode',
      label: 'warm-lightmode',
      dark: false,
      surface: Color(0xFFF5F0E8),
      ink: Color(0xFF2C1810),
      muted: Color(0xFF8B7355),
      accent: Color(0xFF8B4513),
      amber: Color(0xFFE65100),
      border: Color(0xFFD5C8A8),
    ),
    ThemePalette(
      id: 'poseidon',
      label: 'poseidon',
      dark: true,
      surface: Color(0xFF0F2440),
      ink: Color(0xFFEAF7FF),
      muted: Color(0xFF44638F),
      accent: Color(0xFF5DB8F5),
      amber: Color(0xFFFFA726),
      border: Color(0xFF1B4676),
    ),
    ThemePalette(
      id: 'sisyphus',
      label: 'sisyphus',
      dark: true,
      surface: Color(0xFF202020),
      ink: Color(0xFFD3D3D3),
      muted: Color(0xFF5C5C5C),
      accent: Color(0xFFE7E7E7),
      amber: Color(0xFFB7B7B7),
      border: Color(0xFF646464),
    ),
    ThemePalette(
      id: 'charizard',
      label: 'charizard',
      dark: true,
      surface: Color(0xFF2B160E),
      ink: Color(0xFFFFF0D4),
      muted: Color(0xFFC58A45),
      accent: Color(0xFFF29C38),
      amber: Color(0xFFFFA726),
      border: Color(0xFF713515),
    ),
  ];

  static ThemePalette byId(String? id) =>
      all.firstWhere((palette) => palette.id == id, orElse: () => all.first);
}
