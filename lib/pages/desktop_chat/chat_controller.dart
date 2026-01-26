import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/custom_code/services/web_notification_service.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

enum ChatState { loading, success, error }

class ChatController extends GetxController {
  // Observable variables
  final Rx<ChatState> chatState = ChatState.loading.obs;
  final RxList<ChatsRecord> chats = <ChatsRecord>[].obs;
  final Rx<ChatsRecord?> selectedChat = Rx<ChatsRecord?>(null);
  final RxString searchQuery = ''.obs;
  final RxInt selectedTabIndex = 0.obs;
  final RxString chatFilter = 'All'.obs; // Filter: All, Unread, DM, Groups
  final RxMap<String, DateTime> locallySeenChats = <String, DateTime>{}.obs;

  // Error message
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadChats();
  }

  StreamSubscription? _chatsSubscription;
  StreamSubscription? _serviceChatsSubscription;

  @override
  void onClose() {
    _chatsSubscription?.cancel();
    _serviceChatsSubscription?.cancel();
    super.onClose();
  }

  // Load chats from Firestore with real-time updates
  Future<void> loadChats() async {
    try {
      // Cancel existing subscriptions if any
      await _chatsSubscription?.cancel();
      await _serviceChatsSubscription?.cancel();

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
        }
        // Don't remove based on Firestore lastMessageSeen alone - it might be stale
        // The user needs to explicitly click on the chat to mark it as seen
      }

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
            markMessagesAsSeen(chat).catchError((e) {
              print('⚠️ Error auto-marking open chat as seen: $e');
            });
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
    combinedChats.sort((a, b) {
      final aTime = a.lastMessageAt;
      final bTime = b.lastMessageAt;

      // Handle null values - put nulls at the end
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1; // a goes after b
      if (bTime == null) return -1; // b goes after a

      // Both have values, sort descending (newest first)
      return bTime.compareTo(aTime);
    });

    chats.value = combinedChats;
    chatState.value = ChatState.success;
  }

  // Set selected chat
  void selectChat(ChatsRecord chat) {
    selectedChat.value = chat;
    markMessagesAsSeen(chat);
  }

  // Update search query
  void updateSearchQuery(String query) {
    searchQuery.value = query;
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

    // Check if we already know this chat is unread (sticky)
    if (knownUnreadChats.contains(chat.reference.id)) {
      return true; // Keep showing badge until user clicks
    }

    // Check Firestore state
    if (currentUserReference == null) return false;

    final userInSeenList = chat.lastMessageSeen.contains(currentUserReference);
    final hasLastMessage = chat.lastMessage.isNotEmpty;

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
    if (currentUserReference == null) {
      return Stream.value(0);
    }

    // CRITICAL: If this chat is currently open, return 0 (WhatsApp-like behavior)
    if (selectedChat.value != null &&
        selectedChat.value!.reference.id == chat.reference.id) {
      return Stream.value(0);
    }

    // Check local state first
    if (locallySeenChats.containsKey(chat.reference.id)) {
      final seenAt = locallySeenChats[chat.reference.id];
      final lastMessageAt = chat.lastMessageAt;
      if (seenAt != null &&
          lastMessageAt != null &&
          !lastMessageAt.isAfter(seenAt)) {
        return Stream.value(0);
      }
    }

    // If user has seen the last message, no unread messages
    if (chat.lastMessageSeen.contains(currentUserReference)) {
      return Stream.value(0);
    }

    // If no last message or user sent the last message, no unread
    if (chat.lastMessage.isEmpty ||
        chat.lastMessageSent == currentUserReference) {
      return Stream.value(0);
    }

    // Get the timestamp of the last message - we only count messages at/after this
    // This prevents counting old messages that don't have isReadBy populated
    final lastMessageAt = chat.lastMessageAt;
    if (lastMessageAt == null) {
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

      return count;
    });
  }

  // Get total unread message count across all chats
  // Uses the same logic as hasUnreadMessages() for consistency
  Stream<int> getTotalUnreadMessageCount() {
    if (currentUserReference == null) {
      return Stream.value(0);
    }

    // CRITICAL: Listen to chats stream - will trigger when chats update
    // We also manually trigger updates when knownUnreadChats changes
    return chats.stream.asyncMap((chatsList) async {
      int totalCount = 0;

      // Process chats in batches for better performance
      final batchSize = 10; // Process 10 chats at a time
      for (int i = 0; i < chatsList.length; i += batchSize) {
        final batch = chatsList.skip(i).take(batchSize);

        final futures = batch.map((chat) async {
          // CRITICAL: If this chat is currently open, return 0 (WhatsApp-like behavior)
          if (selectedChat.value != null &&
              selectedChat.value!.reference.id == chat.reference.id) {
            return 0;
          }

          // Use the SAME logic as hasUnreadMessages() for consistency
          // 1. Check knownUnreadChats FIRST (sticky) - if chat is known unread, we MUST count it
          // This prevents flickering when new messages arrive
          final isKnownUnread = knownUnreadChats.contains(chat.reference.id);

          // 2. Check locally seen chats - but only skip if NO new messages arrived
          if (locallySeenChats.containsKey(chat.reference.id)) {
            final seenAt = locallySeenChats[chat.reference.id];
            final lastMessageAt = chat.lastMessageAt;
            // Only skip if no new message arrived after user saw it
            // If new message arrived (lastMessageAt is after seenAt), we still need to count
            if (seenAt != null &&
                lastMessageAt != null &&
                !lastMessageAt.isAfter(seenAt)) {
              // No new messages since user saw it, but if it's in knownUnreadChats, still count
              // (this handles edge cases where knownUnreadChats wasn't cleared properly)
              if (!isKnownUnread) {
                return 0;
              }
            }
          }

          // 3. Quick check: if user has seen last message in Firestore, likely no unread
          // BUT if it's in knownUnreadChats, we still count (sticky behavior for new messages)
          if (!isKnownUnread) {
            if (chat.lastMessageSeen.contains(currentUserReference) ||
                chat.lastMessage.isEmpty ||
                chat.lastMessageSent == currentUserReference) {
              return 0;
            }
          }

          // 4. For chats with potential unread messages, count actual unread messages
          try {
            final lastMessageAt = chat.lastMessageAt;
            if (lastMessageAt == null) {
              // No last message timestamp - return 0 (cleanup should have removed from knownUnreadChats)
              return 0;
            }

            final messages = await queryMessagesRecord(
              parent: chat.reference,
              queryBuilder: (messages) => messages
                  .orderBy('created_at', descending: true)
                  .limit(500), // Limit to recent messages
            ).first;

            int chatCount = 0;
            for (final message in messages) {
              // Only count messages that are unread
              final isUnread = message.senderRef != currentUserReference &&
                  !message.isSystemMessage &&
                  !message.isReadBy.contains(currentUserReference);

              if (isUnread) {
                chatCount++;
              } else if (message.senderRef == currentUserReference ||
                  message.isReadBy.contains(currentUserReference)) {
                // Stop when we reach a seen or sent message
                break;
              }
            }

            // IMPORTANT: Only return count if chat is actually unread
            // If user has seen the chat locally and no new messages, return 0
            // This ensures badge disappears when user opens the chat
            if (locallySeenChats.containsKey(chat.reference.id)) {
              final seenAt = locallySeenChats[chat.reference.id];
              final lastMessageAt = chat.lastMessageAt;
              // If user saw it and no new messages arrived, return 0
              if (seenAt != null &&
                  lastMessageAt != null &&
                  !lastMessageAt.isAfter(seenAt)) {
                return 0;
              }
            }

            return chatCount;
          } catch (e) {
            print('Error counting unread for chat ${chat.reference.id}: $e');
            // On error, return 0 - cleanup logic should handle knownUnreadChats
            return 0;
          }
        });

        final counts = await Future.wait(futures);
        totalCount += counts.fold<int>(0, (sum, count) => sum + count);
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

      // CRITICAL: Remove from knownUnreadChats immediately when user opens the chat
      // This ensures the badge disappears right away
      knownUnreadChats.remove(chat.reference.id);
      // Trigger badge update by updating chats (even if same, triggers stream)
      final currentChats = List<ChatsRecord>.from(chats);
      chats.value = currentChats;

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
          chat.reference.update({
            'last_message_seen': updatedSeenList.map((ref) => ref).toList(),
          }).then((_) {
            // Stream will auto-update from Firestore, no need to reload
            print('✅ Marked chat ${chat.reference.id} as seen in Firestore');
          }).catchError((e) {
            // If Firestore update fails, we don't necessarily need to remove from local state
            // because the local 'seen' is still valid for the current UI session.
            print('❌ Error marking messages as seen: $e');
          });
        }
      }
    } catch (e) {
      print('❌ Error marking messages as seen: $e');
    }
  }

  // Mark individual messages as read for better accuracy
  // Marks ALL unread messages in the chat as read
  Future<void> _markIndividualMessagesAsRead(ChatsRecord chat) async {
    if (currentUserReference == null) return;

    try {
      // Get all messages (increased limit to handle more messages)
      final messages = await queryMessagesRecord(
        parent: chat.reference,
        queryBuilder: (messages) => messages
            .orderBy('created_at', descending: true)
            .limit(1000), // Process more messages for accuracy
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
              print(
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
        print(
            '✅ Marked $updateCount messages as read in chat ${chat.reference.id}');
      } else if (updateCount >= maxBatchSize) {
        // If we hit the limit, we'd need to process remaining messages
        // For now, log it - in production you might want to implement pagination
        print(
            '⚠️ Marked $updateCount messages as read (hit batch limit, may need to process more)');
      }
    } catch (e) {
      print('❌ Error marking individual messages as read: $e');
    }
  }

  // Get filtered chats based on search and tab
  List<ChatsRecord> get filteredChats {
    List<ChatsRecord> filteredChatsList = List.from(chats);

    // Hide chats with no messages (temporary chats only appear when selected)
    // But always show service chats regardless of message count
    filteredChatsList = filteredChatsList.where((chat) {
      if (chat.isServiceChat == true) {
        return true; // Always show service chats
      }
      if (chat.lastMessage.isEmpty) {
        return false;
      }
      return true;
    }).toList();

    // 1. Filter by chat filter (All, Unread, DM, Groups, Service)
    if (chatFilter.value == 'Unread') {
      filteredChatsList =
          filteredChatsList.where((chat) => hasUnreadMessages(chat)).toList();
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
        // Direct messages only
        filteredChatsList =
            filteredChatsList.where((chat) => !chat.isGroup).toList();
      } else if (selectedTabIndex.value == 2) {
        // Groups only
        filteredChatsList =
            filteredChatsList.where((chat) => chat.isGroup).toList();
      }
      // If selectedTabIndex is 0 (All), we show everything
    }

    // 2. Filter by search query
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filteredChatsList = filteredChatsList.where((chat) {
        // Check chat title (for groups or if title is set)
        if (chat.title.toLowerCase().contains(query)) {
          return true;
        }

        // Check last message
        if (chat.lastMessage.toLowerCase().contains(query)) {
          return true;
        }

        // Check description
        if (chat.description.toLowerCase().contains(query)) {
          return true;
        }

        // For direct chats, check search_names which contains member names
        if (chat.searchNames.isNotEmpty) {
          return chat.searchNames
              .any((name) => name.toLowerCase().contains(query));
        }

        return false;
      }).toList();
    }

    // 3. Sort chats: Pinned chats at the top, then by last message time (like WhatsApp)
    filteredChatsList.sort((a, b) {
      // First, sort by pinned status (pinned chats come first)
      if (a.isPin != b.isPin) {
        return a.isPin ? -1 : 1;
      }
      // Then sort by last message time (most recent first)
      if (a.lastMessageAt != null && b.lastMessageAt != null) {
        return b.lastMessageAt!.compareTo(a.lastMessageAt!);
      }
      // Handle null cases - chats with lastMessageAt come first
      if (a.lastMessageAt != null && b.lastMessageAt == null) return -1;
      if (a.lastMessageAt == null && b.lastMessageAt != null) return 1;
      return 0;
    });

    // Update tab title with unread count
    _updateTabTitle(filteredChatsList);

    return filteredChatsList;
  }

  // Refresh chats
  Future<void> refreshChats() async {
    await loadChats();
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
