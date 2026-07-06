import '/auth/firebase_auth/auth_util.dart';
import '/utils/debug_log.dart';
import '/backend/backend.dart';
import '/custom_code/services/web_notification_service.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '/pages/desktop_chat/windows_firestore_gate.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';

enum ChatState { loading, success, error }

/// Represents a single message search result for Slack-style display
class MessageSearchResult {
  final String chatId;
  final String chatName;
  final String senderName;
  final String senderPhoto;
  final String content;
  final DateTime? createdAt;
  final DocumentReference messageRef;
  final DocumentReference chatRef;
  final bool isGroup;

  MessageSearchResult({
    required this.chatId,
    required this.chatName,
    required this.senderName,
    required this.senderPhoto,
    required this.content,
    required this.createdAt,
    required this.messageRef,
    required this.chatRef,
    required this.isGroup,
  });
}

class ChatController extends GetxController {
  // Static accessor for notification routing on macOS
  static ChatController? get instanceOrNull {
    try {
      return Get.find<ChatController>();
    } catch (_) {
      return null;
    }
  }

  // Pending notification chat: set when notification arrives before controller is ready
  static ChatsRecord? pendingNotificationChat;

  // Observable variables
  final Rx<ChatState> chatState = ChatState.loading.obs;
  final RxList<ChatsRecord> chats = <ChatsRecord>[].obs;
  final Rx<ChatsRecord?> selectedChat = Rx<ChatsRecord?>(null);
  final RxString searchQuery = ''.obs;
  final RxInt selectedTabIndex = 0.obs;
  final RxString chatFilter = 'All'.obs; // Filter: All, Unread, DM, Groups, or folder:<id>
  // When filtering by a custom folder, this holds the folder's chat IDs
  final RxList<String> activeFolderChatIds = <String>[].obs;
  final RxMap<String, DateTime> locallySeenChats = <String, DateTime>{}.obs;

  // Blocked users set (reactive)
  final Rx<Set<String>> blockedUserIds = Rx<Set<String>>(<String>{});

  // Cache: userRef.id → display name (populated on chat load for fast search)
  final Map<String, String> _userDisplayNameCache = {};
  final Map<String, UsersRecord> _userRecordCache = {};
  final Map<String, Future<UsersRecord>> _userFutureCache = {};

  // Last known unread message count per chat (avoids badge flashing "1" on reload)
  final Map<String, int> _unreadCountCache = {};

  int? getCachedUnreadCount(String chatId) => _unreadCountCache[chatId];

  void cacheUnreadCount(String chatId, int count) {
    _unreadCountCache[chatId] = count;
  }

  void _setCachedUnreadCount(String chatId, int count) {
    cacheUnreadCount(chatId, count);
  }

  void _invalidateCachedUnreadCount(String chatId) {
    _unreadCountCache.remove(chatId);
  }

  /// Windows/Linux: sidebar stays on spinner until DM names + avatars are prefetched.
  final RxBool desktopSidebarReady = true.obs;
  bool _desktopSidebarPrimed = false;

  /// Returns cached display name for a user (used by UI to avoid "Direct Chat" flash).
  String? getCachedDisplayName(String? userRefId) =>
      userRefId == null ? null : _userDisplayNameCache[userRefId];

  Future<UsersRecord> getOrCreateUserFuture(DocumentReference ref) {
    if (!fsIsRealUserRef(ref)) {
      final cached = _userRecordCache[ref.id];
      if (cached != null) return Future.value(cached);
      final synthetic = fsSyntheticAgentUser(ref);
      _userRecordCache[ref.id] = synthetic;
      _userDisplayNameCache[ref.id] = synthetic.displayName;
      return Future.value(synthetic);
    }

    final cached = _userRecordCache[ref.id];
    if (cached != null) return Future.value(cached);
    return _userFutureCache.putIfAbsent(ref.id, () async {
      try {
        final user = await fsGetUserOnce(ref);
        _userRecordCache[ref.id] = user;
        if (user.displayName.isNotEmpty) {
          _userDisplayNameCache[ref.id] = user.displayName;
        }
        return user;
      } catch (e) {
        _userFutureCache.remove(ref.id);
        rethrow;
      }
    });
  }

  // Chat IDs that matched a message content search (async, cleared when query changes)
  final RxSet<String> _messageSearchMatchIds = <String>{}.obs;

  // Error message
  final RxString errorMessage = ''.obs;

  Timer? _messageSearchDebounce;

  /// Reactive list of message-level search results for Slack-style display
  final RxList<MessageSearchResult> messageSearchResults = <MessageSearchResult>[].obs;
  final RxBool isSearchingMessages = false.obs;

  bool _listListenersPaused = false;

  List<ChatsRecord> _cachedServiceChats = [];
  bool _desktopExtrasLoading = false;

