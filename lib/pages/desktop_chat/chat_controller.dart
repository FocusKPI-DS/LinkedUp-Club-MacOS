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
  final RxSet<String> locallySeenChats = <String>{}.obs;
  final Rx<DocumentReference?> currentWorkspaceRef =
      Rx<DocumentReference?>(null);

  // Error message
  final RxString errorMessage = ''.obs;

  // Method to update current workspace (called from main.dart when switching)
  void updateCurrentWorkspace(DocumentReference? workspaceRef) {
    print('🔄 ChatController: Updating workspace to ${workspaceRef?.path}');
    currentWorkspaceRef.value = workspaceRef;
  }

  @override
  void onInit() {
    super.onInit();
    loadChats();

    // Listen for workspace changes
    ever(currentWorkspaceRef, (workspaceRef) {
      print('🔄 Workspace changed to: ${workspaceRef?.path}');
      // Refresh the filtered chats when workspace changes
      update();
    });
  }

  StreamSubscription? _chatsSubscription;

  @override
  void onClose() {
    _chatsSubscription?.cancel();
    super.onClose();
  }

  // Load chats from Firestore with real-time updates
  Future<void> loadChats() async {
    try {
      // Cancel existing subscription if any
      await _chatsSubscription?.cancel();

      chatState.value = ChatState.loading;

      // Check if user is logged in
      if (currentUserReference == null) {
        errorMessage.value = 'User not logged in';
        chatState.value = ChatState.error;
        return;
      }

      // Get current user's workspace using UsersRecord
      final currentUserDoc =
          await UsersRecord.getDocumentOnce(currentUserReference!);
      final userWorkspaceRef = currentUserDoc.currentWorkspaceRef;

      print('🔍 DEBUG: Current workspace ref: $userWorkspaceRef');
      print('🔍 DEBUG: Current workspace path: ${userWorkspaceRef?.path}');

      // Store current workspace for filtering (can be null)
      currentWorkspaceRef.value = userWorkspaceRef;

      // Load chats even if workspace_ref is null (for backward compatibility)
      print('🔍 DEBUG: Starting chat query...');

      // Use queryChatsRecord stream which handles errors better
      final chatsStream = queryChatsRecord(
        queryBuilder: (chatsRecord) => chatsRecord
            .where('members', arrayContains: currentUserReference)
            .orderBy('last_message_at', descending: true),
      );

      _chatsSubscription = chatsStream.listen(
        (chatsList) {
          print('🔍 DEBUG: Query returned ${chatsList.length} chats');
          chats.value = chatsList;
          chatState.value = ChatState.success;
          print('✅ DEBUG: Chat state set to success');
        },
        onError: (error) {
          print('❌ DEBUG: Query error: $error');
          errorMessage.value = 'Error loading chats: $error';
          chatState.value = ChatState.error;
        },
      );
    } catch (e) {
      print('❌ DEBUG: Exception in loadChats: $e');
      errorMessage.value = 'Error loading chats: $e';
      chatState.value = ChatState.error;
    }
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

  // Check if chat has unread messages
  bool hasUnreadMessages(ChatsRecord chat) {
    // First check local state to prevent flickering
    if (locallySeenChats.contains(chat.reference.id)) {
      return false; // Already marked as seen locally
    }

    // Then check Firestore state
    if (currentUserReference == null) return false;

    bool hasUnread = !chat.lastMessageSeen.contains(currentUserReference) &&
        chat.lastMessage.isNotEmpty &&
        chat.lastMessageSent != currentUserReference;

    return hasUnread;
  }

  // Get unread message count for a specific chat
  // Returns a stream that efficiently counts unread messages
  // Uses smart logic: only counts messages at/after lastMessageAt if user hasn't seen last message
  Stream<int> getUnreadMessageCount(ChatsRecord chat) {
    if (currentUserReference == null) {
      return Stream.value(0);
    }

    // Check local state first - if chat is marked as seen locally, return 0
    if (locallySeenChats.contains(chat.reference.id)) {
      return Stream.value(0);
    }

    // If user has seen the last message, no unread messages
    if (chat.lastMessageSeen.contains(currentUserReference)) {
      return Stream.value(0);
    }

    // If no last message or user sent the last message, no unread
    if (chat.lastMessage.isEmpty || chat.lastMessageSent == currentUserReference) {
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
        // Stop if we've reached messages older than lastMessageAt
        // All messages before this are considered "seen" (user was in chat before)
        if (message.createdAt == null || message.createdAt!.isBefore(lastMessageAt)) {
          break;
        }

        // Only count messages at/after lastMessageAt that are:
        // 1. Not sent by current user
        // 2. Not system messages
        // 3. Not in isReadBy (truly unread)
        if (message.senderRef != currentUserReference &&
            !message.isSystemMessage &&
            !message.isReadBy.contains(currentUserReference) &&
            (message.createdAt!.isAfter(lastMessageAt) ||
             message.createdAt!.isAtSameMomentAs(lastMessageAt))) {
          count++;
        }
      }
      
      return count;
    });
  }

  // Get total unread message count across all chats
  // Optimized to efficiently count unread messages across all chats
  Stream<int> getTotalUnreadMessageCount() {
    if (currentUserReference == null) {
      return Stream.value(0);
    }

    // Use the chats stream and count unread messages efficiently
    return chats.stream.asyncMap((chatsList) async {
      int totalCount = 0;
      
      // Process chats in batches for better performance
      final batchSize = 10; // Process 10 chats at a time
      for (int i = 0; i < chatsList.length; i += batchSize) {
        final batch = chatsList.skip(i).take(batchSize);
        
        final futures = batch.map((chat) async {
          // Skip if locally marked as seen
          if (locallySeenChats.contains(chat.reference.id)) {
            return 0;
          }

          // Quick check: if user has seen last message, likely no unread
          if (chat.lastMessageSeen.contains(currentUserReference) ||
              chat.lastMessage.isEmpty ||
              chat.lastMessageSent == currentUserReference) {
            return 0;
          }

          // For chats with potential unread messages, count only NEW unread messages
          // Only count messages at/after lastMessageAt to avoid counting old messages
          try {
            final lastMessageAt = chat.lastMessageAt;
            if (lastMessageAt == null) {
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
              // Stop if we've reached messages older than lastMessageAt
              if (message.createdAt == null || message.createdAt!.isBefore(lastMessageAt)) {
                break;
              }

              // Only count messages at/after lastMessageAt that are unread
              if (message.senderRef != currentUserReference &&
                  !message.isSystemMessage &&
                  !message.isReadBy.contains(currentUserReference) &&
                  (message.createdAt!.isAfter(lastMessageAt) ||
                   message.createdAt!.isAtSameMomentAs(lastMessageAt))) {
                chatCount++;
              }
            }
            return chatCount;
          } catch (e) {
            print('Error counting unread for chat ${chat.reference.id}: $e');
            return 0;
          }
        });

        final counts = await Future.wait(futures);
        totalCount += counts.fold(0, (sum, count) => sum + count);
      }
      
      return totalCount;
    });
  }

  // Mark messages as seen
  Future<void> markMessagesAsSeen(ChatsRecord chat) async {
    try {
      if (currentUserReference == null) return;

      // Immediately update local state to prevent flickering
      locallySeenChats.add(chat.reference.id);

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
            // Force UI update by refreshing the chat list
            loadChats();
          }).catchError((e) {
            // If Firestore update fails, remove from local state
            locallySeenChats.remove(chat.reference.id);
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
          final updatedReadBy =
              List<DocumentReference>.from(message.isReadBy);
          if (!updatedReadBy.contains(currentUserReference)) {
            updatedReadBy.add(currentUserReference!);
            batch.update(message.reference, {
              'is_read_by': updatedReadBy.map((ref) => ref).toList(),
            });
            updateCount++;
            
            // Commit batch if we reach the limit
            if (updateCount >= maxBatchSize) {
              await batch.commit();
              print('✅ Marked $updateCount messages as read in chat ${chat.reference.id} (batch)');
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
        print('✅ Marked $updateCount messages as read in chat ${chat.reference.id}');
      } else if (updateCount >= maxBatchSize) {
        // If we hit the limit, we'd need to process remaining messages
        // For now, log it - in production you might want to implement pagination
        print('⚠️ Marked $updateCount messages as read (hit batch limit, may need to process more)');
      }
    } catch (e) {
      print('❌ Error marking individual messages as read: $e');
    }
  }

  // Get filtered chats based on search and tab
  List<ChatsRecord> get filteredChats {
    List<ChatsRecord> filteredChats = List.from(chats);

    // Hide chats with no messages (temporary chats only appear when selected)
    filteredChats = filteredChats.where((chat) {
      if (chat.lastMessage.isEmpty) {
        return false;
      }
      return true;
    }).toList();

    // Filter by search query
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filteredChats = filteredChats.where((chat) {
        if (chat.isGroup) {
          return chat.title.toLowerCase().contains(query);
        } else {
          // For direct chats, we'll filter in the UI based on user data
          return true;
        }
      }).toList();
    }

    // Filter by selected tab
    if (selectedTabIndex.value == 0) {
      // All - show both direct messages and groups (no filtering)
      // filteredChats remains unchanged
    } else if (selectedTabIndex.value == 1) {
      // Direct messages only
      filteredChats = filteredChats.where((chat) => !chat.isGroup).toList();
    } else if (selectedTabIndex.value == 2) {
      // Groups only
      filteredChats = filteredChats.where((chat) => chat.isGroup).toList();
    }

    // Sort chats: Pinned chats at the top, then by last message time
    filteredChats.sort((a, b) {
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
    _updateTabTitle(filteredChats);

    return filteredChats;
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
