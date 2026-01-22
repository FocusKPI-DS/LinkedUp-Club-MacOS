import '/auth/base_auth_user_provider.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/components/invite_friends_button_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/summerai_todos.dart';
import '/custom_code/widgets/todays_calendar_events.dart';
import '/custom_code/widgets/task_stats.dart';
import 'dart:async';
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/permissions_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'home_model.dart';
export 'home_model.dart';
import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:branchio_dynamic_linking_akp5u6/flutter_flow/custom_functions.dart'
    as branchio_dynamic_linking_akp5u6_functions;
import 'package:get/get.dart';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:share_plus/share_plus.dart';

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
        backgroundColor: Color(
            0xFFF8FAFF), // Subtle white tinted with blue (Color(0xFF2563EB))
        body: SafeArea(
          top: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      32.0, 32.0, 32.0, 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      _buildHeaderSection(context),

                      const SizedBox(height: 32),

                      // Two-column layout with equal heights
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Column
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Today's Schedule Card
                                  _buildTodaysCalendarSection(context),

                                  const SizedBox(height: 24),

                                  // Task Stats Section - will expand to match right column
                                  const Expanded(
                                    child: TaskStats(),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 24),

                            // Right Column
                            Expanded(
                              child: _buildSummerAITasksSection(context),
                            ),
                          ],
                        ),
                      ),

                      // Bottom spacing
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              // Invite friends buttons in top right
              Positioned(
                top: 32,
                right: 32,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                          onPressed: () => _showEmailInviteDialog(),
                          child: Icon(
                            CupertinoIcons.mail_solid,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                          onPressed: () => _showInviteDialog(context),
                          child: Icon(
                            CupertinoIcons.person_add_solid,
                            size: 17,
                          ),
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
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Column(
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$greeting, ',
                          style: const TextStyle(
                            fontFamily: '.SF Pro Display',
                            color: Color(0xFF1E293B),
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: userName,
                          style: const TextStyle(
                            fontFamily: '.SF Pro Display',
                            color: Color(0xFF2563EB),
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Here's your command center for today.",
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      color: Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    ).animateOnPageLoad(animationsMap['heroOnPageLoadAnimation']!);
  }

  Widget _buildTodaysCalendarSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const TodaysCalendarEvents(),
    );
  }


  String _getInviteMessage() {
    // Get current user's UID for personalized referral link
    final userUid = currentUserUid.isNotEmpty
        ? currentUserUid
        : (currentUserReference?.id ?? '');

    // Create personalized referral link
    final referralLink = 'https://lona.club/invite/$userUid';

    return 'Hey! I\'ve been using this app named Lona for communication, and it\'s amazing! It really boosts productivity and makes team collaboration so much easier. You should check it out!\n\nJoin me on Lona: $referralLink';
  }

  Future<void> _shareInviteMessage() async {
    // Open native iOS share sheet (like WhatsApp)
    // Get screen size for share position origin
    final size = MediaQuery.of(context).size;
    final sharePositionOrigin = Rect.fromLTWH(
      size.width / 2 - 100,
      size.height / 2,
      200,
      100,
    );

    await Share.share(
      _getInviteMessage(),
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  void _showInviteDialog(BuildContext context) async {
    // Show iOS 26+ adaptive dialog with invite options (iOS 26+ liquid glass effect)
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Invite Friends',
      message:
          'Share Lona with your friends and boost your team\'s productivity together!',
      icon: 'person.2.fill',
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Share',
          style: AlertActionStyle.primary,
          onPressed: () {
            _shareInviteMessage();
          },
        ),
      ],
    );
  }

  void _showEmailInviteDialog() {
    final emailController = TextEditingController();
    
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('Invite via Email'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: CupertinoTextField(
            controller: emailController,
            placeholder: 'Recipient Email',
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            child: Text('Send Invite'),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                Navigator.pop(dialogContext);
                return;
              }
              Navigator.pop(dialogContext);

              try {
                final userUid = currentUserUid.isNotEmpty
                    ? currentUserUid
                    : (currentUserReference?.id ?? '');
                final referralLink = 'https://lona.club/invite/$userUid';

                await actions.sendResendInvite(
                  email: email,
                  senderName: currentUserDisplayName,
                  referralLink: referralLink,
                );
                
                // Show green tick overlay
                _showSuccessTick();
              } catch (e) {
                // Silently fail
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessTick() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 0,
        right: 0,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: value,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    
    overlay.insert(entry);
    
    // Remove after 1.5 seconds
    Future.delayed(Duration(milliseconds: 1500), () {
      entry.remove();
    });
  }

  Widget _buildSummerAITasksSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const SummerAITodos(),
    );
  }
}
