// SPDX-FileCopyrightText: 2026 tamborowicz (fork patch: terminal skin)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Fork patch (terminal skin): palette picker as its own page, so the upstream
// appearance screen only needs one extra tile.

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/theme_palettes.dart';
import 'package:fluffychat/widgets/theme_builder.dart';
import 'package:material_ui/material_ui.dart';

class TerminalStylePage extends StatelessWidget {
  const TerminalStylePage({super.key});

  String get _currentPaletteId => AppSettings.themePalette.value;

  void _select(BuildContext context, String id) {
    AppSettings.themePalette.setItem(id);
    ThemeController.of(context).refreshTheme();
    (context as Element).markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Paleta (terminal skin)')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Tło + akcent + tekst. Zmiana działa natychmiast w całej apce.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final palette in ThemePalettes.all)
            _PaletteRow(
              palette: palette,
              selected: palette.id == _currentPaletteId,
              onTap: () => _select(context, palette.id),
            ),
          const Divider(height: 32),
          ListTile(
            title: const Text('Czcionka'),
            subtitle: Text(
              'chrome: ${AppConfig.monospaceFont} · treść: ${AppConfig.bodyFont}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  final ThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteRow({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      selected: selected,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 22,
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
          ),
          Container(width: 12, height: 22, color: palette.accent),
          Container(width: 12, height: 22, color: palette.ink),
        ],
      ),
      title: Text(palette.label),
      subtitle: Text(
        '${palette.dark ? 'dark' : 'light'} · ${_hex(palette.accent)} na ${_hex(palette.surface)}',
        style: TextStyle(
          fontFamily: AppConfig.monospaceFont,
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
    );
  }
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
