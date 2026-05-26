import 'dart:html' as html;

/// Web: checks if the current window is running inside an iframe
/// by comparing window.parent to window itself.
bool isRunningInIframe() {
  try {
    return !identical(html.window.parent, html.window) &&
        html.window.parent != null;
  } catch (e) {
    // Cross-origin iframe access may throw; if so, we're definitely in an iframe
    return true;
  }
}
