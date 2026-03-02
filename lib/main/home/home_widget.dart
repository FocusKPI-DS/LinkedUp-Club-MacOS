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
import '/custom_code/widgets/productivity_trend_chart.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/permissions_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // Helper method to detect if we're on mobile (iOS or mobile web)
  bool _isMobile(BuildContext context) {
    if (kIsWeb) {
      // Check if web is mobile by screen width
      final screenWidth = MediaQuery.of(context).size.width;
      return screenWidth < 768; // Mobile web threshold
    }
    // Native iOS or Android
    return !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  }


  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    
    final isMobile = _isMobile(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Absorb all scroll notifications to prevent tab bar from minimizing/blurring
        return true;
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: const Color(0xFFF8FAFC), // Premium light gray background
          body: SafeArea(
            top: true,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      isMobile ? 20.0 : 40.0,
                      isMobile ? 24.0 : 40.0,
                      isMobile ? 20.0 : 40.0,
                      isMobile ? 24.0 : 40.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        _buildHeaderSection(context, isMobile),

                        SizedBox(height: isMobile ? 24.0 : 40.0),

                        // Conditional layout based on platform
                        if (isMobile)
                          // Mobile: Single column layout
                          _buildMobileLayout(context)
                        else
                          // Desktop: Two-column layout
                          _buildDesktopLayout(context),

                        // Bottom spacing
                        SizedBox(height: isMobile ? 20.0 : 40.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Mobile-optimized single column layout
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Task Stats Section (compact for mobile)
        const TaskStats(),
        
        const SizedBox(height: 20),
        
        // Today's Schedule Card
        _buildTodaysCalendarSection(context),
        
        const SizedBox(height: 20),
        
        // Action Items Section
        _buildSummerAITasksSection(context),
        
        const SizedBox(height: 20),
        
        // Productivity Trend Chart
        const ProductivityTrendChart(),
      ],
    );
  }

  // Desktop two-column layout (original)
  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Two-column section
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Today's Schedule Card
                    _buildTodaysCalendarSection(context),

                    const SizedBox(height: 28),

                    // Task Stats Section
                    const TaskStats(),
                  ],
                ),
              ),

              const SizedBox(width: 28),

              // Right Column - matches left column height
              Expanded(
                child: _buildSummerAITasksSection(context),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 28),
        
        // Productivity Trend Chart - Full Width
        const ProductivityTrendChart(),
      ],
    );
  }

  Widget _buildHeaderSection(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add top spacing
        SizedBox(height: isMobile ? 20.0 : 32.0),
        if (currentUserReference != null)
          StreamBuilder<UsersRecord>(
            stream: UsersRecord.getDocument(currentUserReference!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return SizedBox(height: isMobile ? 10 : 20);
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
                  // First line: Greeting + Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          greeting,
                          style: TextStyle(
                            fontFamily: '.SF Pro Display',
                            color: Color(0xFF1E293B),
                            fontSize: isMobile ? 30 : 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: isMobile ? -0.4 : -0.5,
                          ),
                        ),
                      ),
                      Row(
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
                                  size: isMobile ? 16 : 17,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 8.0 : 12.0),
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
                                  size: isMobile ? 16 : 17,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 4 : 6),
                  // Second line: User's name
                  Text(
                    userName,
                    style: TextStyle(
                      fontFamily: '.SF Pro Display',
                      color: Color(0xFF2563EB),
                      fontSize: isMobile ? 30 : 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: isMobile ? -0.4 : -0.5,
                    ),
                  ),
                  SizedBox(height: isMobile ? 6 : 8),
                  Text(
                    "Here's your command center for today.",
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      color: Color(0xFF64748B),
                      fontSize: isMobile ? 16 : 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: isMobile ? -0.1 : -0.2,
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
    final isMobile = _isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: isMobile ? 12 : 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: isMobile ? 4 : 6,
            offset: const Offset(0, 1),
            spreadRadius: 0,
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
    final isMobile = _isMobile(context);
    // On mobile, set a fixed height to ensure the card fills properly
    // Calculate based on screen height for iOS
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = isMobile 
        ? (screenHeight * 0.5).clamp(400.0, 600.0) // 50% of screen, 400-600px
        : null; // Desktop uses intrinsic height
    
    return Container(
      // On mobile, use fixed height; on desktop, use intrinsic size
      height: cardHeight,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: isMobile ? 12 : 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: isMobile ? 4 : 6,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: SummerAITodos(isMobile: isMobile),
    );
  }
}
