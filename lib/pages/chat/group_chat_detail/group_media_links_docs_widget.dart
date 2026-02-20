import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:page_transition/page_transition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'group_media_links_docs_model.dart';
export 'group_media_links_docs_model.dart';

class GroupMediaLinksDocsWidget extends StatefulWidget {
  const GroupMediaLinksDocsWidget({
    super.key,
    required this.chatDoc,
  });

  final ChatsRecord? chatDoc;

  static String routeName = 'GroupMediaLinksDocs';
  static String routePath = '/groupMediaLinksDocs';

  @override
  State<GroupMediaLinksDocsWidget> createState() =>
      _GroupMediaLinksDocsWidgetState();
}

class _GroupMediaLinksDocsWidgetState
    extends State<GroupMediaLinksDocsWidget> with TickerProviderStateMixin {
  late GroupMediaLinksDocsModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupMediaLinksDocsModel());
    _tabController = TabController(length: 3, vsync: this);

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.messages = await queryMessagesRecordOnce(
        parent: widget.chatDoc?.reference,
      );
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Extract images from messages
  List<String> _getImages() {
    final messages = _model.messages;
    if (messages == null) return [];
    final allImages = <String>[];
    for (final msg in messages) {
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
          // Avoid duplicates
          if (!links.any((link) => link['url'] == url)) {
            links.add({
              'url': url,
              'preview': msg.content.length > 100
                  ? '${msg.content.substring(0, 100)}...'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: FlutterFlowTheme.of(context).primaryText,
            size: 24.0,
          ),
          onPressed: () async {
            context.pop();
          },
        ),
        title: Text(
          'Media, Links, and Docs',
          style: FlutterFlowTheme.of(context).headlineSmall.override(
                fontFamily: 'Inter',
                fontSize: 20.0,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: const [],
        centerTitle: false,
        elevation: 0.0,
        bottom: TabBar(
          controller: _tabController,
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
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMediaTab(),
          _buildDocsTab(),
          _buildLinksTab(),
        ],
      ),
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
                  imageUrl: imageUrl,
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
}

