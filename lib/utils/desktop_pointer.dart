import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a pointer cursor when hovering over clickable desktop UI.
extension DesktopPointer on Widget {
  Widget withClickCursor({bool enabled = true}) {
    if (!enabled) return this;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: this,
    );
  }
}

ButtonStyle desktopClickableButtonStyle(ButtonStyle? base) {
  return (base ?? const ButtonStyle()).copyWith(
    mouseCursor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return SystemMouseCursors.basic;
      }
      return SystemMouseCursors.click;
    }),
  );
}
