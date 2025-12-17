import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/component/empty_schedule/empty_schedule_widget.dart';
import '/components/delete_chat_group_widget.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/chat/chat_component/add_user/add_user_widget.dart';
import '/pages/chat/chat_component/reminder_time/reminder_time_widget.dart';
import '/pages/event/gallary/gallary_widget.dart';
import '/pages/chat/chat_group_creation/chat_group_creation_widget.dart';
import 'dart:ui';
import 'dart:io';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:page_transition/page_transition.dart';
import 'group_chat_detail_model.dart';
export 'group_chat_detail_model.dart';

/// Group Information for Tech Conference 2025
class GroupChatDetailWidget extends StatefulWidget {
  const GroupChatDetailWidget({
    super.key,
    required this.chatDoc,
    this.onClose,
  });

  final ChatsRecord? chatDoc;
  final VoidCallback? onClose;

  static String routeName = 'GroupChatDetail';
  static String routePath = '/groupChatDetail';

  @override
  State<GroupChatDetailWidget> createState() => _GroupChatDetailWidgetState();
}

class _GroupChatDetailWidgetState extends State<GroupChatDetailWidget> {
  late GroupChatDetailModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupChatDetailModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      // Initialize text controllers with current values
      _model.groupNameController?.text = widget.chatDoc?.title ?? '';
      _model.groupDescriptionController?.text =
          widget.chatDoc?.description ?? '';

      _model.laoding = true;
      safeSetState(() {});
      if (currentUserReference == widget.chatDoc?.admin) {
        _model.chat = await queryReportsRecordOnce(
          queryBuilder: (reportsRecord) => reportsRecord.where(
            'chat_group',
            isEqualTo: widget.chatDoc?.reference,
          ),
        );
        _model.report = _model.chat!.toList().cast<ReportsRecord>();
        safeSetState(() {});
      }
      await Future.wait([
        Future(() async {
          _model.messages = await queryMessagesRecordOnce(
            parent: widget.chatDoc?.reference,
          );
          _model.message = _model.messages!
              .where((e) => e.image != '')
              .toList()
              .toList()
              .cast<MessagesRecord>();
          safeSetState(() {});
        }),
        Future(() async {
          _model.participant = await queryParticipantRecordOnce(
            parent: widget.chatDoc?.eventRef,
          );
          _model.participants =
              _model.participant!.toList().cast<ParticipantRecord>();
          safeSetState(() {});
        }),
      ]);
      _model.laoding = false;
      safeSetState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  /// Helper function to send a system update message to the group chat
  Future<void> _sendSystemMessage(String messageContent) async {
    if (widget.chatDoc == null || currentUserReference == null) return;

    try {
      final messageRef = MessagesRecord.createDoc(widget.chatDoc!.reference);
      await messageRef.set({
        'content': messageContent,
        'sender_ref': currentUserReference,
        'sender_name': currentUserDisplayName.isNotEmpty
            ? currentUserDisplayName
            : (currentUserDocument?.displayName ?? 'Someone'),
        'sender_photo': currentUserPhoto.isNotEmpty
            ? currentUserPhoto
            : (currentUserDocument?.photoUrl ?? ''),
        'created_at': getCurrentTimestamp,
        'message_type': MessageType.text.serialize(),
        'is_read_by': [],
      });

      // Update chat's last message
      await widget.chatDoc!.reference.update({
        'last_message': messageContent,
        'last_message_at': getCurrentTimestamp,
        'last_message_sent': currentUserReference,
        'last_message_type': MessageType.text.serialize(),
      });
    } catch (e) {
      print('Error sending system message: $e');
      // Don't show error to user as the update itself succeeded
    }
  }

