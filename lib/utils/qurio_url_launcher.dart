/// Utility to open URLs that works both standalone and embedded in Qurio.
///
/// When running inside Qurio's iframe, URLs are sent to the Qurio parent
/// window via postMessage, and Qurio opens them in the system browser.
/// When running standalone (web or native), uses the standard `url_launcher`.
///
/// Usage:
///   import '/utils/qurio_url_launcher.dart';
///
///   await qurioLaunchUrl('https://example.com');
///   await qurioLaunchUrl('https://example.com', mode: LaunchMode.externalApplication);

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'qurio_embedded.dart';
import 'qurio_bridge.dart';

/// Open a URL, routing through Qurio when embedded in its iframe.
///
/// Returns true if the URL was successfully launched or delegated to Qurio.
Future<bool> qurioLaunchUrl(
  dynamic url, {
  LaunchMode mode = LaunchMode.externalApplication,
}) async {
  // Resolve to a Uri
  final Uri uri;
  if (url is Uri) {
    uri = url;
  } else if (url is String) {
    uri = Uri.parse(url);
  } else {
    print('[qurioLaunchUrl] ❌ Invalid URL type: ${url.runtimeType}');
    return false;
  }

  // When embedded in Qurio, delegate to Qurio's system browser opener
  if (kIsWeb && QurioEmbedded.isEmbeddedInQurio) {
    print('[qurioLaunchUrl] 🔗 Delegating to Qurio: ${uri.toString()}');
    return QurioBridge.openUrl(uri.toString());
  }

  // Standalone: use standard url_launcher
  try {
    return await launchUrl(uri, mode: mode);
  } catch (e) {
    print('[qurioLaunchUrl] ❌ Failed to launch URL: $e');
    return false;
  }
}
