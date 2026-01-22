import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/mobile_chat/mobile_chat_widget.dart';
import '/pages/desktop_chat/chat_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, File;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  });

  final DocumentReference? userRef;
  final bool isEditable;

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
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
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

  Future<void> _startChat(UsersRecord user) async {
    try {
      final currentWorkspaceRef = currentUserDocument?.currentWorkspaceRef;

      final existingChats = await queryChatsRecordOnce(
        queryBuilder: (chatsRecord) => chatsRecord
            .where('members', arrayContains: currentUserReference)
            .where('is_group', isEqualTo: false)
            .where('workspace_ref', isEqualTo: currentWorkspaceRef),
      );

      ChatsRecord? existingChat;
      for (final chat in existingChats) {
        if (chat.members.contains(user.reference) &&
            chat.members.length == 2 &&
            !chat.isGroup &&
            chat.workspaceRef?.path == currentWorkspaceRef?.path) {
          existingChat = chat;
          break;
        }
      }

      ChatsRecord chatToOpen;

      if (existingChat != null) {
        // Refresh the chat from Firestore to ensure we have the latest data
        chatToOpen = await ChatsRecord.getDocumentOnce(existingChat.reference);
      } else {
        final newChatRef = await ChatsRecord.collection.add({
          ...createChatsRecordData(
            isGroup: false,
            title: '',
            createdAt: getCurrentTimestamp,
            lastMessageAt: getCurrentTimestamp,
            lastMessage: '',
            lastMessageSent: currentUserReference,
            workspaceRef: currentUserDocument?.currentWorkspaceRef,
          ),
          'members': [currentUserReference!, user.reference],
          'last_message_seen': [currentUserReference!],
        });

        chatToOpen = await ChatsRecord.getDocumentOnce(newChatRef);
      }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
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
  /// Builds the photo edit button with blue pencil icon and dropdown menu
  Widget _buildPhotoEditButton({
    required bool isCoverPhoto,
    required String? photoUrl,
    required UsersRecord user,
  }) {
    return PopupMenuButton<String>(
      tooltip: isCoverPhoto ? 'Edit cover photo' : 'Edit profile photo',
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      offset: Offset(0, 50),
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
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'view',
          child: Row(
            children: [
              Icon(CupertinoIcons.eye, size: 20, color: Color(0xFF0077B5)),
              SizedBox(width: 12),
              Text('View photo'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(CupertinoIcons.pencil, size: 20, color: Color(0xFF0077B5)),
              SizedBox(width: 12),
              Text('Edit photo'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(CupertinoIcons.delete, size: 20, color: Color(0xFFEF4444)),
              SizedBox(width: 12),
              Text('Delete photo', style: TextStyle(color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
      onSelected: (String value) {
        try {
          if (value == 'view') {
            _viewPhoto(photoUrl, isCoverPhoto);
          } else if (value == 'edit') {
            _editPhoto(isCoverPhoto, user).catchError((error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${error.toString()}'),
                    backgroundColor: Color(0xFFEF4444),
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            });
          } else if (value == 'delete') {
            _deletePhoto(isCoverPhoto, user).catchError((error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${error.toString()}'),
                    backgroundColor: Color(0xFFEF4444),
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            });
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unexpected error: ${e.toString()}'),
                backgroundColor: Color(0xFFEF4444),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      },
    );
  }

  /// Views the photo in full screen
  void _viewPhoto(String? photoUrl, bool isCoverPhoto) {
    try {
      if (!mounted) return;

      if (photoUrl == null || photoUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No photo to view'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.contain,
                    errorWidget: (context, url, error) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.exclamationmark_triangle,
                              color: Colors.white, size: 48),
                          SizedBox(height: 16),
                          Text('Failed to load image',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 40,
                child: IconButton(
                  icon: Icon(CupertinoIcons.xmark_circle_fill,
                      color: Colors.white, size: 32),
                  onPressed: () {
                    try {
                      Navigator.of(context).pop();
                    } catch (e) {
                      // Ignore if dialog already closed
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error viewing photo: ${e.toString()}'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 4),
          ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error showing loading dialog: ${e.toString()}'),
                backgroundColor: Color(0xFFEF4444),
                duration: Duration(seconds: 4),
              ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating profile: ${e.toString()}'),
                  backgroundColor: Color(0xFFEF4444),
                  duration: Duration(seconds: 4),
                ),
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

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${isCoverPhoto ? 'Cover' : 'Profile'} photo updated successfully!'),
                backgroundColor: Color(0xFF10B981),
              ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading photo: ${e.toString()}'),
                backgroundColor: Color(0xFFEF4444),
                duration: Duration(seconds: 4),
              ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 4),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No photo to delete'),
            backgroundColor: Color(0xFFEF4444),
          ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error showing confirmation: ${e.toString()}'),
              backgroundColor: Color(0xFFEF4444),
              duration: Duration(seconds: 4),
            ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error showing loading dialog: ${e.toString()}'),
                backgroundColor: Color(0xFFEF4444),
                duration: Duration(seconds: 4),
              ),
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

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${isCoverPhoto ? 'Cover' : 'Profile'} photo deleted successfully'),
                backgroundColor: Color(0xFF10B981),
              ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting photo: ${e.toString()}'),
                backgroundColor: Color(0xFFEF4444),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: ${e.toString()}'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 4),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
          ),
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
            final mutualConnections = currentUser != null
                ? _calculateMutualConnections(currentUser, profileUser)
                : 0;

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
                child: SingleChildScrollView(
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

                      // Profile Info Section
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
                                        ? TextField(
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
                                        ? TextField(
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
                                          ? TextField(
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

                                    // Edit Profile Button (for own profile when editable)
                                    if (widget.isEditable &&
                                        isOwnProfile &&
                                        !_model.isEditing) ...[
                                      SizedBox(height: 16),
                                      Container(
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
                                            onTap: () {
                                              setState(() {
                                                _model.isEditing = true;
                                              });
                                            },
                                            child: Center(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    CupertinoIcons.pencil,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Edit Profile',
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
                                                ],
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
                                                      // Reset controllers to original values
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
                                                        BorderRadius.circular(
                                                            20),
                                                    onTap: () =>
                                                        _startChat(profileUser),
                                                    child: Center(
                                                      child: Row(
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
                                          else
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
                                                    onTap: () {
                                                      // Navigate to connections page or show connect option
                                                      context.safePop();
                                                    },
                                                    child: Center(
                                                      child: Text(
                                                        'Connect',
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'SF Pro Display',
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                          decoration:
                                                              TextDecoration
                                                                  .none,
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
                                                  // More options
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
                                          ? TextField(
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
}
