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

  // Blocked users set (reactive)
  final Rx<Set<String>> blockedUserIds = Rx<Set<String>>(<String>{});

  // Cache: userRef.id → display name (populated on chat load for fast search)
  final Map<String, String> _userDisplayNameCache = {};

  /// Returns cached display name for a user (used by UI to avoid "Direct Chat" flash).
  String? getCachedDisplayName(String? userRefId) =>
      userRefId == null ? null : _userDisplayNameCache[userRefId];

  // Chat IDs that matched a message content search (async, cleared when query changes)
  final RxSet<String> _messageSearchMatchIds = <String>{}.obs;

  // Error message
  final RxString errorMessage = ''.obs;

  Timer? _messageSearchDebounce;

  @override
  void onInit() {
    super.onInit();
    loadChats();
  }

  StreamSubscription? _chatsSubscription;
  StreamSubscription? _serviceChatsSubscription;
  StreamSubscription? _blockedUsersSubscription;

  @override
  void onClose() {
    _chatsSubscription?.cancel();
    _blockedUsersSubscription?.cancel();
    _serviceChatsSubscription?.cancel();
    super.onClose();
  }

  // Load chats from Firestore with real-time updates
  Future<void> loadChats() async {
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

      // Listen to blocked users for real-time filtering
      print(
          'Debug: Initializing blocked user listener in ChatController. CurrentUserRef: $currentUserReference');
      _blockedUsersSubscription = BlockedUsersRecord.collection
          .where('blocker_user', isEqualTo: currentUserReference)
          .snapshots()
          .listen((snapshot) {
        blockedUserIds.value = snapshot.docs
            .map((doc) => BlockedUsersRecord.fromSnapshot(doc).blockedUser?.id)
            .whereType<String>()
            .toSet();
        print('Debug: ChatController updated blocked IDs to: $blockedUserIds');
        chats.refresh();
      }, onError: (e) {
        print('Debug: Error in ChatController blocked user listener: $e');
      });
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

    // Populate user display name cache so search can match member names
    // even if search_names is not populated in Firestore
    _populateUserDisplayNameCache(combinedChats);
  }

  // Set selected chat
  void selectChat(ChatsRecord chat) {
    _manuallyMarkedUnread.remove(chat.reference.id);
    selectedChat.value = chat;
    markMessagesAsSeen(chat);
  }

  // Mark a chat as unread (local-only, WeChat-style)
  void markChatAsUnread(ChatsRecord chat) {
    _manuallyMarkedUnread.add(chat.reference.id);
    knownUnreadChats.add(chat.reference.id);
    // Set seenAt to epoch so any lastMessageAt is always "after" it
    locallySeenChats[chat.reference.id] =
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  // Update search query and trigger async message search
  void updateSearchQuery(String query) {
    searchQuery.value = query;
    _messageSearchMatchIds.clear();
    _messageSearchDebounce?.cancel();
    if (query.isEmpty) return;
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
    // IMPORTANT: Don't filter out chats that have lastMessageAt even if lastMessage is empty
    // (this can happen if video message update failed - we still want to show the group)
    filteredChatsList = filteredChatsList.where((chat) {
      if (chat.isServiceChat == true) {
        return true; // Always show service chats
      }

      // Filter out chats with blocked users
      // Check if any member (other than current user) is in the blocked list
      if (chat.members.any((member) =>
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
      } else if (selectedTabIndex.value == 3) {
        // Unread only
        filteredChatsList =
            filteredChatsList.where((chat) => hasUnreadMessages(chat)).toList();
      }
      // If selectedTabIndex is 0 (All), we show everything
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
    filteredChatsList.sort((a, b) {
      // First, sort by pinned status (pinned chats come first)
      if (a.isPin != b.isPin) {
        return a.isPin ? -1 : 1;
      }
      // Then sort by last message time (most recent first)
      final aTime = a.lastMessageAt;
      final bTime = b.lastMessageAt;

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
            final doc = await ref.get();
            if (doc.exists) {
              final data = doc.data() as Map<String, dynamic>?;
              final name = (data?['display_name'] as String?) ??
                  (data?['name'] as String?) ??
                  '';
              _userDisplayNameCache[ref.id] = name;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print('⚠️ Error populating user name cache: $e');
    }
  }

  // Search within message content for all chats and populate _messageSearchMatchIds
  Future<void> _searchMessagesContent(String query) async {
    if (query.isEmpty) {
      _messageSearchMatchIds.clear();
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    final newMatches = <String>{};

    // Search messages in all current chats (limit to avoid too many reads)
    final chatsToSearch = chats.take(50).toList();
    for (final chat in chatsToSearch) {
      try {
        // Messages are stored as a subcollection of each chat document
        final messages = await chat.reference
            .collection('messages')
            .orderBy('created_at', descending: true)
            .limit(200)
            .get();

        for (final doc in messages.docs) {
          final text = ((doc.data()['content'] ?? '') as String).toLowerCase();
          if (text.contains(lowercaseQuery)) {
            newMatches.add(chat.reference.id);
            break; // Found a match in this chat, move to next
          }
        }
      } catch (_) {}
    }

    // Only update if the query hasn't changed while we were searching
    if (searchQuery.value.toLowerCase() == lowercaseQuery) {
      _messageSearchMatchIds.clear();
      _messageSearchMatchIds.addAll(newMatches);
    }
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
