import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/nav/nav.dart' show appNavigatorKey;
import '/pages/desktop_chat/chat_controller.dart';
import '/pages/mobile_chat/mobile_chat_widget.dart';
import '/utils/debug_log.dart';

/// Opens a 1:1 chat in the current product shell:
/// Desktop Chat on macOS/web, Mobile Chat on iOS.
///
/// Use this instead of routing to the legacy `Chat` / `ChatDetail` pages.
Future<void> openDirectChat(
  ChatsRecord chat, {
  BuildContext? context,
}) async {
  final navContext = (context != null && context.mounted)
      ? context
      : appNavigatorKey.currentContext;
  if (navContext == null || !navContext.mounted) {
    debugLog('openDirectChat: no mounted navigator context');
    return;
  }

  final useMobileChat = !kIsWeb && Platform.isIOS;
  if (useMobileChat) {
    await Navigator.of(navContext).push(
      MaterialPageRoute(
        builder: (_) => MobileChatWidget(initialChat: chat),
      ),
    );
    return;
  }

  navContext.pushNamed(
    '_initialize',
    queryParameters: {'tab': 'DesktopChat'},
  );
  Future.delayed(const Duration(milliseconds: 500), () {
    _selectChatInDesktop(chat);
  });
}

void _selectChatInDesktop(ChatsRecord chat, {int retryCount = 0}) {
  if (retryCount > 20) {
    debugLog('openDirectChat: failed to select chat after 20 retries');
    return;
  }

  try {
    ChatController? chatController;
    try {
      chatController = Get.find<ChatController>();
      if (chatController.chats.isEmpty && retryCount < 10) {
        Future.delayed(Duration(milliseconds: 400 * (retryCount + 1)), () {
          _selectChatInDesktop(chat, retryCount: retryCount + 1);
        });
        return;
      }
    } catch (e) {
      if (retryCount < 10) {
        Future.delayed(Duration(milliseconds: 400 * (retryCount + 1)), () {
          _selectChatInDesktop(chat, retryCount: retryCount + 1);
        });
        return;
      }
      debugLog('openDirectChat: ChatController not found after 10 retries: $e');
      return;
    }

    ChatsRecord chatToSelect = chat;
    try {
      chatToSelect = chatController.chats.firstWhere(
        (c) => c.reference.id == chat.reference.id,
      );
    } catch (_) {
      if (retryCount < 5) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _selectChatInDesktop(chat, retryCount: retryCount + 1);
        });
        return;
      }
    }

    final controller = chatController;
    if (controller == null) return;
    controller.selectChat(chatToSelect);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (controller.selectedChat.value?.reference.id != chat.reference.id) {
        if (retryCount < 15) {
          _selectChatInDesktop(chat, retryCount: retryCount + 1);
        }
      }
    });
  } catch (e) {
    debugLog('openDirectChat: select error (retry $retryCount): $e');
    Future.delayed(Duration(milliseconds: 400 * (retryCount + 1)), () {
      _selectChatInDesktop(chat, retryCount: retryCount + 1);
    });
  }
}
