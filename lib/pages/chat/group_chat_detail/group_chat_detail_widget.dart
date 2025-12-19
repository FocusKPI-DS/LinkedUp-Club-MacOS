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
import '/pages/chat/group_action_tasks/group_action_tasks_widget.dart';
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
import 'package:url_launcher/url_launcher.dart';
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

class _GroupChatDetailWidgetState extends State<GroupChatDetailWidget> with TickerProviderStateMixin {
  late GroupChatDetailModel _model;
  late TabController _mediaLinksDocsTabController;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupChatDetailModel());
    _mediaLinksDocsTabController = TabController(length: 3, vsync: this);

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      // Initialize text controllers with current values
      _model.groupNameController?.text = widget.chatDoc?.title ?? '';
      // Don't initialize description if it's the same as group type
      final description = widget.chatDoc?.description ?? '';
      _model.groupDescriptionController?.text = 
          (description == 'Internal Group' || description == 'Public Group') 
              ? '' 
              : description;

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
              .where((e) => 
                  e.messageType == MessageType.image ||
                  e.image != '' ||
                  e.images.isNotEmpty)
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
    _mediaLinksDocsTabController.dispose();
    super.dispose();
  }

  // Extract images from messages
  List<String> _getImages() {
    final allImages = <String>[];
    for (final msg in _model.message) {
      if (msg.messageType == MessageType.image ||
          msg.image != '' ||
          msg.images.isNotEmpty) {
        if (msg.image != '') {
          allImages.add(msg.image);
        }
        if (msg.images.isNotEmpty) {
          allImages.addAll(msg.images);
        }
      }
    }
    return allImages;
  }

  // Extract links from message content
  List<Map<String, dynamic>> _getLinks() {
    final messages = _model.messages;
    if (messages == null) return [];
    final links = <Map<String, dynamic>>[];
    final urlRegex = RegExp(
      r'https?://[^\s<>"{}|\\^`\[\]]+',
      caseSensitive: false,
    );

    for (final msg in messages) {
      if (msg.content.isNotEmpty) {
        final matches = urlRegex.allMatches(msg.content);
        for (final match in matches) {
          final url = match.group(0)!;
          if (!links.any((link) => link['url'] == url)) {
            links.add({
              'url': url,
              'preview': msg.content.length > 100
                  ? msg.content.substring(0, 100) + '...'
                  : msg.content,
              'sender': msg.senderName.isNotEmpty ? msg.senderName : null,
            });
          }
        }
      }
    }
    return links;
  }

  // Extract docs (files) from messages
  List<Map<String, dynamic>> _getDocs() {
    final messages = _model.messages;
    if (messages == null) return [];
    final docs = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (msg.attachmentUrl.isNotEmpty) {
        docs.add({
          'url': msg.attachmentUrl,
          'fileName': msg.content.isNotEmpty
              ? msg.content
              : 'file_${msg.reference.id}',
          'sender': msg.senderName.isNotEmpty ? msg.senderName : null,
          'messageType': msg.messageType,
        });
      }
    }
    return docs;
  }

  Widget _buildMediaLinksDocsView() {
    return TabBarView(
      controller: _mediaLinksDocsTabController,
      children: [
        _buildMediaTab(),
        _buildDocsTab(),
        _buildLinksTab(),
      ],
    );
  }

  Widget _buildMediaTab() {
    final images = _getImages();
    
    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 64.0,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 16.0),
            Text(
              'No media',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    fontFamily: 'Inter',
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final imageUrl = images[index];
        return InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.fade,
                child: FlutterFlowExpandedImageView(
                  image: CachedNetworkImage(
                    fadeInDuration: const Duration(milliseconds: 300),
                    fadeOutDuration: const Duration(milliseconds: 300),
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                  ),
                  allowRotation: false,
                  tag: imageUrl,
                  useHeroAnimation: true,
                ),
              ),
            );
          },
          child: Hero(
            tag: imageUrl,
            transitionOnUserGestures: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocsTab() {
    final docs = _getDocs();
    
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 64.0,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 16.0),
            Text(
              'No documents',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    fontFamily: 'Inter',
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final fileName = doc['fileName'] as String;
        final url = doc['url'] as String;
        final sender = doc['sender'] as String?;
        final isPdf = fileName.toLowerCase().endsWith('.pdf');

        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            children: [
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).alternate,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                  color: FlutterFlowTheme.of(context).primary,
                  size: 24.0,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Inter',
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.0,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sender != null) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        sender,
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              fontFamily: 'Inter',
                              fontSize: 12.0,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.download_rounded,
                  color: FlutterFlowTheme.of(context).primary,
                ),
                onPressed: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinksTab() {
    final links = _getLinks();
    
    if (links.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_outlined,
              size: 64.0,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 16.0),
            Text(
              'No links',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    fontFamily: 'Inter',
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: links.length,
      itemBuilder: (context, index) {
        final link = links[index];
        final url = link['url'] as String;
        final preview = link['preview'] as String?;
        final sender = link['sender'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: InkWell(
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Row(
              children: [
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).alternate,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(
                    Icons.link,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 24.0,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        url,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: FlutterFlowTheme.of(context).primary,
                              letterSpacing: 0.0,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (preview != null && preview.isNotEmpty) ...[
                        const SizedBox(height: 4.0),
                        Text(
                          preview,
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                fontFamily: 'Inter',
                                fontSize: 12.0,
                                color: FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (sender != null) ...[
                        const SizedBox(height: 4.0),
                        Text(
                          sender,
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                fontFamily: 'Inter',
                                fontSize: 12.0,
                                color: FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ],
            ),
          ),
        );
      },
    );
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
        'is_system_message': true,
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
      // Open gallery directly
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        // Show loading indicator with proper context handling
        bool isDialogShowing = false;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            isDialogShowing = true;
            return Center(
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Uploading photo...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        try {
          // Upload image
          final oldImageUrl = widget.chatDoc?.chatImageUrl ?? '';
          final newImageUrl = await _uploadGroupImage(image);

          // Update chat document
          await widget.chatDoc!.reference.update({
            'chat_image_url': newImageUrl,
          });

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

          // Close loading dialog safely
          if (mounted && isDialogShowing && Navigator.canPop(context)) {
            Navigator.of(context).pop();
            isDialogShowing = false;
          }

          // Show success dropdown instead of snackbar
          if (mounted) {
            _showSuccessDropdown('Photo updated successfully');
          }
        } catch (uploadError) {
          // Close loading dialog safely on error
          if (mounted && isDialogShowing && Navigator.canPop(context)) {
            Navigator.of(context).pop();
            isDialogShowing = false;
          }
          
          if (mounted) {
            _showErrorDropdown('Failed to update photo');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDropdown('Failed to select image');
      }
    }
  }

  void _showSuccessDropdown(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 200.0, left: 80.0, right: 80.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: const Color(0xFF10B981), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 16.0,
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1F36),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Auto dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  void _showErrorDropdown(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 200.0, left: 80.0, right: 80.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: const Color(0xFFEF4444), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 16.0,
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1F36),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _makeUserAdmin(UsersRecord user) async {
    if (widget.chatDoc == null) return;

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        backgroundColor: Colors.white,
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(24.0),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF4FF),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Color(0xFF3B82F6),
                      size: 20.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  const Text(
                    'Make Admin',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              // Content
              Text(
                'Are you sure you want to make ${user.displayName} an admin? They will have full permissions to manage this group.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.0,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24.0),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Make Admin',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      // Update chat document to set new admin
      await widget.chatDoc!.reference.update({
        'admin': user.reference,
      });

      // Send system message
      final userName = currentUserDisplayName.isNotEmpty
          ? currentUserDisplayName
          : (currentUserDocument?.displayName ?? 'Someone');
      
      await _sendSystemMessage(
        '$userName promoted ${user.displayName} to admin',
      );

      if (mounted) {
        _showSuccessDropdown('${user.displayName} is now admin');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDropdown('Failed to promote user');
      }
    }
  }



  Future<void> _removeUser(UsersRecord user) async {
    if (widget.chatDoc == null) return;

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        backgroundColor: Colors.white,
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(24.0),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(
                      Icons.person_remove,
                      color: Color(0xFFEF4444),
                      size: 20.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  const Text(
                    'Remove User',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              // Content
              Text(
                'Are you sure you want to remove ${user.displayName} from the group? This action cannot be undone.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.0,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24.0),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      // Remove user from chat members
      final updatedMembers = List<DocumentReference>.from(widget.chatDoc!.members);
      updatedMembers.remove(user.reference);

      await widget.chatDoc!.reference.update({
        'members': updatedMembers,
      });

      // Send system message
      final userName = currentUserDisplayName.isNotEmpty
          ? currentUserDisplayName
          : (currentUserDocument?.displayName ?? 'Someone');
      
      await _sendSystemMessage(
        '$userName removed ${user.displayName} from the group',
      );

      if (mounted) {
        _showSuccessDropdown('${user.displayName} removed');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDropdown('Failed to remove user');
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

  Future<void> _showAddMembersDialog() async {
    if (widget.chatDoc == null) return;

    // Initialize userRef with current members
    _model.userRef = widget.chatDoc!.members.toList();
    safeSetState(() {});

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 500.0,
                  maxHeight: 600.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFE5E7EB),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(dialogContext).pop(),
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFF6B7280),
                          size: 24.0,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      const Expanded(
                        child: Text(
                          'Add member',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18.0,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1F36),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Search bar
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 16.0, right: 8.0),
                          child: Icon(
                            Icons.search,
                            color: Color(0xFF6B7280),
                            size: 20.0,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.0,
                              color: Color(0xFF1A1F36),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search connections',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.0,
                                color: Color(0xFF9CA3AF),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 12.0,
                              ),
                            ),
                            onChanged: (value) {
                              // TODO: Implement search functionality
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Contacts label
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: const Text(
                    'Your Connections',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                // User list
                Expanded(
                  child: AuthUserStreamWidget(
                    builder: (context) => StreamBuilder<UsersRecord>(
                      stream: UsersRecord.getDocument(currentUserReference!),
                      builder: (context, currentUserSnapshot) {
                        if (!currentUserSnapshot.hasData) {
                          return const Center(
                            child: SizedBox(
                              width: 40.0,
                              height: 40.0,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          );
                        }

                        final currentUser = currentUserSnapshot.data!;
                        final connections = currentUser.friends;
                        final existingMembers = widget.chatDoc!.members.toList();
                        
                        // Filter connections to only show those not already in the group
                        // Compare by reference ID to ensure accurate matching
                        final candidateUserRefs = connections
                            .where((ref) {
                              // Skip if it's the current user
                              if (ref.id == currentUserReference?.id) {
                                return false;
                              }
                              // Skip if already in the group
                              final isAlreadyMember = existingMembers.any((member) => member.id == ref.id);
                              return !isAlreadyMember;
                            })
                            .toList();

                        if (candidateUserRefs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48.0,
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                  const SizedBox(height: 16.0),
                                  const Text(
                                    'No connections available',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  const Text(
                                    'All your connections are already in this group',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14.0,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: candidateUserRefs.length,
                          itemBuilder: (context, index) {
                            final userRef = candidateUserRefs[index];
                            return FutureBuilder<UsersRecord>(
                              future: UsersRecord.getDocumentOnce(userRef),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }

                                final user = snapshot.data!;
                                final isSelected = _model.userRef.contains(userRef);

                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      if (isSelected) {
                                        _model.removeFromUserRef(userRef);
                                      } else {
                                        _model.addToUserRef(userRef);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFF3F4F6),
                                          width: 1.0,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Checkbox
                                        Container(
                                          width: 20.0,
                                          height: 20.0,
                                          margin: const EdgeInsets.only(right: 12.0),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF3B82F6)
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF3B82F6)
                                                  : const Color(0xFFD1D5DB),
                                              width: 2.0,
                                            ),
                                            borderRadius: BorderRadius.circular(4.0),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 14.0,
                                                )
                                              : null,
                                        ),
                                        // Avatar
                                        Container(
                                          width: 48.0,
                                          height: 48.0,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEBF4FF),
                                            shape: BoxShape.circle,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(24.0),
                                            child: user.photoUrl.isNotEmpty
                                                ? Image.network(
                                                    user.photoUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return const Center(
                                                        child: Icon(
                                                          Icons.person,
                                                          color: Color(0xFF3B82F6),
                                                          size: 24.0,
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : const Center(
                                                    child: Icon(
                                                      Icons.person,
                                                      color: Color(0xFF3B82F6),
                                                      size: 24.0,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12.0),
                                        // User info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.displayName,
                                                style: const TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF1A1F36),
                                                ),
                                              ),
                                              if (user.email.isNotEmpty)
                                                Text(
                                                  user.email,
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 13.0,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                            ],
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
                      },
                    ),
                  ),
                ),
                // Add button
                if (_model.userRef.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.0)),
                      border: Border(
                        top: BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            // Update only the members list - admin field remains unchanged
                            // New members are added as regular members, not admins
                            await widget.chatDoc!.reference.update({
                              ...mapToFirestore({
                                'members': _model.userRef,
                              }),
                            });

                            // Send system message
                            final userName = currentUserDisplayName.isNotEmpty
                                ? currentUserDisplayName
                                : (currentUserDocument?.displayName ?? 'Someone');
                            final addedCount = _model.userRef.length - widget.chatDoc!.members.length;
                            if (addedCount > 0) {
                              await _sendSystemMessage(
                                '$userName added $addedCount ${addedCount == 1 ? 'member' : 'members'}',
                              );
                            }

                            if (mounted) {
                              Navigator.of(dialogContext).pop();
                              _showSuccessDropdown('Members added successfully');
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(dialogContext).pop();
                              _showErrorDropdown('Failed to add members');
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, size: 20.0),
                            const SizedBox(width: 8.0),
                            Text(
                              'Add ${_model.userRef.length - widget.chatDoc!.members.length} ${(_model.userRef.length - widget.chatDoc!.members.length) == 1 ? 'member' : 'members'}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    final description = currentChatDoc?.description ?? '';
                    _model.groupDescriptionController!.text =
                        (description == 'Internal Group' || description == 'Public Group') 
                            ? '' 
                            : description;
                  }
                });
              }

              return Container(
                constraints: const BoxConstraints(
                  maxWidth: 650.0,
                ),
                decoration: const BoxDecoration(),
                child: Stack(
                  children: [
                    Column(
                      children: [
                    // Sticky Header Section - Group Info
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _model.showMediaLinksDocs
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          _model.showMediaLinksDocs = false;
                                          safeSetState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.arrow_back,
                                            color: FlutterFlowTheme.of(context).primaryText,
                                            size: 24.0,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Text(
                                          'Media, Links, and Docs',
                                          style: FlutterFlowTheme.of(context).headlineSmall.override(
                                                fontFamily: 'Inter',
                                                fontSize: 20.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8.0),
                                  TabBar(
                                    controller: _mediaLinksDocsTabController,
                                    labelColor: FlutterFlowTheme.of(context).primary,
                                    unselectedLabelColor: FlutterFlowTheme.of(context).secondaryText,
                                    labelStyle: FlutterFlowTheme.of(context).titleMedium.override(
                                          fontFamily: 'Inter',
                                          fontSize: 14.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    unselectedLabelStyle: FlutterFlowTheme.of(context).titleMedium,
                                    indicatorColor: FlutterFlowTheme.of(context).primary,
                                    tabs: const [
                                      Tab(text: 'Media'),
                                      Tab(text: 'Docs'),
                                      Tab(text: 'Links'),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  // Group Image
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 120.0,
                                  height: 120.0,
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
                                if (currentChatDoc?.admin == currentUserReference ||
                                    currentChatDoc?.createdBy == currentUserReference)
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: InkWell(
                                      onTap: () async {
                                        // Show popup menu next to the icon
                                        final RenderBox button = context.findRenderObject() as RenderBox;
                                        final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
                                        final RelativeRect position = RelativeRect.fromRect(
                                          Rect.fromPoints(
                                            button.localToGlobal(Offset.zero, ancestor: overlay),
                                            button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
                                          ),
                                          Offset.zero & overlay.size,
                                        );

                                        final result = await showMenu<String>(
                                          context: context,
                                          position: position,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8.0),
                                          ),
                                          color: Colors.white,
                                          elevation: 8,
                                          items: [
                                            PopupMenuItem<String>(
                                              value: 'view',
                                              height: 40,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.visibility,
                                                    size: 18.0,
                                                    color: Color(0xFF3B82F6),
                                                  ),
                                                  SizedBox(width: 8.0),
                                                  Text(
                                                    'View',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 14.0,
                                                      color: Color(0xFF1A1F36),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'edit',
                                              height: 40,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.edit,
                                                    size: 18.0,
                                                    color: Color(0xFF3B82F6),
                                                  ),
                                                  SizedBox(width: 8.0),
                                                  Text(
                                                    'Edit',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 14.0,
                                                      color: Color(0xFF1A1F36),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );

                                        if (result == 'view') {
                                          // View full image
                                          await Navigator.push(
                                            context,
                                            PageTransition(
                                              type: PageTransitionType.fade,
                                              child: FlutterFlowExpandedImageView(
                                                image: Image.network(
                                                  currentChatDoc?.chatImageUrl ?? '',
                                                  fit: BoxFit.contain,
                                                ),
                                                allowRotation: false,
                                                tag: 'groupImage',
                                                useHeroAnimation: true,
                                              ),
                                            ),
                                          );
                                        } else if (result == 'edit') {
                                          // Edit image - open gallery directly
                                          await _editGroupImage();
                                        }
                                      },
                                      child: Container(
                                        width: 36.0,
                                        height: 36.0,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 18.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16.0),
                            
                            // Group Name
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _model.isEditingName
                                      ? TextField(
                                          controller: _model.groupNameController,
                                          textAlign: TextAlign.center,
                                          autofocus: true,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 24.0,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1F36),
                                          ),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                            isDense: true,
                                          ),
                                          onSubmitted: (_) => _saveGroupName(),
                                          onEditingComplete: _saveGroupName,
                                        )
                                      : Text(
                                          valueOrDefault<String>(
                                            currentChatDoc?.title,
                                            'Group Name',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 24.0,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1F36),
                                          ),
                                        ),
                                ),
                                if (currentChatDoc?.admin == currentUserReference ||
                                    currentChatDoc?.createdBy == currentUserReference)
                                  InkWell(
                                    onTap: () async {
                                      if (_model.isEditingName) {
                                        await _saveGroupName();
                                      } else {
                                        _model.isEditingName = true;
                                        safeSetState(() {});
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        _model.isEditingName ? Icons.check : Icons.edit,
                                        color: const Color(0xFF3B82F6),
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            
                            const SizedBox(height: 8.0),
                            
                            // Group Description
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _model.isEditingDescription
                                      ? TextField(
                                          controller: _model.groupDescriptionController,
                                          textAlign: TextAlign.center,
                                          autofocus: true,
                                          maxLines: 3,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF6B7280),
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Add group description',
                                            hintStyle: TextStyle(
                                              color: Color(0xFF9CA3AF),
                                            ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                            isDense: true,
                                          ),
                                          onSubmitted: (_) => _saveGroupDescription(),
                                          onEditingComplete: _saveGroupDescription,
                                        )
                                      : Text(
                                          valueOrDefault<String>(
                                            (currentChatDoc?.description == 'Internal Group' || 
                                             currentChatDoc?.description == 'Public Group') 
                                                ? 'Add group description' 
                                                : currentChatDoc?.description,
                                            'Add group description',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w400,
                                            color: (currentChatDoc?.description == 'Internal Group' || 
                                                   currentChatDoc?.description == 'Public Group' ||
                                                   currentChatDoc?.description?.isEmpty == true) 
                                                ? const Color(0xFF9CA3AF)
                                                : const Color(0xFF6B7280),
                                          ),
                                        ),
                                ),
                                if (currentChatDoc?.admin == currentUserReference ||
                                    currentChatDoc?.createdBy == currentUserReference)
                                  InkWell(
                                    onTap: () async {
                                      if (_model.isEditingDescription) {
                                        await _saveGroupDescription();
                                      } else {
                                        _model.isEditingDescription = true;
                                        safeSetState(() {});
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        _model.isEditingDescription ? Icons.check : Icons.edit,
                                        color: const Color(0xFF3B82F6),
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            
                            const SizedBox(height: 12.0),
                            
                            // Member count
                            Text(
                              'Group · ${valueOrDefault<String>(
                                currentChatDoc?.members.length.toString(),
                                '0',
                              )} members',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.0,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Scrollable Content
                    Expanded(
                      child: _model.showMediaLinksDocs
                          ? _buildMediaLinksDocsView()
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                        InkWell(
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          hoverColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          onTap: () async {
                                            _model.showMediaLinksDocs = true;
                                            safeSetState(() {});
                                          },
                                          child: Row(
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
                                              Icon(
                                                Icons.chevron_right,
                                                color: FlutterFlowTheme.of(
                                                        context)
                                                    .secondaryText,
                                                size: 20.0,
                                              ),
                                            ],
                                          ),
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
                                                        // Collect all images from both 'image' field and 'images' list
                                                        final allImages = <String>[];
                                                        for (final msg in _model.message) {
                                                          if (msg.image != '') {
                                                            allImages.add(msg.image);
                                                          }
                                                          if (msg.images.isNotEmpty) {
                                                            allImages.addAll(msg.images);
                                                          }
                                                        }
                                                        final image = allImages.take(4).toList();

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
                                                      .where((e) => 
                                                          e.messageType == MessageType.image ||
                                                          e.image != '' ||
                                                          e.images.isNotEmpty)
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
                                                              images: () {
                                                                // Collect all images from both 'image' field and 'images' list
                                                                final allImages = <String>[];
                                                                for (final msg in _model.message) {
                                                                  if (msg.image != '') {
                                                                    allImages.add(msg.image);
                                                                  }
                                                                  if (msg.images.isNotEmpty) {
                                                                    allImages.addAll(msg.images);
                                                                  }
                                                                }
                                                                return allImages;
                                                              }(),
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
                                    // Action Tasks Section - Inline
                                    StreamBuilder<List<ActionItemsRecord>>(
                                      stream: queryActionItemsRecord(
                                        queryBuilder: (actionItemsRecord) => actionItemsRecord
                                            .where('chat_ref', isEqualTo: widget.chatDoc!.reference)
                                            .orderBy('created_time', descending: true)
                                            .limit(10),
                                      ),
                                      builder: (context, snapshot) {
                                        final actionItems = snapshot.data ?? [];
                                        final taskCount = actionItems.length;
                                        
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              splashColor: Colors.transparent,
                                              focusColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              highlightColor: Colors.transparent,
                                              onTap: () async {
                                                await Navigator.push(
                                                  context,
                                                  PageRouteBuilder(
                                                    opaque: false,
                                                    barrierColor: Colors.transparent,
                                                    pageBuilder: (context, animation, secondaryAnimation) => 
                                                      GroupActionTasksWidget(
                                                        chatDoc: widget.chatDoc,
                                                      ),
                                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                      const begin = Offset(1.0, 0.0);
                                                      const end = Offset.zero;
                                                      const curve = Curves.easeInOut;
                                                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                                      var offsetAnimation = animation.drive(tween);
                                                      return SlideTransition(position: offsetAnimation, child: child);
                                                    },
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(12.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(12.0),
                                                  border: Border.all(
                                                    color: const Color(0xFFE5E7EB),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(8.0),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(8.0),
                                                          ),
                                                          child: const Icon(
                                                            Icons.task_alt_outlined,
                                                            size: 20,
                                                            color: Color(0xFF3B82F6),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              'Action Tasks',
                                                              style: const TextStyle(
                                                                fontFamily: 'Inter',
                                                                color: Color(0xFF1A1F36),
                                                                fontSize: 14.0,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                            Text(
                                                              '$taskCount ${taskCount == 1 ? 'task' : 'tasks'}',
                                                              style: const TextStyle(
                                                                fontFamily: 'Inter',
                                                                color: Color(0xFF6B7280),
                                                                fontSize: 12.0,
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
                                        );
                                      },
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
                                                        await _showAddMembersDialog();
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
                                                                            if (currentChatDoc?.admin == currentUserReference || 
                                                                                currentChatDoc?.createdBy == currentUserReference)
                                                                              PopupMenuButton<String>(
                                                                                icon: const Icon(
                                                                                  Icons.more_vert,
                                                                                  color: Color(0xFF6B7280),
                                                                                  size: 16.0,
                                                                                ),
                                                                                color: Colors.white,
                                                                                elevation: 8,
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.circular(8.0),
                                                                                ),
                                                                                itemBuilder: (context) => [
                                                                                  if (rowUsersRecord.reference != currentUserReference &&
                                                                                      rowUsersRecord.reference != currentChatDoc?.admin &&
                                                                                      rowUsersRecord.reference != currentChatDoc?.createdBy)
                                                                                    PopupMenuItem<String>(
                                                                                      value: 'make_admin',
                                                                                      child: Row(
                                                                                        children: [
                                                                                          Container(
                                                                                            padding: const EdgeInsets.all(6.0),
                                                                                            decoration: BoxDecoration(
                                                                                              color: const Color(0xFFEBF4FF),
                                                                                              borderRadius: BorderRadius.circular(6.0),
                                                                                            ),
                                                                                            child: const Icon(
                                                                                              Icons.admin_panel_settings,
                                                                                              color: Color(0xFF3B82F6),
                                                                                              size: 16.0,
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(width: 12.0),
                                                                                          const Text(
                                                                                            'Make Admin',
                                                                                            style: TextStyle(
                                                                                              fontFamily: 'Inter',
                                                                                              fontSize: 14.0,
                                                                                              fontWeight: FontWeight.w500,
                                                                                              color: Color(0xFF1A1F36),
                                                                                            ),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    ),
                                                                                  if (rowUsersRecord.reference != currentUserReference &&
                                                                                      rowUsersRecord.reference != currentChatDoc?.createdBy)
                                                                                    PopupMenuItem<String>(
                                                                                      value: 'remove_user',
                                                                                      child: Row(
                                                                                        children: [
                                                                                          Container(
                                                                                            padding: const EdgeInsets.all(6.0),
                                                                                            decoration: BoxDecoration(
                                                                                              color: const Color(0xFFFEF2F2),
                                                                                              borderRadius: BorderRadius.circular(6.0),
                                                                                            ),
                                                                                            child: const Icon(
                                                                                              Icons.person_remove,
                                                                                              color: Color(0xFFEF4444),
                                                                                              size: 16.0,
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(width: 12.0),
                                                                                          const Text(
                                                                                            'Remove User',
                                                                                            style: TextStyle(
                                                                                              fontFamily: 'Inter',
                                                                                              fontSize: 14.0,
                                                                                              fontWeight: FontWeight.w500,
                                                                                              color: Color(0xFF1A1F36),
                                                                                            ),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    ),
                                                                                ],
                                                                                onSelected: (value) async {
                                                                                  if (value == 'make_admin') {
                                                                                    await _makeUserAdmin(rowUsersRecord);
                                                                                  } else if (value == 'remove_user') {
                                                                                    await _removeUser(rowUsersRecord);
                                                                                  }
                                                                                },
                                                                              )
                                                                            else
                                                                              const SizedBox(width: 16.0),
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
                    ),
                  ],
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
              );
            },
          ),
        ),
      ),
    );
  }
}