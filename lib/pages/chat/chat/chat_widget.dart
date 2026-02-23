import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/component/chat_edit/chat_edit_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:aligned_dialog/aligned_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'chat_model.dart';
export 'chat_model.dart';

/// Chat Interface Overview
class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  static String routeName = 'Chat';
  static String routePath = '/chat';

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> with TickerProviderStateMixin {
  late ChatModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  // Blocked users state (UID based)
  Set<String> _blockedUserIds = {};
  StreamSubscription? _blockedUsersSubscription;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.loading = true;
      safeSetState(() {});
      await Future.delayed(
        const Duration(
          milliseconds: 1000,
        ),
      );
      _model.loading = false;
      safeSetState(() {});
    });

    _model.tabBarController = TabController(
      vsync: this,
      length: 3,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

    animationsMap.addAll({
      'textOnPageLoadAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 1000.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'conditionalBuilderOnPageLoadAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'containerOnPageLoadAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'textOnPageLoadAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 1000.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'conditionalBuilderOnPageLoadAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'textOnPageLoadAnimation3': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 300.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'containerOnPageLoadAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'textOnPageLoadAnimation4': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 300.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'containerOnPageLoadAnimation3': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'textOnPageLoadAnimation5': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 300.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'containerOnPageLoadAnimation4': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
      'textOnPageLoadAnimation6': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 500.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'containerOnPageLoadAnimation5': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: null,
      ),
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      safeSetState(() {});
      // Listen to blocked users for real-time filtering (UID based)
      print('Debug: Initializing blocked user listener in ChatWidget. CurrentUserRef: $currentUserReference');
      _blockedUsersSubscription = BlockedUsersRecord.collection
          .where('blocker_user', isEqualTo: currentUserReference)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          _blockedUserIds = snapshot.docs
              .map((doc) => BlockedUsersRecord.fromSnapshot(doc).blockedUser?.id)
              .whereType<String>()
              .toSet();
          print('Debug: ChatWidget (List) updated blocked IDs to: $_blockedUserIds');
        });
      }, onError: (e) {
        print('Debug: Error in ChatWidget blocked user listener: $e');
      });
    });
  }

  @override
  void dispose() {
    _model.dispose();
    _blockedUsersSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceRef = currentUserDocument?.currentWorkspaceRef;

    // Create streams for regular chats and service chats
    final regularChatsStream = queryChatsRecord(
      queryBuilder: (chatsRecord) {
        var query = chatsRecord.where(
          'members',
          arrayContains: currentUserReference,
        );
        debugPrint('🔍 Querying chats where user is member: ${currentUserReference?.path}');
        return query;
      },
    );

    final serviceChatsStream = queryChatsRecord(
      queryBuilder: (chatsRecord) {
        return chatsRecord.where('is_service_chat', isEqualTo: true);
      },
    );

    // Combine both streams using StreamBuilder with two snapshots
    return StreamBuilder<List<ChatsRecord>>(
      stream: regularChatsStream,
      builder: (context, regularSnapshot) {
        return StreamBuilder<List<ChatsRecord>>(
          stream: serviceChatsStream,
          builder: (context, serviceSnapshot) {
            // Combine both lists
            final List<ChatsRecord> allChats = [];
            if (regularSnapshot.hasData) {
              allChats.addAll(regularSnapshot.data!);
              debugPrint('🔍 Regular chats loaded: ${regularSnapshot.data!.length}');
              // Debug: Find "Lets Gooo" group
              final letsGoGroup = regularSnapshot.data!.where((c) => 
                c.title.toLowerCase().contains('lets go') || 
                c.title.toLowerCase().contains('let\'s go')
              ).toList();
              if (letsGoGroup.isNotEmpty) {
                debugPrint('🔍 FOUND "Lets Gooo" group! Title: "${letsGoGroup.first.title}", isGroup: ${letsGoGroup.first.isGroup}, members: ${letsGoGroup.first.members.length}');
              } else {
                debugPrint('🔍 "Lets Gooo" group NOT found in regular chats query results');
              }
            }
            if (serviceSnapshot.hasData) {
              // Remove duplicates by reference path
              final existingPaths =
                  allChats.map((c) => c.reference.path).toSet();
              for (final chat in serviceSnapshot.data!) {
                if (!existingPaths.contains(chat.reference.path)) {
                  allChats.add(chat);
                }
              }
            }

            // Create a combined snapshot
            final combinedSnapshot = AsyncSnapshot<List<ChatsRecord>>.withData(
              regularSnapshot.connectionState == ConnectionState.waiting ||
                      serviceSnapshot.connectionState == ConnectionState.waiting
                  ? ConnectionState.waiting
                  : ConnectionState.done,
              allChats,
            );

            return _buildChatList(context, combinedSnapshot, workspaceRef);
          },
        );
      },
    );
  }

  Widget _buildChatList(
      BuildContext context,
      AsyncSnapshot<List<ChatsRecord>> snapshot,
      DocumentReference? workspaceRef) {
    // Sort chats client-side by last_message_at (handles null values)
    List<ChatsRecord>? sortedChats;
    if (snapshot.hasData && snapshot.data != null) {
      sortedChats = List.from(snapshot.data!);
      sortedChats.sort((a, b) {
        final aTime = a.lastMessageAt;
        final bTime = b.lastMessageAt;

        // Handle null values - put nulls at the end
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1; // a goes after b
        if (bTime == null) return -1; // b goes after a

        // Both have values, sort descending (newest first)
        return bTime.compareTo(aTime);
      });
    }
    // Show loading state
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: SizedBox(
            width: 50.0,
            height: 50.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                FlutterFlowTheme.of(context).primary,
              ),
            ),
          ),
        ),
      );
    }

    // Show error state
    if (snapshot.hasError) {
      print('Error loading chats: ${snapshot.error}');
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: FlutterFlowTheme.of(context).error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading chats',
                style: FlutterFlowTheme.of(context).titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection',
                style: FlutterFlowTheme.of(context).bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    // Handle no data
    if (!snapshot.hasData || sortedChats == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: SizedBox(
            width: 50.0,
            height: 50.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                FlutterFlowTheme.of(context).primary,
              ),
            ),
          ),
        ),
      );
    }

    // Filter chats by workspace on client-side to handle both workspace_ref and legacy chats
    // Use sortedChats which is already sorted by last_message_at (handles null values)
    List<ChatsRecord> allChats = sortedChats;
    List<ChatsRecord> chatChatsRecordList = allChats.where((chat) {
      // Filter out chats with blocked users (UID based)
      // Check if any member (other than current user) is in the blocked list
      if (chat.members.any((member) =>
          member != currentUserReference && _blockedUserIds.contains(member.id))) {
        return false;
      }

      // Always show service chats regardless of workspace
      if (chat.isServiceChat == true) {
        return true;
      }
      // If workspace_ref is null, show all chats (backward compatibility)
      if (workspaceRef == null) {
        return true;
      }
      // If chat has workspace_ref, only show if it matches
      if (chat.workspaceRef != null) {
        return chat.workspaceRef?.path == workspaceRef.path;
      }
      // Show legacy chats without workspace_ref
      return true;
    }).toList();
    
    // Debug: Log all groups to help diagnose missing groups
    debugPrint('🔍 All chats after filtering: ${chatChatsRecordList.length}');
    final allGroups = chatChatsRecordList.where((e) => e.isGroup == true).toList();
    debugPrint('🔍 All groups found: ${allGroups.length}');
    
    // Specifically search for "Lets Gooo" group
    final letsGoGroups = chatChatsRecordList.where((e) => 
      e.title.toLowerCase().contains('lets go') || 
      e.title.toLowerCase().contains('let\'s go') ||
      e.title.toLowerCase().contains('let\'s gooo') ||
      e.title.toLowerCase().contains('lets gooo')
    ).toList();
    
    if (letsGoGroups.isNotEmpty) {
      debugPrint('🔍 ✅ FOUND "Lets Gooo" group in filtered list!');
      for (var group in letsGoGroups) {
        debugPrint('  - Title: "${group.title}"');
        debugPrint('    isGroup: ${group.isGroup}');
        debugPrint('    isPin: ${group.isPin}');
        debugPrint('    lastMessageAt: ${group.lastMessageAt}');
        debugPrint('    lastMessage: "${group.lastMessage}"');
        debugPrint('    workspaceRef: ${group.workspaceRef?.path}');
        debugPrint('    members count: ${group.members.length}');
      }
    } else {
      debugPrint('🔍 ❌ "Lets Gooo" group NOT found in filtered chat list!');
      debugPrint('   Checking all chats before filtering...');
      final allGroupsBeforeFilter = allChats.where((e) => 
        (e.title.toLowerCase().contains('lets go') || 
         e.title.toLowerCase().contains('let\'s go'))
      ).toList();
      if (allGroupsBeforeFilter.isNotEmpty) {
        debugPrint('   ✅ Found in allChats before filtering!');
        for (var group in allGroupsBeforeFilter) {
          debugPrint('     - "${group.title}" - Filtered out? Checking workspace...');
          debugPrint('       workspaceRef: ${group.workspaceRef?.path}, current workspace: ${workspaceRef?.path}');
        }
      } else {
        debugPrint('   ❌ Not found in allChats either - might not be in query results');
      }
    }
    
    for (var group in allGroups) {
      debugPrint('  - "${group.title}" (isGroup: ${group.isGroup}, isPin: ${group.isPin}, lastMessageAt: ${group.lastMessageAt}, lastMessage: "${group.lastMessage}", workspaceRef: ${group.workspaceRef?.path})');
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF9FAFB),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            context.pushNamed(
              ChatGroupCreationWidget.routeName,
              queryParameters: {
                'isEdit': serializeParam(
                  false,
                  ParamType.bool,
                ),
              }.withoutNulls,
            );
          },
          backgroundColor: FlutterFlowTheme.of(context).primary,
          elevation: 8.0,
          child: FaIcon(
            FontAwesomeIcons.edit,
            color: FlutterFlowTheme.of(context).info,
            size: 20.0,
          ),
        ),
        body: SafeArea(
          top: true,
          child: Align(
            alignment: const AlignmentDirectional(0.0, 1.0),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 650.0,
              ),
              decoration: const BoxDecoration(),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            16.0, 16.0, 16.0, 0.0),
                        child: InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context.pushNamed(
                              SearchChatWidget.routeName,
                              extra: <String, dynamic>{
                                kTransitionInfoKey: const TransitionInfo(
                                  hasTransition: true,
                                  transitionType: PageTransitionType.fade,
                                ),
                              },
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            height: 50.0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: FlutterFlowTheme.of(context).accent2,
                                width: 1.0,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    color: FlutterFlowTheme.of(context).accent2,
                                    size: 20.0,
                                  ),
                                  Text(
                                    'Search',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w500,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .accent2,
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w500,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ].divide(const SizedBox(width: 12.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Align(
                              alignment: const Alignment(0.0, 0),
                              child: TabBar(
                                labelColor:
                                    FlutterFlowTheme.of(context).primary,
                                unselectedLabelColor:
                                    FlutterFlowTheme.of(context).secondaryText,
                                labelStyle: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                unselectedLabelStyle:
                                    FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w500,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w500,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                        ),
                                indicatorColor:
                                    FlutterFlowTheme.of(context).primary,
                                tabs: const [
                                  Tab(
                                    text: 'All Chat',
                                  ),
                                  Tab(
                                    text: 'Contact',
                                  ),
                                  Tab(
                                    text: 'Group',
                                  ),
                                ],
                                controller: _model.tabBarController,
                                onTap: (i) async {
                                  [() async {}, () async {}, () async {}][i]();
                                },
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _model.tabBarController,
                                children: [
                                  KeepAliveWidgetWrapper(
                                    builder: (context) => SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          StickyHeader(
                                            overlapHeaders: false,
                                            header: InkWell(
                                              splashColor: Colors.transparent,
                                              focusColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              highlightColor:
                                                  Colors.transparent,
                                              onTap: () async {
                                                context.pushNamed(
                                                    ContactsListWidget
                                                        .routeName);
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                height: 65.0,
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      const AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(16.0,
                                                            12.0, 16.0, 12.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Container(
                                                              width: 40.0,
                                                              height: 40.0,
                                                              decoration:
                                                                  const BoxDecoration(
                                                                color: Color(
                                                                    0xFFEFF6FF),
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              child:
                                                                  const Align(
                                                                alignment:
                                                                    AlignmentDirectional(
                                                                        0.0,
                                                                        0.0),
                                                                child: Icon(
                                                                  Icons.people,
                                                                  color: Color(
                                                                      0xFF3B82F6),
                                                                  size: 20.0,
                                                                ),
                                                              ),
                                                            ),
                                                            Text(
                                                              'View network connections',
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    font: GoogleFonts
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
                                                                        0xFF3B82F6),
                                                                    fontSize:
                                                                        16.0,
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
                                                          ].divide(
                                                              const SizedBox(
                                                                  width: 12.0)),
                                                        ),
                                                        const Icon(
                                                          Icons.chevron_right,
                                                          color:
                                                              Color(0xFF6B7280),
                                                          size: 16.0,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsetsDirectional
                                                          .fromSTEB(
                                                          18.0, 0.0, 18.0, 0.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      if (chatChatsRecordList
                                                          .where((e) =>
                                                              e.isPin == true)
                                                          .toList()
                                                          .isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                  0.0,
                                                                  12.0,
                                                                  0.0,
                                                                  12.0),
                                                          child: Text(
                                                            'Pinned',
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
                                                                      0xFF6B7280),
                                                                  fontSize:
                                                                      12.0,
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
                                                          ).animateOnPageLoad(
                                                              animationsMap[
                                                                  'textOnPageLoadAnimation1']!),
                                                        ),
                                                      Builder(
                                                        builder: (context) {
                                                          final allChatPin =
                                                              chatChatsRecordList
                                                                  .where((e) =>
                                                                      e.isPin ==
                                                                      true)
                                                                  .toList()
                                                                  ..sort((a, b) {
                                                                    final aTime = a.lastMessageAt;
                                                                    final bTime = b.lastMessageAt;
                                                                    // Handle null values - put nulls at the end
                                                                    if (aTime == null && bTime == null) return 0;
                                                                    if (aTime == null) return 1; // a goes after b
                                                                    if (bTime == null) return -1; // b goes after a
                                                                    // Both have values, sort descending (newest first)
                                                                    return bTime.compareTo(aTime);
                                                                  });

                                                          return Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            children: List.generate(
                                                                allChatPin
                                                                    .length,
                                                                (allChatPinIndex) {
                                                              final allChatPinItem =
                                                                  allChatPin[
                                                                      allChatPinIndex];
                                                              return Builder(
                                                                builder:
                                                                    (context) {
                                                                  if (allChatPinItem
                                                                          .isGroup ==
                                                                      false) {
                                                                    return Builder(
                                                                      builder: (context) =>
                                                                          StreamBuilder<
                                                                              UsersRecord>(
                                                                        stream: UsersRecord.getDocument(allChatPinItem
                                                                            .members
                                                                            .where((e) =>
                                                                                e.id !=
                                                                                currentUserReference?.id)
                                                                            .toList()
                                                                            .firstOrNull!),
                                                                        builder:
                                                                            (context,
                                                                                snapshot) {
                                                                          // Customize what your widget looks like when it's loading.
                                                                          if (!snapshot
                                                                              .hasData) {
                                                                            return Center(
                                                                              child: SizedBox(
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

                                                                          final containerUsersRecord =
                                                                              snapshot.data!;

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
                                                                              context.pushNamed(
                                                                                ChatDetailWidget.routeName,
                                                                                queryParameters: {
                                                                                  'chatDoc': serializeParam(
                                                                                    allChatPinItem,
                                                                                    ParamType.Document,
                                                                                  ),
                                                                                }.withoutNulls,
                                                                                extra: <String, dynamic>{
                                                                                  'chatDoc': allChatPinItem,
                                                                                },
                                                                              );
                                                                            },
                                                                            onLongPress:
                                                                                () async {
                                                                              await showAlignedDialog(
                                                                                context: context,
                                                                                isGlobal: false,
                                                                                avoidOverflow: false,
                                                                                targetAnchor: const AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                followerAnchor: const AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                builder: (dialogContext) {
                                                                                  return Material(
                                                                                    color: Colors.transparent,
                                                                                    child: GestureDetector(
                                                                                      onTap: () {
                                                                                        FocusScope.of(dialogContext).unfocus();
                                                                                        FocusManager.instance.primaryFocus?.unfocus();
                                                                                      },
                                                                                      child: SizedBox(
                                                                                        width: 150.0,
                                                                                        child: ChatEditWidget(
                                                                                          isPin: true,
                                                                                          actionEdit: () async {
                                                                                            await allChatPinItem.reference.update(createChatsRecordData(
                                                                                              isPin: false,
                                                                                            ));
                                                                                          },
                                                                                          delete: () async {
                                                                                            await allChatPinItem.reference.delete();
                                                                                          },
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                },
                                                                              );
                                                                            },
                                                                            child:
                                                                                Container(
                                                                              width: double.infinity,
                                                                              height: 72.0,
                                                                              decoration: BoxDecoration(
                                                                                color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                borderRadius: BorderRadius.circular(12.0),
                                                                              ),
                                                                              child: Padding(
                                                                                padding: const EdgeInsetsDirectional.fromSTEB(12.0, 12.0, 12.0, 12.0),
                                                                                child: Row(
                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                                  children: [
                                                                                    Expanded(
                                                                                      child: Row(
                                                                                        mainAxisSize: MainAxisSize.min,
                                                                                        children: [
                                                                                          Stack(
                                                                                            children: [
                                                                                              ClipRRect(
                                                                                                borderRadius: BorderRadius.circular(24.0),
                                                                                                child: CachedNetworkImage(
                                                                                                  fadeInDuration: const Duration(milliseconds: 300),
                                                                                                  fadeOutDuration: const Duration(milliseconds: 300),
                                                                                                  imageUrl: valueOrDefault<String>(
                                                                                                    containerUsersRecord.photoUrl,
                                                                                                    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fjurica-koletic-7YVZYZeITc8-unsplash.jpg?alt=media&token=d05a38c8-e024-4624-bdb3-82e4f7c6afab',
                                                                                                  ),
                                                                                                  width: 48.0,
                                                                                                  height: 48.0,
                                                                                                  fit: BoxFit.cover,
                                                                                                ),
                                                                                              ),
                                                                                              if (false)
                                                                                                Align(
                                                                                                  alignment: const AlignmentDirectional(1.0, 1.0),
                                                                                                  child: Container(
                                                                                                    width: 12.0,
                                                                                                    height: 12.0,
                                                                                                    decoration: const BoxDecoration(
                                                                                                      color: Color(0xFF10B981),
                                                                                                      shape: BoxShape.circle,
                                                                                                    ),
                                                                                                  ),
                                                                                                ),
                                                                                            ],
                                                                                          ),
                                                                                          Column(
                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                                            children: [
                                                                                              Row(
                                                                                                mainAxisSize: MainAxisSize.min,
                                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                children: [
                                                                                                  Text(
                                                                                                    valueOrDefault<String>(
                                                                                                      containerUsersRecord.displayName,
                                                                                                      'N/A',
                                                                                                    ).maybeHandleOverflow(
                                                                                                      maxChars: 15,
                                                                                                    ),
                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                          font: GoogleFonts.inter(
                                                                                                            fontWeight: FontWeight.w500,
                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                          ),
                                                                                                          color: const Color(0xFF1F2937),
                                                                                                          fontSize: 16.0,
                                                                                                          letterSpacing: 0.0,
                                                                                                          fontWeight: FontWeight.w500,
                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                        ),
                                                                                                  ),
                                                                                                ],
                                                                                              ),
                                                                                              Stack(
                                                                                                children: [
                                                                                                  Row(
                                                                                                    mainAxisSize: MainAxisSize.max,
                                                                                                    children: [
                                                                                                      if (allChatPinItem.lastMessage != '')
                                                                                                        Text(
                                                                                                          valueOrDefault<String>(
                                                                                                            allChatPinItem.lastMessageSent == currentUserReference ? 'You: ' : '${containerUsersRecord.displayName}: ',
                                                                                                            'N/A',
                                                                                                          ).maybeHandleOverflow(
                                                                                                            maxChars: 10,
                                                                                                            replacement: '…',
                                                                                                          ),
                                                                                                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                font: GoogleFonts.inter(
                                                                                                                  fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                ),
                                                                                                                letterSpacing: 0.0,
                                                                                                                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                              ),
                                                                                                        ),
                                                                                                      if (allChatPinItem.lastMessageType == MessageType.image)
                                                                                                        const Icon(
                                                                                                          Icons.image,
                                                                                                          color: Color(0xFF6B7280),
                                                                                                          size: 12.0,
                                                                                                        ),
                                                                                                      if (allChatPinItem.lastMessageType == MessageType.video)
                                                                                                        const Icon(
                                                                                                          Icons.videocam,
                                                                                                          color: Color(0xFF6B7280),
                                                                                                          size: 12.0,
                                                                                                        ),
                                                                                                      Text(
                                                                                                        valueOrDefault<String>(
                                                                                                          allChatPinItem.lastMessage == ''
                                                                                                              ? 'Let\'s start a chat!'
                                                                                                              : valueOrDefault<String>(
                                                                                                                  allChatPinItem.lastMessage,
                                                                                                                  'H ey everyone! I\'m excited for...',
                                                                                                                ),
                                                                                                          'N/A',
                                                                                                        ).maybeHandleOverflow(
                                                                                                          maxChars: 15,
                                                                                                          replacement: '…',
                                                                                                        ),
                                                                                                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                              font: GoogleFonts.inter(
                                                                                                                fontWeight: FontWeight.normal,
                                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                              ),
                                                                                                              color: FlutterFlowTheme.of(context).secondaryText,
                                                                                                              fontSize: 14.0,
                                                                                                              letterSpacing: 0.0,
                                                                                                              fontWeight: FontWeight.normal,
                                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                            ),
                                                                                                      ),
                                                                                                    ],
                                                                                                  ),
                                                                                                ],
                                                                                              ),
                                                                                            ].divide(const SizedBox(height: 4.0)),
                                                                                          ),
                                                                                        ].divide(const SizedBox(width: 12.0)),
                                                                                      ),
                                                                                    ),
                                                                                    Column(
                                                                                      mainAxisSize: MainAxisSize.max,
                                                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                                                      children: [
                                                                                        Text(
                                                                                          allChatPinItem.lastMessageAt != null
                                                                                              ? valueOrDefault<String>(
                                                                                                  dateTimeFormat("relative", allChatPinItem.lastMessageAt),
                                                                                                  'N/A',
                                                                                                )
                                                                                              : 'N/A',
                                                                                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                font: GoogleFonts.inter(
                                                                                                  fontWeight: FontWeight.normal,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                ),
                                                                                                color: const Color(0xFF6B7280),
                                                                                                fontSize: 12.0,
                                                                                                letterSpacing: 0.0,
                                                                                                fontWeight: FontWeight.normal,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                              ),
                                                                                        ),
                                                                                        Builder(
                                                                                          builder: (context) {
                                                                                            if (allChatPinItem.lastMessageSeen.contains(currentUserReference) == false) {
                                                                                              return Container(
                                                                                                width: 20.0,
                                                                                                height: 20.0,
                                                                                                decoration: const BoxDecoration(
                                                                                                  color: Color(0xFF3B82F6),
                                                                                                  shape: BoxShape.circle,
                                                                                                ),
                                                                                              );
                                                                                            } else if ((allChatPinItem.lastMessageSeen.contains(currentUserReference) == true) && (allChatPinItem.lastMessageSent == currentUserReference)) {
                                                                                              return const Icon(
                                                                                                Icons.check,
                                                                                                color: Color(0xFF6B7280),
                                                                                                size: 16.0,
                                                                                              );
                                                                                            } else {
                                                                                              return Container(
                                                                                                width: 5.0,
                                                                                                height: 5.0,
                                                                                                decoration: BoxDecoration(
                                                                                                  color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                ),
                                                                                              );
                                                                                            }
                                                                                          },
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                      ),
                                                                    );
                                                                  } else {
                                                                    return Builder(
                                                                      builder:
                                                                          (context) =>
                                                                              InkWell(
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
                                                                            ChatDetailWidget.routeName,
                                                                            queryParameters:
                                                                                {
                                                                              'chatDoc': serializeParam(
                                                                                allChatPinItem,
                                                                                ParamType.Document,
                                                                              ),
                                                                            }.withoutNulls,
                                                                            extra: <String,
                                                                                dynamic>{
                                                                              'chatDoc': allChatPinItem,
                                                                            },
                                                                          );
                                                                        },
                                                                        onLongPress:
                                                                            () async {
                                                                          await showAlignedDialog(
                                                                            context:
                                                                                context,
                                                                            isGlobal:
                                                                                false,
                                                                            avoidOverflow:
                                                                                false,
                                                                            targetAnchor:
                                                                                const AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                            followerAnchor:
                                                                                const AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                            builder:
                                                                                (dialogContext) {
                                                                              return Material(
                                                                                color: Colors.transparent,
                                                                                child: GestureDetector(
                                                                                  onTap: () {
                                                                                    FocusScope.of(dialogContext).unfocus();
                                                                                    FocusManager.instance.primaryFocus?.unfocus();
                                                                                  },
                                                                                  child: SizedBox(
                                                                                    width: 150.0,
                                                                                    child: ChatEditWidget(
                                                                                      isPin: true,
                                                                                      actionEdit: () async {
                                                                                        await allChatPinItem.reference.update(createChatsRecordData(
                                                                                          isPin: false,
                                                                                        ));
                                                                                        Navigator.pop(context);
                                                                                      },
                                                                                      delete: () async {
                                                                                        await allChatPinItem.reference.delete();
                                                                                        Navigator.pop(context);
                                                                                      },
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            },
                                                                          );
                                                                        },
                                                                        child:
                                                                            Container(
                                                                          width:
                                                                              double.infinity,
                                                                          height:
                                                                              72.0,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                FlutterFlowTheme.of(context).secondaryBackground,
                                                                            borderRadius:
                                                                                BorderRadius.circular(12.0),
                                                                          ),
                                                                          child:
                                                                              Padding(
                                                                            padding: const EdgeInsetsDirectional.fromSTEB(
                                                                                12.0,
                                                                                12.0,
                                                                                12.0,
                                                                                12.0),
                                                                            child:
                                                                                Row(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Expanded(
                                                                                  child: Row(
                                                                                    mainAxisSize: MainAxisSize.min,
                                                                                    children: [
                                                                                      Stack(
                                                                                        children: [
                                                                                          ClipRRect(
                                                                                            borderRadius: BorderRadius.circular(24.0),
                                                                                            child: CachedNetworkImage(
                                                                                              fadeInDuration: const Duration(milliseconds: 300),
                                                                                              fadeOutDuration: const Duration(milliseconds: 300),
                                                                                              imageUrl: valueOrDefault<String>(
                                                                                                allChatPinItem.chatImageUrl,
                                                                                                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fjurica-koletic-7YVZYZeITc8-unsplash.jpg?alt=media&token=d05a38c8-e024-4624-bdb3-82e4f7c6afab',
                                                                                              ),
                                                                                              width: 48.0,
                                                                                              height: 48.0,
                                                                                              fit: BoxFit.cover,
                                                                                            ),
                                                                                          ),
                                                                                          if (false)
                                                                                            Align(
                                                                                              alignment: const AlignmentDirectional(1.0, 1.0),
                                                                                              child: Container(
                                                                                                width: 12.0,
                                                                                                height: 12.0,
                                                                                                decoration: const BoxDecoration(
                                                                                                  color: Color(0xFF10B981),
                                                                                                  shape: BoxShape.circle,
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                        ],
                                                                                      ),
                                                                                      Column(
                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                        children: [
                                                                                          Row(
                                                                                            mainAxisSize: MainAxisSize.min,
                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                            children: [
                                                                                              Text(
                                                                                                allChatPinItem.title.maybeHandleOverflow(
                                                                                                  maxChars: 15,
                                                                                                ),
                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                      font: GoogleFonts.inter(
                                                                                                        fontWeight: FontWeight.w500,
                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                      ),
                                                                                                      color: const Color(0xFF1F2937),
                                                                                                      fontSize: 16.0,
                                                                                                      letterSpacing: 0.0,
                                                                                                      fontWeight: FontWeight.w500,
                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                    ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                          Row(
                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                            children: [
                                                                                              if (allChatPinItem.lastMessageType == MessageType.image)
                                                                                                const Icon(
                                                                                                  Icons.image,
                                                                                                  color: Color(0xFF6B7280),
                                                                                                  size: 18.0,
                                                                                                ),
                                                                                              if (allChatPinItem.lastMessageType == MessageType.video)
                                                                                                const Icon(
                                                                                                  Icons.videocam,
                                                                                                  color: Color(0xFF6B7280),
                                                                                                  size: 18.0,
                                                                                                ),
                                                                                              Text(
                                                                                                valueOrDefault<String>(
                                                                                                  allChatPinItem.lastMessage,
                                                                                                  'Let\'s Start a Chat',
                                                                                                ).maybeHandleOverflow(
                                                                                                  maxChars: 15,
                                                                                                  replacement: '…',
                                                                                                ),
                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                      font: GoogleFonts.inter(
                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                      ),
                                                                                                      letterSpacing: 0.0,
                                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                    ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        ].divide(const SizedBox(height: 4.0)),
                                                                                      ),
                                                                                    ].divide(const SizedBox(width: 12.0)),
                                                                                  ),
                                                                                ),
                                                                                Column(
                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                                                  children: [
                                                                                    Text(
                                                                                      valueOrDefault<String>(
                                                                                        dateTimeFormat("relative", allChatPinItem.lastMessageAt),
                                                                                        'N/A',
                                                                                      ),
                                                                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                            font: GoogleFonts.inter(
                                                                                              fontWeight: FontWeight.normal,
                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                            ),
                                                                                            color: const Color(0xFF6B7280),
                                                                                            fontSize: 12.0,
                                                                                            letterSpacing: 0.0,
                                                                                            fontWeight: FontWeight.normal,
                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                          ),
                                                                                    ),
                                                                                    Builder(
                                                                                      builder: (context) {
                                                                                        if (allChatPinItem.lastMessageSent != currentUserReference) {
                                                                                          return Visibility(
                                                                                            visible: !allChatPinItem.lastMessageSeen.contains(currentUserReference),
                                                                                            child: Container(
                                                                                              width: 20.0,
                                                                                              height: 20.0,
                                                                                              decoration: const BoxDecoration(
                                                                                                color: Color(0xFF3B82F6),
                                                                                                shape: BoxShape.circle,
                                                                                              ),
                                                                                            ),
                                                                                          );
                                                                                        } else {
                                                                                          return const Icon(
                                                                                            Icons.check,
                                                                                            color: Color(0xFF6B7280),
                                                                                            size: 16.0,
                                                                                          );
                                                                                        }
                                                                                      },
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ).animateOnPageLoad(
                                                                        animationsMap[
                                                                            'containerOnPageLoadAnimation1']!,
                                                                        effects: [
                                                                          MoveEffect(
                                                                            curve:
                                                                                Curves.easeInOut,
                                                                            delay:
                                                                                valueOrDefault<double>(
                                                                              (allChatPinIndex * 48),
                                                                              0.0,
                                                                            ).ms,
                                                                            duration:
                                                                                600.0.ms,
                                                                            begin:
                                                                                const Offset(0.0, 30.0),
                                                                            end:
                                                                                const Offset(0.0, 0.0),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    );
                                                                  }
                                                                },
                                                              ).animateOnPageLoad(
                                                                animationsMap[
                                                                    'conditionalBuilderOnPageLoadAnimation1']!,
                                                                effects: [
                                                                  MoveEffect(
                                                                    curve: Curves
                                                                        .easeInOut,
                                                                    delay: valueOrDefault<
                                                                        double>(
                                                                      (allChatPinIndex *
                                                                          48),
                                                                      0.0,
                                                                    ).ms,
                                                                    duration:
                                                                        600.0
                                                                            .ms,
                                                                    begin:
                                                                        const Offset(
                                                                            0.0,
                                                                            30.0),
                                                                    end: const Offset(
                                                                        0.0,
                                                                        0.0),
                                                                  ),
                                                                ],
                                                              );
                                                            }),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsetsDirectional
                                                          .fromSTEB(
                                                          18.0, 0.0, 18.0, 0.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      if (chatChatsRecordList
                                                          .where((e) =>
                                                              e.isPin == false)
                                                          .toList()
                                                          .isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                  0.0,
                                                                  12.0,
                                                                  0.0,
                                                                  12.0),
                                                          child: Text(
                                                            'Recent',
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
                                                                      0xFF6B7280),
                                                                  fontSize:
                                                                      12.0,
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
                                                          ).animateOnPageLoad(
                                                              animationsMap[
                                                                  'textOnPageLoadAnimation2']!),
                                                        ),
                                                      Builder(
                                                        builder: (context) {
                                                          final allChatAll =
                                                              chatChatsRecordList
                                                                  .where((e) =>
                                                                      e.isPin ==
                                                                      false)
                                                                  .toList()
                                                                  ..sort((a, b) {
                                                                    final aTime = a.lastMessageAt;
                                                                    final bTime = b.lastMessageAt;
                                                                    // Handle null values - put nulls at the end
                                                                    if (aTime == null && bTime == null) return 0;
                                                                    if (aTime == null) return 1; // a goes after b
                                                                    if (bTime == null) return -1; // b goes after a
                                                                    // Both have values, sort descending (newest first)
                                                                    return bTime.compareTo(aTime);
                                                                  });

                                                          return Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            children: List.generate(
                                                                allChatAll
                                                                    .length,
                                                                (allChatAllIndex) {
                                                              final allChatAllItem =
                                                                  allChatAll[
                                                                      allChatAllIndex];
                                                              return Builder(
                                                                builder:
                                                                    (context) {
                                                                  if (allChatAllItem
                                                                          .isGroup ==
                                                                      false) {
                                                                    return Builder(
                                                                      builder: (context) =>
                                                                          FutureBuilder<
                                                                              UsersRecord>(
                                                                        future: UsersRecord.getDocumentOnce(allChatAllItem.members.where((e) => e.id != currentUserReference?.id).toList().firstOrNull !=
                                                                                null
                                                                            ? allChatAllItem.members.where((e) => e.id != currentUserReference?.id).toList().firstOrNull!
                                                                            : allChatAllItem.members.lastOrNull!),
                                                                        builder:
                                                                            (context,
                                                                                snapshot) {
                                                                          // Customize what your widget looks like when it's loading.
                                                                          if (!snapshot
                                                                              .hasData) {
                                                                            return Center(
                                                                              child: SizedBox(
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

                                                                          final containerUsersRecord =
                                                                              snapshot.data!;

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
                                                                              context.pushNamed(
                                                                                ChatDetailWidget.routeName,
                                                                                queryParameters: {
                                                                                  'chatDoc': serializeParam(
                                                                                    allChatAllItem,
                                                                                    ParamType.Document,
                                                                                  ),
                                                                                }.withoutNulls,
                                                                                extra: <String, dynamic>{
                                                                                  'chatDoc': allChatAllItem,
                                                                                },
                                                                              );
                                                                            },
                                                                            onLongPress:
                                                                                () async {
                                                                              await showAlignedDialog(
                                                                                context: context,
                                                                                isGlobal: false,
                                                                                avoidOverflow: false,
                                                                                targetAnchor: const AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                followerAnchor: const AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                builder: (dialogContext) {
                                                                                  return Material(
                                                                                    color: Colors.transparent,
                                                                                    child: GestureDetector(
                                                                                      onTap: () {
                                                                                        FocusScope.of(dialogContext).unfocus();
                                                                                        FocusManager.instance.primaryFocus?.unfocus();
                                                                                      },
                                                                                      child: SizedBox(
                                                                                        width: 150.0,
                                                                                        child: ChatEditWidget(
                                                                                          isPin: false,
                                                                                          actionEdit: () async {
                                                                                            await allChatAllItem.reference.update(createChatsRecordData(
                                                                                              isPin: true,
                                                                                            ));
                                                                                          },
                                                                                          delete: () async {
                                                                                            await allChatAllItem.reference.delete();
                                                                                          },
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                },
                                                                              );
                                                                            },
                                                                            child:
                                                                                Container(
                                                                              width: double.infinity,
                                                                              height: 72.0,
                                                                              decoration: BoxDecoration(
                                                                                color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                borderRadius: BorderRadius.circular(12.0),
                                                                              ),
                                                                              child: Padding(
                                                                                padding: const EdgeInsetsDirectional.fromSTEB(12.0, 12.0, 12.0, 12.0),
                                                                                child: Row(
                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                                  children: [
                                                                                    Expanded(
                                                                                      child: Row(
                                                                                        mainAxisSize: MainAxisSize.min,
                                                                                        children: [
                                                                                          Stack(
                                                                                            children: [
                                                                                              ClipRRect(
                                                                                                borderRadius: BorderRadius.circular(24.0),
                                                                                                child: CachedNetworkImage(
                                                                                                  fadeInDuration: const Duration(milliseconds: 300),
                                                                                                  fadeOutDuration: const Duration(milliseconds: 300),
                                                                                                  imageUrl: valueOrDefault<String>(
                                                                                                    containerUsersRecord.photoUrl,
                                                                                                    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fjurica-koletic-7YVZYZeITc8-unsplash.jpg?alt=media&token=d05a38c8-e024-4624-bdb3-82e4f7c6afab',
                                                                                                  ),
                                                                                                  width: 48.0,
                                                                                                  height: 48.0,
                                                                                                  fit: BoxFit.cover,
                                                                                                ),
                                                                                              ),
                                                                                              if (false)
                                                                                                Align(
                                                                                                  alignment: const AlignmentDirectional(1.0, 1.0),
                                                                                                  child: Container(
                                                                                                    width: 12.0,
                                                                                                    height: 12.0,
                                                                                                    decoration: const BoxDecoration(
                                                                                                      color: Color(0xFF10B981),
                                                                                                      shape: BoxShape.circle,
                                                                                                    ),
                                                                                                  ),
                                                                                                ),
                                                                                            ],
                                                                                          ),
                                                                                          Column(
                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                                            children: [
                                                                                              Row(
                                                                                                mainAxisSize: MainAxisSize.min,
                                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                children: [
                                                                                                  Text(
                                                                                                    valueOrDefault<String>(
                                                                                                      containerUsersRecord.displayName,
                                                                                                      'N/A',
                                                                                                    ).maybeHandleOverflow(
                                                                                                      maxChars: 15,
                                                                                                    ),
                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                          font: GoogleFonts.inter(
                                                                                                            fontWeight: FontWeight.w500,
                                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                          ),
                                                                                                          color: const Color(0xFF1F2937),
                                                                                                          fontSize: 16.0,
                                                                                                          letterSpacing: 0.0,
                                                                                                          fontWeight: FontWeight.w500,
                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                        ),
                                                                                                  ),
                                                                                                ],
                                                                                              ),
                                                                                              Stack(
                                                                                                children: [
                                                                                                  Row(
                                                                                                    mainAxisSize: MainAxisSize.max,
                                                                                                    children: [
                                                                                                      if (allChatAllItem.lastMessage != '')
                                                                                                        Text(
                                                                                                          valueOrDefault<String>(
                                                                                                            allChatAllItem.lastMessageSent == currentUserReference ? 'You: ' : '${containerUsersRecord.displayName}: ',
                                                                                                            'N/A',
                                                                                                          ).maybeHandleOverflow(
                                                                                                            maxChars: 10,
                                                                                                            replacement: '…',
                                                                                                          ),
                                                                                                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                                font: GoogleFonts.inter(
                                                                                                                  fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                                ),
                                                                                                                letterSpacing: 0.0,
                                                                                                                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                              ),
                                                                                                        ),
                                                                                                      if (allChatAllItem.lastMessageType == MessageType.image)
                                                                                                        const Icon(
                                                                                                          Icons.image,
                                                                                                          color: Color(0xFF6B7280),
                                                                                                          size: 12.0,
                                                                                                        ),
                                                                                                      if (allChatAllItem.lastMessageType == MessageType.video)
                                                                                                        const Icon(
                                                                                                          Icons.videocam,
                                                                                                          color: Color(0xFF6B7280),
                                                                                                          size: 12.0,
                                                                                                        ),
                                                                                                      Text(
                                                                                                        valueOrDefault<String>(
                                                                                                          allChatAllItem.lastMessage == ''
                                                                                                              ? 'Let\'s start a chat!'
                                                                                                              : valueOrDefault<String>(
                                                                                                                  allChatAllItem.lastMessage,
                                                                                                                  'H ey everyone! I\'m excited for...',
                                                                                                                ),
                                                                                                          'N/A',
                                                                                                        ).maybeHandleOverflow(
                                                                                                          maxChars: 15,
                                                                                                          replacement: '…',
                                                                                                        ),
                                                                                                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                              font: GoogleFonts.inter(
                                                                                                                fontWeight: FontWeight.normal,
                                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                              ),
                                                                                                              color: FlutterFlowTheme.of(context).secondaryText,
                                                                                                              fontSize: 14.0,
                                                                                                              letterSpacing: 0.0,
                                                                                                              fontWeight: FontWeight.normal,
                                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                            ),
                                                                                                      ),
                                                                                                    ],
                                                                                                  ),
                                                                                                ],
                                                                                              ),
                                                                                            ].divide(const SizedBox(height: 4.0)),
                                                                                          ),
                                                                                        ].divide(const SizedBox(width: 12.0)),
                                                                                      ),
                                                                                    ),
                                                                                    Column(
                                                                                      mainAxisSize: MainAxisSize.max,
                                                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                                                      children: [
                                                                                        Text(
                                                                                          allChatAllItem.lastMessageAt != null
                                                                                              ? valueOrDefault<String>(
                                                                                                  dateTimeFormat("relative", allChatAllItem.lastMessageAt),
                                                                                                  'N/A',
                                                                                                )
                                                                                              : dateTimeFormat("relative", getCurrentTimestamp),
                                                                                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                font: GoogleFonts.inter(
                                                                                                  fontWeight: FontWeight.normal,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                ),
                                                                                                color: const Color(0xFF6B7280),
                                                                                                fontSize: 12.0,
                                                                                                letterSpacing: 0.0,
                                                                                                fontWeight: FontWeight.normal,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                              ),
                                                                                        ),
                                                                                        Builder(
                                                                                          builder: (context) {
                                                                                            if (allChatAllItem.lastMessageSeen.contains(currentUserReference) == false) {
                                                                                              return Container(
                                                                                                width: 20.0,
                                                                                                height: 20.0,
                                                                                                decoration: const BoxDecoration(
                                                                                                  color: Color(0xFF3B82F6),
                                                                                                  shape: BoxShape.circle,
                                                                                                ),
                                                                                              );
                                                                                            } else if ((allChatAllItem.lastMessageSeen.contains(currentUserReference) == true) && (allChatAllItem.lastMessageSent == currentUserReference)) {
                                                                                              return const Icon(
                                                                                                Icons.check,
                                                                                                color: Color(0xFF6B7280),
                                                                                                size: 16.0,
                                                                                              );
                                                                                            } else {
                                                                                              return Container(
                                                                                                width: 5.0,
                                                                                                height: 5.0,
                                                                                                decoration: BoxDecoration(
                                                                                                  color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                                ),
                                                                                              );
                                                                                            }
                                                                                          },
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                      ),
                                                                    );
                                                                  } else {
                                                                    return Builder(
                                                                      builder:
                                                                          (context) =>
                                                                              InkWell(
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
                                                                            ChatDetailWidget.routeName,
                                                                            queryParameters:
                                                                                {
                                                                              'chatDoc': serializeParam(
                                                                                allChatAllItem,
                                                                                ParamType.Document,
                                                                              ),
                                                                            }.withoutNulls,
                                                                            extra: <String,
                                                                                dynamic>{
                                                                              'chatDoc': allChatAllItem,
                                                                            },
                                                                          );
                                                                        },
                                                                        onLongPress:
                                                                            () async {
                                                                          await showAlignedDialog(
                                                                            context:
                                                                                context,
                                                                            isGlobal:
                                                                                false,
                                                                            avoidOverflow:
                                                                                false,
                                                                            targetAnchor:
                                                                                const AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                            followerAnchor:
                                                                                const AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                            builder:
                                                                                (dialogContext) {
                                                                              return Material(
                                                                                color: Colors.transparent,
                                                                                child: GestureDetector(
                                                                                  onTap: () {
                                                                                    FocusScope.of(dialogContext).unfocus();
                                                                                    FocusManager.instance.primaryFocus?.unfocus();
                                                                                  },
                                                                                  child: SizedBox(
                                                                                    width: 150.0,
                                                                                    child: ChatEditWidget(
                                                                                      isPin: false,
                                                                                      actionEdit: () async {
                                                                                        await allChatAllItem.reference.update(createChatsRecordData(
                                                                                          isPin: true,
                                                                                        ));
                                                                                      },
                                                                                      delete: () async {
                                                                                        await allChatAllItem.reference.delete();
                                                                                      },
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            },
                                                                          );
                                                                        },
                                                                        child:
                                                                            Container(
                                                                          width:
                                                                              double.infinity,
                                                                          height:
                                                                              72.0,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                FlutterFlowTheme.of(context).secondaryBackground,
                                                                            borderRadius:
                                                                                BorderRadius.circular(12.0),
                                                                          ),
                                                                          child:
                                                                              Padding(
                                                                            padding: const EdgeInsetsDirectional.fromSTEB(
                                                                                12.0,
                                                                                12.0,
                                                                                12.0,
                                                                                12.0),
                                                                            child:
                                                                                Row(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Expanded(
                                                                                  child: Row(
                                                                                    mainAxisSize: MainAxisSize.min,
                                                                                    children: [
                                                                                      Stack(
                                                                                        children: [
                                                                                          ClipRRect(
                                                                                            borderRadius: BorderRadius.circular(24.0),
                                                                                            child: CachedNetworkImage(
                                                                                              fadeInDuration: const Duration(milliseconds: 300),
                                                                                              fadeOutDuration: const Duration(milliseconds: 300),
                                                                                              imageUrl: valueOrDefault<String>(
                                                                                                allChatAllItem.chatImageUrl,
                                                                                                'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fjurica-koletic-7YVZYZeITc8-unsplash.jpg?alt=media&token=d05a38c8-e024-4624-bdb3-82e4f7c6afab',
                                                                                              ),
                                                                                              width: 48.0,
                                                                                              height: 48.0,
                                                                                              fit: BoxFit.cover,
                                                                                            ),
                                                                                          ),
                                                                                          if (false)
                                                                                            Align(
                                                                                              alignment: const AlignmentDirectional(1.0, 1.0),
                                                                                              child: Container(
                                                                                                width: 12.0,
                                                                                                height: 12.0,
                                                                                                decoration: const BoxDecoration(
                                                                                                  color: Color(0xFF10B981),
                                                                                                  shape: BoxShape.circle,
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                        ],
                                                                                      ),
                                                                                      Column(
                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                        children: [
                                                                                          Row(
                                                                                            mainAxisSize: MainAxisSize.min,
                                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                            children: [
                                                                                              Text(
                                                                                                valueOrDefault<String>(
                                                                                                  allChatAllItem.title,
                                                                                                  'N/A',
                                                                                                ).maybeHandleOverflow(
                                                                                                  maxChars: 15,
                                                                                                ),
                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                      font: GoogleFonts.inter(
                                                                                                        fontWeight: FontWeight.w500,
                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                      ),
                                                                                                      color: const Color(0xFF1F2937),
                                                                                                      fontSize: 16.0,
                                                                                                      letterSpacing: 0.0,
                                                                                                      fontWeight: FontWeight.w500,
                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                    ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                          Row(
                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                            children: [
                                                                                              if (allChatAllItem.lastMessageType == MessageType.image)
                                                                                                const Icon(
                                                                                                  Icons.image,
                                                                                                  color: Color(0xFF6B7280),
                                                                                                  size: 18.0,
                                                                                                ),
                                                                                              if (allChatAllItem.lastMessageType == MessageType.video)
                                                                                                const Icon(
                                                                                                  Icons.videocam,
                                                                                                  color: Color(0xFF6B7280),
                                                                                                  size: 18.0,
                                                                                                ),
                                                                                              Text(
                                                                                                valueOrDefault<String>(
                                                                                                  allChatAllItem.lastMessage,
                                                                                                  'Let\'s Start a Chat',
                                                                                                ).maybeHandleOverflow(
                                                                                                  maxChars: 15,
                                                                                                  replacement: '…',
                                                                                                ),
                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                      font: GoogleFonts.inter(
                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                      ),
                                                                                                      letterSpacing: 0.0,
                                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                    ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        ].divide(const SizedBox(height: 4.0)),
                                                                                      ),
                                                                                    ].divide(const SizedBox(width: 12.0)),
                                                                                  ),
                                                                                ),
                                                                                Column(
                                                                                  mainAxisSize: MainAxisSize.max,
                                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                                                  children: [
                                                                                    Text(
                                                                                      allChatAllItem.lastMessageAt != null
                                                                                          ? valueOrDefault<String>(
                                                                                              dateTimeFormat("relative", allChatAllItem.lastMessageAt),
                                                                                              'N/A',
                                                                                            )
                                                                                          : 'N/A',
                                                                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                            font: GoogleFonts.inter(
                                                                                              fontWeight: FontWeight.normal,
                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                            ),
                                                                                            color: const Color(0xFF6B7280),
                                                                                            fontSize: 12.0,
                                                                                            letterSpacing: 0.0,
                                                                                            fontWeight: FontWeight.normal,
                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                          ),
                                                                                    ),
                                                                                    if (allChatAllItem.lastMessage != '')
                                                                                      Builder(
                                                                                        builder: (context) {
                                                                                          if (allChatAllItem.lastMessageSent != currentUserReference) {
                                                                                            return Visibility(
                                                                                              visible: !allChatAllItem.lastMessageSeen.contains(currentUserReference),
                                                                                              child: Container(
                                                                                                width: 20.0,
                                                                                                height: 20.0,
                                                                                                decoration: const BoxDecoration(
                                                                                                  color: Color(0xFF3B82F6),
                                                                                                  shape: BoxShape.circle,
                                                                                                ),
                                                                                              ),
                                                                                            );
                                                                                          } else {
                                                                                            return const Icon(
                                                                                              Icons.check,
                                                                                              color: Color(0xFF6B7280),
                                                                                              size: 16.0,
                                                                                            );
                                                                                          }
                                                                                        },
                                                                                      ),
                                                                                  ],
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  }
                                                                },
                                                              ).animateOnPageLoad(
                                                                animationsMap[
                                                                    'conditionalBuilderOnPageLoadAnimation2']!,
                                                                effects: [
                                                                  MoveEffect(
                                                                    curve: Curves
                                                                        .easeInOut,
                                                                    delay: valueOrDefault<
                                                                        double>(
                                                                      (allChatAllIndex *
                                                                          48),
                                                                      0.0,
                                                                    ).ms,
                                                                    duration:
                                                                        600.0
                                                                            .ms,
                                                                    begin:
                                                                        const Offset(
                                                                            0.0,
                                                                            30.0),
                                                                    end: const Offset(
                                                                        0.0,
                                                                        0.0),
                                                                  ),
                                                                ],
                                                              );
                                                            }),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  KeepAliveWidgetWrapper(
                                    builder: (context) => SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .fromSTEB(18.0, 0.0, 18.0, 0.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (chatChatsRecordList
                                                    .where((e) =>
                                                        (e.isPin == true) &&
                                                        (e.isGroup == false))
                                                    .toList()
                                                    .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 12.0,
                                                            0.0, 12.0),
                                                    child: Text(
                                                      'Pinned',
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                            ),
                                                            color: const Color(
                                                                0xFF6B7280),
                                                            fontSize: 12.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                    ).animateOnPageLoad(
                                                        animationsMap[
                                                            'textOnPageLoadAnimation3']!),
                                                  ),
                                                Builder(
                                                  builder: (context) {
                                                    final chatVar =
                                                        chatChatsRecordList
                                                            .where((e) =>
                                                                (e.isPin ==
                                                                    true) &&
                                                                (e.isGroup ==
                                                                    false))
                                                            .toList()
                                                            ..sort((a, b) {
                                                              final aTime = a.lastMessageAt;
                                                              final bTime = b.lastMessageAt;
                                                              // Handle null values - put nulls at the end
                                                              if (aTime == null && bTime == null) return 0;
                                                              if (aTime == null) return 1; // a goes after b
                                                              if (bTime == null) return -1; // b goes after a
                                                              // Both have values, sort descending (newest first)
                                                              return bTime.compareTo(aTime);
                                                            });

                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: List.generate(
                                                          chatVar.length,
                                                          (chatVarIndex) {
                                                        final chatVarItem =
                                                            chatVar[
                                                                chatVarIndex];
                                                        return Builder(
                                                          builder: (context) =>
                                                              FutureBuilder<
                                                                  UsersRecord>(
                                                            future: UsersRecord.getDocumentOnce(chatVarItem
                                                                        .members
                                                                        .where((e) =>
                                                                            e.id !=
                                                                            currentUserReference
                                                                                ?.id)
                                                                        .toList()
                                                                        .firstOrNull !=
                                                                    null
                                                                ? chatVarItem
                                                                    .members
                                                                    .where((e) =>
                                                                        e.id !=
                                                                        currentUserReference
                                                                            ?.id)
                                                                    .toList()
                                                                    .firstOrNull!
                                                                : chatVarItem
                                                                    .members
                                                                    .lastOrNull!),
                                                            builder: (context,
                                                                snapshot) {
                                                              // Customize what your widget looks like when it's loading.
                                                              if (!snapshot
                                                                  .hasData) {
                                                                return Center(
                                                                  child:
                                                                      SizedBox(
                                                                    width: 50.0,
                                                                    height:
                                                                        50.0,
                                                                    child:
                                                                        CircularProgressIndicator(
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

                                                              final containerUsersRecord =
                                                                  snapshot
                                                                      .data!;

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
                                                                onTap:
                                                                    () async {
                                                                  context
                                                                      .pushNamed(
                                                                    ChatDetailWidget
                                                                        .routeName,
                                                                    queryParameters:
                                                                        {
                                                                      'chatDoc':
                                                                          serializeParam(
                                                                        chatVarItem,
                                                                        ParamType
                                                                            .Document,
                                                                      ),
                                                                    }.withoutNulls,
                                                                    extra: <String,
                                                                        dynamic>{
                                                                      'chatDoc':
                                                                          chatVarItem,
                                                                    },
                                                                  );
                                                                },
                                                                onLongPress:
                                                                    () async {
                                                                  await showAlignedDialog(
                                                                    context:
                                                                        context,
                                                                    isGlobal:
                                                                        false,
                                                                    avoidOverflow:
                                                                        false,
                                                                    targetAnchor: const AlignmentDirectional(
                                                                            0.0,
                                                                            0.0)
                                                                        .resolve(
                                                                            Directionality.of(context)),
                                                                    followerAnchor: const AlignmentDirectional(
                                                                            0.0,
                                                                            0.0)
                                                                        .resolve(
                                                                            Directionality.of(context)),
                                                                    builder:
                                                                        (dialogContext) {
                                                                      return Material(
                                                                        color: Colors
                                                                            .transparent,
                                                                        child:
                                                                            GestureDetector(
                                                                          onTap:
                                                                              () {
                                                                            FocusScope.of(dialogContext).unfocus();
                                                                            FocusManager.instance.primaryFocus?.unfocus();
                                                                          },
                                                                          child:
                                                                              SizedBox(
                                                                            width:
                                                                                150.0,
                                                                            child:
                                                                                ChatEditWidget(
                                                                              isPin: true,
                                                                              actionEdit: () async {
                                                                                await chatVarItem.reference.update(createChatsRecordData(
                                                                                  isPin: false,
                                                                                ));
                                                                              },
                                                                              delete: () async {
                                                                                await chatVarItem.reference.delete();
                                                                              },
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                  );
                                                                },
                                                                child:
                                                                    Container(
                                                                  width: double
                                                                      .infinity,
                                                                  height: 72.0,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryBackground,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12.0),
                                                                  ),
                                                                  child:
                                                                      Padding(
                                                                    padding: const EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                        12.0,
                                                                        12.0,
                                                                        12.0,
                                                                        12.0),
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Expanded(
                                                                          child:
                                                                              Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            children:
                                                                                [
                                                                              Stack(
                                                                                children: [
                                                                                  ClipRRect(
                                                                                    borderRadius: BorderRadius.circular(24.0),
                                                                                    child: CachedNetworkImage(
                                                                                      fadeInDuration: const Duration(milliseconds: 300),
                                                                                      fadeOutDuration: const Duration(milliseconds: 300),
                                                                                      imageUrl: valueOrDefault<String>(
                                                                                        containerUsersRecord.photoUrl,
                                                                                        'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fjurica-koletic-7YVZYZeITc8-unsplash.jpg?alt=media&token=d05a38c8-e024-4624-bdb3-82e4f7c6afab',
                                                                                      ),
                                                                                      width: 48.0,
                                                                                      height: 48.0,
                                                                                      fit: BoxFit.cover,
                                                                                    ),
                                                                                  ),
                                                                                  if (false)
                                                                                    Align(
                                                                                      alignment: const AlignmentDirectional(1.0, 1.0),
                                                                                      child: Container(
                                                                                        width: 12.0,
                                                                                        height: 12.0,
                                                                                        decoration: const BoxDecoration(
                                                                                          color: Color(0xFF10B981),
                                                                                          shape: BoxShape.circle,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                ],
                                                                              ),
                                                                              Column(
                                                                                mainAxisSize: MainAxisSize.max,
                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                children: [
                                                                                  Row(
                                                                                    mainAxisSize: MainAxisSize.min,
                                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                    children: [
                                                                                      Text(
                                                                                        containerUsersRecord.displayName.maybeHandleOverflow(
                                                                                          maxChars: 15,
                                                                                        ),
                                                                                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                              font: GoogleFonts.inter(
                                                                                                fontWeight: FontWeight.w500,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                              ),
                                                                                              color: const Color(0xFF1F2937),
                                                                                              fontSize: 16.0,
                                                                                              letterSpacing: 0.0,
                                                                                              fontWeight: FontWeight.w500,
                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                            ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                  Stack(
                                                                                    children: [
                                                                                      Row(
                                                                                        mainAxisSize: MainAxisSize.max,
                                                                                        children: [
                                                                                          if (chatVarItem.lastMessage != '')
                                                                                            Text(
                                                                                              chatVarItem.lastMessageSent == currentUserReference
                                                                                                  ? 'You: '
                                                                                                  : '${containerUsersRecord.displayName}: '.maybeHandleOverflow(
                                                                                                      maxChars: 10,
                                                                                                      replacement: '…',
                                                                                                    ),
                                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                    font: GoogleFonts.inter(
                                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                    ),
                                                                                                    letterSpacing: 0.0,
                                                                                                    fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                  ),
                                                                                            ),
                                                                                          if (chatVarItem.lastMessageType == MessageType.image)
                                                                                            const Icon(
                                                                                              Icons.image,
                                                                                              color: Color(0xFF6B7280),
                                                                                              size: 12.0,
                                                                                            ),
                                                                                          if (chatVarItem.lastMessageType == MessageType.video)
                                                                                            const Icon(
                                                                                              Icons.videocam,
                                                                                              color: Color(0xFF6B7280),
                                                                                              size: 12.0,
                                                                                            ),
                                                                                          Text(
                                                                                            chatVarItem.lastMessage == ''
                                                                                                ? 'Let\'s start a chat!'
                                                                                                : valueOrDefault<String>(
                                                                                                    chatVarItem.lastMessage,
                                                                                                    'H ey everyone! I\'m excited for...',
                                                                                                  ).maybeHandleOverflow(
                                                                                                    maxChars: 15,
                                                                                                    replacement: '…',
                                                                                                  ),
                                                                                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                  font: GoogleFonts.inter(
                                                                                                    fontWeight: FontWeight.normal,
                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                  ),
                                                                                                  color: FlutterFlowTheme.of(context).secondaryText,
                                                                                                  fontSize: 14.0,
                                                                                                  letterSpacing: 0.0,
                                                                                                  fontWeight: FontWeight.normal,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                ),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ].divide(const SizedBox(height: 4.0)),
                                                                              ),
                                                                            ].divide(const SizedBox(width: 12.0)),
                                                                          ),
                                                                        ),
                                                                        Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceBetween,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.end,
                                                                          children: [
                                                                            Text(
                                                                              valueOrDefault<String>(
                                                                                dateTimeFormat("relative", chatVarItem.lastMessageAt),
                                                                                'N/A',
                                                                              ),
                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                    font: GoogleFonts.inter(
                                                                                      fontWeight: FontWeight.normal,
                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                    ),
                                                                                    color: const Color(0xFF6B7280),
                                                                                    fontSize: 12.0,
                                                                                    letterSpacing: 0.0,
                                                                                    fontWeight: FontWeight.normal,
                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                  ),
                                                                            ),
                                                                            Builder(
                                                                              builder: (context) {
                                                                                if (chatVarItem.lastMessageSeen.contains(currentUserReference) == false) {
                                                                                  return Container(
                                                                                    width: 20.0,
                                                                                    height: 20.0,
                                                                                    decoration: const BoxDecoration(
                                                                                      color: Color(0xFF3B82F6),
                                                                                      shape: BoxShape.circle,
                                                                                    ),
                                                                                  );
                                                                                } else if ((chatVarItem.lastMessageSent == currentUserReference) && (chatVarItem.lastMessageSeen.contains(currentUserReference) == true)) {
                                                                                  return const Icon(
                                                                                    Icons.check,
                                                                                    color: Color(0xFF6B7280),
                                                                                    size: 16.0,
                                                                                  );
                                                                                } else {
                                                                                  return Container(
                                                                                    width: 5.0,
                                                                                    height: 5.0,
                                                                                    decoration: BoxDecoration(
                                                                                      color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                      shape: BoxShape.circle,
                                                                                    ),
                                                                                  );
                                                                                }
                                                                              },
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ).animateOnPageLoad(
                                                                animationsMap[
                                                                    'containerOnPageLoadAnimation2']!,
                                                                effects: [
                                                                  MoveEffect(
                                                                    curve: Curves
                                                                        .easeInOut,
                                                                    delay: valueOrDefault<
                                                                        double>(
                                                                      (chatVarIndex *
                                                                          48),
                                                                      0.0,
                                                                    ).ms,
                                                                    duration:
                                                                        600.0
                                                                            .ms,
                                                                    begin:
                                                                        const Offset(
                                                                            0.0,
                                                                            30.0),
                                                                    end: const Offset(
                                                                        0.0,
                                                                        0.0),
                                                                  ),
                                                                ],
                                                              );
                                                            },
                                                          ),
                                                        );
                                                      }),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .fromSTEB(18.0, 0.0, 18.0, 0.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (chatChatsRecordList
                                                    .where((e) =>
                                                        e.isGroup == false)
                                                    .toList()
                                                    .isNotEmpty)
                                                  Align(
                                                    alignment:
                                                        const AlignmentDirectional(
                                                            -1.0, 0.0),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(0.0,
                                                              12.0, 0.0, 12.0),
                                                      child: Text(
                                                        'Friends',
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              font: GoogleFonts
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
                                                                  0xFF6B7280),
                                                              fontSize: 12.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                            ),
                                                      ).animateOnPageLoad(
                                                          animationsMap[
                                                              'textOnPageLoadAnimation4']!),
                                                    ),
                                                  ),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Builder(
                                                      builder: (context) {
                                                        final chatVar =
                                                            chatChatsRecordList
                                                                .where((e) =>
                                                                    (e.isPin ==
                                                                        false) &&
                                                                    (e.isGroup ==
                                                                        false))
                                                                .toList()
                                                                ..sort((a, b) {
                                                                  final aTime = a.lastMessageAt;
                                                                  final bTime = b.lastMessageAt;
                                                                  // Handle null values - put nulls at the end
                                                                  if (aTime == null && bTime == null) return 0;
                                                                  if (aTime == null) return 1; // a goes after b
                                                                  if (bTime == null) return -1; // b goes after a
                                                                  // Both have values, sort descending (newest first)
                                                                  return bTime.compareTo(aTime);
                                                                });

                                                        return Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          children: List.generate(
                                                              chatVar.length,
                                                              (chatVarIndex) {
                                                            final chatVarItem =
                                                                chatVar[
                                                                    chatVarIndex];
                                                            return Builder(
                                                              builder: (context) =>
                                                                  FutureBuilder<
                                                                      UsersRecord>(
                                                                future: UsersRecord.getDocumentOnce(chatVarItem
                                                                            .members
                                                                            .where((e) =>
                                                                                e.id !=
                                                                                currentUserReference
                                                                                    ?.id)
                                                                            .toList()
                                                                            .firstOrNull !=
                                                                        null
                                                                    ? chatVarItem
                                                                        .members
                                                                        .where((e) =>
                                                                            e.id !=
                                                                            currentUserReference
                                                                                ?.id)
                                                                        .toList()
                                                                        .firstOrNull!
                                                                    : chatVarItem
                                                                        .members
                                                                        .lastOrNull!),
                                                                builder: (context,
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
                                                                          valueColor:
                                                                              AlwaysStoppedAnimation<Color>(
                                                                            FlutterFlowTheme.of(context).primary,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  }

                                                                  final containerUsersRecord =
                                                                      snapshot
                                                                          .data!;

                                                                  return InkWell(
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
                                                                      context
                                                                          .pushNamed(
                                                                        ChatDetailWidget
                                                                            .routeName,
                                                                        queryParameters:
                                                                            {
                                                                          'chatDoc':
                                                                              serializeParam(
                                                                            chatVarItem,
                                                                            ParamType.Document,
                                                                          ),
                                                                        }.withoutNulls,
                                                                        extra: <String,
                                                                            dynamic>{
                                                                          'chatDoc':
                                                                              chatVarItem,
                                                                        },
                                                                      );
                                                                    },
                                                                    onLongPress:
                                                                        () async {
                                                                      await showAlignedDialog(
                                                                        context:
                                                                            context,
                                                                        isGlobal:
                                                                            false,
                                                                        avoidOverflow:
                                                                            false,
                                                                        targetAnchor:
                                                                            const AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                        followerAnchor:
                                                                            const AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                        builder:
                                                                            (dialogContext) {
                                                                          return Material(
                                                                            color:
                                                                                Colors.transparent,
                                                                            child:
                                                                                GestureDetector(
                                                                              onTap: () {
                                                                                FocusScope.of(dialogContext).unfocus();
                                                                                FocusManager.instance.primaryFocus?.unfocus();
                                                                              },
                                                                              child: SizedBox(
                                                                                width: 150.0,
                                                                                child: ChatEditWidget(
                                                                                  isPin: false,
                                                                                  actionEdit: () async {
                                                                                    await chatVarItem.reference.update(createChatsRecordData(
                                                                                      isPin: true,
                                                                                    ));
                                                                                  },
                                                                                  delete: () async {
                                                                                    await chatVarItem.reference.delete();
                                                                                  },
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                      );
                                                                    },
                                                                    child:
                                                                        Container(
                                                                      width: double
                                                                          .infinity,
                                                                      height:
                                                                          72.0,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryBackground,
                                                                        borderRadius:
                                                                            BorderRadius.circular(12.0),
                                                                      ),
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsetsDirectional
                                                                            .fromSTEB(
                                                                            12.0,
                                                                            12.0,
                                                                            12.0,
                                                                            12.0),
                                                                        child:
                                                                            Row(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceBetween,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Expanded(
                                                                              child: Row(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                children: [
                                                                                  Stack(
                                                                                    children: [
                                                                                      ClipRRect(
                                                                                        borderRadius: BorderRadius.circular(24.0),
                                                                                        child: CachedNetworkImage(
                                                                                          fadeInDuration: const Duration(milliseconds: 300),
                                                                                          fadeOutDuration: const Duration(milliseconds: 300),
                                                                                          imageUrl: valueOrDefault<String>(
                                                                                            containerUsersRecord.photoUrl,
                                                                                            'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fjurica-koletic-7YVZYZeITc8-unsplash.jpg?alt=media&token=d05a38c8-e024-4624-bdb3-82e4f7c6afab',
                                                                                          ),
                                                                                          width: 48.0,
                                                                                          height: 48.0,
                                                                                          fit: BoxFit.cover,
                                                                                        ),
                                                                                      ),
                                                                                      if (false)
                                                                                        Align(
                                                                                          alignment: const AlignmentDirectional(1.0, 1.0),
                                                                                          child: Container(
                                                                                            width: 12.0,
                                                                                            height: 12.0,
                                                                                            decoration: const BoxDecoration(
                                                                                              color: Color(0xFF10B981),
                                                                                              shape: BoxShape.circle,
                                                                                            ),
                                                                                          ),
                                                                                        ),
                                                                                    ],
                                                                                  ),
                                                                                  Column(
                                                                                    mainAxisSize: MainAxisSize.max,
                                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    children: [
                                                                                      Row(
                                                                                        mainAxisSize: MainAxisSize.min,
                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                        children: [
                                                                                          Text(
                                                                                            containerUsersRecord.displayName.maybeHandleOverflow(
                                                                                              maxChars: 15,
                                                                                            ),
                                                                                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                  font: GoogleFonts.inter(
                                                                                                    fontWeight: FontWeight.w500,
                                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                  ),
                                                                                                  color: const Color(0xFF1F2937),
                                                                                                  fontSize: 16.0,
                                                                                                  letterSpacing: 0.0,
                                                                                                  fontWeight: FontWeight.w500,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                ),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                      Stack(
                                                                                        children: [
                                                                                          Row(
                                                                                            mainAxisSize: MainAxisSize.max,
                                                                                            children: [
                                                                                              if (chatVarItem.lastMessage != '')
                                                                                                Text(
                                                                                                  chatVarItem.lastMessageSent == currentUserReference ? 'You: ' : '${containerUsersRecord.displayName}: ',
                                                                                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                        font: GoogleFonts.inter(
                                                                                                          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                        ),
                                                                                                        letterSpacing: 0.0,
                                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                      ),
                                                                                                ),
                                                                                              if (chatVarItem.lastMessageType == MessageType.image)
                                                                                                const Icon(
                                                                                                  Icons.image,
                                                                                                  color: Color(0xFF6B7280),
                                                                                                  size: 12.0,
                                                                                                ),
                                                                                              if (chatVarItem.lastMessageType == MessageType.video)
                                                                                                const Icon(
                                                                                                  Icons.videocam,
                                                                                                  color: Color(0xFF6B7280),
                                                                                                  size: 12.0,
                                                                                                ),
                                                                                              Text(
                                                                                                chatVarItem.lastMessage == ''
                                                                                                    ? 'Let\'s start a chat!'
                                                                                                    : valueOrDefault<String>(
                                                                                                        chatVarItem.lastMessage,
                                                                                                        'H ey everyone! I\'m excited for...',
                                                                                                      ).maybeHandleOverflow(
                                                                                                        maxChars: 15,
                                                                                                        replacement: '…',
                                                                                                      ),
                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                      font: GoogleFonts.inter(
                                                                                                        fontWeight: FontWeight.normal,
                                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                      ),
                                                                                                      color: FlutterFlowTheme.of(context).secondaryText,
                                                                                                      fontSize: 14.0,
                                                                                                      letterSpacing: 0.0,
                                                                                                      fontWeight: FontWeight.normal,
                                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                    ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    ].divide(const SizedBox(height: 4.0)),
                                                                                  ),
                                                                                ].divide(const SizedBox(width: 12.0)),
                                                                              ),
                                                                            ),
                                                                            Column(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                              crossAxisAlignment: CrossAxisAlignment.end,
                                                                              children: [
                                                                                Text(
                                                                                  valueOrDefault<String>(
                                                                                    dateTimeFormat("relative", chatVarItem.lastMessageAt),
                                                                                    'N/A',
                                                                                  ),
                                                                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                        font: GoogleFonts.inter(
                                                                                          fontWeight: FontWeight.normal,
                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                        ),
                                                                                        color: const Color(0xFF6B7280),
                                                                                        fontSize: 12.0,
                                                                                        letterSpacing: 0.0,
                                                                                        fontWeight: FontWeight.normal,
                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                      ),
                                                                                ),
                                                                                Builder(
                                                                                  builder: (context) {
                                                                                    if (chatVarItem.lastMessageSeen.contains(currentUserReference) == false) {
                                                                                      return Container(
                                                                                        width: 20.0,
                                                                                        height: 20.0,
                                                                                        decoration: const BoxDecoration(
                                                                                          color: Color(0xFF3B82F6),
                                                                                          shape: BoxShape.circle,
                                                                                        ),
                                                                                      );
                                                                                    } else if ((chatVarItem.lastMessageSeen.contains(currentUserReference) == true) && (chatVarItem.lastMessageSent == currentUserReference)) {
                                                                                      return const Icon(
                                                                                        Icons.check,
                                                                                        color: Color(0xFF6B7280),
                                                                                        size: 16.0,
                                                                                      );
                                                                                    } else {
                                                                                      return Container(
                                                                                        width: 5.0,
                                                                                        height: 5.0,
                                                                                        decoration: BoxDecoration(
                                                                                          color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                          shape: BoxShape.circle,
                                                                                        ),
                                                                                      );
                                                                                    }
                                                                                  },
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ).animateOnPageLoad(
                                                                    animationsMap[
                                                                        'containerOnPageLoadAnimation3']!,
                                                                    effects: [
                                                                      MoveEffect(
                                                                        curve: Curves
                                                                            .easeInOut,
                                                                        delay: valueOrDefault<
                                                                            double>(
                                                                          (chatVarIndex *
                                                                              48),
                                                                          0.0,
                                                                        ).ms,
                                                                        duration:
                                                                            600.0.ms,
                                                                        begin: const Offset(
                                                                            0.0,
                                                                            30.0),
                                                                        end: const Offset(
                                                                            0.0,
                                                                            0.0),
                                                                      ),
                                                                    ],
                                                                  );
                                                                },
                                                              ),
                                                            );
                                                          }),
                                                        );
                                                      },
                                                    ),
                                                  ].divide(const SizedBox(
                                                      height: 16.0)),
                                                ),
                                                if (false)
                                                  Container(
                                                    width: double.infinity,
                                                    height: 72.0,
                                                    decoration: BoxDecoration(
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .secondaryBackground,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(12.0,
                                                              12.0, 12.0, 12.0),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            children: [
                                                              Container(
                                                                width: 48.0,
                                                                height: 48.0,
                                                                decoration:
                                                                    const BoxDecoration(
                                                                  color: Color(
                                                                      0xFFDBEAFE),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                                child:
                                                                    const Align(
                                                                  alignment:
                                                                      AlignmentDirectional(
                                                                          0.0,
                                                                          0.0),
                                                                  child: Icon(
                                                                    Icons
                                                                        .people,
                                                                    color: Color(
                                                                        0xFF3B82F6),
                                                                    size: 24.0,
                                                                  ),
                                                                ),
                                                              ),
                                                              Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .spaceBetween,
                                                                    children: [
                                                                      Text(
                                                                        'UX Design Workshop',
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(
                                                                              font: GoogleFonts.inter(
                                                                                fontWeight: FontWeight.w500,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                              color: const Color(0xFF1F2937),
                                                                              fontSize: 16.0,
                                                                              letterSpacing: 0.0,
                                                                              fontWeight: FontWeight.w500,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                      ),
                                                                      Text(
                                                                        'Yesterday',
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(
                                                                              font: GoogleFonts.inter(
                                                                                fontWeight: FontWeight.normal,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                              color: const Color(0xFF6B7280),
                                                                              fontSize: 12.0,
                                                                              letterSpacing: 0.0,
                                                                              fontWeight: FontWeight.normal,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Text(
                                                                    'E mma: Here\'s the agenda for ...',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.inter(
                                                                            fontWeight:
                                                                                FontWeight.normal,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).secondaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.normal,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ].divide(
                                                                    const SizedBox(
                                                                        height:
                                                                            4.0)),
                                                              ),
                                                            ].divide(
                                                                const SizedBox(
                                                                    width:
                                                                        12.0)),
                                                          ),
                                                          const Icon(
                                                            Icons.push_pin,
                                                            color: Color(
                                                                0xFF6B7280),
                                                            size: 16.0,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  KeepAliveWidgetWrapper(
                                    builder: (context) => SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .fromSTEB(18.0, 0.0, 18.0, 0.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (chatChatsRecordList
                                                    .where((e) =>
                                                        (e.isPin == true) &&
                                                        (e.isGroup == true))
                                                    .toList()
                                                    .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 12.0,
                                                            0.0, 12.0),
                                                    child: Text(
                                                      'Pinned',
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                            ),
                                                            color: const Color(
                                                                0xFF6B7280),
                                                            fontSize: 12.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                    ).animateOnPageLoad(
                                                        animationsMap[
                                                            'textOnPageLoadAnimation5']!),
                                                  ),
                                                Builder(
                                                  builder: (context) {
                                                    final chatVar =
                                                        chatChatsRecordList
                                                            .where((e) =>
                                                                (e.isPin ==
                                                                    true) &&
                                                                (e.isGroup ==
                                                                    true))
                                                            .toList()
                                                            ..sort((a, b) {
                                                              final aTime = a.lastMessageAt;
                                                              final bTime = b.lastMessageAt;
                                                              // Handle null values - put nulls at the end
                                                              if (aTime == null && bTime == null) return 0;
                                                              if (aTime == null) return 1; // a goes after b
                                                              if (bTime == null) return -1; // b goes after a
                                                              // Both have values, sort descending (newest first)
                                                              return bTime.compareTo(aTime);
                                                            });

                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: List.generate(
                                                          chatVar.length,
                                                          (chatVarIndex) {
                                                        final chatVarItem =
                                                            chatVar[
                                                                chatVarIndex];
                                                        return Builder(
                                                          builder: (context) =>
                                                              InkWell(
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
                                                              context.pushNamed(
                                                                ChatDetailWidget
                                                                    .routeName,
                                                                queryParameters:
                                                                    {
                                                                  'chatDoc':
                                                                      serializeParam(
                                                                    chatVarItem,
                                                                    ParamType
                                                                        .Document,
                                                                  ),
                                                                }.withoutNulls,
                                                                extra: <String,
                                                                    dynamic>{
                                                                  'chatDoc':
                                                                      chatVarItem,
                                                                },
                                                              );
                                                            },
                                                            onLongPress:
                                                                () async {
                                                              await showAlignedDialog(
                                                                context:
                                                                    context,
                                                                isGlobal: false,
                                                                avoidOverflow:
                                                                    false,
                                                                targetAnchor:
                                                                    const AlignmentDirectional(
                                                                            0.0,
                                                                            0.0)
                                                                        .resolve(
                                                                            Directionality.of(context)),
                                                                followerAnchor:
                                                                    const AlignmentDirectional(
                                                                            0.0,
                                                                            0.0)
                                                                        .resolve(
                                                                            Directionality.of(context)),
                                                                builder:
                                                                    (dialogContext) {
                                                                  return Material(
                                                                    color: Colors
                                                                        .transparent,
                                                                    child:
                                                                        GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        FocusScope.of(dialogContext)
                                                                            .unfocus();
                                                                        FocusManager
                                                                            .instance
                                                                            .primaryFocus
                                                                            ?.unfocus();
                                                                      },
                                                                      child:
                                                                          SizedBox(
                                                                        width:
                                                                            150.0,
                                                                        child:
                                                                            ChatEditWidget(
                                                                          isPin:
                                                                              true,
                                                                          actionEdit:
                                                                              () async {
                                                                            await chatVarItem.reference.update(createChatsRecordData(
                                                                              isPin: false,
                                                                            ));
                                                                          },
                                                                          delete:
                                                                              () async {
                                                                            await chatVarItem.reference.delete();
                                                                          },
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              );
                                                            },
                                                            child: Container(
                                                              width: double
                                                                  .infinity,
                                                              height: 72.0,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryBackground,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12.0),
                                                              ),
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                        12.0,
                                                                        12.0,
                                                                        12.0,
                                                                        12.0),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .max,
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Expanded(
                                                                      child:
                                                                          Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children:
                                                                            [
                                                                          Stack(
                                                                            children: [
                                                                              ClipRRect(
                                                                                borderRadius: BorderRadius.circular(24.0),
                                                                                child: CachedNetworkImage(
                                                                                  fadeInDuration: const Duration(milliseconds: 300),
                                                                                  fadeOutDuration: const Duration(milliseconds: 300),
                                                                                  imageUrl: valueOrDefault<String>(
                                                                                    chatVarItem.chatImageUrl,
                                                                                    'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fjurica-koletic-7YVZYZeITc8-unsplash.jpg?alt=media&token=d05a38c8-e024-4624-bdb3-82e4f7c6afab',
                                                                                  ),
                                                                                  width: 48.0,
                                                                                  height: 48.0,
                                                                                  fit: BoxFit.cover,
                                                                                ),
                                                                              ),
                                                                              if (false)
                                                                                Align(
                                                                                  alignment: const AlignmentDirectional(1.0, 1.0),
                                                                                  child: Container(
                                                                                    width: 12.0,
                                                                                    height: 12.0,
                                                                                    decoration: const BoxDecoration(
                                                                                      color: Color(0xFF10B981),
                                                                                      shape: BoxShape.circle,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                            ],
                                                                          ),
                                                                          Column(
                                                                            mainAxisSize:
                                                                                MainAxisSize.max,
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.spaceBetween,
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children:
                                                                                [
                                                                              Row(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                children: [
                                                                                  Text(
                                                                                    chatVarItem.title.maybeHandleOverflow(
                                                                                      maxChars: 15,
                                                                                    ),
                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                          font: GoogleFonts.inter(
                                                                                            fontWeight: FontWeight.w500,
                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                          ),
                                                                                          color: const Color(0xFF1F2937),
                                                                                          fontSize: 16.0,
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FontWeight.w500,
                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                        ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                              Row(
                                                                                mainAxisSize: MainAxisSize.max,
                                                                                children: [
                                                                                  if (chatVarItem.lastMessageType == MessageType.image)
                                                                                    const Icon(
                                                                                      Icons.image,
                                                                                      color: Color(0xFF6B7280),
                                                                                      size: 18.0,
                                                                                    ),
                                                                                  if (chatVarItem.lastMessageType == MessageType.video)
                                                                                    const Icon(
                                                                                      Icons.videocam,
                                                                                      color: Color(0xFF6B7280),
                                                                                      size: 18.0,
                                                                                    ),
                                                                                  Text(
                                                                                    valueOrDefault<String>(
                                                                                      chatVarItem.lastMessage,
                                                                                      'Let\'s Start a Chat',
                                                                                    ).maybeHandleOverflow(
                                                                                      maxChars: 15,
                                                                                      replacement: '…',
                                                                                    ),
                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                          font: GoogleFonts.inter(
                                                                                            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                          ),
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                        ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ].divide(const SizedBox(height: 4.0)),
                                                                          ),
                                                                        ].divide(const SizedBox(width: 12.0)),
                                                                      ),
                                                                    ),
                                                                    Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .end,
                                                                      children: [
                                                                        Text(
                                                                          valueOrDefault<
                                                                              String>(
                                                                            dateTimeFormat("relative",
                                                                                chatVarItem.lastMessageAt),
                                                                            'N/A',
                                                                          ),
                                                                          style: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .override(
                                                                                font: GoogleFonts.inter(
                                                                                  fontWeight: FontWeight.normal,
                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                ),
                                                                                color: const Color(0xFF6B7280),
                                                                                fontSize: 12.0,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FontWeight.normal,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                        ),
                                                                        Builder(
                                                                          builder:
                                                                              (context) {
                                                                            if (chatVarItem.lastMessageSeen.contains(currentUserReference) ==
                                                                                false) {
                                                                              return Visibility(
                                                                                visible: !chatVarItem.lastMessageSeen.contains(currentUserReference),
                                                                                child: Container(
                                                                                  width: 20.0,
                                                                                  height: 20.0,
                                                                                  decoration: const BoxDecoration(
                                                                                    color: Color(0xFF3B82F6),
                                                                                    shape: BoxShape.circle,
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            } else if ((chatVarItem.lastMessageSeen.contains(currentUserReference) == false) &&
                                                                                (chatVarItem.lastMessageSent == currentUserReference)) {
                                                                              return const Icon(
                                                                                Icons.check,
                                                                                color: Color(0xFF6B7280),
                                                                                size: 16.0,
                                                                              );
                                                                            } else {
                                                                              return Container(
                                                                                width: 5.0,
                                                                                height: 5.0,
                                                                                decoration: BoxDecoration(
                                                                                  color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                  shape: BoxShape.circle,
                                                                                ),
                                                                              );
                                                                            }
                                                                          },
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ).animateOnPageLoad(
                                                            animationsMap[
                                                                'containerOnPageLoadAnimation4']!,
                                                            effects: [
                                                              MoveEffect(
                                                                curve: Curves
                                                                    .easeInOut,
                                                                delay:
                                                                    valueOrDefault<
                                                                        double>(
                                                                  (chatVarIndex *
                                                                      48),
                                                                  0.0,
                                                                ).ms,
                                                                duration:
                                                                    600.0.ms,
                                                                begin:
                                                                    const Offset(
                                                                        0.0,
                                                                        30.0),
                                                                end:
                                                                    const Offset(
                                                                        0.0,
                                                                        0.0),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsetsDirectional
                                                .fromSTEB(18.0, 0.0, 18.0, 0.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (chatChatsRecordList
                                                    .where((e) =>
                                                        e.isGroup == true)
                                                    .toList()
                                                    .isNotEmpty)
                                                  Align(
                                                    alignment:
                                                        const AlignmentDirectional(
                                                            -1.0, 0.0),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(0.0,
                                                              12.0, 0.0, 12.0),
                                                      child: Text(
                                                        'Group',
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              font: GoogleFonts
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
                                                                  0xFF6B7280),
                                                              fontSize: 12.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                            ),
                                                      ).animateOnPageLoad(
                                                          animationsMap[
                                                              'textOnPageLoadAnimation6']!),
                                                    ),
                                                  ),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Builder(
                                                      builder: (context) {
                                                        final chatVar =
                                                            chatChatsRecordList
                                                                .where((e) =>
                                                                    (e.isPin ==
                                                                        false) &&
                                                                    (e.isGroup ==
                                                                        true))
                                                                .toList()
                                                                ..sort((a, b) {
                                                                  final aTime = a.lastMessageAt;
                                                                  final bTime = b.lastMessageAt;
                                                                  // Handle null values - put nulls at the end
                                                                  if (aTime == null && bTime == null) return 0;
                                                                  if (aTime == null) return 1; // a goes after b
                                                                  if (bTime == null) return -1; // b goes after a
                                                                  // Both have values, sort descending (newest first)
                                                                  return bTime.compareTo(aTime);
                                                                });
                                                        
                                                        // Debug: Log all groups to help diagnose missing groups
                                                        debugPrint('🔍 Groups found: ${chatVar.length}');
                                                        for (var group in chatVar) {
                                                          debugPrint('  - ${group.title} (isGroup: ${group.isGroup}, lastMessageAt: ${group.lastMessageAt}, lastMessage: ${group.lastMessage})');
                                                        }

                                                        return Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          children: List.generate(
                                                              chatVar.length,
                                                              (chatVarIndex) {
                                                            final chatVarItem =
                                                                chatVar[
                                                                    chatVarIndex];
                                                            return Builder(
                                                              builder:
                                                                  (context) =>
                                                                      InkWell(
                                                                splashColor: Colors
                                                                    .transparent,
                                                                focusColor: Colors
                                                                    .transparent,
                                                                hoverColor: Colors
                                                                    .transparent,
                                                                highlightColor:
                                                                    Colors
                                                                        .transparent,
                                                                onTap:
                                                                    () async {
                                                                  context
                                                                      .pushNamed(
                                                                    ChatDetailWidget
                                                                        .routeName,
                                                                    queryParameters:
                                                                        {
                                                                      'chatDoc':
                                                                          serializeParam(
                                                                        chatVarItem,
                                                                        ParamType
                                                                            .Document,
                                                                      ),
                                                                    }.withoutNulls,
                                                                    extra: <String,
                                                                        dynamic>{
                                                                      'chatDoc':
                                                                          chatVarItem,
                                                                    },
                                                                  );
                                                                },
                                                                onLongPress:
                                                                    () async {
                                                                  await showAlignedDialog(
                                                                    context:
                                                                        context,
                                                                    isGlobal:
                                                                        false,
                                                                    avoidOverflow:
                                                                        false,
                                                                    targetAnchor: const AlignmentDirectional(
                                                                            0.0,
                                                                            0.0)
                                                                        .resolve(
                                                                            Directionality.of(context)),
                                                                    followerAnchor: const AlignmentDirectional(
                                                                            0.0,
                                                                            0.0)
                                                                        .resolve(
                                                                            Directionality.of(context)),
                                                                    builder:
                                                                        (dialogContext) {
                                                                      return Material(
                                                                        color: Colors
                                                                            .transparent,
                                                                        child:
                                                                            GestureDetector(
                                                                          onTap:
                                                                              () {
                                                                            FocusScope.of(dialogContext).unfocus();
                                                                            FocusManager.instance.primaryFocus?.unfocus();
                                                                          },
                                                                          child:
                                                                              SizedBox(
                                                                            width:
                                                                                150.0,
                                                                            child:
                                                                                ChatEditWidget(
                                                                              isPin: false,
                                                                              actionEdit: () async {
                                                                                await chatVarItem.reference.update(createChatsRecordData(
                                                                                  isPin: true,
                                                                                ));
                                                                              },
                                                                              delete: () async {
                                                                                await chatVarItem.reference.delete();
                                                                              },
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                  );
                                                                },
                                                                child:
                                                                    Container(
                                                                  width: double
                                                                      .infinity,
                                                                  height: 72.0,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryBackground,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12.0),
                                                                  ),
                                                                  child:
                                                                      Padding(
                                                                    padding: const EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                        12.0,
                                                                        12.0,
                                                                        12.0,
                                                                        12.0),
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Expanded(
                                                                          child:
                                                                              Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            children:
                                                                                [
                                                                              Stack(
                                                                                children: [
                                                                                  ClipRRect(
                                                                                    borderRadius: BorderRadius.circular(24.0),
                                                                                    child: CachedNetworkImage(
                                                                                      fadeInDuration: const Duration(milliseconds: 300),
                                                                                      fadeOutDuration: const Duration(milliseconds: 300),
                                                                                      imageUrl: valueOrDefault<String>(
                                                                                        chatVarItem.chatImageUrl,
                                                                                        'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fjurica-koletic-7YVZYZeITc8-unsplash.jpg?alt=media&token=d05a38c8-e024-4624-bdb3-82e4f7c6afab',
                                                                                      ),
                                                                                      width: 48.0,
                                                                                      height: 48.0,
                                                                                      fit: BoxFit.cover,
                                                                                    ),
                                                                                  ),
                                                                                  if (false)
                                                                                    Align(
                                                                                      alignment: const AlignmentDirectional(1.0, 1.0),
                                                                                      child: Container(
                                                                                        width: 12.0,
                                                                                        height: 12.0,
                                                                                        decoration: const BoxDecoration(
                                                                                          color: Color(0xFF10B981),
                                                                                          shape: BoxShape.circle,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                ],
                                                                              ),
                                                                              Column(
                                                                                mainAxisSize: MainAxisSize.max,
                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                children: [
                                                                                  Row(
                                                                                    mainAxisSize: MainAxisSize.min,
                                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                    children: [
                                                                                      Text(
                                                                                        chatVarItem.title.maybeHandleOverflow(
                                                                                          maxChars: 15,
                                                                                        ),
                                                                                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                              font: GoogleFonts.inter(
                                                                                                fontWeight: FontWeight.w500,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                              ),
                                                                                              color: const Color(0xFF1F2937),
                                                                                              fontSize: 16.0,
                                                                                              letterSpacing: 0.0,
                                                                                              fontWeight: FontWeight.w500,
                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                            ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                  Row(
                                                                                    mainAxisSize: MainAxisSize.max,
                                                                                    children: [
                                                                                      if (chatVarItem.lastMessageType == MessageType.image)
                                                                                        const Icon(
                                                                                          Icons.image,
                                                                                          color: Color(0xFF6B7280),
                                                                                          size: 18.0,
                                                                                        ),
                                                                                      Text(
                                                                                        valueOrDefault<String>(
                                                                                          chatVarItem.lastMessage,
                                                                                          'Let\'s Start a Chat',
                                                                                        ).maybeHandleOverflow(
                                                                                          maxChars: 15,
                                                                                          replacement: '…',
                                                                                        ),
                                                                                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                              font: GoogleFonts.inter(
                                                                                                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                              ),
                                                                                              letterSpacing: 0.0,
                                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                            ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ].divide(const SizedBox(height: 4.0)),
                                                                              ),
                                                                            ].divide(const SizedBox(width: 12.0)),
                                                                          ),
                                                                        ),
                                                                        Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceBetween,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.end,
                                                                          children: [
                                                                            Text(
                                                                              valueOrDefault<String>(
                                                                                dateTimeFormat("relative", chatVarItem.lastMessageAt),
                                                                                'N/A',
                                                                              ),
                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                    font: GoogleFonts.inter(
                                                                                      fontWeight: FontWeight.normal,
                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                    ),
                                                                                    color: const Color(0xFF6B7280),
                                                                                    fontSize: 12.0,
                                                                                    letterSpacing: 0.0,
                                                                                    fontWeight: FontWeight.normal,
                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                  ),
                                                                            ),
                                                                            Builder(
                                                                              builder: (context) {
                                                                                if (chatVarItem.lastMessageSeen.contains(currentUserReference) == false) {
                                                                                  return Visibility(
                                                                                    visible: !chatVarItem.lastMessageSeen.contains(currentUserReference),
                                                                                    child: Container(
                                                                                      width: 20.0,
                                                                                      height: 20.0,
                                                                                      decoration: const BoxDecoration(
                                                                                        color: Color(0xFF3B82F6),
                                                                                        shape: BoxShape.circle,
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                } else if ((chatVarItem.lastMessageSeen.contains(currentUserReference) == true) && (chatVarItem.lastMessageSent == currentUserReference)) {
                                                                                  return const Icon(
                                                                                    Icons.check,
                                                                                    color: Color(0xFF6B7280),
                                                                                    size: 16.0,
                                                                                  );
                                                                                } else {
                                                                                  return Container(
                                                                                    width: 5.0,
                                                                                    height: 5.0,
                                                                                    decoration: BoxDecoration(
                                                                                      color: FlutterFlowTheme.of(context).secondaryBackground,
                                                                                      shape: BoxShape.circle,
                                                                                    ),
                                                                                  );
                                                                                }
                                                                              },
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ).animateOnPageLoad(
                                                                animationsMap[
                                                                    'containerOnPageLoadAnimation5']!,
                                                                effects: [
                                                                  MoveEffect(
                                                                    curve: Curves
                                                                        .easeInOut,
                                                                    delay: valueOrDefault<
                                                                        double>(
                                                                      (chatVarIndex *
                                                                          48),
                                                                      0.0,
                                                                    ).ms,
                                                                    duration:
                                                                        600.0
                                                                            .ms,
                                                                    begin:
                                                                        const Offset(
                                                                            0.0,
                                                                            30.0),
                                                                    end: const Offset(
                                                                        0.0,
                                                                        0.0),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }),
                                                        );
                                                      },
                                                    ),
                                                  ].divide(const SizedBox(
                                                      height: 16.0)),
                                                ),
                                                if (false)
                                                  Container(
                                                    width: double.infinity,
                                                    height: 72.0,
                                                    decoration: BoxDecoration(
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .secondaryBackground,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(12.0,
                                                              12.0, 12.0, 12.0),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            children: [
                                                              Container(
                                                                width: 48.0,
                                                                height: 48.0,
                                                                decoration:
                                                                    const BoxDecoration(
                                                                  color: Color(
                                                                      0xFFDBEAFE),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                                child:
                                                                    const Align(
                                                                  alignment:
                                                                      AlignmentDirectional(
                                                                          0.0,
                                                                          0.0),
                                                                  child: Icon(
                                                                    Icons
                                                                        .people,
                                                                    color: Color(
                                                                        0xFF3B82F6),
                                                                    size: 24.0,
                                                                  ),
                                                                ),
                                                              ),
                                                              Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .spaceBetween,
                                                                    children: [
                                                                      Text(
                                                                        'UX Design Workshop',
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(
                                                                              font: GoogleFonts.inter(
                                                                                fontWeight: FontWeight.w500,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                              color: const Color(0xFF1F2937),
                                                                              fontSize: 16.0,
                                                                              letterSpacing: 0.0,
                                                                              fontWeight: FontWeight.w500,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                      ),
                                                                      Text(
                                                                        'Yesterday',
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(
                                                                              font: GoogleFonts.inter(
                                                                                fontWeight: FontWeight.normal,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                              color: const Color(0xFF6B7280),
                                                                              fontSize: 12.0,
                                                                              letterSpacing: 0.0,
                                                                              fontWeight: FontWeight.normal,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Text(
                                                                    'E mma: Here\'s the agenda for ...',
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.inter(
                                                                            fontWeight:
                                                                                FontWeight.normal,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).secondaryText,
                                                                          fontSize:
                                                                              14.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.normal,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ].divide(
                                                                    const SizedBox(
                                                                        height:
                                                                            4.0)),
                                                              ),
                                                            ].divide(
                                                                const SizedBox(
                                                                    width:
                                                                        12.0)),
                                                          ),
                                                          const Icon(
                                                            Icons.push_pin,
                                                            color: Color(
                                                                0xFF6B7280),
                                                            size: 16.0,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_model.loading == true)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      child: Align(
                        alignment: const AlignmentDirectional(0.0, 0.0),
                        child: Padding(
                          padding: const EdgeInsets.all(50.0),
                          child: SizedBox(
                            width: 150.0,
                            height: 150.0,
                            child: custom_widgets.FFlowSpinner(
                              width: 150.0,
                              height: 150.0,
                              backgroundColor: Colors.transparent,
                              spinnerColor:
                                  FlutterFlowTheme.of(context).primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
