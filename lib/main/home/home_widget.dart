import '/auth/base_auth_user_provider.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/paginated_notifications.dart';
import '/custom_code/widgets/summerai_todos.dart';
import '/custom_code/widgets/recent_news_announcements.dart';
import 'dart:async';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/permissions_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '/pages/desktop_chat/chat_controller.dart';
import 'home_model.dart';
export 'home_model.dart';

/// Beautiful Home Page with Hero Section, Quick Actions, and Activity Feed
class HomeWidget extends StatefulWidget {
  const HomeWidget({
    super.key,
  });

  static String routeName = 'Home';
  static String routePath = '/home';

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> with TickerProviderStateMixin {
  late HomeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      unawaited(
        () async {
          await actions.closekeyboard();
        }(),
      );
      unawaited(
        () async {
          await actions.dismissKeyboard(
            context,
          );
        }(),
      );
      if (loggedIn) {
        unawaited(
          () async {
            _model.isSuccess = await actions.ensureFcmToken(
              currentUserReference!,
            );
          }(),
        );
      }
      unawaited(
        () async {
          await actions.updateAppBadge();
        }(),
      );
      await action_blocks.homeCheck(context);
      if (!(await getPermissionStatus(locationPermission))) {
        await requestPermission(locationPermission);
      }
    });

    animationsMap.addAll({
      'heroOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 800.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 800.0.ms,
            begin: const Offset(0.0, 30.0),
            end: const Offset(0.0, 0.0),
          ),
        ],
      ),
      'aiSummaryOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 200.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 200.0.ms,
            duration: 600.0.ms,
            begin: const Offset(0.0, 30.0),
            end: const Offset(0.0, 0.0),
          ),
        ],
      ),
      'recentEventsOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 400.0.ms,
            duration: 600.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 400.0.ms,
            duration: 600.0.ms,
            begin: const Offset(0.0, 30.0),
            end: const Offset(0.0, 0.0),
          ),
        ],
      ),
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Hero Section
                _buildHeroSection(context),

                // SummerAI Tasks Section
                _buildSummerAITasksSection(context),

                // Recent Activity Section
                _buildRecentActivitySection(context),

                // Recent Announcements Section
                _buildRecentAnnouncementsSection(context),

                // Bottom spacing
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEFF6FF), // Blue-50
            Colors.white,
            const Color(0xFFF8FAFC), // Slate-50
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row - Greeting and Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentUserReference != null)
                      StreamBuilder<UsersRecord>(
                        stream: UsersRecord.getDocument(currentUserReference!),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(height: 20);
                          }

                          final user = snapshot.data!;
                          final userName = user.displayName.isNotEmpty
                              ? user.displayName
                              : user.email.split('@')[0];

                          final now = DateTime.now();
                          final hour = now.hour;
                          String greeting;
                          if (hour < 12) {
                            greeting = 'Good Morning';
                          } else if (hour < 17) {
                            greeting = 'Good Afternoon';
                          } else {
                            greeting = 'Good Evening';
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting,',
                                style: FlutterFlowTheme.of(context)
                                    .headlineSmall
                                    .override(
                                      fontFamily: 'Inter',
                                      color: const Color(0xFF1E293B),
                                      fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              400
                                          ? 16.0
                                          : MediaQuery.of(context).size.width <
                                                  600
                                              ? 20.0
                                              : 24.0,
                                      fontWeight: FontWeight.w700,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                userName,
                                style: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .override(
                                      fontFamily: 'Inter',
                                      color:
                                          const Color(0xFF2563EB), // Blue-600
                                      fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              400
                                          ? 20.0
                                          : MediaQuery.of(context).size.width <
                                                  600
                                              ? 26.0
                                              : 32.0,
                                      fontWeight: FontWeight.w700,
                                    ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('EEEE, MMMM d, y').format(now),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Inter',
                                      color: const Color(0xFF475569),
                                      fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              400
                                          ? 12.0
                                          : MediaQuery.of(context).size.width <
                                                  600
                                              ? 14.0
                                              : 16.0,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bottom section - Workspace Info
          if (currentUserReference != null)
            StreamBuilder<UsersRecord>(
              stream: UsersRecord.getDocument(currentUserReference!),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData ||
                    !userSnapshot.data!.hasCurrentWorkspaceRef()) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1).withOpacity(0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E293B).withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: const Color(0xFF475569),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Join Workspace',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    color: const Color(0xFF64748B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                final workspaceRef = userSnapshot.data!.currentWorkspaceRef;
                return StreamBuilder<WorkspacesRecord>(
                  stream: WorkspacesRecord.getDocument(workspaceRef!),
                  builder: (context, workspaceSnapshot) {
                    final workspace = workspaceSnapshot.data;
                    final workspaceName = workspace?.name ?? 'Loading...';
                    final hasLogo = workspace?.logoUrl.isNotEmpty ?? false;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1).withOpacity(0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E293B).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: hasLogo
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: workspace?.logoUrl ?? '',
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Center(
                                        child: Text(
                                          workspaceName.isNotEmpty
                                              ? workspaceName[0].toUpperCase()
                                              : 'W',
                                          style: TextStyle(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      workspaceName.isNotEmpty
                                          ? workspaceName[0].toUpperCase()
                                          : 'W',
                                      style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                workspaceName,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Inter',
                                      color: const Color(0xFF1E293B),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Your workspace',
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      fontFamily: 'Inter',
                                      color: const Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width < 400
                                  ? 4
                                  : MediaQuery.of(context).size.width < 600
                                      ? 6
                                      : 8),
                          // Workspace Switch Dropdown
                          StreamBuilder<List<WorkspaceMembersRecord>>(
                            stream: queryWorkspaceMembersRecord(
                              queryBuilder: (workspaceMembersRecord) =>
                                  workspaceMembersRecord.where('user_ref',
                                      isEqualTo: currentUserReference),
                            ),
                            builder: (context, membershipsSnapshot) {
                              if (!membershipsSnapshot.hasData ||
                                  membershipsSnapshot.data!.length <= 1) {
                                return const SizedBox.shrink();
                              }

                              final memberships = membershipsSnapshot.data!;
                              return PopupMenuButton<DocumentReference?>(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF64748B),
                                  size: MediaQuery.of(context).size.width < 400
                                      ? 16
                                      : MediaQuery.of(context).size.width < 600
                                          ? 18
                                          : 20,
                                ),
                                offset: Offset(0, 50),
                                color: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 8,
                                onSelected: (selectedWorkspaceRef) async {
                                  // Handle "Join a new workspace" button click
                                  if (selectedWorkspaceRef == null) {
                                    context.pushNamed(
                                      'MobileSettings',
                                      queryParameters: {
                                        'section': 'Workspace Management',
                                      },
                                    );
                                    return;
                                  }

                                  // Update user's current workspace
                                  final userRef = currentUserReference;
                                  if (userRef != null) {
                                    await userRef.update({
                                      'current_workspace_ref':
                                          selectedWorkspaceRef,
                                    });

                                    // Update chat controller with new workspace
                                    try {
                                      final chatController =
                                          Get.find<ChatController>();
                                      chatController.updateCurrentWorkspace(
                                          selectedWorkspaceRef);
                                    } catch (e) {
                                      // ChatController not found
                                    }

                                    // Show confirmation
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Workspace switched'),
                                        duration: Duration(seconds: 2),
                                        backgroundColor:
                                            const Color(0xFF34C759),
                                      ),
                                    );

                                    // Refresh the page
                                    safeSetState(() {});
                                  }
                                },
                                itemBuilder: (context) {
                                  final workspaceItems =
                                      memberships.map((membership) {
                                    return PopupMenuItem<DocumentReference?>(
                                      value: membership.workspaceRef,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: FutureBuilder<WorkspacesRecord>(
                                        future:
                                            WorkspacesRecord.getDocumentOnce(
                                          membership.workspaceRef ??
                                              FirebaseFirestore.instance
                                                  .collection('workspaces')
                                                  .doc('placeholder'),
                                        ),
                                        builder: (context, ws) {
                                          final name = ws.hasData
                                              ? ws.data?.name ?? 'Loading...'
                                              : 'Loading...';
                                          final hasLogo = ws.hasData &&
                                              (ws.data?.logoUrl.isNotEmpty ??
                                                  false);
                                          final logoUrl =
                                              ws.data?.logoUrl ?? '';

                                          return Row(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: hasLogo
                                                    ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child:
                                                            CachedNetworkImage(
                                                          imageUrl: logoUrl,
                                                          width: 40,
                                                          height: 40,
                                                          fit: BoxFit.cover,
                                                          placeholder:
                                                              (context, url) =>
                                                                  Center(
                                                            child: Text(
                                                              name.isNotEmpty
                                                                  ? name[0]
                                                                      .toUpperCase()
                                                                  : 'W',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ),
                                                          errorWidget: (context,
                                                                  url, error) =>
                                                              Center(
                                                            child: Text(
                                                              name.isNotEmpty
                                                                  ? name[0]
                                                                      .toUpperCase()
                                                                  : 'W',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : Center(
                                                        child: Text(
                                                          name.isNotEmpty
                                                              ? name[0]
                                                                  .toUpperCase()
                                                              : 'W',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    if (ws.hasData &&
                                                        ws.data?.description
                                                                .isNotEmpty ==
                                                            true)
                                                      Text(
                                                        ws.data!.description,
                                                        style: TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color: Colors.white
                                                              .withOpacity(0.6),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    );
                                  }).toList();

                                  // Add "Join a new workspace" button
                                  workspaceItems.add(
                                    PopupMenuItem<DocumentReference?>(
                                      value: null,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.add_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Join New Workspace',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  return workspaceItems;
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    ).animateOnPageLoad(animationsMap['heroOnPageLoadAnimation']!);
  }

  Widget _buildSummerAITasksSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 0.0),
      child: const SummerAITodos(),
    ).animateOnPageLoad(animationsMap['aiSummaryOnPageLoadAnimation']!);
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: FlutterFlowTheme.of(context).headlineSmall.override(
                  fontFamily: 'Inter',
                  fontSize: MediaQuery.of(context).size.width < 400
                      ? 18.0
                      : MediaQuery.of(context).size.width < 600
                          ? 20.0
                          : 24.0,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 400,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: FlutterFlowTheme.of(context).alternate,
              ),
            ),
            child: currentUserReference != null
                ? PaginatedNotifications(
                    userRef: currentUserReference!,
                    width: double.infinity,
                    height: 400,
                  )
                : Center(
                    child: Text(
                      'Please log in to view activity',
                      style: FlutterFlowTheme.of(context).bodyMedium,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAnnouncementsSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Announcements',
                style: FlutterFlowTheme.of(context).headlineSmall.override(
                      fontFamily: 'Inter',
                      fontSize:
                          MediaQuery.of(context).size.width < 600 ? 20.0 : 24.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 16),
          const RecentNewsAnnouncements(),
        ],
      ),
    );
  }
}
