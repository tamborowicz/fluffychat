// SPDX-FileCopyrightText: 2026 tamborowicz (fork patch: terminal skin)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Fork patch (terminal skin): flat bubbles - solid fill plus a 1px outline and
// no gradient wallpaper behind own messages. Called from message.dart in two
// lines so the upstream file stays easy to merge.

import 'package:material_ui/material_ui.dart';

abstract class TerminalBubble {
  /// Turns off the gradient wallpaper behind own bubbles.
  static const bool ignoreGradient = true;

  static BoxDecoration decoration(
    BuildContext context, {
    required bool noBubble,
    required Color? color,
    required BorderRadius borderRadius,
  }) => BoxDecoration(
    color: noBubble ? Colors.transparent : color,
    borderRadius: borderRadius,
    border: noBubble
        ? null
        : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
  );
}