  @override
  void onInit() {
    super.onInit();
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      desktopSidebarReady.value = false;
      // Let the chat shell mount before the first (single) Firestore query.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!isClosed) {
          loadChats(staggerSubscriptions: true);
        }
      });
    } else {
      loadChats();
    }
  }

  /// Suspend chat-list Firestore streams while viewing a thread (Windows/Linux).
  Future<void> pauseListListeners() async {
    if (_listListenersPaused || kIsWeb) return;
    if (!Platform.isWindows && !Platform.isLinux) return;
    _listListenersPaused = true;
    _desktopPollTimer?.cancel();
    await _chatsSubscription?.cancel();
    await _serviceChatsSubscription?.cancel();
    await _blockedUsersSubscription?.cancel();
    _chatsSubscription = null;
    _serviceChatsSubscription = null;
    _blockedUsersSubscription = null;
    debugLog('⏸️ [ChatController] Paused list listeners (thread open)');
  }

  Future<void> resumeListListeners() async {
    if (!_listListenersPaused || kIsWeb) return;
    if (!Platform.isWindows && !Platform.isLinux) return;
    _listListenersPaused = false;
    debugLog('▶️ [ChatController] Resuming list listeners');
    await loadChats(staggerSubscriptions: true);
  }

  StreamSubscription? _chatsSubscription;
  StreamSubscription? _serviceChatsSubscription;
  StreamSubscription? _blockedUsersSubscription;
  Timer? _desktopPollTimer;

  static bool get _desktopPollMode =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  @override
  void onClose() {
    _desktopPollTimer?.cancel();
    _chatsSubscription?.cancel();
    _blockedUsersSubscription?.cancel();
    _serviceChatsSubscription?.cancel();
    super.onClose();
  }

  // Load chats from Firestore with real-time updates (poll-only on Windows/Linux).
  Future<void> loadChats({bool staggerSubscriptions = false}) async {
    if (_desktopPollMode) {
      return _loadChatsDesktopPoll();
    }
    try {
      // Cancel existing subscriptions if any
      await _chatsSubscription?.cancel();
      await _serviceChatsSubscription?.cancel();
      await _blockedUsersSubscription?.cancel();

      chatState.value = ChatState.loading;

      // Check if user is logged in
      if (currentUserReference == null) {
        errorMessage.value = 'User not logged in';
        chatState.value = ChatState.error;
        return;
      }

      // Regular chats stream
      final regularChatsStream = queryChatsRecord(
        queryBuilder: (chatsRecord) =>
            chatsRecord.where('members', arrayContains: currentUserReference),
      );

      // Service chats stream (visible to all users)
      final serviceChatsStream = queryChatsRecord(
        queryBuilder: (chatsRecord) =>
            chatsRecord.where('is_service_chat', isEqualTo: true),
      );

      // Store regular chats
      List<ChatsRecord> regularChats = [];
      List<ChatsRecord> serviceChats = [];

      // Listen to regular chats
      _chatsSubscription = regularChatsStream.listen(
        (chatsList) {
          regularChats = chatsList;
          _combineAndUpdateChats(regularChats, serviceChats);
        },
        onError: (error) {
          errorMessage.value = 'Error loading chats: $error';
          chatState.value = ChatState.error;
        },
      );

      if (staggerSubscriptions) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (isClosed) return;
      }

      // Listen to service chats
      _serviceChatsSubscription = serviceChatsStream.listen(
        (chatsList) {
          serviceChats = chatsList;
          _combineAndUpdateChats(regularChats, serviceChats);
        },
        onError: (error) {
          errorMessage.value = 'Error loading service chats: $error';
          chatState.value = ChatState.error;
        },
      );

      if (staggerSubscriptions) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (isClosed) return;
      }

      // Listen to blocked users for real-time filtering (native plugin only)
      if (!useWindowsFirestoreRest) {
        debugLog(
            'Debug: Initializing blocked user listener in ChatController. CurrentUserRef: $currentUserReference');
        _blockedUsersSubscription = BlockedUsersRecord.collection
            .where('blocker_user', isEqualTo: currentUserReference)
            .snapshots()
            .listen((snapshot) {
          blockedUserIds.value = snapshot.docs
              .map((doc) =>
                  BlockedUsersRecord.fromSnapshot(doc).blockedUser?.id)
              .whereType<String>()
              .toSet();
          debugLog(
              'Debug: ChatController updated blocked IDs to: $blockedUserIds');
          chats.refresh();
        }, onError: (e) {
          debugLog('Debug: Error in ChatController blocked user listener: $e');
        });
      }
    } catch (e) {
      errorMessage.value = 'Error loading chats: $e';
      chatState.value = ChatState.error;
    }
  }

  // Combine regular and service chats, remove duplicates, sort, and update
  void _combineAndUpdateChats(
      List<ChatsRecord> regularChats, List<ChatsRecord> serviceChats) {
    // Combine and remove duplicates by reference path
    final Map<String, ChatsRecord> uniqueChats = {};
    for (final chat in regularChats) {
      uniqueChats[chat.reference.path] = chat;
    }
    for (final chat in serviceChats) {
      uniqueChats[chat.reference.path] = chat;
    }

    final combinedChats = uniqueChats.values.toList();

    // BEFORE updating chats, sync knownUnreadChats with actual state
    // IMPORTANT: Only remove from knownUnreadChats if user EXPLICITLY saw the chat locally
    // Don't remove based on Firestore state alone to prevent flickering
    if (currentUserReference != null) {
      // First, clean up knownUnreadChats - ONLY remove chats that user explicitly saw
      final chatsToRemove = <String>[];
      for (final chatId in knownUnreadChats) {
        // Find the chat in the combined list
        final chatIndex =
            combinedChats.indexWhere((c) => c.reference.id == chatId);

        // If chat not found in current list (might have been deleted), remove it
        if (chatIndex == -1) {
          chatsToRemove.add(chatId);
          continue;
        }

        final chat = combinedChats[chatIndex];

        // ONLY remove if user explicitly saw it locally AND no new messages arrived
        // This prevents flickering - we don't remove based on Firestore state alone
        if (locallySeenChats.containsKey(chatId)) {
          final seenAt = locallySeenChats[chatId];
          final lastMessageAt = chat.lastMessageAt;
          // Only remove if user saw it AND no new message arrived after that
          if (seenAt != null &&
              lastMessageAt != null &&
              !lastMessageAt.isAfter(seenAt)) {
            // User explicitly saw it and no new messages - safe to remove
            chatsToRemove.add(chatId);
          }
        } else if (chat.lastMessageSeen.contains(currentUserReference)) {
          // Add this check! If it was read on another device (Firestore updated),
          // and we haven't seen it locally here recently, it should be removed from unread!
          chatsToRemove.add(chatId);
        }
      } // end for loop over knownUnreadChats

      // Remove chats that user explicitly saw
      for (final chatId in chatsToRemove) {
        knownUnreadChats.remove(chatId);
      }

      // Then, add new unread chats to knownUnreadChats
      // BUT exclude the currently open chat (WhatsApp-like behavior)
      final currentSelectedChat = selectedChat.value;
      final currentSelectedChatId = currentSelectedChat?.reference.id;

      for (final chat in combinedChats) {
        // CRITICAL: If this chat is currently open, don't add it to knownUnreadChats
        // and remove it if it's already there (WhatsApp-like behavior)
        if (currentSelectedChatId != null &&
            chat.reference.id == currentSelectedChatId) {
          // Chat is currently open, so remove from knownUnreadChats
          knownUnreadChats.remove(chat.reference.id);
          // Update locallySeenChats to current time to keep it in sync
          locallySeenChats[chat.reference.id] = DateTime.now();

          // If there are new unread messages in the open chat, mark them as seen
          // This ensures Firestore is updated so other devices also see it as read
          final userInSeenList =
              chat.lastMessageSeen.contains(currentUserReference);
          final hasLastMessage = chat.lastMessage.isNotEmpty;
          final isNotSentByUser = chat.lastMessageSent != currentUserReference;

          if (hasLastMessage && isNotSentByUser && !userInSeenList) {
            // New message arrived in open chat - mark as seen in background
            // Don't await to avoid blocking the UI update
            if (!useWindowsFirestoreRest) {
              markMessagesAsSeen(chat).catchError((e) {
                debugLog('⚠️ Error auto-marking open chat as seen: $e');
              });
            }
          }

          // Skip adding to knownUnreadChats
          continue;
        }

        // Check if this chat has a new unread message
        final userInSeenList =
            chat.lastMessageSeen.contains(currentUserReference);
        final hasLastMessage = chat.lastMessage.isNotEmpty;
        final isNotSentByUser = chat.lastMessageSent != currentUserReference;

        // If chat has unread message and user hasn't seen it, add to knownUnreadChats
        if (hasLastMessage && isNotSentByUser && !userInSeenList) {
          // Check if locally seen - if so, only add if new message arrived after seen time
          if (locallySeenChats.containsKey(chat.reference.id)) {
            final seenAt = locallySeenChats[chat.reference.id];
            final lastMessageAt = chat.lastMessageAt;
            // Only add if new message arrived AFTER user saw the chat
            if (lastMessageAt != null &&
                seenAt != null &&
                lastMessageAt.isAfter(seenAt)) {
              knownUnreadChats.add(chat.reference.id);
            }
          } else {
            // Not locally seen, so definitely unread
            knownUnreadChats.add(chat.reference.id);
          }
        }
      }
    }

    // Sort chats client-side by last_message_at (handles null values)
    // Falls back to created_at so new/legacy chats without messages still sort properly
    combinedChats.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;

      // Handle null values - put nulls at the end
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1; // a goes after b
      if (bTime == null) return -1; // b goes after a

      // Both have values, sort descending (newest first)
      return bTime.compareTo(aTime);
    });

    chats.value = combinedChats;
    chatState.value = ChatState.success;

    // DIAGNOSTIC: Log when chats update to track preview data freshness
    for (final c in combinedChats.take(5)) {
      debugLog('📋 [ChatController] chatId=${c.reference.id} lastMessage="${c.lastMessage}" lastMsgAt=${c.lastMessageAt}');
    }

    // Populate user display name cache so search can match member names
    // even if search_names is not populated in Firestore
    _populateUserDisplayNameCache(combinedChats);

    // Check for pending notification chat (set when notification arrived before controller was ready)
    if (pendingNotificationChat != null) {
      final pending = pendingNotificationChat!;
      pendingNotificationChat = null;
      selectChat(pending);
      debugLog('✅ [ChatController] Auto-selected pending notification chat: ${pending.reference.id}');
    }
  }

  // Set selected chat
  void selectChat(ChatsRecord chat) {
    _manuallyMarkedUnread.remove(chat.reference.id);
    selectedChat.value = chat;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      // Avoid native messages subcollection — local badge + REST chat patch only.
      locallySeenChats[chat.reference.id] = DateTime.now();
      knownUnreadChats.remove(chat.reference.id);
      _setCachedUnreadCount(chat.reference.id, 0);
      final currentChats = List<ChatsRecord>.from(chats);
      chats.value = currentChats;
      pauseListListeners();
      if (useWindowsFirestoreRest) {
        unawaited(_patchChatSeenViaRest(chat));
      }
      return;
    }

    markMessagesAsSeen(chat);
  }

  // Mark a chat as unread (local-only, WeChat-style)
  void markChatAsUnread(ChatsRecord chat) {
    _manuallyMarkedUnread.add(chat.reference.id);
    knownUnreadChats.add(chat.reference.id);
    _invalidateCachedUnreadCount(chat.reference.id);
    // Set seenAt to epoch so any lastMessageAt is always "after" it
    locallySeenChats[chat.reference.id] =
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  // Update search query and trigger async message search
  void updateSearchQuery(String query) {
    searchQuery.value = query;
    _messageSearchMatchIds.clear();
    messageSearchResults.clear();
    _messageSearchDebounce?.cancel();
    if (query.isEmpty) {
      isSearchingMessages.value = false;
      return;
    }
    isSearchingMessages.value = true;
    // Debounce message search by 400ms to avoid hammering Firestore
    _messageSearchDebounce = Timer(const Duration(milliseconds: 400), () {
      _searchMessagesContent(query);
    });
  }

  // Update selected tab
  void updateSelectedTab(int index) {
    selectedTabIndex.value = index;
  }

  // Update chat filter
  void updateChatFilter(String filter) {
    chatFilter.value = filter;
  }

  // Track chats we've confirmed as unread to prevent Firestore race conditions
  final RxSet<String> knownUnreadChats = <String>{}.obs;

  // Chats manually marked unread by the user (WeChat-style). These bypass
  // Firestore seen-list checks so the badge stays even if read on another device.
  final RxSet<String> _manuallyMarkedUnread = <String>{}.obs;

  // Check if chat has unread messages
  bool hasUnreadMessages(ChatsRecord chat) {
    // CRITICAL: If this chat is currently open, it should never show as unread
    // This implements WhatsApp-like behavior where open chats don't show badges
    // NOTE: We only READ from observables here, mutations happen in _combineAndUpdateChats()
    if (selectedChat.value != null &&
        selectedChat.value!.reference.id == chat.reference.id) {
      // Chat is currently open, so it's always considered "seen"
      // Don't mutate observables here - that's handled in _combineAndUpdateChats()
      return false;
    }

    // If the user manually marked this chat as unread (WeChat-style), always show badge
    // regardless of what Firestore says — clears when user opens the chat
    if (_manuallyMarkedUnread.contains(chat.reference.id)) {
      return true;
    }

    // Check Firestore marked_unread_by field (persisted across app restarts)
    if (currentUserReference != null) {
      final markedUnreadBy = chat.snapshotData['marked_unread_by'] as List<dynamic>?;
      if (markedUnreadBy != null && markedUnreadBy.contains(currentUserReference)) {
        return true;
      }
    }

    // If user has explicitly seen this chat (clicked on it), it's not unread
    if (locallySeenChats.containsKey(chat.reference.id)) {
      final seenAt = locallySeenChats[chat.reference.id];
      final lastMessageAt = chat.lastMessageAt;

      if (seenAt != null &&
          lastMessageAt != null &&
          !lastMessageAt.isAfter(seenAt)) {
        // User clicked after last message, so remove from known unread
        knownUnreadChats.remove(chat.reference.id);
        return false;
      }
    }

    // Check Firestore state
    if (currentUserReference == null) return false;

    final userInSeenList = chat.lastMessageSeen.contains(currentUserReference);
    final hasLastMessage = chat.lastMessage.isNotEmpty;

    // Check if we already know this chat is unread (sticky)
    if (knownUnreadChats.contains(chat.reference.id)) {
      // FIX: If Firestore says it's seen, and we are not locally overriding it with an unread state
      // (meaning there's no newer message since they last saw it on this device),
      // we should consider it seen (e.g., they read it on their phone).
      if (userInSeenList) {
        knownUnreadChats.remove(chat.reference.id);
        return false;
      }
      return true; // Keep showing badge until user clicks
    }

    bool hasUnread = !userInSeenList && hasLastMessage;

    if (hasUnread) {
      // Add to known unread so it stays sticky
      knownUnreadChats.add(chat.reference.id);
    }

    return hasUnread;
  }

  // Get unread message count for a specific chat
  // Returns a stream that efficiently counts unread messages
  // Uses smart logic: only counts messages at/after lastMessageAt if user hasn't seen last message
  Stream<int> getUnreadMessageCount(ChatsRecord chat) {
    final chatId = chat.reference.id;

    if (currentUserReference == null) {
      _setCachedUnreadCount(chatId, 0);
      return Stream.value(0);
    }

    // CRITICAL: If this chat is currently open, return 0 (WhatsApp-like behavior)
    if (selectedChat.value != null &&
        selectedChat.value!.reference.id == chatId) {
      _setCachedUnreadCount(chatId, 0);
      return Stream.value(0);
    }

    // Check local state first
    if (locallySeenChats.containsKey(chatId)) {
      final seenAt = locallySeenChats[chatId];
      final lastMessageAt = chat.lastMessageAt;
      if (seenAt != null &&
          lastMessageAt != null &&
          !lastMessageAt.isAfter(seenAt)) {
        _setCachedUnreadCount(chatId, 0);
        return Stream.value(0);
      }
    }

    // If user has seen the last message, no unread messages
    if (chat.lastMessageSeen.contains(currentUserReference)) {
      _setCachedUnreadCount(chatId, 0);
      return Stream.value(0);
    }

    // If no last message or user sent the last message, no unread
    if (chat.lastMessage.isEmpty ||
        chat.lastMessageSent == currentUserReference) {
      _setCachedUnreadCount(chatId, 0);
      return Stream.value(0);
    }

    // Get the timestamp of the last message - we only count messages at/after this
    // This prevents counting old messages that don't have isReadBy populated
    final lastMessageAt = chat.lastMessageAt;
    if (lastMessageAt == null) {
      _setCachedUnreadCount(chatId, 0);
      return Stream.value(0);
    }

    // Stream messages and count only those at/after lastMessageAt that are unread
    // This ensures we only count NEW messages since the user last saw the chat
    return queryMessagesRecord(
      parent: chat.reference,
      queryBuilder: (messages) => messages
          .orderBy('created_at', descending: true)
          .limit(500), // Limit to recent messages for performance
    ).map((messagesList) {
      int count = 0;

      for (final message in messagesList) {
        // Only count messages that are:
        // 1. Not sent by current user
        // 2. Not system messages
        // 3. Not in isReadBy (truly unread)
        final isUnread = message.senderRef != currentUserReference &&
            !message.isSystemMessage &&
            !message.isReadBy.contains(currentUserReference);

        if (isUnread) {
          count++;
        } else if (message.senderRef == currentUserReference ||
            message.isReadBy.contains(currentUserReference)) {
          // If we find a message sent by the user or already seen by the user,
          // and we are iterating newest to oldest, we can stop here.
          break;
        }
      }

      _setCachedUnreadCount(chatId, count);
      return count;
    });
  }

  // Get total unread message count across all chats
  // Lightweight: count chats with unread (no per-chat message collection reads) to avoid Firebase overload.
  Stream<int> getTotalUnreadMessageCount() {
    if (currentUserReference == null) {
      return Stream.value(0);
    }

    return chats.stream.map((chatsList) {
      int totalCount = 0;
      for (final chat in chatsList) {
        if (hasUnreadMessages(chat)) {
          totalCount++;
        }
      }
      return totalCount;
    });
  }

  // Mark messages as seen
  Future<void> markMessagesAsSeen(ChatsRecord chat) async {
    try {
      if (currentUserReference == null) return;

      // Immediately update local state to prevent flickering
      // Use current time as the seen timestamp
      locallySeenChats[chat.reference.id] = DateTime.now();
      _setCachedUnreadCount(chat.reference.id, 0);

      // CRITICAL: Remove from knownUnreadChats immediately when user opens the chat
      // This ensures the badge disappears right away
      knownUnreadChats.remove(chat.reference.id);
      // Trigger badge update by updating chats (even if same, triggers stream)
      final currentChats = List<ChatsRecord>.from(chats);
      chats.value = currentChats;

      if (useWindowsFirestoreRest) {
        await _patchChatSeenViaRest(chat);
        return;
      }

      // Mark individual messages as read
      await _markIndividualMessagesAsRead(chat);

      // Update chat-level lastMessageSeen
      if (!chat.lastMessageSeen.contains(currentUserReference) &&
          chat.lastMessage.isNotEmpty &&
          chat.lastMessageSent != currentUserReference) {
        final updatedSeenList =
            List<DocumentReference>.from(chat.lastMessageSeen);
        if (!updatedSeenList.contains(currentUserReference)) {
          updatedSeenList.add(currentUserReference!);

          // Update Firestore in background without blocking UI
          // Also remove user from marked_unread_by if they manually marked it
          chat.reference.update({
            'last_message_seen': updatedSeenList.map((ref) => ref).toList(),
            'marked_unread_by': FieldValue.arrayRemove([currentUserReference!]),
          }).then((_) {
            // Stream will auto-update from Firestore, no need to reload
            debugLog('✅ Marked chat ${chat.reference.id} as seen in Firestore');
          }).catchError((e) {
            // If Firestore update fails, we don't necessarily need to remove from local state
            // because the local 'seen' is still valid for the current UI session.
            debugLog('❌ Error marking messages as seen: $e');
          });
        }
      } else {
        // Even if already in seen list, still remove from marked_unread_by
        final markedUnreadBy = chat.snapshotData['marked_unread_by'] as List<dynamic>?;
        if (markedUnreadBy != null && markedUnreadBy.contains(currentUserReference)) {
          chat.reference.update({
            'marked_unread_by': FieldValue.arrayRemove([currentUserReference!]),
          }).catchError((e) {
            debugLog('❌ Error removing from marked_unread_by: $e');
          });
        }
      }
    } catch (e) {
      debugLog('❌ Error marking messages as seen: $e');
    }
  }

  /// Chat-level seen state only — no messages subcollection reads on Windows.
  Future<void> _patchChatSeenViaRest(ChatsRecord chat) async {
    if (currentUserReference == null) return;

    try {
      final patch = <String, dynamic>{};
      if (!chat.lastMessageSeen.contains(currentUserReference) &&
          chat.lastMessage.isNotEmpty &&
          chat.lastMessageSent != currentUserReference) {
        final updatedSeenList =
            List<DocumentReference>.from(chat.lastMessageSeen);
        if (!updatedSeenList.contains(currentUserReference)) {
          updatedSeenList.add(currentUserReference!);
          patch['last_message_seen'] =
              updatedSeenList.map((ref) => ref).toList();
        }
      }

      final markedUnreadBy =
          chat.snapshotData['marked_unread_by'] as List<dynamic>?;
      if (markedUnreadBy != null &&
          markedUnreadBy.contains(currentUserReference)) {
        patch['marked_unread_by'] = markedUnreadBy
            .where((r) => r != currentUserReference)
            .toList();
      }

      if (patch.isEmpty) return;

      await fsPatchDocument(chat.reference, patch);
      debugLog('✅ [REST] Marked chat ${chat.reference.id} as seen');
    } catch (e) {
      debugLog('❌ [REST] Error marking chat as seen: $e');
    }
  }

  // Mark individual messages as read for better accuracy
  // Marks ALL unread messages in the chat as read
  Future<void> _markIndividualMessagesAsRead(ChatsRecord chat) async {
    if (currentUserReference == null) return;

    try {
      // Get all messages (increased limit to handle more messages)
      final messages = !kIsWeb && (Platform.isWindows || Platform.isLinux)
          ? await queryMessagesRecordOnce(
              parent: chat.reference,
              queryBuilder: (messages) => messages
                  .orderBy('created_at', descending: true)
                  .limit(1000),
            )
          : await queryMessagesRecord(
              parent: chat.reference,
              queryBuilder: (messages) => messages
                  .orderBy('created_at', descending: true)
                  .limit(1000),
            ).first;

      // Batch update messages - Firestore batch limit is 500 operations
      final batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;
      const maxBatchSize = 500;

      for (final message in messages) {
        // Only mark messages that are unread and not sent by current user
        if (message.senderRef != currentUserReference &&
            !message.isSystemMessage &&
            !message.isReadBy.contains(currentUserReference)) {
          final updatedReadBy = List<DocumentReference>.from(message.isReadBy);
          if (!updatedReadBy.contains(currentUserReference)) {
            updatedReadBy.add(currentUserReference!);
            batch.update(message.reference, {
              'is_read_by': updatedReadBy.map((ref) => ref).toList(),
            });
            updateCount++;

            // Commit batch if we reach the limit
            if (updateCount >= maxBatchSize) {
              await batch.commit();
              debugLog(
                  '✅ Marked $updateCount messages as read in chat ${chat.reference.id} (batch)');
              // Note: We can't create a new batch in the same function easily,
              // so for now we'll just commit what we have. If there are more than 500,
              // they'll be marked in the next call or we'd need to implement pagination.
              break;
            }
          }
        }
      }

      // Commit batch update if there are changes
      if (updateCount > 0 && updateCount < maxBatchSize) {
        await batch.commit();
        debugLog(
            '✅ Marked $updateCount messages as read in chat ${chat.reference.id}');
      } else if (updateCount >= maxBatchSize) {
        // If we hit the limit, we'd need to process remaining messages
        // For now, log it - in production you might want to implement pagination
        debugLog(
            '⚠️ Marked $updateCount messages as read (hit batch limit, may need to process more)');
      }
    } catch (e) {
      debugLog('❌ Error marking individual messages as read: $e');
    }
  }

  /// Chats with no messages in this many days are considered inactive.
  static const int inactiveDays = 30;

  /// Returns true if the chat has had no new messages in the last [inactiveDays].
  bool _isInactive(ChatsRecord chat) {
    final lastActivity = chat.lastMessageAt ?? chat.createdAt;
    if (lastActivity == null) return true; // no timestamp → inactive
    return DateTime.now().difference(lastActivity).inDays >= inactiveDays;
  }

  // Get filtered chats based on search and tab
  List<ChatsRecord> get filteredChats {
    List<ChatsRecord> filteredChatsList = List.from(chats);

    // Hide chats with no messages (temporary chats only appear when selected)
    // But always show service chats regardless of message count
    // IMPORTANT: Don't filter out chats that have lastMessageAt even if lastMessage is empty
    // (this can happen if video message update failed - we still want to show the group)
    filteredChatsList = filteredChatsList.where((chat) {
      if (chat.isServiceChat == true) {
        return true; // Always show service chats
      }

      // Filter out DM chats with blocked users (but keep group chats visible)
      if (!chat.isGroup && chat.members.any((member) =>
          member != currentUserReference &&
          blockedUserIds.value.contains(member.id))) {
        return false;
      }

      // If chat has lastMessageAt timestamp, show it even if lastMessage is empty
      // (handles cases where video message update failed)
      if (chat.lastMessageAt != null) {
        return true;
      }

      // Allow all connects and groups to display, even if they have no message history yet
      return true;
    }).toList();

    // 1. Filter by chat filter (All, Unread, DM, Groups, Service, Blocked)
    if (chatFilter.value == 'Unread') {
      filteredChatsList =
          filteredChatsList.where((chat) => hasUnreadMessages(chat)).toList();
    } else if (chatFilter.value == 'Inactive') {
      // Show only inactive chats (no messages in 30+ days)
      filteredChatsList =
          filteredChatsList.where((chat) => _isInactive(chat)).toList();
    } else if (chatFilter.value == 'DM') {
      filteredChatsList =
          filteredChatsList.where((chat) => !chat.isGroup).toList();
    } else if (chatFilter.value == 'Groups') {
      filteredChatsList =
          filteredChatsList.where((chat) => chat.isGroup).toList();
    } else if (chatFilter.value == 'Service') {
      filteredChatsList = filteredChatsList
          .where((chat) => chat.isServiceChat == true)
          .toList();
    } else {
      // Fallback to selected tab if filter is 'All' or unknown
      if (selectedTabIndex.value == 1) {
        // Unread only
        filteredChatsList =
            filteredChatsList.where((chat) => hasUnreadMessages(chat)).toList();
      }
      // All tab (index 0): show every chat including inactive
    }

    // 2. Filter by search query
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filteredChatsList = filteredChatsList.where((chat) {
        // Check chat title (for groups or if title is set)
        if (chat.title.toLowerCase().contains(query)) return true;

        // Check last message preview
        if (chat.lastMessage.toLowerCase().contains(query)) return true;

        // Check description
        if (chat.description.toLowerCase().contains(query)) return true;

        // Check search_names from Firestore (if populated)
        if (chat.searchNames.isNotEmpty) {
          if (chat.searchNames
              .any((name) => name.toLowerCase().contains(query))) {
            return true;
          }
        }

        // Fallback: check member display names from our local cache
        // This handles DMs where search_names is not set in Firestore
        for (final memberRef in chat.members) {
          if (memberRef == currentUserReference) continue; // skip self
          final cachedName = _userDisplayNameCache[memberRef.id]?.toLowerCase();
          if (cachedName != null && cachedName.contains(query)) return true;
        }

        // Check if this chat has a message content match (from async search)
        if (_messageSearchMatchIds.contains(chat.reference.id)) return true;

        return false;
      }).toList();
    }

    // 3. Sort chats: Pinned chats at the top, then by last message time (like WhatsApp)
    // Falls back to created_at so new/legacy chats without messages still sort properly
    filteredChatsList.sort((a, b) {
      // First, sort by pinned status (pinned chats come first)
      final userRef = currentUserReference;
      final aPinned = a.isPinnedByUser(userRef);
      final bPinned = b.isPinnedByUser(userRef);
      if (aPinned != bPinned) {
        return aPinned ? -1 : 1;
      }
      // Then sort by last message time (most recent first)
      // Use createdAt as fallback for chats that have never had a message
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;

      // Handle null values - put nulls at the end
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1; // a goes after b
      if (bTime == null) return -1; // b goes after a

      // Both have values, sort descending (newest first)
      return bTime.compareTo(aTime);
    });

    // Update tab title with unread count
    _updateTabTitle(filteredChatsList);

    return filteredChatsList;
  }

  // Populate user display name cache from chat members
  Future<void> _populateUserDisplayNameCache(
      List<ChatsRecord> updatedChats) async {
    try {
      // Collect all member refs we haven't cached yet
      final refsToFetch = <DocumentReference>{};
      for (final chat in updatedChats) {
        for (final memberRef in chat.members) {
          if (!_userDisplayNameCache.containsKey(memberRef.id)) {
            refsToFetch.add(memberRef);
          }
        }
      }

      if (refsToFetch.isEmpty) return;

      // Fetch up to 30 at a time with whereIn
      final refList = refsToFetch.toList();
      for (int i = 0; i < refList.length; i += 30) {
        final batch = refList.skip(i).take(30).toList();
        for (final ref in batch) {
          try {
            if (useWindowsFirestoreRest) {
              final user = await fsTryGetUserOnce(ref);
              if (user != null) {
                final name = user.displayName;
                _userDisplayNameCache[ref.id] = name;
              }
            } else {
              final doc = await ref.get();
              if (doc.exists) {
                final data = doc.data() as Map<String, dynamic>?;
                final name = (data?['display_name'] as String?) ??
                    (data?['name'] as String?) ??
                    '';
                _userDisplayNameCache[ref.id] = name;
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugLog('⚠️ Error populating user name cache: $e');
    }
  }

  // Search within message content for all chats and populate results
  Future<void> _searchMessagesContent(String query) async {
    if (query.isEmpty) {
      _messageSearchMatchIds.clear();
      messageSearchResults.clear();
      isSearchingMessages.value = false;
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    final newMatches = <String>{};
    final newResults = <MessageSearchResult>[];

    // Search messages in all current chats (limit to avoid too many reads)
    final chatsToSearch = chats.take(50).toList();
    for (final chat in chatsToSearch) {
      try {
        // Get chat display name
        String chatName = chat.title;
        if (chatName.isEmpty && !chat.isGroup) {
          final otherRef = chat.members.firstWhere(
            (m) => m != currentUserReference,
            orElse: () => chat.members.first,
          );
          chatName = _userDisplayNameCache[otherRef.id] ?? 'Chat';
        }
        if (chatName.isEmpty) chatName = 'Group Chat';

        final Iterable<MessagesRecord> messageRecords;
        if (useWindowsFirestoreRest) {
          messageRecords = await fsQueryChatMessages(
            chat.reference,
            limit: 200,
          );
        } else {
          final snapshot = await chat.reference
              .collection('messages')
              .orderBy('created_at', descending: true)
              .limit(200)
              .get();
          messageRecords = snapshot.docs
              .map((doc) => MessagesRecord.getDocumentFromData(doc.data(), doc.reference));
        }

        for (final message in messageRecords) {
          final text = message.content.toLowerCase();
          if (text.contains(lowercaseQuery)) {
            newMatches.add(chat.reference.id);
            // Collect up to 3 matching messages per chat
            if (newResults.where((r) => r.chatId == chat.reference.id).length < 3) {
              String senderName = message.senderName;
              String senderPhoto = message.senderPhoto;
              if (senderName.isEmpty && message.senderRef != null) {
                final senderRef = message.senderRef!;
                senderName = _userDisplayNameCache[senderRef.id] ?? '';
                if (senderName.isEmpty) {
                  try {
                    final userDoc = await fsGetUserOnce(senderRef);
                    senderName = userDoc.displayName;
                    if (senderPhoto.isEmpty) {
                      senderPhoto = userDoc.photoUrl;
                    }
                    if (senderName.isNotEmpty) {
                      _userDisplayNameCache[senderRef.id] = senderName;
                    }
                  } catch (_) {}
                }
              }

              newResults.add(MessageSearchResult(
                chatId: chat.reference.id,
                chatName: chatName,
                senderName: senderName,
                senderPhoto: senderPhoto,
                content: message.content,
                createdAt: message.createdAt,
                messageRef: message.reference,
                chatRef: chat.reference,
                isGroup: chat.isGroup,
              ));
            }
          }
        }
      } catch (_) {}
    }

    // Sort results by date (newest first)
    newResults.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });

    // Only update if the query hasn't changed while we were searching
    if (searchQuery.value.toLowerCase() == lowercaseQuery) {
      _messageSearchMatchIds.clear();
      _messageSearchMatchIds.addAll(newMatches);
      messageSearchResults.value = newResults;
      isSearchingMessages.value = false;
    }
  }

  // Refresh chats
  Future<void> refreshChats({bool force = false}) async {
    if (_desktopPollMode) {
      await _fetchChatsDesktopOnce(force: force);
      if (!force) {
        _desktopPollTimer?.cancel();
        _desktopPollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
          if (!_listListenersPaused && !isClosed) {
            _fetchChatsDesktopOnce();
          }
        });
      }
      return;
    }
    await loadChats();
  }

  /// Instant sidebar update after pin/unpin while chat list polling is paused.
  void applyLocalChatPinState({
    required DocumentReference chatRef,
    required DocumentReference userRef,
    required bool pinned,
  }) {
    ChatsRecord patchRecord(ChatsRecord chat) {
      if (chat.reference.path != chatRef.path) return chat;
      final pinnedBy = List<DocumentReference>.from(chat.pinnedBy);
      if (pinned) {
        if (!pinnedBy.any((ref) => ref.path == userRef.path)) {
          pinnedBy.add(userRef);
        }
      } else {
        pinnedBy.removeWhere((ref) => ref.path == userRef.path);
      }
      final data = Map<String, dynamic>.from(chat.snapshotData);
      data['pinned_by'] = pinnedBy;
      return ChatsRecord.getDocumentFromData(data, chat.reference);
    }

    chats.value = chats.map(patchRecord).toList();
    final selected = selectedChat.value;
    if (selected != null && selected.reference.path == chatRef.path) {
      selectedChat.value = patchRecord(selected);
    }
    chats.refresh();
  }

  /// Instant sidebar preview after send/edit while chat list polling is paused.
  void applyLocalChatLastMessageFromPatch(
    DocumentReference chatRef,
    Map<String, dynamic> patch,
  ) {
    if (isClosed) return;

    ChatsRecord patchRecord(ChatsRecord chat) {
      if (chat.reference.path != chatRef.path) return chat;
      final data = Map<String, dynamic>.from(chat.snapshotData);
      for (final entry in patch.entries) {
        data[entry.key] = entry.value;
      }
      return ChatsRecord.getDocumentFromData(data, chat.reference);
    }

    final updated = chats.map(patchRecord).toList();
    updated.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    chats.value = updated;
    final selected = selectedChat.value;
    if (selected != null && selected.reference.path == chatRef.path) {
      selectedChat.value = patchRecord(selected);
    }
    chats.refresh();
  }

  Future<void> _loadChatsDesktopPoll() async {
    if (_listListenersPaused || isClosed) return;
    await _fetchChatsDesktopOnce();
    _desktopPollTimer?.cancel();
    _desktopPollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_listListenersPaused && !isClosed) {
        _fetchChatsDesktopOnce();
      }
    });
  }

  Future<void> _fetchChatsDesktopOnce({bool force = false}) async {
    if (!force && (_listListenersPaused || isClosed)) return;
    if (currentUserReference == null) {
      errorMessage.value = 'User not logged in';
      chatState.value = ChatState.error;
      return;
    }
    try {
      final waitForSidebar = !_desktopSidebarPrimed;
      if (waitForSidebar || chats.isEmpty) {
        chatState.value = ChatState.loading;
        if (waitForSidebar) {
          desktopSidebarReady.value = false;
        }
      }

      final List<ChatsRecord> regularChats;
      if (useWindowsFirestoreRest) {
        regularChats =
            await fsQueryMemberChats(currentUserReference!);
      } else {
        regularChats = await WindowsFirestoreGate.instance.run(
          () => queryChatsRecordOnce(
            queryBuilder: (chatsRecord) => chatsRecord.where(
              'members',
              arrayContains: currentUserReference,
            ),
          ),
          label: 'chats:members',
        );
      }

      var serviceChats = _cachedServiceChats;
      if (waitForSidebar || serviceChats.isEmpty) {
        try {
          if (useWindowsFirestoreRest) {
            serviceChats = await fsQueryServiceChats();
          } else {
            serviceChats = await WindowsFirestoreGate.instance.run(
              () => queryChatsRecordOnce(
                queryBuilder: (chatsRecord) =>
                    chatsRecord.where('is_service_chat', isEqualTo: true),
              ),
              label: 'chats:service',
            );
          }
          _cachedServiceChats = serviceChats;
        } catch (e) {
          debugLog('⚠️ [ChatController] service chats load: $e');
        }
      }

      _combineAndUpdateChats(regularChats, serviceChats);

      if (waitForSidebar) {
        await _preloadSidebarMetadata();
        _desktopSidebarPrimed = true;
        desktopSidebarReady.value = true;
      } else {
        unawaited(_preloadSidebarMetadata());
      }

      chatState.value = ChatState.success;
      debugLog(
        '✅ [ChatController] desktop list ready: ${regularChats.length} chats',
      );

      if (!_desktopExtrasLoading) {
        _desktopExtrasLoading = true;
        unawaited(_fetchBlockedUsersDesktopOnce());
      }
    } catch (e) {
      errorMessage.value = 'Error loading chats: $e';
      chatState.value = ChatState.error;
      desktopSidebarReady.value = true;
      debugLog('❌ [ChatController] desktop poll failed: $e');
    }
  }

  Future<void> _preloadSidebarMetadata() async {
    final refsById = <String, DocumentReference>{};

    for (final chat in chats) {
      if (!chat.isGroup && chat.members.isNotEmpty) {
        final otherRef = chat.members.firstWhere(
          (m) => m != currentUserReference,
          orElse: () => chat.members.first,
        );
        if (fsIsRealUserRef(otherRef)) {
          refsById.putIfAbsent(otherRef.id, () => otherRef);
        } else {
          final synthetic = fsSyntheticAgentUser(otherRef);
          _userRecordCache[otherRef.id] = synthetic;
          _userDisplayNameCache[otherRef.id] = synthetic.displayName;
        }
      }

      final senderRef = chat.lastMessageSent;
      if (senderRef != null &&
          senderRef != currentUserReference &&
          fsIsRealUserRef(senderRef)) {
        refsById.putIfAbsent(senderRef.id, () => senderRef);
      } else if (senderRef != null &&
          senderRef != currentUserReference &&
          !fsIsRealUserRef(senderRef)) {
        final synthetic = fsSyntheticAgentUser(senderRef);
        _userRecordCache[senderRef.id] = synthetic;
        _userDisplayNameCache[senderRef.id] = synthetic.displayName;
      }
    }

    final toFetch = refsById.values
        .where((ref) => !_userRecordCache.containsKey(ref.id))
        .toList();

    const batchSize = 8;
    for (var i = 0; i < toFetch.length; i += batchSize) {
      if (isClosed || _listListenersPaused) return;
      final batch = toFetch.skip(i).take(batchSize);
      await Future.wait(
        batch.map((ref) async {
          try {
            await getOrCreateUserFuture(ref);
          } catch (e) {
            debugLog('⚠️ [ChatController] skip user prefetch ${ref.path}: $e');
          }
        }),
      );
    }
  }

  Future<void> _fetchBlockedUsersDesktopOnce() async {
    if (currentUserReference == null) return;
    try {
      if (useWindowsFirestoreRest) {
        final records = await fsQueryBlockedUsers(currentUserReference!);
        blockedUserIds.value = records
            .map((doc) => doc.blockedUser?.id)
            .whereType<String>()
            .toSet();
      } else {
        final snapshot = await WindowsFirestoreGate.instance.run(
          () => BlockedUsersRecord.collection
              .where('blocker_user', isEqualTo: currentUserReference)
              .get(),
          label: 'blocked-users',
        );
        blockedUserIds.value = snapshot.docs
            .map((doc) => BlockedUsersRecord.fromSnapshot(doc).blockedUser?.id)
            .whereType<String>()
            .toSet();
      }
    } catch (_) {}
  }

  // Update tab title with unread message count
  void _updateTabTitle(List<ChatsRecord> chats) {
    int unreadCount = 0;
    for (final chat in chats) {
      if (hasUnreadMessages(chat)) {
        unreadCount++;
      }
    }
    WebNotificationService.instance.updateTabTitle(unreadCount);
  }
}
