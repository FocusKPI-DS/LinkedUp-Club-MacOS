import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import '/pages/mobile_chat/mobile_chat_widget.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/utils/chat_helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, File;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'dart:ui';
import 'user_summary_model.dart';
export 'user_summary_model.dart';

/// UserSummaryWidget displays the user's profile summary page.
///
/// This widget is DIRECTLY LINKED with the onboarding process:
/// - All fields set during onboarding (bio, location, interests, photoUrl) are displayed here
/// - When editable (isEditable: true), users can update these same fields
/// - The save function saves to the same Firestore fields that onboarding uses
///
/// Fields from onboarding displayed here:
/// - photoUrl: Profile picture (set during onboarding)
/// - location: User's location address (from onboarding placePickerValue.address)
/// - bio: User's bio/description (from onboarding bioTextController)
/// - interests: List of user interests (from onboarding iterested list)
///
/// Additional fields displayed:
/// - display_name: Set during sign up, editable here
/// - email: Set during sign up, displayed but not editable
/// - cover_photo_url: Optional cover photo (separate from onboarding)
/// - website: Optional website URL (not in onboarding, but editable)
class UserSummaryWidget extends StatefulWidget {
  const UserSummaryWidget({
    super.key,
    required this.userRef,
    this.isEditable = false,
    this.initialEditMode = false,
  });

  final DocumentReference? userRef;
  final bool isEditable;
  final bool initialEditMode;

  static String routeName = 'UserSummary';
  static String routePath = '/userSummary';

  @override
  State<UserSummaryWidget> createState() => _UserSummaryWidgetState();
}

