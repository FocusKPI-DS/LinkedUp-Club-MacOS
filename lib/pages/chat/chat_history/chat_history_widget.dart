import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'chat_history_model.dart';
export 'chat_history_model.dart';

class ChatHistoryWidget extends StatefulWidget {
  const ChatHistoryWidget({
    super.key,
    required this.chatDoc,
    this.showAppBar = true,
  });

  final ChatsRecord chatDoc;
  final bool showAppBar;

  static String routeName = 'ChatHistory';
  static String routePath = '/chatHistory';

  @override
  State<ChatHistoryWidget> createState() => _ChatHistoryWidgetState();
}

class _ChatHistoryWidgetState extends State<ChatHistoryWidget> {
  late ChatHistoryModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatHistoryModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();
    _model.textController?.addListener(() => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  List<MessagesRecord> _filterMessages(List<MessagesRecord> messages) {
    final query = _model.textController?.text.toLowerCase() ?? '';
    final filter = _model.selectedFilter;

    return messages.where((m) {
      // 1. Filter by Type
      bool typeMatch = true;
      if (filter == 'Image') {
        typeMatch = m.messageType == MessageType.image;
      } else if (filter == 'Video') {
        typeMatch = m.messageType == MessageType.video;
      } else if (filter == 'File') {
         // Assuming MessageType.file exists, or check attachmentUrl
        typeMatch = m.messageType == MessageType.file || (m.attachmentUrl != null && m.attachmentUrl!.isNotEmpty && m.messageType != MessageType.image && m.messageType != MessageType.video);
      } else if (filter == 'Link') {
        typeMatch = m.content.contains('http');
      } else if (filter == 'Pinned') {
        typeMatch = m.isPinned == true;
      }

      if (!typeMatch) return false;

      // 2. Filter by Text (if search query exists)
      if (query.isNotEmpty) {
        if (m.messageType == MessageType.text) {
          return m.content.toLowerCase().contains(query);
        } else if (filter == 'File' && m.attachmentUrl != null) {
             // Basic check if filename might be in content or just allow all files if query is present?
             // Let's search content as it might contain filename
             return m.content.toLowerCase().contains(query);
        }
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _model.unfocusNode.canRequestFocus
          ? FocusScope.of(context).requestFocus(_model.unfocusNode)
          : FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: widget.showAppBar
            ? AppBar(
                backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
                automaticallyImplyLeading: false,
                leading: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 30.0,
                  borderWidth: 1.0,
                  buttonSize: 60.0,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 30.0,
                  ),
                  onPressed: () async {
                    context.pop();
                  },
                ),
                title: Text(
                  'Chat History',
                  style: FlutterFlowTheme.of(context).headlineMedium.override(
                        fontFamily: 'Inter',
                        color: FlutterFlowTheme.of(context).primaryText,
                        fontSize: 22.0,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                elevation: 0.0,
              )
            : null,
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Search Bar Area
              Container(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 12.0),
                child: TextFormField(
                  controller: _model.textController,
                  focusNode: _model.textFieldFocusNode,
                  autofocus: false,
                  obscureText: false,
                  decoration: InputDecoration(
                    hintText: 'Search message content...',
                    hintStyle: FlutterFlowTheme.of(context).labelMedium,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: FlutterFlowTheme.of(context).alternate,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: FlutterFlowTheme.of(context).primary,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    filled: true,
                    fillColor: FlutterFlowTheme.of(context).primaryBackground,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                    suffixIcon: _model.textController!.text.isNotEmpty
                        ? InkWell(
                            onTap: () async {
                              _model.textController?.clear();
                              safeSetState(() {});
                            },
                            child: Icon(
                              Icons.clear,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              size: 20,
                            ),
                          )
                        : null,
                  ),
                  style: FlutterFlowTheme.of(context).bodyMedium,
                  cursorColor: FlutterFlowTheme.of(context).primary,
                ),
              ),
              
              // Filter Tabs
              Container(
                 color: FlutterFlowTheme.of(context).secondaryBackground,
                 width: double.infinity,
                 padding: EdgeInsets.only(bottom: 12),
                 child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      SizedBox(width: 8),
                      _buildFilterChip('Image'),
                      SizedBox(width: 8),
                      _buildFilterChip('Video'),
                      SizedBox(width: 8),
                      _buildFilterChip('File'),
                      SizedBox(width: 8),
                      _buildFilterChip('Link'),
                      SizedBox(width: 8),
                      _buildFilterChip('Pinned'),
                    ],
                  ),
                ),
              ),

              // Results List
              Expanded(
                child: StreamBuilder<List<MessagesRecord>>(
                  stream: queryMessagesRecord(
                    parent: widget.chatDoc.reference,
                    queryBuilder: (messagesRecord) => messagesRecord
                        .orderBy('created_at', descending: true),
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: SizedBox(
                          width: 50.0,
                          height: 50.0,
                          child: CircularProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      );
                    }
                    
                    final allMessages = snapshot.data!;
                    final filteredMessages = _filterMessages(allMessages);
                    
                    if (filteredMessages.isEmpty) {
                       return Center(
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Icon(Icons.search_off_rounded, size: 64, color: FlutterFlowTheme.of(context).secondaryText),
                             SizedBox(height: 12),
                             Text(
                               'No results found',
                               style: FlutterFlowTheme.of(context).bodyMedium.override(
                                 fontFamily: 'Inter',
                                 color: FlutterFlowTheme.of(context).secondaryText,
                               ),
                             ),
                           ],
                         ),
                       );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      itemCount: filteredMessages.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: FlutterFlowTheme.of(context).alternate.withOpacity(0.5)),
                      itemBuilder: (context, index) {
                         final message = filteredMessages[index];
                         return _buildMessageItem(message);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _model.selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _model.selectedFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? FlutterFlowTheme.of(context).primary.withOpacity(0.1) 
              : FlutterFlowTheme.of(context).primaryBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? FlutterFlowTheme.of(context).primary 
                : FlutterFlowTheme.of(context).alternate,
          ),
        ),
        child: Text(
          label,
          style: FlutterFlowTheme.of(context).bodyMedium.override(
            fontFamily: 'Inter',
            color: isSelected 
                ? FlutterFlowTheme.of(context).primary 
                : FlutterFlowTheme.of(context).secondaryText,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(MessagesRecord message) {
    return InkWell(
      onTap: () {
        context.pop(message.reference.id);
      },
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
               width: 40,
               height: 40,
               clipBehavior: Clip.antiAlias,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 border: Border.all(color: FlutterFlowTheme.of(context).alternate, width: 1),
               ),
               child: StreamBuilder<UsersRecord>(
                 stream: UsersRecord.getDocument(message.senderRef!),
                 builder: (context, snapshot) {
                   if (!snapshot.hasData) return Container(color: FlutterFlowTheme.of(context).alternate);
                   return CachedNetworkImage(
                     imageUrl: snapshot.data!.photoUrl,
                     fit: BoxFit.cover,
                     placeholder: (context, url) => Container(color: FlutterFlowTheme.of(context).alternate),
                     errorWidget: (context, url, error) => Icon(Icons.person),
                   );
                 },
               ),
            ),
            SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Time
                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<UsersRecord>(
                           stream: UsersRecord.getDocument(message.senderRef!),
                           builder: (context, snapshot) {
                             if (!snapshot.hasData) return Text('...');
                             return Text(
                               snapshot.data!.displayName,
                               style: FlutterFlowTheme.of(context).bodyMedium.override(
                                 fontFamily: 'Inter',
                                 color: FlutterFlowTheme.of(context).secondaryText,
                                 fontSize: 13,
                               ),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                              );
                           },
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        dateTimeFormat('relative', message.createdAt),
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                          fontFamily: 'Inter',
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  
                  // Message Content
                  if (message.messageType == MessageType.text)
                    _buildHighlightedText(message.content)
                  else if (message.messageType == MessageType.image)
                    Builder(
                      builder: (context) {
                        String imageUrl = message.image;
                        if ((imageUrl == null || imageUrl.isEmpty) && 
                            message.images != null && 
                            message.images.isNotEmpty) {
                          imageUrl = message.images.first;
                        }
                        return Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                PageTransition(
                                  type: PageTransitionType.fade,
                                  child: FlutterFlowExpandedImageView(
                                    image: CachedNetworkImage(
                                      fadeInDuration: const Duration(milliseconds: 300),
                                      fadeOutDuration: const Duration(milliseconds: 300),
                                      imageUrl: valueOrDefault<String>(
                                        imageUrl,
                                        message.attachmentUrl ?? '',
                                      ),
                                      fit: BoxFit.contain,
                                    ),
                                    allowRotation: false,
                                    tag: valueOrDefault<String>(
                                      imageUrl,
                                      message.attachmentUrl ?? 'image_${message.reference.id}',
                                    ),
                                    useHeroAnimation: true,
                                    imageUrl: valueOrDefault<String>(
                                      imageUrl,
                                      message.attachmentUrl ?? '',
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Hero(
                              tag: valueOrDefault<String>(
                                imageUrl,
                                message.attachmentUrl ?? 'image_${message.reference.id}',
                              ),
                              transitionOnUserGestures: true,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: valueOrDefault<String>(
                                    imageUrl,
                                    message.attachmentUrl ?? '',
                                  ),
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Container(
                                    width: 120,
                                    height: 120,
                                    color: FlutterFlowTheme.of(context).alternate,
                                    child: Icon(Icons.broken_image, 
                                      color: FlutterFlowTheme.of(context).secondaryText),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    )
                  else if (message.messageType == MessageType.video)
                    Row(
                      children: [
                        Icon(Icons.videocam_rounded, size: 20, color: FlutterFlowTheme.of(context).primary),
                        SizedBox(width: 6),
                        Text('Video Message', style: FlutterFlowTheme.of(context).bodyMedium),
                      ],
                    )
                  else if (message.messageType == MessageType.file)
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).alternate.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insert_drive_file_rounded, size: 20, color: FlutterFlowTheme.of(context).primaryText),
                          SizedBox(width: 6),
                          Text('File: ${message.content}', style: FlutterFlowTheme.of(context).bodyMedium),
                        ],
                      ),
                    )
                  else if (message.content.contains('http'))
                     // Link handling could be better but this is a start
                     Text(
                       message.content,
                       style: FlutterFlowTheme.of(context).bodyMedium.override(
                         fontFamily: 'Inter',
                         color: Colors.blue,
                         decoration: TextDecoration.underline,
                       ),
                     )
                  else
                     Text(message.content),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text) {
    final query = _model.textController?.text.toLowerCase() ?? '';
    if (query.isEmpty) {
      return Text(
        text,
        style: FlutterFlowTheme.of(context).bodyMedium,
      );
    }

    // Highlighting logic
    final lowerText = text.toLowerCase();
    final int startIndex = lowerText.indexOf(query);
    if (startIndex == -1) {
       return Text(text, style: FlutterFlowTheme.of(context).bodyMedium);
    }
    
    final int endIndex = startIndex + query.length;
    
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, startIndex),
            style: FlutterFlowTheme.of(context).bodyMedium,
          ),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: GoogleFonts.inter(
              textStyle: FlutterFlowTheme.of(context).bodyMedium,
              backgroundColor: Colors.yellow.withOpacity(0.3),
              color: FlutterFlowTheme.of(context).primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: text.substring(endIndex),
            style: FlutterFlowTheme.of(context).bodyMedium,
          ),
        ],
      ),
    );
  }
}
