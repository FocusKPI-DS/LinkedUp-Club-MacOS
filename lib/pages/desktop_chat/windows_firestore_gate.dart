import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Serializes native Firestore calls on Windows/Linux.
/// Concurrent reads/listeners crash the desktop plugin (non-platform thread).
class WindowsFirestoreGate {
  WindowsFirestoreGate._();

  static final WindowsFirestoreGate instance = WindowsFirestoreGate._();

  static bool get enabled =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  Future<void>? _chain;

  Future<T> run<T>(
    Future<T> Function() action, {
    String? label,
  }) async {
    if (!enabled) return action();

    final completer = Completer<T>();
    final prev = _chain ?? Future<void>.value();

    _chain = prev.then((_) async {
      try {
        if (label != null) {
          // ignore: avoid_print
          print('[WindowsFirestoreGate] → $label');
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final result = await action();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });

    return completer.future;
  }
}
