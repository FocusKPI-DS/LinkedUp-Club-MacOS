import 'dart:async';
import 'dart:html' as html;

/// IME composing state handler - Web implementation.
/// Listens to DOM compositionstart/compositionend events to track
/// whether an IME (e.g. Chinese Pinyin) is actively composing.
///
/// Also intercepts keydown(Enter) during composition at the DOM level
/// to prevent it from reaching Flutter's shortcut system.
class IMEComposingHandler {
  bool _isComposing = false;
  StreamSubscription? _startSub;
  StreamSubscription? _endSub;
  StreamSubscription? _keydownSub;

  bool get isComposing => _isComposing;

  void init() {
    _startSub = html.document.on['compositionstart'].listen((_) {
      _isComposing = true;
      print('DEBUG IME: compositionstart -> isComposing=true');
    });
    _endSub = html.document.on['compositionend'].listen((_) {
      // Use a generous delay to ensure Flutter's shortcut/action pipeline
      // completes before we clear the flag. Without this, a race condition
      // allows Enter-to-send while the user is just confirming IME input.
      Future.delayed(const Duration(milliseconds: 100), () {
        _isComposing = false;
        print('DEBUG IME: compositionend -> isComposing=false (delayed)');
      });
    });

    // DOM-level keydown interceptor: block Enter propagation during composition.
    // This prevents the key event from ever reaching Flutter's Shortcut system.
    _keydownSub = html.document.on['keydown'].listen((event) {
      if (_isComposing && event is html.KeyboardEvent) {
        if (event.key == 'Enter' || event.keyCode == 13) {
          print('DEBUG IME: BLOCKED Enter keydown during composition');
          event.preventDefault();
          event.stopPropagation();
          event.stopImmediatePropagation();
        }
      }
    });
  }

  void dispose() {
    _startSub?.cancel();
    _endSub?.cancel();
    _keydownSub?.cancel();
  }
}
