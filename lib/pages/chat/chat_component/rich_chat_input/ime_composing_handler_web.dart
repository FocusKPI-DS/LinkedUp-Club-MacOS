import 'dart:async';
import 'dart:html' as html;

/// IME composing state handler - Web implementation.
/// Listens to DOM compositionstart/compositionend events to track
/// whether an IME (e.g. Chinese Pinyin) is actively composing.
class IMEComposingHandler {
  bool _isComposing = false;
  StreamSubscription? _startSub;
  StreamSubscription? _endSub;

  bool get isComposing => _isComposing;

  void init() {
    _startSub = html.document.on['compositionstart'].listen((_) {
      _isComposing = true;
      print('DEBUG IME: compositionstart -> isComposing=true');
    });
    _endSub = html.document.on['compositionend'].listen((_) {
      // Delay clearing so that keydown(Enter) fired during composition
      // still sees isComposing=true. The browser fires keydown BEFORE
      // compositionend, so this microtask ensures correct ordering.
      Future.microtask(() {
        _isComposing = false;
        print('DEBUG IME: compositionend -> isComposing=false');
      });
    });
  }

  void dispose() {
    _startSub?.cancel();
    _endSub?.cancel();
  }
}
