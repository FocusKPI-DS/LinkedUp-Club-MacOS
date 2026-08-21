import '/auth/base_auth_user_provider.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/summerai_todos.dart';
import '/custom_code/widgets/todays_calendar_events.dart';
import '/custom_code/widgets/task_stats.dart';
import '/custom_code/widgets/app_update_dialog.dart';
import '/pages/desktop_chat/desktop_safe_user_builder.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
// import '/custom_code/widgets/productivity_trend_chart.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '/actions/actions.dart' as action_blocks;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/permissions_util.dart';
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

/// Staged load phases for Windows (avoids concurrent Firestore + shader crash).
enum _WindowsHomeLoadPhase { shell, stats, calendar, full }

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

  _WindowsHomeLoadPhase _windowsHomePhase = _WindowsHomeLoadPhase.shell;

  String? _actionItemAnnouncement;
  Timer? _actionItemAnnouncementTimer;
  final GlobalKey _homeStackKey = GlobalKey();
  final GlobalKey _headerGreetingRowKey = GlobalKey();

  double _announcementTop(bool isMobile) {
    const bannerHeight = 38.0;
    final rowBox =
        _headerGreetingRowKey.currentContext?.findRenderObject() as RenderBox?;
    final stackBox =
        _homeStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (rowBox != null &&
        stackBox != null &&
        rowBox.hasSize &&
        stackBox.hasSize) {
      final rowTop =
          rowBox.localToGlobal(Offset.zero, ancestor: stackBox).dy;
      return rowTop + (rowBox.size.height - bannerHeight) / 2;
    }
    final pagePaddingTop = isMobile ? 18.0 : 28.0;
    const rowHeight = 38.0;
    return pagePaddingTop + (rowHeight - bannerHeight) / 2;
  }

  void _showActionItemAnnouncement(String message) {
    _actionItemAnnouncementTimer?.cancel();
    setState(() => _actionItemAnnouncement = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    _actionItemAnnouncementTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _actionItemAnnouncement = null);
      }
    });
  }

  Widget _buildActionItemAnnouncementBanner(String message) {
    return Center(
      key: ValueKey(message),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());

    if (!kIsWeb && Platform.isWindows) {
      _windowsHomePhase = _WindowsHomeLoadPhase.shell;
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        for (final phase in [
          _WindowsHomeLoadPhase.stats,
          _WindowsHomeLoadPhase.calendar,
          _WindowsHomeLoadPhase.full,
        ]) {
          await Future.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          setState(() => _windowsHomePhase = phase);
        }
      });
    } else {
      _windowsHomePhase = _WindowsHomeLoadPhase.full;
    }

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
      if (loggedIn && !kIsWeb && !Platform.isWindows && !Platform.isLinux) {
        unawaited(
          () async {
            _model.isSuccess = await actions.ensureFcmToken(
              currentUserReference!,
            );
          }(),
        );
      }
      if (!kIsWeb && !Platform.isWindows && !Platform.isLinux) {
        unawaited(
          () async {
            await actions.updateAppBadge();
          }(),
        );
      }
      await action_blocks.homeCheck(context);
      // One-time (per version) update popup, shown while on the home page.
      // Reuses the established per-platform update dialogs; no-op on web.
      if (loggedIn && mounted) {
        unawaited(AppUpdateDialog.maybeShowUpdatePrompt(context));
      }
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
    _actionItemAnnouncementTimer?.cancel();
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

  bool get _isWindowsDesktop => !kIsWeb && Platform.isWindows;

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
          backgroundColor:
              const Color(0xFFF8FAFC), // Premium light gray background
          body: SafeArea(
            top: true,
            child: Stack(
              key: _homeStackKey,
              clipBehavior: Clip.none,
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      isMobile ? 20.0 : 40.0,
                      isMobile ? 18.0 : 28.0,
                      isMobile ? 20.0 : 40.0,
                      isMobile ? 24.0 : 40.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                if (_actionItemAnnouncement != null)
                  Positioned(
                    top: _announcementTop(isMobile),
                    left: isMobile ? 20.0 : 40.0,
                    right: isMobile ? 20.0 : 40.0,
                    child: IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _buildActionItemAnnouncementBanner(
                          _actionItemAnnouncement!,
                        ),
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
        // const ProductivityTrendChart(),
      ],
    );
  }

  // Desktop two-column layout (original)
  Widget _buildDesktopLayout(BuildContext context) {
    if (_isWindowsDesktop && _windowsHomePhase == _WindowsHomeLoadPhase.shell) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final showCalendar = !_isWindowsDesktop ||
        _windowsHomePhase.index >= _WindowsHomeLoadPhase.calendar.index;
    final showSummerAi = !_isWindowsDesktop ||
        _windowsHomePhase.index >= _WindowsHomeLoadPhase.full.index;
    final showStats = !_isWindowsDesktop ||
        _windowsHomePhase.index >= _WindowsHomeLoadPhase.stats.index;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showCalendar) ...[
                      _buildTodaysCalendarSection(context),
                      const SizedBox(height: 28),
                    ],
                    if (showStats) const TaskStats(),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: showSummerAi
                    ? _buildSummerAITasksSection(context)
                    : const SizedBox(height: 200),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildHeaderSection(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentUserReference != null)
          DesktopSafeUserBuilder(
            userRef: currentUserReference!,
            fetchOnce: fsGetUserOnce,
            builder: (context, user) {
              if (user == null) {
                return SizedBox(height: isMobile ? 10 : 20);
              }

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

              final greetingStyle = TextStyle(
                fontFamily: '.SF Pro Display',
                color: Color(0xFF1E293B),
                fontSize: isMobile ? 30 : 32,
                fontWeight: FontWeight.w500,
                letterSpacing: isMobile ? -0.4 : -0.5,
              );
              final nameStyle = TextStyle(
                fontFamily: '.SF Pro Display',
                color: Color(0xFF2563EB),
                fontSize: isMobile ? 30 : 32,
                fontWeight: FontWeight.w700,
                letterSpacing: isMobile ? -0.4 : -0.5,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting + name on one line
                  KeyedSubtree(
                    key: _headerGreetingRowKey,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$greeting, ',
                            style: greetingStyle,
                          ),
                          TextSpan(
                            text: userName,
                            style: nameStyle,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
      child: SummerAITodos(
        isMobile: isMobile,
        onShowAnnouncement: _showActionItemAnnouncement,
      ),
    );
  }
}
