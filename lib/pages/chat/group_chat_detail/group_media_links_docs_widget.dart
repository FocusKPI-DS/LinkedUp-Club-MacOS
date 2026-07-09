import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
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

enum _EmbeddedFilesFilter { all, media, files, links }

class GroupMediaLinksDocsWidget extends StatefulWidget {
  const GroupMediaLinksDocsWidget({
    super.key,
    required this.chatDoc,
    this.embedded = false,
  });

  final ChatsRecord? chatDoc;
  final bool embedded;

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
  _EmbeddedFilesFilter _embeddedFilter = _EmbeddedFilesFilter.all;
  bool _loadingMessages = true;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupMediaLinksDocsModel());
    _tabController = TabController(
      length: 3,
      vsync: this,
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  @override
  void didUpdateWidget(covariant GroupMediaLinksDocsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatDoc?.reference.path != widget.chatDoc?.reference.path) {
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    final chatRef = widget.chatDoc?.reference;
    if (chatRef == null) {
      if (!mounted) return;
      setState(() {
        _model.messages = [];
        _loadingMessages = false;
      });
      return;
    }

    if (mounted) {
      setState(() => _loadingMessages = true);
    }

    try {
      final messages = await fsQueryChatMessages(chatRef, limit: 500);
      if (!mounted) return;
      _model.messages = messages;
    } catch (_) {
      if (!mounted) return;
      _model.messages = [];
    } finally {
      if (mounted) {
        setState(() => _loadingMessages = false);
      }
    }
  }

  @override
  void dispose() {
    _model.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool _isMediaMessage(MessagesRecord msg) {
    if (msg.image.isNotEmpty || msg.images.isNotEmpty || msg.video.isNotEmpty) {
      return true;
    }
    if (msg.messageType == MessageType.image ||
        msg.messageType == MessageType.video) {
      return true;
    }
    if (msg.attachmentUrl.isEmpty) return false;
    if (msg.messageType == MessageType.voice) return false;
    if (msg.audio.isNotEmpty || msg.audioPath.isNotEmpty) return false;
    final lowerUrl = msg.attachmentUrl.toLowerCase();
    return lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.gif') ||
        lowerUrl.contains('.webp') ||
        lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.webm');
  }

  bool _isFileMessage(MessagesRecord msg) {
    if (msg.attachmentUrl.isEmpty) return false;
    if (_isMediaMessage(msg)) return false;
    if (msg.messageType == MessageType.voice) return false;
    if (msg.audio.isNotEmpty || msg.audioPath.isNotEmpty) return false;
    return true;
  }

  List<String> _getImages() {
    final messages = _model.messages;
    if (messages == null) return [];
    final allImages = <String>[];
    for (final msg in messages) {
      if (!_isMediaMessage(msg)) continue;
      if (msg.image.isNotEmpty) {
        allImages.add(msg.image);
      }
      if (msg.images.isNotEmpty) {
        allImages.addAll(msg.images);
      }
      if (msg.video.isNotEmpty) {
        allImages.add(msg.video);
      }
      if (msg.attachmentUrl.isNotEmpty &&
          !allImages.contains(msg.attachmentUrl)) {
        allImages.add(msg.attachmentUrl);
      }
    }
    return allImages;
  }

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

  List<Map<String, dynamic>> _getDocs() {
    final messages = _model.messages;
    if (messages == null) return [];
    final docs = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (!_isFileMessage(msg)) continue;
      docs.add({
        'url': msg.attachmentUrl,
        'fileName': msg.content.isNotEmpty
            ? msg.content
            : 'file_${msg.reference.id}',
        'sender': msg.senderName.isNotEmpty ? msg.senderName : null,
        'messageType': msg.messageType,
      });
    }
    return docs;
  }

  TabBar _buildTabBar() {
    final selectedTabStyle = FlutterFlowTheme.of(context).titleMedium.override(
          fontFamily: 'Inter',
          fontSize: 14.0,
          letterSpacing: 0.0,
          fontWeight: FontWeight.w600,
        );
    final unselectedTabStyle =
        FlutterFlowTheme.of(context).titleMedium.override(
              fontFamily: 'Inter',
              fontSize: 14.0,
              letterSpacing: 0.0,
              fontWeight: FontWeight.w500,
            );

    return TabBar(
      controller: _tabController,
      labelColor: FlutterFlowTheme.of(context).primary,
      unselectedLabelColor: FlutterFlowTheme.of(context).secondaryText,
      labelStyle: selectedTabStyle,
      unselectedLabelStyle: unselectedTabStyle,
      indicatorColor: FlutterFlowTheme.of(context).primary,
      tabs: const [
        Tab(text: 'Media'),
        Tab(text: 'Docs'),
        Tab(text: 'Links'),
      ],
    );
  }

  Widget _buildEmbeddedFilterChips() {
    const chipLabels = {
      _EmbeddedFilesFilter.all: 'All',
      _EmbeddedFilesFilter.media: 'Media',
      _EmbeddedFilesFilter.files: 'Files',
      _EmbeddedFilesFilter.links: 'Links',
    };

    return Padding(
      padding: _embeddedChipPadding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: _EmbeddedFilesFilter.values.map((filter) {
            final isSelected = _embeddedFilter == filter;
            return InkWell(
              onTap: () {
                if (_embeddedFilter == filter) return;
                setState(() => _embeddedFilter = filter);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  chipLabels[filter]!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF374151),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmbeddedFilterContent() {
    if (_loadingMessages) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    switch (_embeddedFilter) {
      case _EmbeddedFilesFilter.all:
        return _buildAllTab();
      case _EmbeddedFilesFilter.media:
        return _buildMediaTab();
      case _EmbeddedFilesFilter.files:
        return _buildDocsTab(emptyLabel: 'No files');
      case _EmbeddedFilesFilter.links:
        return _buildLinksTab();
    }
  }

  static const int _allMediaPreviewLimit = 10;
  static const int _allFilesPreviewLimit = 10;
  static const int _allLinksPreviewLimit = 10;
  static const EdgeInsets _embeddedChipPadding =
      EdgeInsets.fromLTRB(24, 16, 24, 12);
  static const EdgeInsets _embeddedContentPadding =
      EdgeInsets.fromLTRB(24, 16, 24, 28);

  void _goToEmbeddedFilter(_EmbeddedFilesFilter filter) {
    if (_embeddedFilter == filter) return;
    setState(() => _embeddedFilter = filter);
  }

  Widget _buildSectionHeader(
    String title, {
    bool showSeeMore = false,
    VoidCallback? onSeeMore,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          if (showSeeMore && onSeeMore != null) ...[
            const Spacer(),
            TextButton(
              onPressed: onSeeMore,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See more',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder({
    required IconData icon,
    required String label,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64.0,
            color: FlutterFlowTheme.of(context).secondaryText,
          ),
          const SizedBox(height: 16.0),
          Text(
            label,
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

  Widget _buildMediaGrid(
    List<String> images, {
    bool scrollable = true,
    int crossAxisCount = 3,
    EdgeInsets? padding,
  }) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    final gridPadding = padding ??
        (scrollable ? const EdgeInsets.all(16.0) : EdgeInsets.zero);

    final grid = GridView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: gridPadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) => _buildMediaGridItem(images[index]),
    );

    return grid;
  }

  Widget _buildMediaGridItem(String imageUrl) {
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
  }

  Widget _buildDocListItem(Map<String, dynamic> doc) {
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
  }

  Widget _buildLinkListItem(Map<String, dynamic> link) {
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
  }

  Widget _buildAllTab() {
    final images = _getImages();
    final docs = _getDocs();
    final links = _getLinks();

    if (images.isEmpty && docs.isEmpty && links.isEmpty) {
      return _buildEmptyPlaceholder(
        icon: Icons.folder_open_outlined,
        label: 'No media, files, or links',
      );
    }

    final previewImages = images.take(_allMediaPreviewLimit).toList();
    final previewDocs = docs.take(_allFilesPreviewLimit).toList();
    final previewLinks = links.take(_allLinksPreviewLimit).toList();
    final hasMoreMedia = images.length > _allMediaPreviewLimit;
    final hasMoreFiles = docs.length > _allFilesPreviewLimit;
    final hasMoreLinks = links.length > _allLinksPreviewLimit;

    return SingleChildScrollView(
      padding: _embeddedContentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty) ...[
            _buildSectionHeader(
              'Media',
              showSeeMore: hasMoreMedia,
              onSeeMore: () => _goToEmbeddedFilter(_EmbeddedFilesFilter.media),
            ),
            _buildMediaGrid(
              previewImages,
              scrollable: false,
              crossAxisCount: 5,
            ),
            if (docs.isNotEmpty || links.isNotEmpty) const SizedBox(height: 28),
          ],
          if (docs.isNotEmpty) ...[
            _buildSectionHeader(
              'Files',
              showSeeMore: hasMoreFiles,
              onSeeMore: () => _goToEmbeddedFilter(_EmbeddedFilesFilter.files),
            ),
            ...previewDocs.map(_buildDocListItem),
            if (links.isNotEmpty) const SizedBox(height: 20),
          ],
          if (links.isNotEmpty) ...[
            _buildSectionHeader(
              'Links',
              showSeeMore: hasMoreLinks,
              onSeeMore: () => _goToEmbeddedFilter(_EmbeddedFilesFilter.links),
            ),
            ...previewLinks.map(_buildLinkListItem),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaTab() {
    final images = _getImages();

    if (images.isEmpty) {
      return _buildEmptyPlaceholder(
        icon: Icons.image_outlined,
        label: 'No media',
      );
    }

    return _buildMediaGrid(
      images,
      crossAxisCount: 5,
      padding: widget.embedded ? _embeddedContentPadding : null,
    );
  }

  Widget _buildDocsTab({String emptyLabel = 'No documents'}) {
    final docs = _getDocs();

    if (docs.isEmpty) {
      return _buildEmptyPlaceholder(
        icon: Icons.insert_drive_file_outlined,
        label: emptyLabel,
      );
    }

    return ListView.builder(
      padding: widget.embedded
          ? _embeddedContentPadding
          : const EdgeInsets.all(16.0),
      itemCount: docs.length,
      itemBuilder: (context, index) => _buildDocListItem(docs[index]),
    );
  }

  Widget _buildLinksTab() {
    final links = _getLinks();

    if (links.isEmpty) {
      return _buildEmptyPlaceholder(
        icon: Icons.link_outlined,
        label: 'No links',
      );
    }

    return ListView.builder(
      padding: widget.embedded
          ? _embeddedContentPadding
          : const EdgeInsets.all(16.0),
      itemCount: links.length,
      itemBuilder: (context, index) => _buildLinkListItem(links[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return ColoredBox(
        color: FlutterFlowTheme.of(context).primaryBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEmbeddedFilterChips(),
            Expanded(child: _buildEmbeddedFilterContent()),
          ],
        ),
      );
    }

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
        bottom: _buildTabBar(),
      ),
      body: _loadingMessages
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMediaTab(),
                _buildDocsTab(),
                _buildLinksTab(),
              ],
            ),
    );
  }
}
