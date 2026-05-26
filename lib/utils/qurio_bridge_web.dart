import 'dart:html' as html;
import 'dart:convert';

/// Web implementation: sends a message to the Qurio parent window via postMessage.
void postToParent(Map<String, dynamic> message) {
  try {
    html.window.parent?.postMessage(json.encode(message), '*');
  } catch (e) {
    print('[QurioBridge] ❌ Failed to postMessage to parent: $e');
  }
}
