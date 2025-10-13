import '/auth/base_auth_user_provider.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/event/event_component/event_component_widget.dart';
import '/custom_code/widgets/ai_announcements_summary.dart';
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

                // AI Announcements Summary Section
                _buildAISummarySection(context),

                // Recent Events Section
                _buildRecentEventsSection(context),

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
            const Color(0xFFF8FAFC), // Very light grey-white
            const Color(0xFFE2E8F0), // Light grey
            const Color(0xFFCBD5E1), // Medium grey-blue
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: const AlignmentDirectional(0.0, -1.0),
          end: const AlignmentDirectional(0, 1.0),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Message
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
                            color: const Color(0xFF1E293B), // Dark grey-blue
                            fontSize: 24.0,
                            fontWeight: FontWeight.w300,
                          ),
                    ),
                    Text(
                      userName,
                      style: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .override(
                            fontFamily: 'Inter',
                            color:
                                const Color(0xFF0F172A), // Very dark grey-blue
                            fontSize: 32.0,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('EEEE, MMMM d, y').format(now),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Inter',
                            color: const Color(0xFF475569), // Medium grey-blue
                            fontSize: 16.0,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ],
                );
              },
            ),

          const SizedBox(height: 24),

          // Workspace Info
          if (currentUserReference != null)
            StreamBuilder<UsersRecord>(
              stream: UsersRecord.getDocument(currentUserReference!),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData ||
                    !userSnapshot.data!.hasCurrentWorkspaceRef()) {
                  return Container(
                    padding: const EdgeInsets.all(16),
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
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: const Color(0xFF475569),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Join a Workspace',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      fontFamily: 'Inter',
                                      color: const Color(0xFF1E293B),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                'Connect with your team and start collaborating',
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      fontFamily: 'Inter',
                                      color: const Color(0xFF64748B),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        FFButtonWidget(
                          onPressed: () {
                            context.pushNamed('CreateWorkspace');
                          },
                          text: 'Join',
                          options: FFButtonOptions(
                            height: 36,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16, 0, 16, 0),
                            iconPadding: const EdgeInsetsDirectional.fromSTEB(
                                0, 0, 0, 0),
                            color: const Color(0xFF475569),
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                            elevation: 0,
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final workspaceRef = userSnapshot.data!.currentWorkspaceRef;
                return FutureBuilder<WorkspacesRecord>(
                  future: WorkspacesRecord.getDocumentOnce(workspaceRef!),
                  builder: (context, workspaceSnapshot) {
                    final workspace = workspaceSnapshot.data;
                    final workspaceName = workspace?.name ?? 'Loading...';
                    final hasLogo = workspace?.logoUrl.isNotEmpty ?? false;

                    return Container(
                      padding: const EdgeInsets.all(16),
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
                        children: [
                          Container(
                            width: 48,
                            height: 48,
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
                                      width: 48,
                                      height: 48,
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
                                            fontSize: 20,
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  workspaceName,
                                  style: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .override(
                                        fontFamily: 'Inter',
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Text(
                                  'Your workspace',
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        fontFamily: 'Inter',
                                        color: const Color(0xFF64748B),
                                      ),
                                ),
                              ],
                            ),
                          ),
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
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF64748B),
                                  size: 20,
                                ),
                                onSelected: (workspaceRef) async {
                                  // Handle "Join a new workspace" button click
                                  if (workspaceRef == null) {
                                    Navigator.of(context)
                                        .pop(); // Close the dropdown
                                    context.pushNamed(
                                      'MobileSettings',
                                      queryParameters: {
                                        'section': 'Workspace Management',
                                      },
                                    ); // Navigate to workspace management section
                                    return;
                                  }

                                  // Update user's current workspace
                                  final userRef = currentUserReference;
                                  if (userRef != null) {
                                    await userRef.update({
                                      'current_workspace_ref': workspaceRef,
                                    });

                                    // Update chat controller with new workspace
                                    try {
                                      final chatController =
                                          Get.find<ChatController>();
                                      chatController
                                          .updateCurrentWorkspace(workspaceRef);
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
                                          final isSelected = workspaceRef.id ==
                                              membership.workspaceRef?.id;

                                          return Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF1F5F9),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFFCBD5E1),
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    name.isNotEmpty
                                                        ? name[0].toUpperCase()
                                                        : 'W',
                                                    style: TextStyle(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 14,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                    color: isSelected
                                                        ? FlutterFlowTheme.of(
                                                                context)
                                                            .primary
                                                        : const Color(
                                                            0xFF1E293B),
                                                  ),
                                                ),
                                              ),
                                              if (isSelected)
                                                Icon(
                                                  Icons.check_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  size: 16,
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
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.of(context)
                                              .pop(); // Close the dropdown
                                          context.pushNamed(
                                            'MobileSettings',
                                            queryParameters: {
                                              'section': 'Workspace Management',
                                            },
                                          ); // Navigate to workspace management section
                                        },
                                        child: Container(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 8),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF1F5F9),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFFCBD5E1),
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.add_rounded,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Join a new workspace',
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
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

  Widget _buildAISummarySection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 0.0),
      child: AIAnnouncementsSummary(
        width: double.infinity,
        height: 320.0,
      ),
    ).animateOnPageLoad(animationsMap['aiSummaryOnPageLoadAnimation']!);
  }

  Widget _buildRecentEventsSection(BuildContext context) {
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
                'Recent Events',
                style: FlutterFlowTheme.of(context).headlineSmall.override(
                      fontFamily: 'Inter',
                      fontSize: 24.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              FFButtonWidget(
                onPressed: () {
                  context.pushNamed('Search');
                },
                text: 'View All',
                options: FFButtonOptions(
                  height: 32,
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                  iconPadding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                  color: FlutterFlowTheme.of(context).primary,
                  textStyle: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                  elevation: 0,
                  borderSide: const BorderSide(
                    color: Colors.transparent,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<EventsRecord>>(
            stream: queryEventsRecord(
              queryBuilder: (eventsRecord) => eventsRecord
                  .orderBy('created_time', descending: true)
                  .limit(3),
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  ),
                );
              }

              final events = snapshot.data!;
              if (events.isEmpty) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 48,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No events yet',
                          style: FlutterFlowTheme.of(context)
                              .titleMedium
                              .override(
                                fontFamily: 'Inter',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first event to get started',
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                fontFamily: 'Inter',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: events.map((event) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: EventComponentWidget(
                      imageCover: event.coverImageUrl,
                      category:
                          event.category.isNotEmpty ? event.category.first : '',
                      nameEvent: event.title,
                      date: event.startDate != null
                          ? DateFormat('MMM d, y').format(event.startDate!)
                          : '',
                      time: event.startDate != null
                          ? DateFormat('h:mm a').format(event.startDate!)
                          : '',
                      location: event.location,
                      speakers: event.speakers,
                      participant: event.participants.length,
                      eventRef: event.reference,
                      action: () async {
                        context.pushNamed(
                          'EventDetail',
                          pathParameters: {
                            'eventId': event.reference.id,
                          },
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ).animateOnPageLoad(animationsMap['recentEventsOnPageLoadAnimation']!);
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
                      fontSize: 24.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              FFButtonWidget(
                onPressed: () {
                  // Navigate to announcements
                },
                text: 'View All',
                options: FFButtonOptions(
                  height: 32,
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                  iconPadding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                  color: FlutterFlowTheme.of(context).primary,
                  textStyle: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                  elevation: 0,
                  borderSide: const BorderSide(
                    color: Colors.transparent,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<PostsRecord>>(
            stream: queryPostsRecord(
              queryBuilder: (postsRecord) => postsRecord
                  .orderBy('created_time', descending: true)
                  .limit(3),
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  ),
                );
              }

              final posts = snapshot.data!;
              if (posts.isEmpty) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.campaign,
                          size: 48,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No announcements yet',
                          style: FlutterFlowTheme.of(context)
                              .titleMedium
                              .override(
                                fontFamily: 'Inter',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back later for updates',
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                fontFamily: 'Inter',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: posts.map((post) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: FlutterFlowTheme.of(context).alternate,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.campaign,
                                color: FlutterFlowTheme.of(context).primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.postType.isNotEmpty
                                        ? post.postType
                                        : 'Announcement',
                                    style: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  Text(
                                    post.createdAt != null
                                        ? DateFormat('MMM d, y • h:mm a')
                                            .format(post.createdAt!)
                                        : 'Recently',
                                    style: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .override(
                                          fontFamily: 'Inter',
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (post.text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            post.text,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Inter',
                                ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
