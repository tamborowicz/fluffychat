// SPDX-FileCopyrightText: 2026 tamborowicz (fork patch: terminal skin)
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Fork patch (terminal skin): "mono chrome" means the UI is monospace while
// message bodies stay proportional. This is the single place the body style is
// built, so html_message.dart only needs a one-line call.

import 'package:fluffychat/config/app_config.dart';
import 'package:material_ui/material_ui.dart';

abstract class TerminalText {
  static TextStyle messageBody({
    required double fontSize,
    required Color color,
  }) => TextStyle(
    fontSize: fontSize,
    color: color,
    fontFamily: AppConfig.bodyFont,
  );
}