class _UserSummaryWidgetState extends State<UserSummaryWidget> {
  late UserSummaryModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UserSummaryModel());
    // Activate edit mode if initialEditMode is true
    if (widget.initialEditMode && widget.isEditable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _model.isEditing = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  /// Helper method to show iOS 26+ adaptive dialog instead of SnackBar
  Future<void> _showAdaptiveDialog({
    required String title,
    required String message,
    String? icon,
    bool isError = false,
  }) async {
    if (!mounted) return;
    await AdaptiveAlertDialog.show(
      context: context,
      title: title,
      message: message,
      icon: icon ?? (isError ? 'exclamationmark.triangle.fill' : 'checkmark.circle.fill'),
      actions: [
        AlertAction(
          title: 'OK',
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );
  }

  String? _getCoverPhotoUrl(UsersRecord user) {
    final userData = user.snapshotData;
    return userData['cover_photo_url'] as String?;
  }

  Widget _buildInitialsAvatar(UsersRecord user) {
    final initials = user.displayName.isNotEmpty
        ? user.displayName
            .split(' ')
            .map((name) => name.isNotEmpty ? name[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'U';

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0077B5),
            Color(0xFF004182),
          ],
        ),
        border: Border.all(
          color: Colors.white,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPhoto(String? coverPhotoUrl) {
    if (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: coverPhotoUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => _buildDefaultGradient(),
        errorWidget: (context, url, error) => _buildDefaultGradient(),
      );
    }
    return _buildDefaultGradient();
  }

  Widget _buildDefaultGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0077B5), // LinkedIn blue
            Color(0xFF004182),
          ],
        ),
      ),
    );
  }

  int _calculateMutualConnections(
      UsersRecord currentUser, UsersRecord profileUser) {
    if (currentUser.reference == profileUser.reference) return 0;
    return currentUser.friends
        .where((ref) => profileUser.friends.contains(ref))
        .length;
  }

  bool _isUserConnected(DocumentReference userRef, UsersRecord currentUser) {
    return currentUser.friends.contains(userRef);
  }

  bool _isValidSentRequest(DocumentReference userRef, UsersRecord currentUser) {
    // Check if the sent request is still pending and user is not already connected
    return currentUser.sentRequests.contains(userRef) &&
        !currentUser.friends.contains(userRef);
  }

  bool _hasIncomingRequest(DocumentReference userRef, UsersRecord currentUser) {
    return currentUser.friendRequests.contains(userRef) &&
        !currentUser.friends.contains(userRef);
  }

  // Track loading states for connection operations
  final Set<String> _loadingOperations = <String>{};

  bool _isOperationInProgress(String userId) {
    return _loadingOperations.contains(userId);
  }

  void _startOperation(String userId) {
    setState(() {
      _loadingOperations.add(userId);
    });
  }

  void _stopOperation(String userId) {
    setState(() {
      _loadingOperations.remove(userId);
    });
  }

  Future<void> _startChat(UsersRecord user) async {
    try {
      final chatToOpen =
          await ChatHelpers.findOrCreateDirectChat(user.reference);

      if (context.mounted) {
        // Platform-specific navigation
        if (kIsWeb || (!kIsWeb && Platform.isMacOS)) {
          // macOS or Web: Navigate to DesktopChat tab and select the chat
          context.pushNamed(
            '_initialize',
            queryParameters: {'tab': 'DesktopChat'},
          );

          // Wait for DesktopChatWidget to initialize, then select the chat
          // Use multiple retries with increasing delays to ensure the widget is ready
          // Start with a longer delay to ensure navigation completes
          Future.delayed(Duration(milliseconds: 500), () {
            _selectChatInDesktop(chatToOpen, retryCount: 0);
          });
        } else {
          // iOS: Navigate to MobileChat with initialChat
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MobileChatWidget(
                initialChat: chatToOpen,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        await _showAdaptiveDialog(
          title: 'Error',
          message: 'Error starting chat: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _sendConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - don't send if already connected or request already sent
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (currentUserData.friends.contains(user.reference)) {
        _showErrorMessage('You are already connected with ${user.displayName}');
        return;
      }

      if (currentUserData.sentRequests.contains(user.reference)) {
        _showErrorMessage(
            'Connection request already sent to ${user.displayName}');
        return;
      }

      // Check if they already sent us a request (auto-accept scenario)
      if (currentUserData.friendRequests.contains(user.reference)) {
        await _acceptConnectionRequest(user);
        return;
      }

      // Use a batch write for better performance and atomicity
      final batch = FirebaseFirestore.instance.batch();

      // Update current user's sent requests
      batch.update(currentUserReference!, {
        'sent_requests': FieldValue.arrayUnion([user.reference]),
      });

      // Update target user's friend requests
      batch.update(user.reference, {
        'friend_requests': FieldValue.arrayUnion([currentUserReference]),
      });

      await batch.commit();

      if (mounted) {
        _showSuccessMessage('Connection request sent to ${user.displayName}');
      }
    } catch (e) {
      print('Error sending connection request: $e');
      if (mounted) {
        // Check if it's a permission error and provide specific guidance
        if (e.toString().contains('permission-denied')) {
          _showErrorMessage(
              'Unable to send connection request. This feature requires updated permissions.');
        } else {
          _showErrorMessage(
              'Failed to send connection request. Please check your internet connection and try again.');
        }
      }
    } finally {
      _stopOperation(userId);
    }
  }

  Future<void> _cancelConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - ensure request exists
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (!currentUserData.sentRequests.contains(user.reference)) {
        _showErrorMessage('No pending request to ${user.displayName}');
        return;
      }

      // Use a batch write for better performance and atomicity
      final batch = FirebaseFirestore.instance.batch();

      // Update current user: remove from sent_requests
      batch.update(currentUserReference!, {
        'sent_requests': FieldValue.arrayRemove([user.reference]),
      });

      // Update target user: remove from friend_requests
      batch.update(user.reference, {
        'friend_requests': FieldValue.arrayRemove([currentUserReference]),
      });

      await batch.commit();

      if (mounted) {
        _showSuccessMessage('Connection request cancelled');
      }
    } catch (e) {
      print('Error cancelling connection request: $e');
      if (mounted) {
        if (e.toString().contains('permission-denied')) {
          _showErrorMessage(
              'Unable to cancel connection request. This feature requires updated permissions.');
        } else {
          _showErrorMessage(
              'Failed to cancel connection request. Please check your internet connection and try again.');
        }
      }
    } finally {
      _stopOperation(userId);
    }
  }

  Future<void> _acceptConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - ensure they sent us a request and we're not already connected
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (currentUserData.friends.contains(user.reference)) {
        _showErrorMessage('You are already connected with ${user.displayName}');
        return;
      }

      if (!currentUserData.friendRequests.contains(user.reference)) {
        _showErrorMessage('No pending request from ${user.displayName}');
        return;
      }

      // Use a batch write for better performance and atomicity
      final batch = FirebaseFirestore.instance.batch();

      // Update current user: add to friends, remove from friend_requests
      batch.update(currentUserReference!, {
        'friends': FieldValue.arrayUnion([user.reference]),
        'friend_requests': FieldValue.arrayRemove([user.reference]),
        'sent_requests': FieldValue.arrayRemove(
            [user.reference]), // Remove if we also sent them a request
      });

      // Update other user: add to friends, remove from sent_requests
      batch.update(user.reference, {
        'friends': FieldValue.arrayUnion([currentUserReference]),
        'sent_requests': FieldValue.arrayRemove([currentUserReference]),
      });

      await batch.commit();

      if (mounted) {
        _showSuccessMessage('Connection request accepted!');
      }
    } catch (e) {
      print('Error accepting connection request: $e');
      if (mounted) {
        if (e.toString().contains('permission-denied')) {
          _showErrorMessage(
              'Unable to accept connection request. This feature requires updated permissions.');
        } else {
          _showErrorMessage(
              'Failed to accept connection request. Please check your internet connection and try again.');
        }
      }
    } finally {
      _stopOperation(userId);
    }
  }

  Future<void> _declineConnectionRequest(UsersRecord user) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - ensure request exists
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (!currentUserData.friendRequests.contains(user.reference)) {
        _showErrorMessage('No pending request from ${user.displayName}');
        return;
      }

      // Only update current user's document (we have permission for this)
      await currentUserReference!.update({
        'friend_requests': FieldValue.arrayRemove([user.reference]),
      });

      if (mounted) {
        _showSuccessMessage('Connection request declined');
      }
    } catch (e) {
      print('Error declining connection request: $e');
      if (mounted) {
        _showErrorMessage(
            'Failed to decline connection request. Please check your internet connection and try again.');
      }
    } finally {
      _stopOperation(userId);
    }
  }

  void _showSuccessMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(UsersRecord user, UsersRecord currentUser) {
    final isConnected = _isUserConnected(user.reference, currentUser);
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          if (isConnected)
            CupertinoActionSheetAction(
              isDestructiveAction: false,
              onPressed: () {
                Navigator.pop(context);
                _showRemoveConnectionConfirmation(user, currentUser);
              },
              child: Text(
                'Delete Connection',
                style: TextStyle(
                  color: Color(0xFF000000),
                  fontFamily: 'SF Pro Display',
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _showBlockUserConfirmation(user, currentUser);
            },
            child: Text(
              'Block',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontFamily: 'SF Pro Display',
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showRemoveConnectionConfirmation(
      UsersRecord user, UsersRecord currentUser) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete Connection'),
        content: Text(
            'Are you sure you want to remove ${user.displayName} from your connections?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _removeConnection(user, currentUser);
            },
            child: Text('Delete'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeConnection(
      UsersRecord user, UsersRecord currentUser) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Bulletproof check - ensure they are actually connected
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (!currentUserData.friends.contains(user.reference)) {
        _showErrorMessage('You are not connected with ${user.displayName}');
        return;
      }

      // Update current user's document (we have permission for our own document)
      await currentUserReference!.update({
        'friends': FieldValue.arrayRemove([user.reference]),
      });

      // Try to update other user's document (may fail due to permissions, but that's okay)
      // The connection will be removed from their side when they next sync
      try {
        await user.reference.update({
          'friends': FieldValue.arrayRemove([currentUserReference]),
        });
      } catch (e) {
        // If we can't update the other user's document, that's okay
        // The connection is still removed from our side
        print('Note: Could not update other user\'s friends list: $e');
      }

      if (mounted) {
        _showSuccessMessage('Connection removed successfully');
        // Navigate back after a short delay
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      print('Error removing connection: $e');
      if (mounted) {
        if (e.toString().contains('permission-denied')) {
          _showErrorMessage(
              'Unable to remove connection. This feature requires updated permissions.');
        } else {
          _showErrorMessage(
              'Failed to remove connection. Please check your internet connection and try again.');
        }
      }
    } finally {
      _stopOperation(userId);
    }
  }

  void _showBlockUserConfirmation(
      UsersRecord user, UsersRecord currentUser) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Block User'),
        content: Text(
            'Are you sure you want to block ${user.displayName}? You won\'t be able to see their profile or receive messages from them.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _blockUser(user, currentUser);
            },
            child: Text('Block'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(UsersRecord user, UsersRecord currentUser) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    bool connectionRemoved = false;
    bool requestsCleared = false;
    bool blockRecordCreated = false;

    try {
      // Step 1: Remove connection if they are connected (this should have permissions)
      final currentUserDoc = await currentUserReference!.get();
      final currentUserData = UsersRecord.fromSnapshot(currentUserDoc);

      if (currentUserData.friends.contains(user.reference)) {
        try {
          // Remove connection first
          await currentUserReference!.update({
            'friends': FieldValue.arrayRemove([user.reference]),
          });
          connectionRemoved = true;

          // Try to update other user's document (may fail due to permissions, but that's okay)
          try {
            await user.reference.update({
              'friends': FieldValue.arrayRemove([currentUserReference]),
            });
          } catch (e) {
            print('Note: Could not update other user\'s friends list: $e');
            // Continue anyway
          }
        } catch (e) {
          print('Error removing connection during block: $e');
          // Continue with other operations
        }
      }

      // Step 2: Remove any pending requests (this should have permissions)
      try {
        if (currentUserData.sentRequests.contains(user.reference)) {
          await currentUserReference!.update({
            'sent_requests': FieldValue.arrayRemove([user.reference]),
          });
          try {
            await user.reference.update({
              'friend_requests': FieldValue.arrayRemove([currentUserReference]),
            });
          } catch (e) {
            print('Note: Could not update other user\'s friend requests: $e');
          }
        }

        if (currentUserData.friendRequests.contains(user.reference)) {
          await currentUserReference!.update({
            'friend_requests': FieldValue.arrayRemove([user.reference]),
          });
        }
        requestsCleared = true;
      } catch (e) {
        print('Error clearing requests during block: $e');
        // Continue anyway
      }

      // Step 3: Try to create blocked user record (this might fail due to permissions)
      try {
        // Check if user is already blocked first
        final existingBlock = await BlockedUsersRecord.collection
            .where('blocker_user', isEqualTo: currentUserReference)
            .where('blocked_user', isEqualTo: user.reference)
            .get();

        if (existingBlock.docs.isEmpty) {
          // Only try to create if it doesn't exist
          await BlockedUsersRecord.collection.add(
            createBlockedUsersRecordData(
              blockerUser: currentUserReference,
              blockedUser: user.reference,
              createdAt: getCurrentTimestamp,
            ),
          );
          blockRecordCreated = true;
        } else {
          // Already blocked, so consider it successful
          blockRecordCreated = true;
        }
      } catch (e) {
        print('Error creating block record (permission issue expected): $e');
        // This is expected to fail due to permissions, but we continue
        // The connection removal and request clearing still happened
        blockRecordCreated = false;
      }

      // Step 4: Show appropriate message based on what succeeded
      if (mounted) {
        if (blockRecordCreated) {
          _showSuccessMessage('${user.displayName} has been blocked');
        } else if (connectionRemoved || requestsCleared) {
          // Connection/requests were removed but blocking failed
          // Show a message that the user was removed but blocking may not be active
          _showSuccessMessage(
              'Connection removed. Note: Blocking feature requires updated permissions.');
        } else {
          _showErrorMessage(
              'Unable to complete the action. Please check your permissions.');
        }

        // Navigate back after a short delay if we did something useful
        if (connectionRemoved || requestsCleared || blockRecordCreated) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      }
    } catch (e) {
      print('Unexpected error during block operation: $e');
      if (mounted) {
        // Only show error if nothing useful happened
        if (!connectionRemoved && !requestsCleared && !blockRecordCreated) {
          _showErrorMessage(
              'Failed to complete the action. Please check your internet connection and try again.');
        } else {
          // Something worked, show a partial success message
          _showSuccessMessage(
              'Some actions completed, but blocking may not be fully active.');
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      }
    } finally {
      _stopOperation(userId);
    }
  }

  void _selectChatInDesktop(ChatsRecord chat, {int retryCount = 0}) {
    if (retryCount > 20) {
      print('Failed to select chat after 20 retries');
      return;
    }

    try {
      // Try to find the controller
      ChatController? chatController;
      try {
        chatController = Get.find<ChatController>();
        // Verify controller is ready by checking if it has chats loaded
        if (chatController.chats.isEmpty && retryCount < 10) {
          // Chats not loaded yet, wait a bit more
          Future.delayed(Duration(milliseconds: 400 * (retryCount + 1)), () {
            _selectChatInDesktop(chat, retryCount: retryCount + 1);
          });
          return;
        }
      } catch (e) {
        // Controller not found, wait for initialization
        if (retryCount < 10) {
          Future.delayed(Duration(milliseconds: 400 * (retryCount + 1)), () {
            _selectChatInDesktop(chat, retryCount: retryCount + 1);
          });
          return;
        }
        print('ChatController not found after 10 retries: $e');
        return;
      }

      // Try to find the chat in the controller's chats list
      // This ensures we use the same chat object that's in the list (matching list click behavior)
      ChatsRecord chatToSelect = chat;
      try {
        final chatInList = chatController.chats.firstWhere(
          (c) => c.reference.id == chat.reference.id,
        );
        // Use the chat from the list to ensure consistency with what's displayed
        chatToSelect = chatInList;
        print('Found chat in controller list, using that instance');
      } catch (e) {
        // Chat not in list yet - might be a new chat that hasn't loaded
        if (retryCount < 5) {
          Future.delayed(Duration(milliseconds: 500), () {
            _selectChatInDesktop(chat, retryCount: retryCount + 1);
          });
          return;
        }
        // After 5 retries, use the chat we have
        print('Chat not in list after 5 retries, using provided chat instance');
      }

      // Select the chat - this matches exactly what happens when clicking from the list
      chatController.selectChat(chatToSelect);
      print('Successfully selected chat: ${chatToSelect.reference.id}');

      // Verify selection worked and wait a bit for UI to update
      Future.delayed(Duration(milliseconds: 100), () {
        if (chatController != null) {
          final selectedChat = chatController.selectedChat.value;
          if (selectedChat?.reference.id != chat.reference.id) {
            // Selection didn't work, retry
            if (retryCount < 15) {
              _selectChatInDesktop(chat, retryCount: retryCount + 1);
            }
          }
        }
      });
    } catch (e) {
      print('Error selecting chat (retry $retryCount): $e');
      // Controller might not be initialized yet, try again after a delay
      Future.delayed(Duration(milliseconds: 400 * (retryCount + 1)), () {
        _selectChatInDesktop(chat, retryCount: retryCount + 1);
      });
    }
  }

  /// Saves profile changes to Firestore
  /// This function saves the same fields that are collected during onboarding:
  /// - display_name: User's display name (set during sign up, editable here)
  /// - location: User's location address (from onboarding placePickerValue.address)
  /// - bio: User's bio/description (from onboarding bioTextController)
  /// - interests: List of user interests (from onboarding iterested list)
  /// - website: Additional field for user's website (not in onboarding, but editable)
  ///
  /// Note: Other onboarding fields like photoUrl, locationLatlng, and notification
  /// settings are handled separately (photoUrl via EditProfile, notifications via Settings)
  /// Builds the photo edit button with blue pencil icon and dropdown menu - iOS 26+ liquid glass popup
  Widget _buildPhotoEditButton({
    required bool isCoverPhoto,
    required String? photoUrl,
    required UsersRecord user,
  }) {
    return AdaptivePopupMenuButton.widget<String>(
      items: [
        AdaptivePopupMenuItem(
          label: 'View photo',
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'eye'
              : CupertinoIcons.eye,
          value: 'view',
        ),
        AdaptivePopupMenuItem(
          label: 'Edit photo',
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'pencil'
              : CupertinoIcons.pencil,
          value: 'edit',
        ),
        AdaptivePopupMenuItem(
          label: 'Delete photo',
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'trash'
              : CupertinoIcons.delete,
          value: 'delete',
        ),
      ],
      onSelected: (index, item) {
        if (item.value == 'view') {
          _viewPhoto(photoUrl, isCoverPhoto);
        } else if (item.value == 'edit') {
          _editPhoto(isCoverPhoto, user).catchError((error) {
            if (mounted) {
              _showAdaptiveDialog(
                title: 'Error',
                message: 'Error: ${error.toString()}',
                isError: true,
              );
            }
          });
        } else if (item.value == 'delete') {
          _deletePhoto(isCoverPhoto, user).catchError((error) {
            if (mounted) {
              _showAdaptiveDialog(
                title: 'Error',
                message: 'Error: ${error.toString()}',
                isError: true,
              );
            }
          });
        }
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Color(0xFF0077B5), // Blue color
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          CupertinoIcons.pencil,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }

  /// Views the photo in full screen
  Future<void> _viewPhoto(String? photoUrl, bool isCoverPhoto) async {
    try {
      if (!mounted) return;

      if (photoUrl == null || photoUrl.isEmpty) {
        if (!mounted) return;
        await _showAdaptiveDialog(
          title: 'No Photo',
          message: 'No photo to view',
          isError: true,
        );
        return;
      }

      // Match chat behavior: open the FlutterFlow full-screen viewer
      // But don't show download button for profile photos
      await Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: FlutterFlowExpandedImageView(
            image: CachedNetworkImage(
              fadeInDuration: const Duration(milliseconds: 300),
              fadeOutDuration: const Duration(milliseconds: 300),
              imageUrl: photoUrl,
              fit: BoxFit.contain,
            ),
            allowRotation: false,
            tag: photoUrl,
            useHeroAnimation: true,
            imageUrl: photoUrl,
            showDownload: false, // Hide download button for profile photos
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        await _showAdaptiveDialog(
          title: 'Error',
          message: 'Error viewing photo: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  /// Opens image picker to edit photo
  Future<void> _editPhoto(bool isCoverPhoto, UsersRecord user) async {
    if (!mounted) return;

    NavigatorState? navigator;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: isCoverPhoto ? 1920 : 512,
        maxHeight: isCoverPhoto ? 1080 : 512,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (image != null) {
        // Show loading indicator - store the navigator context
        if (!mounted) return;
        try {
          navigator = Navigator.of(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => Center(
              child: CircularProgressIndicator(),
            ),
          );
        } catch (e) {
          if (mounted) {
            await _showAdaptiveDialog(
              title: 'Error',
              message: 'Error showing loading dialog: ${e.toString()}',
              isError: true,
            );
          }
          return;
        }

        try {
          final String downloadUrl = await _uploadPhoto(image, isCoverPhoto);

          if (!mounted) return;

          // Update user document
          try {
            if (isCoverPhoto) {
              await user.reference.update({
                'cover_photo_url': downloadUrl,
              });
            } else {
              await user.reference.update({
                'photo_url': downloadUrl,
              });
            }
          } catch (e) {
            // Close loading dialog first
            try {
              if (navigator.canPop()) {
                navigator.pop();
              }
            } catch (_) {}

            if (mounted) {
              await _showAdaptiveDialog(
                title: 'Error',
                message: 'Error updating profile: ${e.toString()}',
                isError: true,
              );
            }
            return;
          }

          // Close loading dialog and show success message
          if (mounted) {
            try {
              if (navigator.canPop()) {
                navigator.pop(); // Close loading dialog using stored navigator
              }
            } catch (e) {
              print('Error closing dialog: $e');
            }

            await _showAdaptiveDialog(
              title: 'Success',
              message: '${isCoverPhoto ? 'Cover' : 'Profile'} photo updated successfully!',
              icon: 'checkmark.circle.fill',
            );
          }
        } catch (e) {
          // Close loading dialog and show error message
          try {
            if (navigator.canPop()) {
              navigator.pop(); // Close loading dialog using stored navigator
            }
          } catch (_) {}

          if (mounted) {
            await _showAdaptiveDialog(
              title: 'Error',
              message: 'Error uploading photo: ${e.toString()}',
              isError: true,
            );
          }
        }
      }
    } catch (e) {
      // Make sure to close dialog if it's open
      try {
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      } catch (_) {}

      if (mounted) {
        await _showAdaptiveDialog(
          title: 'Error',
          message: 'Error picking image: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  /// Uploads photo to Firebase Storage
  Future<String> _uploadPhoto(XFile imageFile, bool isCoverPhoto) async {
    final currentUser = currentUserReference;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final String folder = isCoverPhoto ? 'cover_photos' : 'profile_photos';
      final String fileName =
          '$folder/${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        final file = File(imageFile.path);
        if (!await file.exists()) {
          throw Exception('Image file does not exist');
        }
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final snapshot = await uploadTask.whenComplete(() {});

      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL');
      }

      return downloadUrl;
    } catch (e) {
      print('Firebase Storage upload error: $e');
      if (e is FirebaseException) {
        throw Exception('Firebase Storage error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  /// Deletes the photo
  Future<void> _deletePhoto(bool isCoverPhoto, UsersRecord user) async {
    if (!mounted) return;

    try {
      final photoUrl = isCoverPhoto ? _getCoverPhotoUrl(user) : user.photoUrl;

      if (photoUrl == null || photoUrl.isEmpty) {
        if (!mounted) return;
        await _showAdaptiveDialog(
          title: 'No Photo',
          message: 'No photo to delete',
          isError: true,
        );
        return;
      }

      // Show confirmation dialog
      bool? confirmed;
      try {
        confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Delete ${isCoverPhoto ? 'Cover' : 'Profile'} Photo'),
            content: Text(
              'Are you sure you want to delete this photo? This action cannot be undone.',
            ),
            actions: [
              CupertinoDialogAction(
                child: Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: Text('Delete'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );
      } catch (e) {
        if (mounted) {
          await _showAdaptiveDialog(
            title: 'Error',
            message: 'Error showing confirmation: ${e.toString()}',
            isError: true,
          );
        }
        return;
      }

      if (!mounted) return;

      if (confirmed == true) {
        // Show loading indicator
        if (!mounted) return;
        NavigatorState? navigator;
        try {
          navigator = Navigator.of(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => Center(
              child: CircularProgressIndicator(),
            ),
          );
        } catch (e) {
          if (mounted) {
            await _showAdaptiveDialog(
              title: 'Error',
              message: 'Error showing loading dialog: ${e.toString()}',
              isError: true,
            );
          }
          return;
        }

        try {
          // Update user document to remove photo URL
          if (isCoverPhoto) {
            await user.reference.update({
              'cover_photo_url': '',
            });
          } else {
            await user.reference.update({
              'photo_url': '',
            });
          }

          // Close loading dialog and show success message
          if (mounted) {
            try {
              if (navigator.canPop()) {
                navigator.pop(); // Close loading dialog using stored navigator
              }
            } catch (e) {
              print('Error closing dialog: $e');
            }

            await _showAdaptiveDialog(
              title: 'Success',
              message: '${isCoverPhoto ? 'Cover' : 'Profile'} photo deleted successfully',
              icon: 'checkmark.circle.fill',
            );
          }
        } catch (e) {
          // Close loading dialog and show error message
          try {
            if (navigator.canPop()) {
              navigator.pop(); // Close loading dialog using stored navigator
            }
          } catch (_) {}

          if (mounted) {
            await _showAdaptiveDialog(
              title: 'Error',
              message: 'Error deleting photo: ${e.toString()}',
              isError: true,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        await _showAdaptiveDialog(
          title: 'Error',
          message: 'Unexpected error: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _saveProfileChanges(UsersRecord user) async {
    try {
      // Parse interests from comma-separated string
      // This matches the format used during onboarding where interests are stored as a list
      List<String> interests = [];
      if (_model.interestsController?.text.isNotEmpty ?? false) {
        interests = _model.interestsController!.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      // Save all fields that are displayed and editable in the user summary page
      // These fields directly correspond to what users set during onboarding
      await user.reference.update({
        'display_name': _model.displayNameController?.text ?? user.displayName,
        'location': _model.locationController?.text ?? user.location,
        'bio': _model.bioController?.text ?? user.bio,
        'website': _model.websiteController?.text ?? '',
        'interests': interests, // Saved as array, matching onboarding format
      });

      // Exit edit mode
      if (mounted) {
        setState(() {
          _model.isEditing = false;
        });
      }

      // Show success message
      if (mounted) {
        await _showAdaptiveDialog(
          title: 'Success',
          message: 'Profile updated successfully!',
          icon: 'checkmark.circle.fill',
        );
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        await _showAdaptiveDialog(
          title: 'Error',
          message: 'Failed to update profile. Please try again.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userRef == null) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('User Profile'),
        ),
        child: Center(
          child: Text('User not found'),
        ),
      );
    }

    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(widget.userRef!),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text('User Profile'),
            ),
            child: Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        final profileUser = userSnapshot.data!;
        final isOwnProfile = currentUserReference == profileUser.reference;

        // Initialize controllers with user data
        if (widget.isEditable && isOwnProfile) {
          if (_model.displayNameController?.text.isEmpty ?? true) {
            _model.displayNameController?.text = profileUser.displayName;
          }
          if (_model.bioController?.text.isEmpty ?? true) {
            _model.bioController?.text = profileUser.bio;
          }
          if (_model.locationController?.text.isEmpty ?? true) {
            _model.locationController?.text = profileUser.location;
          }
          if (_model.websiteController?.text.isEmpty ?? true) {
            _model.websiteController?.text =
                profileUser.snapshotData['website']?.toString() ?? '';
          }
          if (_model.interestsController?.text.isEmpty ?? true) {
            _model.interestsController?.text = profileUser.interests.join(', ');
          }
        }

        return StreamBuilder<UsersRecord>(
          stream: currentUserReference != null
              ? UsersRecord.getDocument(currentUserReference!)
              : null,
          builder: (context, currentUserSnapshot) {
            final currentUser = currentUserSnapshot.data;
            final isConnected = currentUser != null &&
                _isUserConnected(profileUser.reference, currentUser);
            final isSentRequest = currentUser != null &&
                _isValidSentRequest(profileUser.reference, currentUser);
            final hasIncomingRequest = currentUser != null &&
                _hasIncomingRequest(profileUser.reference, currentUser);
            final mutualConnections = currentUser != null
                ? _calculateMutualConnections(currentUser, profileUser)
                : 0;
            final isLoading = currentUser != null &&
                _isOperationInProgress(profileUser.reference.id);

            final isDesktop = kIsWeb || (!kIsWeb && Platform.isMacOS);
            final isInSettings = widget.isEditable && isDesktop;

            return CupertinoPageScaffold(
              backgroundColor: Colors.white,
              navigationBar: widget.isEditable
                  ? null // Hide navigation bar when used in settings
                  : CupertinoNavigationBar(
                      backgroundColor: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 0.5,
                        ),
                      ),
                      middle: Text(
                        'Profile',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                        ),
                      ),
                      leading: CupertinoNavigationBarBackButton(
                        onPressed: () => context.safePop(),
                        color: Color(0xFF007AFF),
                      ),
                    ),
              child: SafeArea(
                top: !isInSettings, // Remove top padding when in desktop settings
                child: isInSettings
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Desktop-optimized Cover Photo - Full width, taller
                            Container(
                              height: 280,
                              width: double.infinity,
                              child: Stack(
                                children: [
                                  _buildCoverPhoto(_getCoverPhotoUrl(profileUser)),
                                  // Gradient overlay for better visibility
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.3),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Edit button for cover photo
                                  if (widget.isEditable && isOwnProfile && _model.isEditing)
                                    Positioned(
                                      top: 16,
                                      right: 24,
                                      child: _buildPhotoEditButton(
                                        isCoverPhoto: true,
                                        photoUrl: _getCoverPhotoUrl(profileUser),
                                        user: profileUser,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Profile Content - Desktop optimized
                            Container(
                              color: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Profile Photo overlapping cover
                                  Transform.translate(
                                    offset: Offset(0, -70),
                                    child: Column(
                                      children: [
                                        // Profile Photo
                                        Center(
                                          child: Stack(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _viewPhoto(profileUser.photoUrl, false),
                                                child: Container(
                                                  width: 140,
                                                  height: 140,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 5),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(0.15),
                                                        blurRadius: 20,
                                                        offset: Offset(0, 8),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(70),
                                                    child: profileUser.photoUrl.isNotEmpty
                                                        ? CachedNetworkImage(
                                                            imageUrl: profileUser.photoUrl,
                                                            width: 140,
                                                            height: 140,
                                                            fit: BoxFit.cover,
                                                            placeholder: (context, url) =>
                                                                _buildInitialsAvatar(profileUser),
                                                            errorWidget: (context, url, error) =>
                                                                _buildInitialsAvatar(profileUser),
                                                          )
                                                        : _buildInitialsAvatar(profileUser),
                                                  ),
                                                ),
                                              ),
                                              // Edit button for profile photo
                                              if (widget.isEditable && isOwnProfile && _model.isEditing)
                                                Positioned(
                                                  bottom: 4,
                                                  right: 4,
                                                  child: _buildPhotoEditButton(
                                                    isCoverPhoto: false,
                                                    photoUrl: profileUser.photoUrl,
                                                    user: profileUser,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 20),

                                        // Name - Editable (Desktop: larger font)
                                        widget.isEditable && isOwnProfile && _model.isEditing
                                            ? Container(
                                                constraints: BoxConstraints(maxWidth: 500),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: TextField(
                                                    controller: _model.displayNameController,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily: 'SF Pro Display',
                                                      fontSize: 32,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF1A1A1A),
                                                      letterSpacing: -0.8,
                                                    ),
                                                    decoration: InputDecoration(
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                          color: Color(0xFF0077B5),
                                                          width: 2,
                                                        ),
                                                      ),
                                                      contentPadding: EdgeInsets.symmetric(
                                                          horizontal: 20, vertical: 16),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                profileUser.displayName.isNotEmpty
                                                    ? profileUser.displayName
                                                    : 'Unknown User',
                                                style: TextStyle(
                                                  fontFamily: 'SF Pro Display',
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF1A1A1A),
                                                  letterSpacing: -0.8,
                                                  decoration: TextDecoration.none,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                        SizedBox(height: 12),

                                        // Bio - Editable
                                        widget.isEditable && isOwnProfile && _model.isEditing
                                            ? Container(
                                                constraints: BoxConstraints(maxWidth: 600),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: TextField(
                                                    controller: _model.bioController,
                                                    maxLines: 3,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily: 'SF Pro Display',
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w400,
                                                      color: Color(0xFF4A5568),
                                                      height: 1.5,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText: 'Tell us about yourself...',
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide(
                                                          color: Color(0xFF0077B5),
                                                          width: 2,
                                                        ),
                                                      ),
                                                      contentPadding: EdgeInsets.all(16),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : (profileUser.bio.isNotEmpty
                                                ? Container(
                                                    constraints: BoxConstraints(maxWidth: 600),
                                                    child: Text(
                                                      profileUser.bio,
                                                      style: TextStyle(
                                                        fontFamily: 'SF Pro Display',
                                                        fontSize: 17,
                                                        fontWeight: FontWeight.w400,
                                                        color: Color(0xFF4A5568),
                                                        height: 1.5,
                                                        decoration: TextDecoration.none,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  )
                                                : SizedBox.shrink()),

                                        // Location - Editable
                                        if (profileUser.location.isNotEmpty ||
                                            (widget.isEditable && isOwnProfile && _model.isEditing)) ...[
                                          SizedBox(height: 12),
                                          widget.isEditable && isOwnProfile && _model.isEditing
                                              ? Container(
                                                  constraints: BoxConstraints(maxWidth: 400),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: TextField(
                                                      controller: _model.locationController,
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontFamily: 'SF Pro Display',
                                                        fontSize: 15,
                                                        color: Color(0xFF666666),
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText: 'Enter your location',
                                                        prefixIcon: Icon(
                                                          CupertinoIcons.location_solid,
                                                          size: 16,
                                                          color: Color(0xFF666666),
                                                        ),
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          borderSide: BorderSide(
                                                            color: Color(0xFF0077B5),
                                                            width: 2,
                                                          ),
                                                        ),
                                                        contentPadding: EdgeInsets.symmetric(
                                                            horizontal: 16, vertical: 14),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      CupertinoIcons.location_solid,
                                                      size: 16,
                                                      color: Color(0xFF6B7280),
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      profileUser.location,
                                                      style: TextStyle(
                                                        fontFamily: 'SF Pro Display',
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w500,
                                                        color: Color(0xFF4A5568),
                                                        decoration: TextDecoration.none,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ],

                                        // Email
                                        if (profileUser.email.isNotEmpty) ...[
                                          SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                CupertinoIcons.mail_solid,
                                                size: 18,
                                                color: Color(0xFF0077B5),
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                profileUser.email,
                                                style: TextStyle(
                                                  fontFamily: 'SF Pro Display',
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1A1A1A),
                                                  decoration: TextDecoration.none,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],

                                        // Connections Count
                                        SizedBox(height: 12),
                                        Text(
                                          '${profileUser.friends.length} connection${profileUser.friends.length == 1 ? '' : 's'}',
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Display',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF6B7280),
                                            decoration: TextDecoration.none,
                                          ),
                                        ),

                                        // Edit Profile Button (when not editing)
                                        if (widget.isEditable && isOwnProfile && !_model.isEditing) ...[
                                          SizedBox(height: 20),
                                          Center(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _model.isEditing = true;
                                                });
                                              },
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(24),
                                                child: BackdropFilter(
                                                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                                  child: Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                        colors: [
                                                          Colors.black.withOpacity(0.05),
                                                          Colors.black.withOpacity(0.02),
                                                        ],
                                                      ),
                                                      borderRadius: BorderRadius.circular(24),
                                                      border: Border.all(
                                                        color: Colors.black.withOpacity(0.08),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      CupertinoIcons.pencil,
                                                      size: 24,
                                                      color: CupertinoColors.systemBlue,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],

                                        // Save/Cancel Buttons (when editing)
                                        if (widget.isEditable && isOwnProfile && _model.isEditing) ...[
                                          SizedBox(height: 24),
                                          Container(
                                            constraints: BoxConstraints(maxWidth: 400),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Container(
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: Color(0xFF0077B5),
                                                        width: 1.5,
                                                      ),
                                                      borderRadius: BorderRadius.circular(22),
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius: BorderRadius.circular(22),
                                                        onTap: () {
                                                          setState(() {
                                                            _model.isEditing = false;
                                                            // Reset controllers
                                                            _model.displayNameController?.text =
                                                                profileUser.displayName;
                                                            _model.bioController?.text =
                                                                profileUser.bio;
                                                            _model.locationController?.text =
                                                                profileUser.location;
                                                            _model.interestsController?.text =
                                                                profileUser.interests.join(', ');
                                                          });
                                                        },
                                                        child: Center(
                                                          child: Text(
                                                            'Cancel',
                                                            style: TextStyle(
                                                              fontFamily: 'SF Pro Display',
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF0077B5),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 16),
                                                Expanded(
                                                  child: Container(
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      color: Color(0xFF0077B5),
                                                      borderRadius: BorderRadius.circular(22),
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius: BorderRadius.circular(22),
                                                        onTap: () => _saveProfileChanges(profileUser),
                                                        child: Center(
                                                          child: Text(
                                                            'Save',
                                                            style: TextStyle(
                                                              fontFamily: 'SF Pro Display',
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                    // Action Buttons (for other users)
                                    if (!isOwnProfile &&
                                        currentUser != null) ...[
                                      SizedBox(height: 16),
                                      Row(
                                        children: [
                                          if (isConnected)
                                            Expanded(
                                              child: Container(
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF0077B5),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    onTap: isLoading
                                                        ? null
                                                        : () =>
                                                        _startChat(profileUser),
                                                    child: Center(
                                                      child: isLoading
                                                          ? SizedBox(
                                                              width: 16,
                                                              height: 16,
                                                              child: CupertinoActivityIndicator(
                                                                color: Colors.white,
                                                              ),
                                                            )
                                                          : Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            CupertinoIcons
                                                                .paperplane_fill,
                                                            size: 16,
                                                            color: Colors.white,
                                                          ),
                                                          SizedBox(width: 6),
                                                          Text(
                                                            'Message',
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'SF Pro Display',
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
                                                              decoration:
                                                                  TextDecoration
                                                                      .none,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          else if (hasIncomingRequest)
                                            Expanded(
                                              child: Row(
                                                children: [
                                            Expanded(
                                              child: Container(
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF0077B5),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                              BorderRadius.circular(20),
                                                          onTap: isLoading
                                                              ? null
                                                              : () => _acceptConnectionRequest(profileUser),
                                                    child: Center(
                                                            child: isLoading
                                                                ? SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: CupertinoActivityIndicator(
                                                                      color: Colors.white,
                                                                    ),
                                                                  )
                                                                : Text(
                                                                    'Accept',
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'SF Pro Display',
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                          decoration:
                                                                          TextDecoration.none,
                                                                    ),
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Container(
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: Color(0xFFE5E7EB),
                                                          width: 1.5,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                      ),
                                                      child: Material(
                                                        color: Colors.transparent,
                                                        child: InkWell(
                                                          borderRadius:
                                                              BorderRadius.circular(20),
                                                          onTap: isLoading
                                                              ? null
                                                              : () => _declineConnectionRequest(profileUser),
                                                          child: Center(
                                                            child: isLoading
                                                                ? SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: CupertinoActivityIndicator(),
                                                                  )
                                                                : Text(
                                                                    'Decline',
                                                                    style: TextStyle(
                                                                      fontFamily:
                                                                          'SF Pro Display',
                                                                      fontSize: 15,
                                                                      fontWeight:
                                                                          FontWeight.w600,
                                                                      color: Color(0xFF666666),
                                                                      decoration:
                                                                          TextDecoration.none,
                                                                    ),
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Expanded(
                                              child: Container(
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: isSentRequest
                                                      ? Color(0xFFF3F4F6)
                                                      : Color(0xFF0077B5),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(20),
                                                    onTap: isLoading
                                                        ? null
                                                        : isSentRequest
                                                            ? () => _cancelConnectionRequest(profileUser)
                                                            : () => _sendConnectionRequest(profileUser),
                                                    child: Center(
                                                      child: isLoading
                                                          ? SizedBox(
                                                              width: 16,
                                                              height: 16,
                                                              child: CupertinoActivityIndicator(
                                                                color: isSentRequest
                                                                    ? Color(0xFF6B7280)
                                                                    : Colors.white,
                                                              ),
                                                            )
                                                          : Text(
                                                              isSentRequest
                                                                  ? 'Pending'
                                                                  : 'Connect',
                                                              style: TextStyle(
                                                                fontFamily:
                                                                    'SF Pro Display',
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight.w600,
                                                                color: isSentRequest
                                                                    ? Color(0xFF6B7280)
                                                                    : Colors.white,
                                                                decoration:
                                                                    TextDecoration.none,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          SizedBox(width: 12),
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Color(0xFF0077B5),
                                                width: 1.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                onTap: () {
                                                  _showMoreOptions(profileUser, currentUser);
                                                },
                                                child: Center(
                                                  child: Icon(
                                                    CupertinoIcons
                                                        .ellipsis_vertical,
                                                    color: Color(0xFF0077B5),
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],

                                        // Interests Section - Desktop optimized
                                        if (profileUser.interests.isNotEmpty ||
                                            (widget.isEditable && isOwnProfile && _model.isEditing)) ...[
                                          SizedBox(height: 32),
                                          Text(
                                            'Interests',
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Display',
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1A1A1A),
                                              decoration: TextDecoration.none,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(height: 16),
                                          widget.isEditable && isOwnProfile && _model.isEditing
                                              ? Container(
                                                  constraints: BoxConstraints(maxWidth: 500),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: TextField(
                                                      controller: _model.interestsController,
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontFamily: 'SF Pro Display',
                                                        fontSize: 15,
                                                        color: Color(0xFF000000),
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText: 'Enter interests separated by commas',
                                                        border: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          borderSide: BorderSide(
                                                            color: Color(0xFF0077B5),
                                                            width: 2,
                                                          ),
                                                        ),
                                                        contentPadding: EdgeInsets.all(16),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Wrap(
                                                  spacing: 12,
                                                  runSpacing: 12,
                                                  alignment: WrapAlignment.center,
                                                  children: profileUser.interests.map((interest) {
                                                    return Container(
                                                      padding: EdgeInsets.symmetric(
                                                          horizontal: 18, vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: Color(0xFFF0F4F8),
                                                        borderRadius: BorderRadius.circular(24),
                                                        border: Border.all(
                                                          color: Color(0xFF0077B5),
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        interest,
                                                        style: TextStyle(
                                                          fontFamily: 'SF Pro Display',
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF0077B5),
                                                          decoration: TextDecoration.none,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                        ],

                                        // Blocked Users Section
                                        if (isOwnProfile) ...[
                                          SizedBox(height: 32),
                                          _buildBlockedUsersSection(),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 40),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            // Cover Photo Section
                            Container(
                              height: 200,
                              width: double.infinity,
                              child: Stack(
                                children: [
                                  _buildCoverPhoto(_getCoverPhotoUrl(profileUser)),
                                  // Edit button for cover photo (only when editable, own profile, and in edit mode)
                                  if (widget.isEditable &&
                                      isOwnProfile &&
                                      _model.isEditing)
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: _buildPhotoEditButton(
                                        isCoverPhoto: true,
                                        photoUrl: _getCoverPhotoUrl(profileUser),
                                        user: profileUser,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Profile Info Section - Reuse the same structure from desktop
                            Container(
                              color: Colors.white,
                              padding: EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Profile Photo and Name Section
                                  Transform.translate(
                                    offset: Offset(0, -60),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Profile Photo - Tappable to view
                                          Center(
                                            child: Stack(
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    _viewPhoto(
                                                        profileUser.photoUrl, false);
                                                  },
                                                  child: Container(
                                                    width: 120,
                                                    height: 120,
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(60),
                                                      child: profileUser
                                                              .photoUrl.isNotEmpty
                                                          ? CachedNetworkImage(
                                                              imageUrl: profileUser
                                                                  .photoUrl,
                                                              width: 120,
                                                              height: 120,
                                                              fit: BoxFit.cover,
                                                              placeholder: (context,
                                                                      url) =>
                                                                  _buildInitialsAvatar(
                                                                      profileUser),
                                                              errorWidget: (context,
                                                                      url, error) =>
                                                                  _buildInitialsAvatar(
                                                                      profileUser),
                                                            )
                                                          : _buildInitialsAvatar(
                                                              profileUser),
                                                    ),
                                                  ),
                                                ),
                                                // Edit button for profile photo (only when editable, own profile, and in edit mode)
                                                if (widget.isEditable &&
                                                    isOwnProfile &&
                                                    _model.isEditing)
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: _buildPhotoEditButton(
                                                      isCoverPhoto: false,
                                                      photoUrl: profileUser.photoUrl,
                                                      user: profileUser,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 16),

                                          // Name and Title - Editable
                                          widget.isEditable &&
                                                  isOwnProfile &&
                                                  _model.isEditing
                                              ? Material(
                                                  color: Colors.transparent,
                                                  child: TextField(
                                                    controller:
                                                        _model.displayNameController,
                                                    style: TextStyle(
                                                      fontFamily: 'SF Pro Display',
                                                      fontSize: 28,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF1A1A1A),
                                                      letterSpacing: -0.8,
                                                      height: 1.15,
                                                    ),
                                                    decoration: InputDecoration(
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        borderSide: BorderSide(
                                                          color: Color(0xFF0077B5),
                                                          width: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Text(
                                                  profileUser.displayName.isNotEmpty
                                                      ? profileUser.displayName
                                                      : 'Unknown User',
                                                  style: TextStyle(
                                                    fontFamily: 'SF Pro Display',
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF1A1A1A),
                                                    letterSpacing: -0.8,
                                                    height: 1.15,
                                                    decoration: TextDecoration.none,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                          SizedBox(height: 10),

                                          // Bio or Email - Editable
                                          widget.isEditable &&
                                                  isOwnProfile &&
                                                  _model.isEditing
                                              ? Material(
                                                  color: Colors.transparent,
                                                  child: TextField(
                                                    controller: _model.bioController,
                                                    maxLines: 3,
                                                    style: TextStyle(
                                                      fontFamily: 'SF Pro Display',
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w400,
                                                      color: Color(0xFF4A5568),
                                                      height: 1.5,
                                                      letterSpacing: 0.1,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Tell us about yourself...',
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        borderSide: BorderSide(
                                                          color: Color(0xFF0077B5),
                                                          width: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : (profileUser.bio.isNotEmpty
                                                  ? Container(
                                                      padding: EdgeInsets.symmetric(
                                                          horizontal: 4),
                                                      child: Text(
                                                        profileUser.bio,
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'SF Pro Display',
                                                          fontSize: 17,
                                                          fontWeight: FontWeight.w400,
                                                          color: Color(0xFF4A5568),
                                                          height: 1.5,
                                                          letterSpacing: 0.1,
                                                          decoration:
                                                              TextDecoration.none,
                                                        ),
                                                        overflow:
                                                            TextOverflow.visible,
                                                        softWrap: true,
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    )
                                                  : SizedBox.shrink()),

                                          // Location - Editable
                                          if (profileUser.location.isNotEmpty ||
                                              (widget.isEditable &&
                                                  isOwnProfile &&
                                                  _model.isEditing)) ...[
                                            SizedBox(height: 8),
                                            widget.isEditable &&
                                                    isOwnProfile &&
                                                    _model.isEditing
                                                ? Material(
                                                    color: Colors.transparent,
                                                    child: TextField(
                                                      controller:
                                                          _model.locationController,
                                                      style: TextStyle(
                                                        fontFamily: 'SF Pro Display',
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w400,
                                                        color: Color(0xFF666666),
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText: 'Enter your location',
                                                        prefixIcon: Icon(
                                                          CupertinoIcons.location_solid,
                                                          size: 14,
                                                          color: Color(0xFF666666),
                                                        ),
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(8),
                                                        ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(8),
                                                          borderSide: BorderSide(
                                                            color: Color(0xFF0077B5),
                                                            width: 2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        CupertinoIcons.location_solid,
                                                        size: 16,
                                                        color: Color(0xFF6B7280),
                                                      ),
                                                      SizedBox(width: 6),
                                                      Flexible(
                                                        child: Text(
                                                          profileUser.location,
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'SF Pro Display',
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: Color(0xFF4A5568),
                                                            letterSpacing: 0.1,
                                                            decoration:
                                                                TextDecoration.none,
                                                          ),
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ],

                                          // Email - Bigger and Bolder
                                          if (profileUser.email.isNotEmpty) ...[
                                            SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  CupertinoIcons.mail_solid,
                                                  size: 18,
                                                  color: Color(0xFF0077B5),
                                                ),
                                                SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    profileUser.email,
                                                    style: TextStyle(
                                                      fontFamily: 'SF Pro Display',
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF1A1A1A),
                                                      letterSpacing: 0.2,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],

                                          // Connection Info
                                          if (!isOwnProfile &&
                                              currentUser != null) ...[
                                            SizedBox(height: 12),
                                            if (isConnected && mutualConnections > 0)
                                              Text(
                                                '${mutualConnections} mutual connection${mutualConnections == 1 ? '' : 's'}',
                                                style: TextStyle(
                                                  fontFamily: 'SF Pro Display',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF0077B5),
                                                  decoration: TextDecoration.none,
                                                ),
                                                overflow: TextOverflow.visible,
                                              )
                                            else if (mutualConnections > 0)
                                              Text(
                                                '${mutualConnections} mutual connection${mutualConnections == 1 ? '' : 's'}',
                                                style: TextStyle(
                                                  fontFamily: 'SF Pro Display',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF666666),
                                                  decoration: TextDecoration.none,
                                                ),
                                                overflow: TextOverflow.visible,
                                              ),
                                          ],
                                          // Total Connections Count
                                          SizedBox(height: 10),
                                          Text(
                                            '${profileUser.friends.length} connection${profileUser.friends.length == 1 ? '' : 's'}',
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Display',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF6B7280),
                                              letterSpacing: 0.1,
                                              decoration: TextDecoration.none,
                                            ),
                                            overflow: TextOverflow.visible,
                                            textAlign: TextAlign.center,
                                          ),

                                          // Edit Profile Button (for own profile when editable) - iOS 26+ liquid glass popup
                                          if (widget.isEditable &&
                                              isOwnProfile &&
                                              !_model.isEditing) ...[
                                            SizedBox(height: 16),
                                            Center(
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _model.isEditing = true;
                                                  });
                                                },
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                  child: BackdropFilter(
                                                    filter: ImageFilter.blur(
                                                        sigmaX: 20, sigmaY: 20),
                                                    child: Container(
                                                      width: 44,
                                                      height: 44,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                          colors: [
                                                            (Theme.of(context)
                                                                        .brightness ==
                                                                    Brightness.dark
                                                                ? Colors.white
                                                                : Colors.black)
                                                                .withOpacity(0.05),
                                                            (Theme.of(context)
                                                                        .brightness ==
                                                                    Brightness.dark
                                                                ? Colors.white
                                                                : Colors.black)
                                                                .withOpacity(0.02),
                                                          ],
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(22),
                                                        border: Border.all(
                                                          color: (Theme.of(context)
                                                                      .brightness ==
                                                                  Brightness.dark
                                                              ? Colors.white
                                                              : Colors.black)
                                                              .withOpacity(0.08),
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        CupertinoIcons.pencil,
                                                        size: 22,
                                                        color: CupertinoColors.systemBlue,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],

                                          // Save/Cancel Buttons (when editing)
                                          if (widget.isEditable &&
                                              isOwnProfile &&
                                              _model.isEditing) ...[
                                            SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Container(
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: Color(0xFF0077B5),
                                                        width: 1.5,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(20),
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                        onTap: () {
                                                          setState(() {
                                                            _model.isEditing = false;
                                                            _model.displayNameController
                                                                    ?.text =
                                                                profileUser
                                                                    .displayName;
                                                            _model.bioController
                                                                    ?.text =
                                                                profileUser.bio;
                                                            _model.locationController
                                                                    ?.text =
                                                                profileUser.location;
                                                            _model.websiteController
                                                                ?.text = profileUser
                                                                    .snapshotData[
                                                                        'website']
                                                                    ?.toString() ??
                                                                '';
                                                            _model.interestsController
                                                                    ?.text =
                                                                profileUser.interests
                                                                    .join(', ');
                                                          });
                                                        },
                                                        child: Center(
                                                          child: Text(
                                                            'Cancel',
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'SF Pro Display',
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight.w600,
                                                              color:
                                                                  Color(0xFF0077B5),
                                                              decoration:
                                                                  TextDecoration.none,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Container(
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: Color(0xFF0077B5),
                                                      borderRadius:
                                                          BorderRadius.circular(20),
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                        onTap: () =>
                                                            _saveProfileChanges(
                                                                profileUser),
                                                        child: Center(
                                                          child: Text(
                                                            'Save',
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'SF Pro Display',
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight.w600,
                                                              color: Colors.white,
                                                              decoration:
                                                                  TextDecoration.none,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],

                                          // Action Buttons (for other users)
                                          if (!isOwnProfile &&
                                              currentUser != null) ...[
                                            SizedBox(height: 16),
                                            Row(
                                              children: [
                                                if (isConnected)
                                                  Expanded(
                                                    child: Container(
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: Color(0xFF0077B5),
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                      ),
                                                      child: Material(
                                                        color: Colors.transparent,
                                                        child: InkWell(
                                                          borderRadius:
                                                              BorderRadius.circular(20),
                                                          onTap: isLoading
                                                              ? null
                                                              : () =>
                                                                  _startChat(profileUser),
                                                          child: Center(
                                                            child: isLoading
                                                                ? SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: CupertinoActivityIndicator(
                                                                      color: Colors.white,
                                                                    ),
                                                                  )
                                                                : Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Icon(
                                                                        CupertinoIcons
                                                                            .paperplane_fill,
                                                                        size: 16,
                                                                        color: Colors.white,
                                                                      ),
                                                                      SizedBox(width: 6),
                                                                      Text(
                                                                        'Message',
                                                                        style: TextStyle(
                                                                          fontFamily:
                                                                              'SF Pro Display',
                                                                          fontSize: 15,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color:
                                                                              Colors.white,
                                                                          decoration:
                                                                              TextDecoration.none,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else if (hasIncomingRequest)
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Container(
                                                            height: 40,
                                                            decoration: BoxDecoration(
                                                              color: Color(0xFF0077B5),
                                                              borderRadius:
                                                                  BorderRadius.circular(20),
                                                            ),
                                                            child: Material(
                                                              color: Colors.transparent,
                                                              child: InkWell(
                                                                borderRadius:
                                                                    BorderRadius.circular(20),
                                                                onTap: isLoading
                                                                    ? null
                                                                    : () => _acceptConnectionRequest(profileUser),
                                                                child: Center(
                                                                  child: isLoading
                                                                      ? SizedBox(
                                                                          width: 16,
                                                                          height: 16,
                                                                          child: CupertinoActivityIndicator(
                                                                            color: Colors.white,
                                                                          ),
                                                                        )
                                                                      : Text(
                                                                          'Accept',
                                                                          style: TextStyle(
                                                                            fontFamily:
                                                                                'SF Pro Display',
                                                                            fontSize: 15,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            color: Colors.white,
                                                                            decoration:
                                                                                TextDecoration.none,
                                                                          ),
                                                                        ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Expanded(
                                                          child: Container(
                                                            height: 40,
                                                            decoration: BoxDecoration(
                                                              border: Border.all(
                                                                color: Color(0xFFE5E7EB),
                                                                width: 1.5,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(20),
                                                            ),
                                                            child: Material(
                                                              color: Colors.transparent,
                                                              child: InkWell(
                                                                borderRadius:
                                                                    BorderRadius.circular(20),
                                                                onTap: isLoading
                                                                    ? null
                                                                    : () => _declineConnectionRequest(profileUser),
                                                                child: Center(
                                                                  child: isLoading
                                                                      ? SizedBox(
                                                                          width: 16,
                                                                          height: 16,
                                                                          child: CupertinoActivityIndicator(),
                                                                        )
                                                                      : Text(
                                                                          'Decline',
                                                                          style: TextStyle(
                                                                            fontFamily:
                                                                                'SF Pro Display',
                                                                            fontSize: 15,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            color: Color(0xFF666666),
                                                                            decoration:
                                                                                TextDecoration.none,
                                                                          ),
                                                                        ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                else
                                                  Expanded(
                                                    child: Container(
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: isSentRequest
                                                            ? Color(0xFFF3F4F6)
                                                            : Color(0xFF0077B5),
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                      ),
                                                      child: Material(
                                                        color: Colors.transparent,
                                                        child: InkWell(
                                                          borderRadius:
                                                              BorderRadius.circular(20),
                                                          onTap: isLoading
                                                              ? null
                                                              : isSentRequest
                                                                  ? () => _cancelConnectionRequest(profileUser)
                                                                  : () => _sendConnectionRequest(profileUser),
                                                          child: Center(
                                                            child: isLoading
                                                                ? SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: CupertinoActivityIndicator(
                                                                      color: isSentRequest
                                                                          ? Color(0xFF6B7280)
                                                                          : Colors.white,
                                                                    ),
                                                                  )
                                                                : Text(
                                                                    isSentRequest
                                                                        ? 'Pending'
                                                                        : 'Connect',
                                                                    style: TextStyle(
                                                                      fontFamily:
                                                                          'SF Pro Display',
                                                                      fontSize: 15,
                                                                      fontWeight:
                                                                          FontWeight.w600,
                                                                      color: isSentRequest
                                                                          ? Color(0xFF6B7280)
                                                                          : Colors.white,
                                                                      decoration:
                                                                          TextDecoration.none,
                                                                    ),
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                SizedBox(width: 12),
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Color(0xFF0077B5),
                                                      width: 1.5,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(20),
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(20),
                                                      onTap: () {
                                                        _showMoreOptions(profileUser, currentUser);
                                                      },
                                                      child: Center(
                                                        child: Icon(
                                                          CupertinoIcons
                                                              .ellipsis_vertical,
                                                          color: Color(0xFF0077B5),
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],

                                          // Interests Section - Editable
                                          if (profileUser.interests.isNotEmpty ||
                                              (widget.isEditable &&
                                                  isOwnProfile &&
                                                  _model.isEditing)) ...[
                                            SizedBox(height: 28),
                                            Text(
                                              'Interests',
                                              style: TextStyle(
                                                fontFamily: 'SF Pro Display',
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1A1A1A),
                                                letterSpacing: 0.2,
                                                decoration: TextDecoration.none,
                                              ),
                                              overflow: TextOverflow.visible,
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 12),
                                            widget.isEditable &&
                                                    isOwnProfile &&
                                                    _model.isEditing
                                                ? Material(
                                                    color: Colors.transparent,
                                                    child: TextField(
                                                      controller:
                                                          _model.interestsController,
                                                      style: TextStyle(
                                                        fontFamily: 'SF Pro Display',
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w400,
                                                        color: Color(0xFF000000),
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText:
                                                            'Enter interests separated by commas',
                                                        border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(8),
                                                        ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(8),
                                                          borderSide: BorderSide(
                                                            color: Color(0xFF0077B5),
                                                            width: 2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Wrap(
                                                    spacing: 10,
                                                    runSpacing: 10,
                                                    alignment: WrapAlignment.center,
                                                    children: profileUser.interests
                                                        .map((interest) {
                                                      return Container(
                                                        padding: EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 10),
                                                        decoration: BoxDecoration(
                                                          color: Color(0xFFF0F4F8),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  24),
                                                          border: Border.all(
                                                            color: Color(0xFF0077B5),
                                                            width: 1.5,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Color(0xFF0077B5)
                                                                  .withOpacity(0.1),
                                                              blurRadius: 4,
                                                              offset: Offset(0, 2),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Text(
                                                          interest,
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'SF Pro Display',
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(0xFF0077B5),
                                                            letterSpacing: 0.2,
                                                            decoration:
                                                                TextDecoration.none,
                                                          ),
                                                          overflow:
                                                              TextOverflow.visible,
                                                          softWrap: false,
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                          ],

                                          // Blocked Users Section - Only show on own profile
                                          if (isOwnProfile) ...[
                                            SizedBox(height: 28),
                                            _buildBlockedUsersSection(),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBlockedUsersSection() {
    if (currentUserReference == null) {
      return SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: BlockedUsersRecord.collection
          .where('blocker_user', isEqualTo: currentUserReference)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final blockedDocs = snapshot.data!.docs;
        
        if (blockedDocs.isEmpty) {
          return SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blocked Users',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0.2,
                decoration: TextDecoration.none,
              ),
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            ...blockedDocs.map((doc) {
              final blockedRecord = BlockedUsersRecord.fromSnapshot(doc);
              
              return StreamBuilder<UsersRecord>(
                stream: UsersRecord.getDocument(blockedRecord.blockedUser!),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return SizedBox.shrink();
                  }

                  final blockedUser = userSnapshot.data!;
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFFFFE5E5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF3B30).withOpacity(0.1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: blockedUser.photoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: blockedUser.photoUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        _buildBlockedUserAvatar(blockedUser),
                                  )
                                : _buildBlockedUserAvatar(blockedUser),
                          ),
                        ),
                        SizedBox(width: 12),
                        // User info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                blockedUser.displayName.isNotEmpty
                                    ? blockedUser.displayName
                                    : 'Unknown User',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                blockedUser.email,
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF6B7280),
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Unblock button
                        CupertinoButton(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minSize: 0,
                          onPressed: () => _showUnblockConfirmation(blockedUser, blockedRecord),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFFFF3B30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Unblock',
                              style: TextStyle(
                                fontFamily: 'SF Pro Text',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildBlockedUserAvatar(UsersRecord user) {
    final initials = user.displayName.isNotEmpty
        ? user.displayName
            .split(' ')
            .map((name) => name.isNotEmpty ? name[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'U';

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFF3B30),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showUnblockConfirmation(UsersRecord user, BlockedUsersRecord blockedRecord) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Unblock User'),
        content: Text(
            'Are you sure you want to unblock ${user.displayName}? You will be able to see their profile and receive messages from them.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () {
              Navigator.pop(context);
              _unblockUser(user, blockedRecord);
            },
            child: Text('Unblock'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _unblockUser(UsersRecord user, BlockedUsersRecord blockedRecord) async {
    final userId = user.reference.id;

    // Prevent multiple operations
    if (_isOperationInProgress(userId)) return;

    _startOperation(userId);

    try {
      // Delete the blocked user record
      await blockedRecord.reference.delete();

      if (mounted) {
        _showSuccessMessage('${user.displayName} has been unblocked');
      }
    } catch (e) {
      print('Error unblocking user: $e');
      if (mounted) {
        if (e.toString().contains('permission-denied')) {
          _showErrorMessage(
              'Unable to unblock user. This feature requires updated permissions.');
        } else {
          _showErrorMessage(
              'Failed to unblock user. Please check your internet connection and try again.');
        }
      }
    } finally {
      _stopOperation(userId);
    }
  }
}
