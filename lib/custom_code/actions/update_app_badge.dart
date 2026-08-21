// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:get/get.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/pages/desktop_chat/chat_controller.dart';

// Update app badge with **unread message count** (chats with unread messages).
// This shows 0 when you have no unread chats; push notification count would show 99+ (all ever delivered) with no way to "clear".
Future<void> updateAppBadge() async {
  try {
    final isSupported = await AppBadgePlus.isSupported();
    if (!isSupported) return;

    if (currentUserReference == null) {
      await AppBadgePlus.updateBadge(0);
      return;
    }

    ChatController chatController;
    try {
      chatController = Get.find<ChatController>();
    } catch (_) {
      chatController = Get.put(ChatController(), permanent: true);
    }

    final count = await chatController
        .getTotalUnreadMessageCount()
        .first
        .timeout(const Duration(seconds: 10), onTimeout: () => 0);

    final badgeCount = count > 99 ? 99 : count;
    await AppBadgePlus.updateBadge(badgeCount);
    if (badgeCount > 0) {
      print('App badge updated with unread count: $badgeCount');
    }
  } catch (e) {
    await AppBadgePlus.updateBadge(0);
    print('Error updating app badge: $e');
  }
}
