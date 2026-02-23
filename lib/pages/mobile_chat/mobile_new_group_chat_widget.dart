import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/mobile_chat/mobile_new_group_chat_model.dart';
import '/pages/desktop_chat/chat_controller.dart';
import '/pages/mobile_chat/mobile_chat_widget.dart';
import 'dart:io';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
export 'mobile_new_group_chat_model.dart';

class MobileNewGroupChatWidget extends StatefulWidget {
  const MobileNewGroupChatWidget({Key? key}) : super(key: key);

  static String routeName = 'MobileNewGroupChat';
  static String routePath = '/mobile-new-group-chat';

  @override
  _MobileNewGroupChatWidgetState createState() => _MobileNewGroupChatWidgetState();
}

class _MobileNewGroupChatWidgetState extends State<MobileNewGroupChatWidget> {
  late MobileNewGroupChatModel _model;
  late ChatController chatController;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MobileNewGroupChatModel());
    // Get existing controller or create a new one if it doesn't exist
    try {
      chatController = Get.find<ChatController>();
    } catch (e) {
      // If controller doesn't exist, create it
      chatController = Get.put(ChatController());
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _pickGroupImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _model.groupImagePath = image.path;
          _model.isUploadingImage = true;
        });

        // Upload image to Firebase Storage
        await _uploadGroupImage(image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  Future<void> _uploadGroupImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final fileName =
          'group_images/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Check if user is authenticated
      if (currentUserReference == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Firebase Storage
      final uploadTask = FirebaseStorage.instance.ref(fileName).putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _model.groupImageUrl = downloadUrl;
        _model.isUploadingImage = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image uploaded successfully!'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    } catch (e) {
      setState(() {
        _model.isUploadingImage = false;
      });

      String errorMessage = 'Error uploading image: $e';
      if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your authentication.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  Future<void> _createGroup() async {
    try {
      if (_model.selectedMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select at least one member'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
        return;
      }

      // Add current user to members list
      final allMembers = [
        currentUserReference ??
            FirebaseFirestore.instance.collection('users').doc('placeholder'),
        ..._model.selectedMembers
      ];

      // Auto-generate group name from member names if not provided
      String groupName = _model.groupName.trim();
      if (groupName.isEmpty) {
        // Fetch all member names
        final List<String> memberNames = [];

        // Get current user name
        if (currentUserReference != null) {
          try {
            final currentUser =
                await UsersRecord.getDocumentOnce(currentUserReference!);
            memberNames.add(currentUser.displayName.isNotEmpty
                ? currentUser.displayName
                : currentUser.email.split('@')[0]);
          } catch (e) {
            memberNames.add('You');
          }
        }

        // Get selected member names
        for (final memberRef in _model.selectedMembers) {
          try {
            final user = await UsersRecord.getDocumentOnce(memberRef);
            memberNames.add(user.displayName.isNotEmpty
                ? user.displayName
                : user.email.split('@')[0]);
          } catch (e) {
            // Skip if we can't fetch the user
          }
        }

        // Join names with comma and space (like Slack)
        groupName = memberNames.join(', ');
      }

      // Create the group chat
      final newChatRef = await ChatsRecord.collection.add({
        ...createChatsRecordData(
          title: groupName,
          isGroup: true,
          createdAt: getCurrentTimestamp,
          createdBy: currentUserReference,
          lastMessageAt: getCurrentTimestamp,
          lastMessage: '',
          lastMessageSent: currentUserReference,
          chatImageUrl: _model.groupImageUrl ?? '',
          admin: currentUserReference,
        ),
        'members': allMembers,
        'last_message_seen': [
          currentUserReference ??
              FirebaseFirestore.instance.collection('users').doc('placeholder')
        ],
      });

      // Send greeting message so the chat appears in the list
      final greeting =
          '${currentUserDisplayName.isNotEmpty ? currentUserDisplayName : "You"} created the group';

      await newChatRef.collection('messages').add({
        'content': greeting,
        'created_at': getCurrentTimestamp,
        'sender_ref': currentUserReference,
        'is_system_message': true,
        'is_read_by': [currentUserReference],
      });

      // Update chat with last message
      await newChatRef.update({
        'last_message': greeting,
        'last_message_at': getCurrentTimestamp,
        'last_message_sent': currentUserReference,
      });

      // Get the created chat document
      final newChat = await ChatsRecord.getDocumentOnce(newChatRef);

      // Select the new group chat
      chatController.selectChat(newChat);

      // Navigate directly to the chat conversation page, replacing the creation page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MobileChatWidget(
            initialChat: newChat,
          ),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating group: $e'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom header with iOS 26 native back button
            Container(
              height: 44,
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // Floating back button - iOS 26+ style with liquid glass effects
                  LiquidStretch(
                    stretch: 0.5,
                    interactionScale: 1.05,
                    child: GlassGlow(
                      glowColor: Colors.white24,
                      glowRadius: 1.0,
                      child: AdaptiveFloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: Color(0xFF007AFF),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Icon(
                          CupertinoIcons.chevron_left,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Centered title
                  Expanded(
                    child: Center(
                      child: Text(
                        'New Group Chat',
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          color: CupertinoColors.label,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.41,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 40), // Balance the back button width
                ],
              ),
            ),
            // Group creation form
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group name input
                    Text(
                      'Group Name (Optional)',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        color: CupertinoColors.label,
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.41,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: CupertinoColors.separator,
                          width: 0.5,
                        ),
                      ),
                      child: CupertinoTextField(
                        controller: _model.groupNameController,
                        onChanged: (value) {
                          setState(() {
                            _model.groupName = value;
                          });
                        },
                        placeholder: 'Enter group name',
                        placeholderStyle: TextStyle(
                          fontFamily: 'SF Pro Text',
                          color: CupertinoColors.systemGrey,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        style: TextStyle(
                          fontFamily: 'SF Pro Text',
                          color: CupertinoColors.label,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Group image upload
                    Text(
                      'Group Image (Optional)',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        color: CupertinoColors.label,
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.41,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        // Image preview/placeholder
                        GestureDetector(
                          onTap: _model.isUploadingImage ? null : _pickGroupImage,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: CupertinoColors.separator,
                                width: 0.5,
                              ),
                            ),
                            child: _model.isUploadingImage
                                ? Center(
                                    child: CupertinoActivityIndicator(
                                      color: CupertinoColors.systemBlue,
                                    ),
                                  )
                                : _model.groupImageUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: CachedNetworkImage(
                                          imageUrl: _model.groupImageUrl!,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 160,
                                          memCacheHeight: 160,
                                          maxWidthDiskCache: 160,
                                          maxHeightDiskCache: 160,
                                          filterQuality: FilterQuality.high,
                                          placeholder: (context, url) => Container(
                                            width: 80,
                                            height: 80,
                                            color: CupertinoColors.systemGrey6,
                                            child: Icon(
                                              CupertinoIcons.photo,
                                              color: CupertinoColors.systemGrey,
                                              size: 24,
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            width: 80,
                                            height: 80,
                                            color: CupertinoColors.systemGrey6,
                                            child: Icon(
                                              CupertinoIcons.photo,
                                              color: CupertinoColors.systemGrey,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons.photo_on_rectangle,
                                            color: CupertinoColors.systemGrey,
                                            size: 24,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Add Image',
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Text',
                                              color: CupertinoColors.systemGrey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Image controls
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _model.groupImageUrl != null
                                    ? 'Image selected'
                                    : 'No image selected',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Text',
                                  color: _model.groupImageUrl != null
                                      ? CupertinoColors.systemGreen
                                      : CupertinoColors.systemGrey,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.24,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  CupertinoButton(
                                    onPressed: _model.isUploadingImage
                                        ? null
                                        : _pickGroupImage,
                                    color: _model.isUploadingImage
                                        ? CupertinoColors.systemGrey
                                        : CupertinoColors.systemBlue,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    borderRadius: BorderRadius.circular(8),
                                    minSize: 0,
                                    child: Text(
                                      _model.groupImageUrl != null
                                          ? 'Change'
                                          : 'Select',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Text',
                                        color: CupertinoColors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: -0.15,
                                      ),
                                    ),
                                  ),
                                  if (_model.groupImageUrl != null) ...[
                                    SizedBox(width: 8),
                                    CupertinoButton(
                                      onPressed: () {
                                        setState(() {
                                          _model.groupImagePath = null;
                                          _model.groupImageUrl = null;
                                        });
                                      },
                                      color: CupertinoColors.systemRed,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      borderRadius: BorderRadius.circular(8),
                                      minSize: 0,
                                      child: Text(
                                        'Remove',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Text',
                                          color: CupertinoColors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: -0.15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Selected members header with search
                    Row(
                      children: [
                        Text(
                          'Selected Members (${_model.selectedMembers.length})',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            color: CupertinoColors.label,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.41,
                          ),
                        ),
                        Spacer(),
                        Container(
                          width: 180,
                          height: 36,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: CupertinoColors.separator,
                              width: 0.5,
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: _model.groupMemberSearchController,
                            onChanged: (_) => setState(() {}),
                            placeholder: 'Search...',
                            placeholderStyle: TextStyle(
                              fontFamily: 'SF Pro Text',
                              color: CupertinoColors.systemGrey,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            padding:
                                EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            prefix: Padding(
                              padding: EdgeInsets.only(left: 8, right: 4),
                              child: Icon(
                                CupertinoIcons.search,
                                color: CupertinoColors.systemBlue,
                                size: 16,
                              ),
                            ),
                            suffix: _model.groupMemberSearchController?.text
                                        .isNotEmpty ==
                                    true
                                ? GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _model.groupMemberSearchController?.clear();
                                      });
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(
                                        CupertinoIcons.xmark_circle_fill,
                                        color: CupertinoColors.systemGrey,
                                        size: 16,
                                      ),
                                    ),
                                  )
                                : null,
                            style: TextStyle(
                              fontFamily: 'SF Pro Text',
                              color: CupertinoColors.label,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Users list for selection (filtered by connections)
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: CupertinoColors.separator,
                          width: 0.5,
                        ),
                      ),
                      child: currentUserReference == null
                          ? Center(
                              child: CupertinoActivityIndicator(
                                color: CupertinoColors.systemBlue,
                              ),
                            )
                          : StreamBuilder<UsersRecord>(
                              stream: UsersRecord.getDocument(currentUserReference!),
                              builder: (context, currentUserSnapshot) {
                                if (!currentUserSnapshot.hasData) {
                                  return Center(
                                    child: CupertinoActivityIndicator(
                                      color: CupertinoColors.systemBlue,
                                    ),
                                  );
                                }

                                final currentUser = currentUserSnapshot.data!;
                                final connections = currentUser.friends;

                                if (connections.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.person_2,
                                          color: CupertinoColors.systemGrey,
                                          size: 48,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No connections yet',
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Text',
                                            color: CupertinoColors.label,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: -0.41,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Add connections to create a group',
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Text',
                                            color: CupertinoColors.systemGrey,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final searchQuery = _model
                                        .groupMemberSearchController?.text
                                        .toLowerCase() ??
                                    '';

                                return ListView.builder(
                                  padding: EdgeInsets.all(8),
                                  itemCount: connections.length,
                                  itemBuilder: (context, index) {
                                    final connectionRef = connections[index];

                                    return StreamBuilder<UsersRecord>(
                                      stream: UsersRecord.getDocument(connectionRef),
                                      builder: (context, userSnapshot) {
                                        if (!userSnapshot.hasData) {
                                          return SizedBox.shrink();
                                        }

                                        final user = userSnapshot.data!;
                                        final isCurrentUser =
                                            user.reference == currentUserReference;
                                        final isSelected = _model.selectedMembers
                                            .contains(user.reference);

                                        if (isCurrentUser) {
                                          return SizedBox.shrink();
                                        }

                                        // Check if search query matches
                                        if (searchQuery.isNotEmpty) {
                                          final displayName =
                                              user.displayName.toLowerCase();
                                          final email = user.email.toLowerCase();
                                          if (!displayName.contains(searchQuery) &&
                                              !email.contains(searchQuery)) {
                                            return SizedBox.shrink();
                                          }
                                        }

                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                _model.selectedMembers
                                                    .remove(user.reference);
                                              } else {
                                                _model.selectedMembers
                                                    .add(user.reference);
                                              }
                                            });
                                          },
                                          child: Container(
                                            margin: EdgeInsets.only(bottom: 4),
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? CupertinoColors.systemBlue.withOpacity(0.1)
                                                  : CupertinoColors.systemBackground,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? CupertinoColors.systemBlue
                                                    : CupertinoColors.separator,
                                                width: isSelected ? 1.5 : 0.5,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: CupertinoColors.systemGrey5,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(20),
                                                        child: CachedNetworkImage(
                                                          imageUrl: user.photoUrl,
                                                          width: 40,
                                                          height: 40,
                                                          fit: BoxFit.cover,
                                                          memCacheWidth: 80,
                                                          memCacheHeight: 80,
                                                          maxWidthDiskCache: 80,
                                                          maxHeightDiskCache: 80,
                                                          filterQuality: FilterQuality.high,
                                                          placeholder: (context, url) => Container(
                                                            width: 40,
                                                            height: 40,
                                                            decoration: BoxDecoration(
                                                              color: CupertinoColors.systemGrey5,
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Icon(
                                                              CupertinoIcons.person_fill,
                                                              color: CupertinoColors.systemGrey,
                                                              size: 18,
                                                            ),
                                                          ),
                                                          errorWidget: (context, url, error) => Container(
                                                            width: 40,
                                                            height: 40,
                                                            decoration: BoxDecoration(
                                                              color: CupertinoColors.systemGrey5,
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Icon(
                                                              CupertinoIcons.person_fill,
                                                              color: CupertinoColors.systemGrey,
                                                              size: 18,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    // Green dot indicator for online status
                                                    if (user.isOnline)
                                                      Positioned(
                                                        right: 0,
                                                        bottom: 0,
                                                        child: Container(
                                                          width: 12,
                                                          height: 12,
                                                          decoration: BoxDecoration(
                                                            color: CupertinoColors.systemGreen,
                                                            shape: BoxShape.circle,
                                                            border: Border.all(
                                                              color: CupertinoColors.systemBackground,
                                                              width: 2,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        user.displayName,
                                                        style: TextStyle(
                                                          fontFamily: 'SF Pro Text',
                                                          color: CupertinoColors.label,
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w600,
                                                          letterSpacing: -0.24,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      SizedBox(height: 2),
                                                      Text(
                                                        user.email,
                                                        style: TextStyle(
                                                          fontFamily: 'SF Pro Text',
                                                          color: CupertinoColors.systemGrey,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w400,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Container(
                                                    padding: EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: CupertinoColors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      CupertinoIcons.check_mark,
                                                      color: CupertinoColors.systemBlue,
                                                      size: 16,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              }),
                    ),
                    SizedBox(height: 20),
                    // Create group button
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        onPressed: _model.selectedMembers.isNotEmpty
                            ? () => _createGroup()
                            : null,
                        color: _model.selectedMembers.isNotEmpty
                            ? CupertinoColors.systemBlue
                            : CupertinoColors.systemGrey,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        borderRadius: BorderRadius.circular(10),
                        child: Text(
                          'Create Group',
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            color: CupertinoColors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.41,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

