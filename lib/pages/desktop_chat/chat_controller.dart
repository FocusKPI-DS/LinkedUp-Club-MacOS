import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/custom_code/services/web_notification_service.dart';
import 'package:get/get.dart';
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

    // Debug logging
    print('Checking unread messages for chat: ${chat.reference.id}');
    print('Last message: "${chat.lastMessage}"');
    print('Last message sent by: ${chat.lastMessageSent}');
    print('Current user: $currentUserReference');
    print('Last message seen by: ${chat.lastMessageSeen}');
    print(
        'Has current user seen: ${chat.lastMessageSeen.contains(currentUserReference)}');

    // Then check Firestore state
    if (currentUserReference == null) return false;

    bool hasUnread = !chat.lastMessageSeen.contains(currentUserReference) &&
        chat.lastMessage.isNotEmpty &&
        chat.lastMessageSent != currentUserReference;

    print('Has unread messages: $hasUnread');
    return hasUnread;
  }

  // Mark messages as seen
  Future<void> markMessagesAsSeen(ChatsRecord chat) async {
    try {
      print('Marking messages as seen for chat: ${chat.reference.id}');
      print('Current user: $currentUserReference');
      print('Last message seen by: ${chat.lastMessageSeen}');
      print(
          'Has current user seen: ${chat.lastMessageSeen.contains(currentUserReference)}');

      // Only update if current user hasn't seen the last message
      if (currentUserReference == null) return;

      if (!chat.lastMessageSeen.contains(currentUserReference) &&
          chat.lastMessage.isNotEmpty &&
          chat.lastMessageSent != currentUserReference) {
        print('Updating last_message_seen for chat: ${chat.reference.id}');

        // Immediately update local state to prevent flickering
        locallySeenChats.add(chat.reference.id);

        // Add current user to the lastMessageSeen list
        final updatedSeenList =
            List<DocumentReference>.from(chat.lastMessageSeen);
        updatedSeenList.add(currentUserReference ??
            FirebaseFirestore.instance.collection('users').doc('placeholder'));

        // Update Firestore in background without blocking UI
        chat.reference.update({
          'last_message_seen': updatedSeenList.map((ref) => ref).toList(),
        }).then((_) {
          print(
              'Successfully updated last_message_seen for chat: ${chat.reference.id}');
        }).catchError((e) {
          // If Firestore update fails, remove from local state
          locallySeenChats.remove(chat.reference.id);
          print('Error marking messages as seen: $e');
        });
      } else {
        print(
            'No need to update last_message_seen - already seen or conditions not met');
      }
    } catch (e) {
      print('Error marking messages as seen: $e');
    }
  }

  // Get filtered chats based on search, tab, and workspace
  List<ChatsRecord> get filteredChats {
    List<ChatsRecord> filteredChats = List.from(chats);

    // Filter by current workspace (UI-level filtering - safer approach)
    // Show chats that belong to the current workspace or have no workspace_ref (for backward compatibility)
    filteredChats = filteredChats.where((chat) {
      // Hide chats with no messages (temporary chats only appear when selected)
      if (chat.lastMessage.isEmpty) {
        return false;
      }

      // If current workspace is null, show all chats (backward compatibility)
      if (currentWorkspaceRef.value == null) {
        return true;
      }

      // If current workspace is set, filter by workspace
      // Show chats that match the workspace OR have no workspace_ref (legacy chats)
      if (chat.hasWorkspaceRef()) {
        // Chat has workspace_ref - only show if it matches current workspace
        final matches =
            chat.workspaceRef?.path == currentWorkspaceRef.value?.path;
        return matches;
      } else {
        // Chat has no workspace_ref - show it (legacy chat)
        return true;
      }
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
