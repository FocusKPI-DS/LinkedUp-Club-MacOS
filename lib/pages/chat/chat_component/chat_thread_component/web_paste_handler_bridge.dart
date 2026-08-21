/// Conditional import bridge for web paste handling.
/// Uses web_paste_handler.dart on web and web_paste_handler_stub.dart on native.
export 'web_paste_handler_stub.dart'
    if (dart.library.html) 'web_paste_handler.dart';