  /// Save group name changes
  Future<void> _saveGroupName() async {
    if (widget.chatDoc == null || _model.groupNameController == null) return;

    final newName = _model.groupNameController!.text.trim();
    if (newName.isEmpty) {
      // Restore old name if empty
      _model.groupNameController!.text = widget.chatDoc?.title ?? '';
      _model.isEditingName = false;
      safeSetState(() {});
      return;
    }

    final oldName = widget.chatDoc?.title ?? '';
    if (oldName != newName) {
      try {
        await widget.chatDoc!.reference.update({
          'title': newName,
        });

        // Send system message
        final userName = currentUserDisplayName.isNotEmpty
            ? currentUserDisplayName
            : (currentUserDocument?.displayName ?? 'Someone');
        await _sendSystemMessage(
          '$userName updated the group name from "$oldName" to "$newName"',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating group name: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }

    _model.isEditingName = false;
    safeSetState(() {});
  }

  /// Save group description changes
  Future<void> _saveGroupDescription() async {
    if (widget.chatDoc == null || _model.groupDescriptionController == null)
      return;

    final newDescription = _model.groupDescriptionController!.text.trim();
    final oldDescription = widget.chatDoc?.description ?? '';

    if (oldDescription != newDescription) {
      try {
        await widget.chatDoc!.reference.update({
          'description': newDescription,
        });

        // Send system message
        final userName = currentUserDisplayName.isNotEmpty
            ? currentUserDisplayName
            : (currentUserDocument?.displayName ?? 'Someone');

        if (oldDescription.isEmpty) {
          await _sendSystemMessage(
            '$userName added a group description',
          );
        } else if (newDescription.isEmpty) {
          await _sendSystemMessage(
            '$userName removed the group description',
          );
        } else {
          await _sendSystemMessage(
            '$userName updated the group description',
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating description: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }

    _model.isEditingDescription = false;
    safeSetState(() {});
  }

  Future<void> _editGroupName() async {
    if (widget.chatDoc == null) return;

    final TextEditingController nameController = TextEditingController(
      text: widget.chatDoc?.title ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Group Name',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter group name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isNotEmpty) {
                          try {
                            final oldName = widget.chatDoc?.title ?? '';
                            final newName = nameController.text.trim();

                            // Only update if name actually changed
                            if (oldName != newName) {
                              await widget.chatDoc!.reference.update({
                                'title': newName,
                              });

                              // Send system message
                              final userName = currentUserDisplayName.isNotEmpty
                                  ? currentUserDisplayName
                                  : (currentUserDocument?.displayName ??
                                      'Someone');
                              await _sendSystemMessage(
                                '$userName updated the group name from "$oldName" to "$newName"',
                              );
                            }

                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Group name updated successfully'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Error updating group name: $e'),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editGroupDescription() async {
    if (widget.chatDoc == null) return;

    final TextEditingController descController = TextEditingController(
      text: widget.chatDoc?.description ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Group Description',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: descController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter group description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final oldDescription =
                              widget.chatDoc?.description ?? '';
                          final newDescription = descController.text.trim();

                          // Only update if description actually changed
                          if (oldDescription != newDescription) {
                            await widget.chatDoc!.reference.update({
                              'description': newDescription,
                            });

                            // Send system message
                            final userName = currentUserDisplayName.isNotEmpty
                                ? currentUserDisplayName
                                : (currentUserDocument?.displayName ??
                                    'Someone');

                            if (oldDescription.isEmpty) {
                              await _sendSystemMessage(
                                '$userName added a group description',
                              );
                            } else if (newDescription.isEmpty) {
                              await _sendSystemMessage(
                                '$userName removed the group description',
                              );
                            } else {
                              await _sendSystemMessage(
                                '$userName updated the group description',
                              );
                            }
                          }

                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Group description updated successfully'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating description: $e'),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editGroupImage() async {
    if (widget.chatDoc == null) return;

    try {
      // Show image source selection bottom sheet
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: Color(0xFF3B82F6)),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF3B82F6)),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Upload image
        final oldImageUrl = widget.chatDoc?.chatImageUrl ?? '';
        final newImageUrl = await _uploadGroupImage(image);

        // Update chat document
        await widget.chatDoc!.reference.update({
          'chat_image_url': newImageUrl,
        });

        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Send system message if image changed
        if (oldImageUrl != newImageUrl) {
          final userName = currentUserDisplayName.isNotEmpty
              ? currentUserDisplayName
              : (currentUserDocument?.displayName ?? 'Someone');

          if (oldImageUrl.isEmpty && newImageUrl.isNotEmpty) {
            await _sendSystemMessage('$userName changed the group photo');
          } else if (oldImageUrl.isNotEmpty && newImageUrl.isNotEmpty) {
            await _sendSystemMessage('$userName changed the group photo');
          }
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group photo updated successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating group photo: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<String> _uploadGroupImage(XFile imageFile) async {
    try {
      // Generate unique file name
      final String fileName =
          'group_images/${widget.chatDoc!.reference.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Firebase Storage
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        // For web, use bytes
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // For mobile/desktop, use file
        final file = File(imageFile.path);
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _editGroupType() async {
    if (widget.chatDoc == null) return;

    final currentIsPrivate = widget.chatDoc?.isPrivate ?? false;
    final newIsPrivate = !currentIsPrivate;

    try {
      await widget.chatDoc!.reference.update({
        'is_private': newIsPrivate,
      });

      // Send system message
      final userName = currentUserDisplayName.isNotEmpty
          ? currentUserDisplayName
          : (currentUserDocument?.displayName ?? 'Someone');

      final groupTypeText = newIsPrivate ? 'Internal Group' : 'Public Group';
      await _sendSystemMessage(
        '$userName changed the group type to $groupTypeText',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group type updated to $groupTypeText'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating group type: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: widget.onClose != null
              ? FlutterFlowIconButton(
                  borderRadius: 20.0,
                  buttonSize: 40.0,
                  icon: Icon(
                    Icons.close,
                    color: const Color(0xFF1A1F36),
                    size: 24.0,
                  ),
                  onPressed: () {
                    widget.onClose?.call();
                  },
                )
              : FlutterFlowIconButton(
                  borderRadius: 20.0,
                  buttonSize: 40.0,
                  icon: Icon(
                    Icons.arrow_back,
                    color: const Color(0xFF1A1F36),
                    size: 24.0,
                  ),
                  onPressed: () async {
                    context.safePop();
                  },
                ),
          title: Padding(
            padding: EdgeInsetsDirectional.only(start: 16.0),
            child: Text(
              'Group Info',
              style: FlutterFlowTheme.of(context).headlineMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
                    color: const Color(0xFF1A1F36),
                    fontSize: 20.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
            ),
          ),
          actions: const [],
          centerTitle: false,
          elevation: 0.0,
          titleSpacing: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: StreamBuilder<ChatsRecord>(
            stream: widget.chatDoc != null
                ? ChatsRecord.getDocument(widget.chatDoc!.reference)
                : null,
            builder: (context, snapshot) {
              // Use the latest chat data from stream, or fallback to widget.chatDoc
              final currentChatDoc =
                  snapshot.hasData ? snapshot.data! : widget.chatDoc;

              // Update controllers when chat data changes
              if (snapshot.hasData &&
                  !_model.isEditingName &&
                  !_model.isEditingDescription) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_model.groupNameController != null && mounted) {
                    _model.groupNameController!.text =
                        currentChatDoc?.title ?? '';
                  }
                  if (_model.groupDescriptionController != null && mounted) {
                    _model.groupDescriptionController!.text =
                        currentChatDoc?.description ?? '';
                  }
                });
              }

              return Align(
                alignment: const AlignmentDirectional(0.0, 1.0),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 650.0,
                  ),
                  decoration: const BoxDecoration(),
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 96.0,
                                          height: 96.0,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0E7FF),
                                            image: DecorationImage(
                                              fit: BoxFit.cover,
                                              image: Image.network(
                                                valueOrDefault<String>(
                                                  currentChatDoc?.chatImageUrl,
                                                  'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdiv.png?alt=media&token=85d5445a-3d2d-4dd5-879e-c4000b1fefd5',
                                                ),
                                              ).image,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 40.0,
                                            height: 40.0,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDBEAFE),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF3B82F6),
                                                width: 2.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF3B82F6)
                                                      .withOpacity(0.4),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                splashColor:
                                                    const Color(0xFF3B82F6)
                                                        .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(20.0),
                                                onTap: () async {
                                                  if (currentChatDoc?.admin ==
                                                          currentUserReference ||
                                                      currentChatDoc
                                                              ?.createdBy ==
                                                          currentUserReference) {
                                                    await _editGroupImage();
                                                  }
                                                },
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.edit,
                                                    color: Color(0xFF2563EB),
                                                    size: 20.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8.0),
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: _model.isEditingName
                                              ? TextField(
                                                  controller: _model
                                                      .groupNameController,
                                                  textAlign: TextAlign.center,
                                                  autofocus: true,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .headlineMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .headlineMedium
                                                                  .fontStyle,
                                                        ),
                                                        color: Colors.black,
                                                        fontSize: 20.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                  decoration: InputDecoration(
                                                    border: InputBorder.none,
                                                    enabledBorder:
                                                        InputBorder.none,
                                                    focusedBorder:
                                                        InputBorder.none,
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    isDense: true,
                                                  ),
                                                  onSubmitted: (_) =>
                                                      _saveGroupName(),
                                                  onEditingComplete:
                                                      _saveGroupName,
                                                )
                                              : Text(
                                                  valueOrDefault<String>(
                                                    currentChatDoc?.title,
                                                    'Group Name',
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .headlineMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .headlineMedium
                                                                  .fontStyle,
                                                        ),
                                                        color: Colors.black,
                                                        fontSize: 20.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .headlineMedium
                                                                .fontStyle,
                                                      ),
                                                ),
                                        ),
                                        if (currentChatDoc?.admin ==
                                                currentUserReference ||
                                            currentChatDoc?.createdBy ==
                                                currentUserReference)
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              splashColor:
                                                  const Color(0xFF3B82F6)
                                                      .withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(22.0),
                                              onTap: () async {
                                                if (currentChatDoc?.admin ==
                                                        currentUserReference ||
                                                    currentChatDoc?.createdBy ==
                                                        currentUserReference) {
                                                  if (_model.isEditingName) {
                                                    await _saveGroupName();
                                                  } else {
                                                    _model.isEditingName = true;
                                                    safeSetState(() {});
                                                  }
                                                }
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(10.0),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFDBEAFE),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF3B82F6),
                                                    width: 2.0,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF3B82F6)
                                                          .withOpacity(0.3),
                                                      blurRadius: 6,
                                                      offset:
                                                          const Offset(0, 2),
                                                      spreadRadius: 0,
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  _model.isEditingName
                                                      ? Icons.check
                                                      : Icons.edit,
                                                  color:
                                                      const Color(0xFF2563EB),
                                                  size: 20.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      'Group · ${valueOrDefault<String>(
                                        currentChatDoc?.members.length
                                            .toString(),
                                        '0',
                                      )} members',
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: const Color(0xFF374151),
                                            fontSize: 14.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    const SizedBox(height: 6.0),
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: _model.isEditingDescription
                                              ? TextField(
                                                  controller: _model
                                                      .groupDescriptionController,
                                                  textAlign: TextAlign.center,
                                                  autofocus: true,
                                                  maxLines: 3,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color: const Color(
                                                            0xFF10B981),
                                                        fontSize: 14.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                      ),
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Add group description',
                                                    hintStyle: TextStyle(
                                                      color: const Color(
                                                              0xFF10B981)
                                                          .withOpacity(0.6),
                                                    ),
                                                    border: InputBorder.none,
                                                    enabledBorder:
                                                        InputBorder.none,
                                                    focusedBorder:
                                                        InputBorder.none,
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    isDense: true,
                                                  ),
                                                  onSubmitted: (_) =>
                                                      _saveGroupDescription(),
                                                  onEditingComplete:
                                                      _saveGroupDescription,
                                                )
                                              : Text(
                                                  valueOrDefault<String>(
                                                    currentChatDoc?.description,
                                                    'Add group description',
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color: valueOrDefault<
                                                                String>(
                                                          widget.chatDoc
                                                              ?.description,
                                                          '',
                                                        ).isEmpty
                                                            ? const Color(
                                                                0xFF10B981)
                                                            : const Color(
                                                                0xFF10B981),
                                                        fontSize: 14.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                ),
                                        ),
                                        if (currentChatDoc?.admin ==
                                                currentUserReference ||
                                            currentChatDoc?.createdBy ==
                                                currentUserReference)
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              splashColor:
                                                  const Color(0xFF3B82F6)
                                                      .withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(22.0),
                                              onTap: () async {
                                                if (currentChatDoc?.admin ==
                                                        currentUserReference ||
                                                    currentChatDoc?.createdBy ==
                                                        currentUserReference) {
                                                  if (_model
                                                      .isEditingDescription) {
                                                    await _saveGroupDescription();
                                                  } else {
                                                    _model.isEditingDescription =
                                                        true;
                                                    safeSetState(() {});
                                                  }
                                                }
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(10.0),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFDBEAFE),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF3B82F6),
                                                    width: 2.0,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF3B82F6)
                                                          .withOpacity(0.3),
                                                      blurRadius: 6,
                                                      offset:
                                                          const Offset(0, 2),
                                                      spreadRadius: 0,
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  _model.isEditingDescription
                                                      ? Icons.check
                                                      : Icons.edit,
                                                  color:
                                                      const Color(0xFF2563EB),
                                                  size: 20.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6.0),
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            valueOrDefault<String>(
                                              currentChatDoc?.isPrivate == true
                                                  ? 'Internal Group'
                                                  : 'Public Group',
                                              'Public Group',
                                            ),
                                            textAlign: TextAlign.center,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                                  color:
                                                      const Color(0xFF10B981),
                                                  fontSize: 14.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.normal,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                          ),
                                        ),
                                        if (currentChatDoc?.admin ==
                                                currentUserReference ||
                                            currentChatDoc?.createdBy ==
                                                currentUserReference)
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              splashColor:
                                                  const Color(0xFF3B82F6)
                                                      .withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(22.0),
                                              onTap: () async {
                                                if (currentChatDoc?.admin ==
                                                        currentUserReference ||
                                                    currentChatDoc?.createdBy ==
                                                        currentUserReference) {
                                                  await _editGroupType();
                                                }
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(10.0),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFDBEAFE),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF3B82F6),
                                                    width: 2.0,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF3B82F6)
                                                          .withOpacity(0.3),
                                                      blurRadius: 6,
                                                      offset:
                                                          const Offset(0, 2),
                                                      spreadRadius: 0,
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.edit,
                                                  color: Color(0xFF2563EB),
                                                  size: 20.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (currentChatDoc?.createdBy ==
                                            currentUserReference)
                                          InkWell(
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () async {
                                              context.pushNamed(
                                                ChatGroupCreationWidget
                                                    .routeName,
                                                queryParameters: {
                                                  'isEdit': serializeParam(
                                                    true,
                                                    ParamType.bool,
                                                  ),
                                                  'chatDoc': serializeParam(
                                                    widget.chatDoc,
                                                    ParamType.Document,
                                                  ),
                                                }.withoutNulls,
                                                extra: <String, dynamic>{
                                                  'chatDoc': widget.chatDoc,
                                                },
                                              );
                                            },
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 40.0,
                                                  height: 40.0,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color:
                                                        const Color(0xFF374151),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Align(
                                                    alignment:
                                                        const AlignmentDirectional(
                                                            0.0, 0.0),
                                                    child: Icon(
                                                      Icons.edit,
                                                      color: Colors.black,
                                                      size: 16.0,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  'Rename',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodySmall
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 12.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodySmall
                                                                .fontStyle,
                                                      ),
                                                ),
                                              ].divide(
                                                  const SizedBox(height: 8.0)),
                                            ),
                                          ),
                                        if (widget.chatDoc?.admin ==
                                            currentUserReference)
                                          Builder(
                                            builder: (context) => InkWell(
                                              splashColor: Colors.transparent,
                                              focusColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              highlightColor:
                                                  Colors.transparent,
                                              onTap: () async {
                                                await showDialog(
                                                  context: context,
                                                  builder: (dialogContext) {
                                                    return Dialog(
                                                      elevation: 0,
                                                      insetPadding:
                                                          EdgeInsets.zero,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      alignment:
                                                          const AlignmentDirectional(
                                                                  0.0, 0.0)
                                                              .resolve(
                                                                  Directionality.of(
                                                                      context)),
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          FocusScope.of(
                                                                  dialogContext)
                                                              .unfocus();
                                                          FocusManager.instance
                                                              .primaryFocus
                                                              ?.unfocus();
                                                        },
                                                        child:
                                                            ReminderTimeWidget(
                                                          chatRef: widget
                                                              .chatDoc!
                                                              .reference,
                                                          currentReminderFreq:
                                                              valueOrDefault<
                                                                  int>(
                                                            widget.chatDoc
                                                                        ?.reminderFrequency !=
                                                                    null
                                                                ? valueOrDefault<
                                                                    int>(
                                                                    widget
                                                                        .chatDoc
                                                                        ?.reminderFrequency,
                                                                    1,
                                                                  )
                                                                : 1,
                                                            1,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 40.0,
                                                    height: 40.0,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: const Color(
                                                          0xFF374151),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Align(
                                                      alignment:
                                                          const AlignmentDirectional(
                                                              0.0, 0.0),
                                                      child: Icon(
                                                        Icons.smart_toy,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        size: 16.0,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    'AI Frequency',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 12.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ].divide(const SizedBox(
                                                    height: 8.0)),
                                              ),
                                            ),
                                          ),
                                      ].divide(const SizedBox(width: 32.0)),
                                    ),
                                  ].divide(const SizedBox(height: 8.0)),
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: const Color(0xFFE5E7EB),
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Media, Links, and Docs',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .titleMedium
                                                  .override(
                                                    font: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .titleMedium
                                                              .fontStyle,
                                                    ),
                                                    color:
                                                        const Color(0xFF1A1F36),
                                                    fontSize: 16.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .titleMedium
                                                            .fontStyle,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Stack(
                                                children: [
                                                  if (_model.message.isNotEmpty)
                                                    Builder(
                                                      builder: (context) {
                                                        final image = _model
                                                            .message
                                                            .map((e) => e.image)
                                                            .toList()
                                                            .take(4)
                                                            .toList();

                                                        return Row(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          children: List
                                                              .generate(
                                                                  image.length,
                                                                  (imageIndex) {
                                                            final imageItem =
                                                                image[
                                                                    imageIndex];
                                                            return InkWell(
                                                              splashColor: Colors
                                                                  .transparent,
                                                              focusColor: Colors
                                                                  .transparent,
                                                              hoverColor: Colors
                                                                  .transparent,
                                                              highlightColor:
                                                                  Colors
                                                                      .transparent,
                                                              onTap: () async {
                                                                await Navigator
                                                                    .push(
                                                                  context,
                                                                  PageTransition(
                                                                    type: PageTransitionType
                                                                        .fade,
                                                                    child:
                                                                        FlutterFlowExpandedImageView(
                                                                      image:
                                                                          CachedNetworkImage(
                                                                        fadeInDuration:
                                                                            const Duration(milliseconds: 500),
                                                                        fadeOutDuration:
                                                                            const Duration(milliseconds: 500),
                                                                        imageUrl:
                                                                            imageItem,
                                                                        fit: BoxFit
                                                                            .contain,
                                                                      ),
                                                                      allowRotation:
                                                                          false,
                                                                      tag:
                                                                          imageItem,
                                                                      useHeroAnimation:
                                                                          true,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              child: Hero(
                                                                tag: imageItem,
                                                                transitionOnUserGestures:
                                                                    true,
                                                                child:
                                                                    ClipRRect(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8.0),
                                                                  child:
                                                                      CachedNetworkImage(
                                                                    fadeInDuration:
                                                                        const Duration(
                                                                            milliseconds:
                                                                                500),
                                                                    fadeOutDuration:
                                                                        const Duration(
                                                                            milliseconds:
                                                                                500),
                                                                    imageUrl:
                                                                        imageItem,
                                                                    width: 64.0,
                                                                    height:
                                                                        64.0,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          }).divide(
                                                              const SizedBox(
                                                                  width: 8.0)),
                                                        );
                                                      },
                                                    ),
                                                  if (!(_model
                                                      .message.isNotEmpty))
                                                    Container(
                                                      width: 64.0,
                                                      height: 64.0,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFE5E7EB),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10.0),
                                                      ),
                                                      child: Align(
                                                        alignment:
                                                            const AlignmentDirectional(
                                                                0.0, 0.0),
                                                        child: Text(
                                                          'No images',
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                fontSize: 12.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (_model.message
                                                      .where(
                                                          (e) => e.image != '')
                                                      .toList()
                                                      .length >
                                                  4)
                                                InkWell(
                                                  splashColor:
                                                      Colors.transparent,
                                                  focusColor:
                                                      Colors.transparent,
                                                  hoverColor:
                                                      Colors.transparent,
                                                  highlightColor:
                                                      Colors.transparent,
                                                  onTap: () async {
                                                    await showModalBottomSheet(
                                                      isScrollControlled: true,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      context: context,
                                                      builder: (context) {
                                                        return GestureDetector(
                                                          onTap: () {
                                                            FocusScope.of(
                                                                    context)
                                                                .unfocus();
                                                            FocusManager
                                                                .instance
                                                                .primaryFocus
                                                                ?.unfocus();
                                                          },
                                                          child: Padding(
                                                            padding: MediaQuery
                                                                .viewInsetsOf(
                                                                    context),
                                                            child:
                                                                GallaryWidget(
                                                              images: _model
                                                                  .message
                                                                  .map((e) =>
                                                                      e.image)
                                                                  .toList(),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ).then((value) =>
                                                        safeSetState(() {}));
                                                  },
                                                  child: Container(
                                                    width: 64.0,
                                                    height: 64.0,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFE5E7EB),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child: Align(
                                                      alignment:
                                                          const AlignmentDirectional(
                                                              0.0, 0.0),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: RichText(
                                                          textScaler:
                                                              MediaQuery.of(
                                                                      context)
                                                                  .textScaler,
                                                          text: TextSpan(
                                                            children: [
                                                              const TextSpan(
                                                                text: '+',
                                                                style:
                                                                    TextStyle(),
                                                              ),
                                                              TextSpan(
                                                                text:
                                                                    valueOrDefault<
                                                                        String>(
                                                                  _model.message
                                                                      .where((e) =>
                                                                          e.image !=
                                                                          '')
                                                                      .toList()
                                                                      .length
                                                                      .toString(),
                                                                  '23',
                                                                ),
                                                                style: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight:
                                                                            FontWeight.normal,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodySmall
                                                                            .fontStyle,
                                                                      ),
                                                                      color: const Color(
                                                                          0xFF6B7280),
                                                                      fontSize:
                                                                          12.0,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .normal,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodySmall
                                                                          .fontStyle,
                                                                    ),
                                                              )
                                                            ],
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodySmall
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodySmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: const Color(
                                                                      0xFF6B7280),
                                                                  fontSize:
                                                                      12.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ].divide(
                                                const SizedBox(width: 8.0)),
                                          ),
                                        ),
                                      ].divide(const SizedBox(height: 12.0)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: const Color(0xFFE5E7EB),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Group\'s Action Tasks',
                                      style: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleMedium
                                                      .fontStyle,
                                            ),
                                            color: Colors.black,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        context.pushNamed(
                                          'GroupActionTasks',
                                          queryParameters: {
                                            'chatDoc': serializeParam(
                                              widget.chatDoc,
                                              ParamType.Document,
                                            ),
                                          }.withoutNulls,
                                        );
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16.0),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                      12.0),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF3B82F6)
                                                            .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                  child: const Icon(
                                                    Icons.task_alt_outlined,
                                                    size: 24,
                                                    color: Color(0xFF3B82F6),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'View Action Tasks',
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .titleMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontStyle,
                                                            ),
                                                            color: const Color(
                                                                0xFF1A1F36),
                                                            fontSize: 16.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Tasks from group conversations',
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(),
                                                            color: const Color(
                                                                0xFF64748B),
                                                            fontSize: 14.0,
                                                            letterSpacing: 0.0,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: Color(0xFF6B7280),
                                              size: 24,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: const Color(0xFFE5E7EB),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    StreamBuilder<ChatsRecord>(
                                      stream: ChatsRecord.getDocument(
                                          widget.chatDoc!.reference),
                                      builder: (context, snapshot) {
                                        // Customize what your widget looks like when it's loading.
                                        if (!snapshot.hasData) {
                                          return Center(
                                            child: SizedBox(
                                              width: 50.0,
                                              height: 50.0,
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }

                                        final containerChatsRecord =
                                            snapshot.data!;

                                        return Container(
                                          decoration: const BoxDecoration(),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Text(
                                                        'Members ',
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .titleMedium
                                                            .override(
                                                              font: GoogleFonts
                                                                  .inter(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                              ),
                                                              color: const Color(
                                                                  0xFF111827),
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontStyle,
                                                            ),
                                                      ),
                                                      Text(
                                                        containerChatsRecord
                                                            .members.length
                                                            .toString(),
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .titleMedium
                                                            .override(
                                                              font: GoogleFonts
                                                                  .inter(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                              ),
                                                              color: const Color(
                                                                  0xFF111827),
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontStyle,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  Builder(
                                                    builder: (context) =>
                                                        InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        setState(() {
                                                          _model.showAddUserPanel =
                                                              !_model
                                                                  .showAddUserPanel;
                                                        });
                                                      },
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          const Icon(
                                                            Icons.add,
                                                            color: Color(
                                                                0xFF4F46E5),
                                                            size: 16.0,
                                                          ),
                                                          Text(
                                                            'Add',
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: const Color(
                                                                      0xFF4F46E5),
                                                                  fontSize:
                                                                      14.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                        ].divide(const SizedBox(
                                                            width: 4.0)),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  const SizedBox(height: 12.0),
                                                  Stack(
                                                    children: [
                                                      Container(
                                                        constraints:
                                                            const BoxConstraints(
                                                          maxHeight: 400.0,
                                                        ),
                                                        decoration:
                                                            const BoxDecoration(),
                                                        child: Builder(
                                                          builder: (context) {
                                                            // Show all members including current user
                                                            final allMembers =
                                                                containerChatsRecord
                                                                    .members;
                                                            // Sort members to show admin/creator first
                                                            final sortedMembers =
                                                                List<DocumentReference>.from(
                                                                    allMembers);
                                                            sortedMembers
                                                                .sort((a, b) {
                                                              // Put admin first
                                                              if (a ==
                                                                  containerChatsRecord
                                                                      .admin)
                                                                return -1;
                                                              if (b ==
                                                                  containerChatsRecord
                                                                      .admin)
                                                                return 1;
                                                              // Put creator first if not admin
                                                              if (a ==
                                                                  containerChatsRecord
                                                                      .createdBy)
                                                                return -1;
                                                              if (b ==
                                                                  containerChatsRecord
                                                                      .createdBy)
                                                                return 1;
                                                              return 0;
                                                            });
                                                            final members =
                                                                sortedMembers;

                                                            return SingleChildScrollView(
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: List.generate(
                                                                    members
                                                                        .length,
                                                                    (membersIndex) {
                                                                  final membersItem =
                                                                      members[
                                                                          membersIndex];
                                                                  return StreamBuilder<
                                                                      UsersRecord>(
                                                                    stream: UsersRecord
                                                                        .getDocument(
                                                                            membersItem),
                                                                    builder:
                                                                        (context,
                                                                            snapshot) {
                                                                      // Customize what your widget looks like when it's loading.
                                                                      if (!snapshot
                                                                          .hasData) {
                                                                        return Center(
                                                                          child:
                                                                              SizedBox(
                                                                            width:
                                                                                50.0,
                                                                            height:
                                                                                50.0,
                                                                            child:
                                                                                CircularProgressIndicator(
                                                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                                                FlutterFlowTheme.of(context).primary,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      }

                                                                      final rowUsersRecord =
                                                                          snapshot
                                                                              .data!;

                                                                      return InkWell(
                                                                        splashColor:
                                                                            Colors.transparent,
                                                                        focusColor:
                                                                            Colors.transparent,
                                                                        hoverColor:
                                                                            Colors.transparent,
                                                                        highlightColor:
                                                                            Colors.transparent,
                                                                        onTap:
                                                                            () async {
                                                                          context
                                                                              .pushNamed(
                                                                            UserProfileDetailWidget.routeName,
                                                                            queryParameters:
                                                                                {
                                                                              'user': serializeParam(
                                                                                rowUsersRecord,
                                                                                ParamType.Document,
                                                                              ),
                                                                            }.withoutNulls,
                                                                            extra: <String,
                                                                                dynamic>{
                                                                              'user': rowUsersRecord,
                                                                            },
                                                                          );
                                                                        },
                                                                        child:
                                                                            Row(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceBetween,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.center,
                                                                          children: [
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              children: [
                                                                                ClipRRect(
                                                                                  borderRadius: BorderRadius.circular(20.0),
                                                                                  child: Image.network(
                                                                                    valueOrDefault<String>(
                                                                                      rowUsersRecord.photoUrl,
                                                                                      'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdiv.png?alt=media&token=85d5445a-3d2d-4dd5-879e-c4000b1fefd5',
                                                                                    ),
                                                                                    width: 40.0,
                                                                                    height: 40.0,
                                                                                    fit: BoxFit.cover,
                                                                                  ),
                                                                                ),
                                                                                Column(
                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                                  children: [
                                                                                    Row(
                                                                                      mainAxisSize: MainAxisSize.min,
                                                                                      children: [
                                                                                        Text(
                                                                                          rowUsersRecord.displayName,
                                                                                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                font: GoogleFonts.inter(
                                                                                                  fontWeight: FontWeight.w500,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                ),
                                                                                                color: Colors.black,
                                                                                                fontSize: 14.0,
                                                                                                letterSpacing: 0.0,
                                                                                                fontWeight: FontWeight.w500,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                              ),
                                                                                        ),
                                                                                        if (widget.chatDoc?.admin == rowUsersRecord.reference || widget.chatDoc?.createdBy == rowUsersRecord.reference)
                                                                                          Padding(
                                                                                            padding: const EdgeInsetsDirectional.only(start: 6.0),
                                                                                            child: Container(
                                                                                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                                                                              decoration: BoxDecoration(
                                                                                                color: const Color(0xFF3B82F6),
                                                                                                borderRadius: BorderRadius.circular(4.0),
                                                                                              ),
                                                                                              child: Text(
                                                                                                'Admin',
                                                                                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                                      font: GoogleFonts.inter(
                                                                                                        fontWeight: FontWeight.w500,
                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                      ),
                                                                                                      color: Colors.white,
                                                                                                      fontSize: 10.0,
                                                                                                      letterSpacing: 0.0,
                                                                                                      fontWeight: FontWeight.w500,
                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                    ),
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                      ],
                                                                                    ),
                                                                                    Row(
                                                                                      mainAxisSize: MainAxisSize.max,
                                                                                      children: [
                                                                                        Text(
                                                                                          'Chat',
                                                                                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                                font: GoogleFonts.inter(
                                                                                                  fontWeight: FontWeight.w500,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                ),
                                                                                                color: Colors.black,
                                                                                                fontSize: 12.0,
                                                                                                letterSpacing: 0.0,
                                                                                                fontWeight: FontWeight.w500,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                              ),
                                                                                        ),
                                                                                        Text(
                                                                                          '•',
                                                                                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                                font: GoogleFonts.inter(
                                                                                                  fontWeight: FontWeight.normal,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                ),
                                                                                                color: Colors.black,
                                                                                                fontSize: 16.0,
                                                                                                letterSpacing: 0.0,
                                                                                                fontWeight: FontWeight.normal,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                              ),
                                                                                        ),
                                                                                        Text(
                                                                                          rowUsersRecord.email,
                                                                                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                                font: GoogleFonts.inter(
                                                                                                  fontWeight: FontWeight.normal,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                ),
                                                                                                color: Colors.black,
                                                                                                fontSize: 12.0,
                                                                                                letterSpacing: 0.0,
                                                                                                fontWeight: FontWeight.normal,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                              ),
                                                                                        ),
                                                                                      ].divide(const SizedBox(width: 4.0)),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ].divide(const SizedBox(width: 12.0)),
                                                                            ),
                                                                            const Icon(
                                                                              Icons.more_vert,
                                                                              color: Colors.black,
                                                                              size: 16.0,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      );
                                                                    },
                                                                  );
                                                                }).divide(
                                                                    const SizedBox(
                                                                        height:
                                                                            12.0)),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      // Overlay Add User Panel
                                                      if (_model
                                                          .showAddUserPanel)
                                                        Positioned.fill(
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12.0),
                                                              border:
                                                                  Border.all(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .alternate,
                                                                width: 1.0,
                                                              ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Color(
                                                                      0x33000000),
                                                                  blurRadius:
                                                                      8.0,
                                                                  offset:
                                                                      Offset(
                                                                          0.0,
                                                                          2.0),
                                                                  spreadRadius:
                                                                      0.0,
                                                                ),
                                                              ],
                                                            ),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                // Header with close button
                                                                Padding(
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          16,
                                                                          12,
                                                                          12,
                                                                          12),
                                                                  child: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .spaceBetween,
                                                                    children: [
                                                                      Text(
                                                                        'Add Members',
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .titleMedium
                                                                            .override(
                                                                              font: GoogleFonts.inter(
                                                                                fontWeight: FontWeight.w600,
                                                                              ),
                                                                              color: const Color(0xFF111827),
                                                                              fontSize: 16.0,
                                                                              letterSpacing: 0.0,
                                                                            ),
                                                                      ),
                                                                      InkWell(
                                                                        onTap:
                                                                            () {
                                                                          setState(
                                                                              () {
                                                                            _model.showAddUserPanel =
                                                                                false;
                                                                          });
                                                                        },
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .close,
                                                                          color:
                                                                              Color(0xFF6B7280),
                                                                          size:
                                                                              20,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                Divider(
                                                                  height: 1,
                                                                  thickness: 1,
                                                                  color: const Color(
                                                                      0xFF374151),
                                                                ),
                                                                // AddUserWidget inline
                                                                Expanded(
                                                                  child:
                                                                      Padding(
                                                                    padding: EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            16,
                                                                            16,
                                                                            16,
                                                                            16),
                                                                    child:
                                                                        AddUserWidget(
                                                                      userRefs: widget
                                                                          .chatDoc!
                                                                          .members,
                                                                      actionOutput:
                                                                          (listUsers) async {
                                                                        await widget
                                                                            .chatDoc!
                                                                            .reference
                                                                            .update({
                                                                          ...mapToFirestore(
                                                                            {
                                                                              'members': listUsers,
                                                                            },
                                                                          ),
                                                                        });
                                                                        setState(
                                                                            () {
                                                                          _model.showAddUserPanel =
                                                                              false;
                                                                        });
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              if (false)
                                                FFButtonWidget(
                                                  onPressed: () {
                                                    print('Button pressed ...');
                                                  },
                                                  text: 'See All Members',
                                                  options: FFButtonOptions(
                                                    width: double.infinity,
                                                    height: 36.0,
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(16.0, 0.0,
                                                            16.0, 0.0),
                                                    iconPadding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                    color: Colors.transparent,
                                                    textStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: const Color(
                                                              0xFF4F46E5),
                                                          fontSize: 14.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                    elevation: 0.0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                ),
                                            ].divide(
                                                const SizedBox(height: 16.0)),
                                          ),
                                        );
                                      },
                                    ),
                                    if (widget.chatDoc?.admin ==
                                        currentUserReference)
                                      Column(
                                        mainAxisSize: MainAxisSize.max,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .tertiary,
                                              borderRadius:
                                                  BorderRadius.circular(16.0),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Text(
                                                        'Report List',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .titleMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryBackground,
                                                                  fontSize:
                                                                      16.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleMedium
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Container(
                                                constraints:
                                                    const BoxConstraints(
                                                  minHeight: 100.0,
                                                  maxHeight: 400.0,
                                                ),
                                                decoration:
                                                    const BoxDecoration(),
                                                child: Builder(
                                                  builder: (context) {
                                                    final reportLists =
                                                        _model.report.toList();
                                                    if (reportLists.isEmpty) {
                                                      return const EmptyScheduleWidget(
                                                        title:
                                                            'No Report so far',
                                                        description:
                                                            'There is no report from user so far.',
                                                        icon: Icon(
                                                          Icons
                                                              .hourglass_empty_outlined,
                                                        ),
                                                      );
                                                    }

                                                    return SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: List.generate(
                                                            reportLists.length,
                                                            (reportListsIndex) {
                                                          final reportListsItem =
                                                              reportLists[
                                                                  reportListsIndex];
                                                          return Stack(
                                                            children: [
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        5.0),
                                                                child:
                                                                    Container(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryBackground,
                                                                    boxShadow: const [
                                                                      BoxShadow(
                                                                        blurRadius:
                                                                            6.0,
                                                                        color: Color(
                                                                            0x33000000),
                                                                        offset:
                                                                            Offset(
                                                                          0.0,
                                                                          1.0,
                                                                        ),
                                                                      )
                                                                    ],
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12.0),
                                                                  ),
                                                                  child:
                                                                      Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            16.0),
                                                                    child: StreamBuilder<
                                                                        UsersRecord>(
                                                                      stream: UsersRecord.getDocument(
                                                                          reportListsItem
                                                                              .reportedUser!),
                                                                      builder:
                                                                          (context,
                                                                              snapshot) {
                                                                        // Customize what your widget looks like when it's loading.
                                                                        if (!snapshot
                                                                            .hasData) {
                                                                          return Center(
                                                                            child:
                                                                                SizedBox(
                                                                              width: 50.0,
                                                                              height: 50.0,
                                                                              child: CircularProgressIndicator(
                                                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                                                  FlutterFlowTheme.of(context).primary,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          );
                                                                        }

                                                                        final columnUsersRecord =
                                                                            snapshot.data!;

                                                                        return Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.center,
                                                                          children:
                                                                              [
                                                                            Container(
                                                                              decoration: const BoxDecoration(),
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.all(16.0),
                                                                                child: Row(
                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                                                  children: [
                                                                                    Row(
                                                                                      mainAxisSize: MainAxisSize.max,
                                                                                      children: [
                                                                                        ClipRRect(
                                                                                          borderRadius: BorderRadius.circular(20.0),
                                                                                          child: Image.network(
                                                                                            valueOrDefault<String>(
                                                                                              columnUsersRecord.photoUrl,
                                                                                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdiv.png?alt=media&token=85d5445a-3d2d-4dd5-879e-c4000b1fefd5',
                                                                                            ),
                                                                                            width: 40.0,
                                                                                            height: 40.0,
                                                                                            fit: BoxFit.cover,
                                                                                          ),
                                                                                        ),
                                                                                        Column(
                                                                                          mainAxisSize: MainAxisSize.max,
                                                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                                                          children: [
                                                                                            Text(
                                                                                              columnUsersRecord.displayName,
                                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                    font: GoogleFonts.inter(
                                                                                                      fontWeight: FontWeight.w500,
                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                    ),
                                                                                                    color: Colors.white,
                                                                                                    fontSize: 14.0,
                                                                                                    letterSpacing: 0.0,
                                                                                                    fontWeight: FontWeight.w500,
                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                  ),
                                                                                            ),
                                                                                            Row(
                                                                                              mainAxisSize: MainAxisSize.max,
                                                                                              children: [
                                                                                                Text(
                                                                                                  columnUsersRecord.email,
                                                                                                  style: FlutterFlowTheme.of(context).bodySmall.override(
                                                                                                        font: GoogleFonts.inter(
                                                                                                          fontWeight: FontWeight.w500,
                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                        ),
                                                                                                        color: Colors.white,
                                                                                                        fontSize: 12.0,
                                                                                                        letterSpacing: 0.0,
                                                                                                        fontWeight: FontWeight.w500,
                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                                                                                                      ),
                                                                                                ),
                                                                                              ].divide(const SizedBox(width: 4.0)),
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                      ].divide(const SizedBox(width: 12.0)),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Padding(
                                                                              padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                              child: Column(
                                                                                mainAxisSize: MainAxisSize.max,
                                                                                children: [
                                                                                  Text(
                                                                                    'Reasons',
                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                          font: GoogleFonts.inter(
                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                          ),
                                                                                          color: FlutterFlowTheme.of(context).tertiary,
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                        ),
                                                                                  ),
                                                                                  Text(
                                                                                    reportListsItem.reason,
                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                          font: GoogleFonts.inter(
                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                          ),
                                                                                          color: Colors.white,
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                        ),
                                                                                  ),
                                                                                ].divide(const SizedBox(height: 5.0)),
                                                                              ),
                                                                            ),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                                              children: [
                                                                                FFButtonWidget(
                                                                                  onPressed: () async {
                                                                                    await reportListsItem.messageRef!.delete();
                                                                                    await reportListsItem.reference.delete();
                                                                                    context.safePop();
                                                                                  },
                                                                                  text: 'Remove',
                                                                                  options: FFButtonOptions(
                                                                                    height: 30.0,
                                                                                    padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                                    iconPadding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                    color: const Color(0x002563EB),
                                                                                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                          font: GoogleFonts.inter(
                                                                                            fontWeight: FontWeight.w500,
                                                                                            fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                          ),
                                                                                          color: FlutterFlowTheme.of(context).tertiary,
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FontWeight.w500,
                                                                                          fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                        ),
                                                                                    elevation: 0.0,
                                                                                    borderRadius: BorderRadius.circular(8.0),
                                                                                  ),
                                                                                ),
                                                                                FFButtonWidget(
                                                                                  onPressed: () async {
                                                                                    await reportListsItem.chatGroup!.update({
                                                                                      ...mapToFirestore(
                                                                                        {
                                                                                          'members': FieldValue.arrayRemove([
                                                                                            columnUsersRecord.reference
                                                                                          ]),
                                                                                          'blocked_user': FieldValue.arrayUnion([
                                                                                            columnUsersRecord.reference
                                                                                          ]),
                                                                                        },
                                                                                      ),
                                                                                    });
                                                                                  },
                                                                                  text: 'Block',
                                                                                  options: FFButtonOptions(
                                                                                    height: 30.0,
                                                                                    padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                                    iconPadding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                    color: FlutterFlowTheme.of(context).error,
                                                                                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                          font: GoogleFonts.inter(
                                                                                            fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                            fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                          ),
                                                                                          color: Colors.white,
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                          fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                        ),
                                                                                    elevation: 0.0,
                                                                                    borderRadius: BorderRadius.circular(24.0),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ].divide(const SizedBox(height: 16.0)),
                                                                        );
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              Align(
                                                                alignment:
                                                                    const AlignmentDirectional(
                                                                        1.0,
                                                                        -1.0),
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsetsDirectional
                                                                          .fromSTEB(
                                                                          0.0,
                                                                          16.0,
                                                                          16.0,
                                                                          0.0),
                                                                  child:
                                                                      InkWell(
                                                                    splashColor:
                                                                        Colors
                                                                            .transparent,
                                                                    focusColor:
                                                                        Colors
                                                                            .transparent,
                                                                    hoverColor:
                                                                        Colors
                                                                            .transparent,
                                                                    highlightColor:
                                                                        Colors
                                                                            .transparent,
                                                                    onTap:
                                                                        () async {
                                                                      await reportListsItem
                                                                          .reference
                                                                          .delete();
                                                                    },
                                                                    child: Icon(
                                                                      Icons
                                                                          .close_sharp,
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText,
                                                                      size:
                                                                          24.0,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        }).divide(
                                                            const SizedBox(
                                                                height: 12.0)),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (false)
                                            FFButtonWidget(
                                              onPressed: () {
                                                print('Button pressed ...');
                                              },
                                              text: 'See All Members',
                                              options: FFButtonOptions(
                                                width: double.infinity,
                                                height: 36.0,
                                                padding:
                                                    const EdgeInsetsDirectional
                                                        .fromSTEB(
                                                        16.0, 0.0, 16.0, 0.0),
                                                iconPadding:
                                                    const EdgeInsetsDirectional
                                                        .fromSTEB(
                                                        0.0, 0.0, 0.0, 0.0),
                                                color: Colors.transparent,
                                                textStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: const Color(
                                                              0xFF4F46E5),
                                                          fontSize: 14.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                elevation: 0.0,
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                            ),
                                        ]
                                            .divide(
                                                const SizedBox(height: 16.0))
                                            .addToStart(
                                                const SizedBox(height: 16.0))
                                            .addToEnd(
                                                const SizedBox(height: 16.0)),
                                      ),
                                  ].divide(const SizedBox(height: 24.0)),
                                ),
                              ),
                            ),
                            if (false)
                              Container(
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Admin Controls',
                                        style: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .fontStyle,
                                              ),
                                              color: Colors.black,
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Container(
                                                width: 32.0,
                                                height: 32.0,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFDBEAFE),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    Icons.smart_toy,
                                                    color: Color(0xFF4F46E5),
                                                    size: 18.0,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                'AI Assistant Setting',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                      color: const Color(
                                                          0xFF111827),
                                                      fontSize: 14.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                              ),
                                            ].divide(
                                                const SizedBox(width: 12.0)),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: Colors.black,
                                            size: 16.0,
                                          ),
                                        ],
                                      ),
                                    ].divide(const SizedBox(height: 16.0)),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  16.0, 8.0, 16.0, 8.0),
                              child: InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () async {
                                  if (widget.chatDoc?.createdBy ==
                                      currentUserReference) {
                                    await showDialog(
                                      context: context,
                                      builder: (dialogContext) {
                                        return Dialog(
                                          elevation: 0,
                                          insetPadding: EdgeInsets.zero,
                                          backgroundColor: Colors.transparent,
                                          alignment: const AlignmentDirectional(
                                                  0.0, 0.0)
                                              .resolve(
                                                  Directionality.of(context)),
                                          child: GestureDetector(
                                            onTap: () {
                                              FocusScope.of(dialogContext)
                                                  .unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: DeleteChatGroupWidget(
                                              groupChatRef:
                                                  widget.chatDoc!.reference,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  } else {
                                    await widget.chatDoc!.reference.update({
                                      ...mapToFirestore(
                                        {
                                          'members': FieldValue.arrayRemove(
                                              [currentUserReference]),
                                        },
                                      ),
                                    });

                                    context.pushNamed(ChatWidget.routeName);
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16.0),
                                  child: Text(
                                    currentChatDoc?.createdBy ==
                                            currentUserReference
                                        ? 'Delete Group'
                                        : 'Exit Group',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w500,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                          color: const Color(0xFFEF4444),
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w500,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ]
                              .divide(const SizedBox(height: 8.0))
                              .addToStart(const SizedBox(height: 8.0))
                              .addToEnd(const SizedBox(height: 16.0)),
                        ),
                      ),
                      if (_model.laoding == true)
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(60.0),
                            child: SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: custom_widgets.FFlowSpinner(
                                width: double.infinity,
                                height: double.infinity,
                                backgroundColor: Colors.transparent,
                                spinnerColor:
                                    FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
