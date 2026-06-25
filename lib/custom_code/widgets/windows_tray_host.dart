import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:linkedup/utils/debug_log.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows: close / Alt+F4 hides the window; app keeps running in the tray.
class WindowsTrayHost extends StatefulWidget {
  const WindowsTrayHost({super.key, required this.child});

  final Widget child;

  static bool get isEnabled => !kIsWeb && Platform.isWindows;

  /// Call from [main] before [runApp].
  static Future<void> prepareWindow() async {
    if (!isEnabled) return;
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
  }

  @override
  State<WindowsTrayHost> createState() => _WindowsTrayHostState();
}

class _WindowsTrayHostState extends State<WindowsTrayHost>
    with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initTray();
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setIcon('assets/images/app_tray_icon.ico');
      await trayManager.setToolTip('Lona');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: 'Open Lona'),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: 'Exit'),
          ],
        ),
      );
    } catch (e) {
      debugLog('WindowsTrayHost: tray init failed: $e');
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    _showMainWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showMainWindow();
        break;
      case 'exit':
        _exitApplication();
        break;
    }
  }

  Future<void> _showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exitApplication() async {
    try {
      await trayManager.destroy();
    } catch (_) {}
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
