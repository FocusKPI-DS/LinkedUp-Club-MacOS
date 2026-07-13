import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Chat message UI font — bundled [Inter] on web/desktop (matches lona.club web).
/// Native iOS/Android keep SF Pro for platform-native mobile feel.
String get chatMessageFontFamily {
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    return 'SF Pro Text';
  }
  return 'Inter';
}
