import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_expanded_image_view.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:page_transition/page_transition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'mobile_group_media_model.dart';
export 'mobile_group_media_model.dart';

class MobileGroupMediaWidget extends StatefulWidget {
  const MobileGroupMediaWidget({
    super.key,
    required this.chatDoc,
  });

  final ChatsRecord? chatDoc;

  static String routeName = 'MobileGroupMedia';
  static String routePath = '/mobileGroupMedia';

  @override
  State<MobileGroupMediaWidget> createState() =>
      _MobileGroupMediaWidgetState();
}

class _MobileGroupMediaWidgetState
    extends State<MobileGroupMediaWidget> with TickerProviderStateMixin {
  late MobileGroupMediaModel _model;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MobileGroupMediaModel());
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

  @override
  Widget build(BuildContext context) {
    // Use iOS 26 adaptive components when available
    if (PlatformInfo.isIOS26OrHigher()) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Custom header with back button matching mobile chat page
              Container(
                height: 44, // Native iOS toolbar height
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Floating back button on the left - iOS 26+ style with liquid glass effects
                    LiquidStretch(
                      stretch: 0.5,
                      interactionScale: 1.05,
                      child: GlassGlow(
                        glowColor: Colors.white24,
                        glowRadius: 1.0,
                        child: AdaptiveFloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.white, // Pure white background
                          foregroundColor: const Color(0xFF007AFF), // System blue icon
                          onPressed: () => context.pop(),
                          child: const Icon(
                            CupertinoIcons.chevron_left,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Centered title in pill shape - native iOS 26 style
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white, // Pure white like back button
                            borderRadius: BorderRadius.circular(16), // Pill shape
                          ),
                          child: const Text(
                            'Media',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 56), // Balance the back button width
                  ],
                ),
              ),
              // Tab bar
              Material(
                color: CupertinoColors.systemBackground,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: CupertinoColors.activeBlue,
                    unselectedLabelColor: CupertinoColors.secondaryLabel,
                    indicatorColor: CupertinoColors.activeBlue,
                    indicatorWeight: 2.0,
                    labelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    tabs: const [
                      Tab(text: 'Images'),
                      Tab(text: 'Docs'),
                      Tab(text: 'Links'),
                    ],
                  ),
                ),
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildImagesTab(),
                    _buildDocsTab(),
                    _buildLinksTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Fallback for older iOS versions
      return Scaffold(
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
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
            'Media',
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
              Tab(text: 'Images'),
              Tab(text: 'Docs'),
              Tab(text: 'Links'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildImagesTab(),
            _buildDocsTab(),
            _buildLinksTab(),
          ],
        ),
      );
    }
  }

  Widget _buildImagesTab() {
    final images = _getImages();

    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PlatformInfo.isIOS26OrHigher()
                  ? CupertinoIcons.photo_on_rectangle
                  : Icons.image_outlined,
              size: 64.0,
              color: PlatformInfo.isIOS26OrHigher()
                  ? CupertinoColors.secondaryLabel
                  : FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 16.0),
            Text(
              'No images',
              style: PlatformInfo.isIOS26OrHigher()
                  ? TextStyle(
                      fontSize: 17,
                      color: CupertinoColors.secondaryLabel,
                    )
                  : FlutterFlowTheme.of(context).titleMedium.override(
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
      padding: const EdgeInsets.all(4.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.0,
        mainAxisSpacing: 2.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final imageUrl = images[index];
        final tapHandler = () async {
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
        };
        
        final imageWidget = Hero(
          tag: imageUrl,
          transitionOnUserGestures: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(0.0),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        );
        
        if (PlatformInfo.isIOS26OrHigher()) {
          return GestureDetector(
            onTap: tapHandler,
            child: imageWidget,
          );
        } else {
          return InkWell(
            onTap: tapHandler,
            child: imageWidget,
          );
        }
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
              PlatformInfo.isIOS26OrHigher()
                  ? CupertinoIcons.doc_on_doc
                  : Icons.insert_drive_file_outlined,
              size: 64.0,
              color: PlatformInfo.isIOS26OrHigher()
                  ? CupertinoColors.secondaryLabel
                  : FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 16.0),
            Text(
              'No documents',
              style: PlatformInfo.isIOS26OrHigher()
                  ? TextStyle(
                      fontSize: 17,
                      color: CupertinoColors.secondaryLabel,
                    )
                  : FlutterFlowTheme.of(context).titleMedium.override(
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final fileName = doc['fileName'] as String;
        final url = doc['url'] as String;
        final sender = doc['sender'] as String?;
        final isPdf = fileName.toLowerCase().endsWith('.pdf');

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: PlatformInfo.isIOS26OrHigher()
                ? CupertinoColors.secondarySystemBackground
                : FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: _buildTapableWidget(
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 40.0,
                    height: 40.0,
                    decoration: BoxDecoration(
                      color: PlatformInfo.isIOS26OrHigher()
                          ? CupertinoColors.tertiarySystemFill
                          : FlutterFlowTheme.of(context).alternate,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Icon(
                      isPdf
                          ? (PlatformInfo.isIOS26OrHigher()
                              ? CupertinoIcons.doc_text_fill
                              : Icons.picture_as_pdf)
                          : (PlatformInfo.isIOS26OrHigher()
                              ? CupertinoIcons.doc_fill
                              : Icons.insert_drive_file),
                      color: PlatformInfo.isIOS26OrHigher()
                          ? CupertinoColors.activeBlue
                          : FlutterFlowTheme.of(context).primary,
                      size: 20.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: PlatformInfo.isIOS26OrHigher()
                              ? const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  color: CupertinoColors.label,
                                )
                              : FlutterFlowTheme.of(context).bodyMedium.override(
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
                            style: PlatformInfo.isIOS26OrHigher()
                                ? const TextStyle(
                                    fontSize: 15,
                                    color: CupertinoColors.secondaryLabel,
                                  )
                                : FlutterFlowTheme.of(context).bodySmall.override(
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
                    PlatformInfo.isIOS26OrHigher()
                        ? CupertinoIcons.chevron_right
                        : Icons.chevron_right,
                    size: 16,
                    color: PlatformInfo.isIOS26OrHigher()
                        ? CupertinoColors.tertiaryLabel
                        : FlutterFlowTheme.of(context).secondaryText,
                  ),
                ],
              ),
            ),
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
              PlatformInfo.isIOS26OrHigher()
                  ? CupertinoIcons.link
                  : Icons.link_outlined,
              size: 64.0,
              color: PlatformInfo.isIOS26OrHigher()
                  ? CupertinoColors.secondaryLabel
                  : FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 16.0),
            Text(
              'No links',
              style: PlatformInfo.isIOS26OrHigher()
                  ? TextStyle(
                      fontSize: 17,
                      color: CupertinoColors.secondaryLabel,
                    )
                  : FlutterFlowTheme.of(context).titleMedium.override(
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: links.length,
      itemBuilder: (context, index) {
        final link = links[index];
        final url = link['url'] as String;
        final preview = link['preview'] as String?;
        final sender = link['sender'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: PlatformInfo.isIOS26OrHigher()
                ? CupertinoColors.secondarySystemBackground
                : FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: _buildTapableWidget(
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 40.0,
                    height: 40.0,
                    decoration: BoxDecoration(
                      color: PlatformInfo.isIOS26OrHigher()
                          ? CupertinoColors.tertiarySystemFill
                          : FlutterFlowTheme.of(context).alternate,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Icon(
                      PlatformInfo.isIOS26OrHigher()
                          ? CupertinoIcons.link
                          : Icons.link,
                      color: PlatformInfo.isIOS26OrHigher()
                          ? CupertinoColors.activeBlue
                          : FlutterFlowTheme.of(context).primary,
                      size: 20.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          url,
                          style: PlatformInfo.isIOS26OrHigher()
                              ? const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  color: CupertinoColors.activeBlue,
                                )
                              : FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600,
                                    color: FlutterFlowTheme.of(context).primary,
                                    letterSpacing: 0.0,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((preview != null && preview.isNotEmpty) || sender != null) ...[
                          const SizedBox(height: 4.0),
                          if (preview != null && preview.isNotEmpty)
                            Text(
                              preview,
                              style: PlatformInfo.isIOS26OrHigher()
                                  ? const TextStyle(
                                      fontSize: 15,
                                      color: CupertinoColors.secondaryLabel,
                                    )
                                  : FlutterFlowTheme.of(context).bodySmall.override(
                                        fontFamily: 'Inter',
                                        fontSize: 12.0,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        letterSpacing: 0.0,
                                      ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (sender != null)
                            Text(
                              sender,
                              style: PlatformInfo.isIOS26OrHigher()
                                  ? const TextStyle(
                                      fontSize: 15,
                                      color: CupertinoColors.secondaryLabel,
                                    )
                                  : FlutterFlowTheme.of(context).bodySmall.override(
                                        fontFamily: 'Inter',
                                        fontSize: 12.0,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        letterSpacing: 0.0,
                                      ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    PlatformInfo.isIOS26OrHigher()
                        ? CupertinoIcons.chevron_right
                        : Icons.chevron_right,
                    size: 16,
                    color: PlatformInfo.isIOS26OrHigher()
                        ? CupertinoColors.tertiaryLabel
                        : FlutterFlowTheme.of(context).secondaryText,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to build tapable widget based on iOS version
  Widget _buildTapableWidget({
    required VoidCallback onTap,
    required Widget child,
  }) {
    if (PlatformInfo.isIOS26OrHigher()) {
      return GestureDetector(
        onTap: onTap,
        child: child,
      );
    } else {
      return InkWell(
        onTap: onTap,
        child: child,
      );
    }
  }
}

