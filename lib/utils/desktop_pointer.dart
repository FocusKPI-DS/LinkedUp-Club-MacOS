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

/// Use as the [PopupMenuItem] child so menu rows show a pointer on desktop.
Widget desktopClickableMenuChild(Widget child) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: child,
  );
}
