import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';

// Import for macOS camera delegate
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:image_picker_macos/image_picker_macos.dart';

import '/custom_code/actions/index.dart' as actions;
import '/pages/mobile_assistant/mobile_assistant_widget.dart';
import '/pages/mobile_settings/mobile_settings_widget.dart';
import '/main/home/home_widget.dart';
// import '/pages/chat/chat/chat_widget.dart'; // Commented out - using MobileChat (now called Chat) instead
import '/pages/mobile_chat/mobile_chat_widget.dart';
import '/pages/desktop_chat/desktop_chat_widget.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';
import 'backend/backend.dart';
import 'pages/desktop_chat/chat_controller.dart';
import 'backend/firebase/firebase_config.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/nav/nav.dart';
import 'flutter_flow/revenue_cat_util.dart' as revenue_cat;
import 'index.dart';

import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:branchio_dynamic_linking_akp5u6/library_values.dart'
    as branchio_dynamic_linking_akp5u6_library_values;
import 'package:linkedup/backend/schema/structs/index.dart';
import 'package:linkedup/custom_code/services/web_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    GoRouter.optionURLReflectsImperativeAPIs = true;

    // Configure image picker for macOS
    if (!kIsWeb && Platform.isMacOS) {
      ImagePickerPlatform.instance = ImagePickerMacOS();
    }

    // Only use path URL strategy on web
    if (kIsWeb) {
      usePathUrlStrategy();
    }

    // Initialize Firebase first
    await initFirebase();

    // Initialize web notifications (only when tab is open)
    if (kIsWeb) {
      await WebNotificationService.instance.initialize();
    }

    // Initialize push notifications asynchronously (non-blocking)
    _initializePushNotificationsAsync();

    // Initialize app state
    final appState = FFAppState();
    await appState.initializePersistedState();

    // Initialize RevenueCat with error handling (disabled on macOS for App Store review)
    if (!kIsWeb && !Platform.isMacOS) {
      try {
        await revenue_cat.initialize(
          "appl_gYrKTEbjDTBkjDuoTAZxGQtSKMW",
          "goog_JKqkobkHgNHXsFahQSZcGrElrkO",
          loadDataAfterLaunch: true,
        );
      } catch (e) {
        // RevenueCat initialization failed
      }
    }

    // Handle app badge (only on mobile platforms)
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      try {
        if (currentUser != null) {
          await actions.setupAppBadgeListener();
          await actions.updateAppBadge();
        } else {
          await actions.clearAppBadge();
        }
      } catch (e) {
        // App badge setup failed
      }
    }

    // Initialize Branch SDK (only on supported platforms)
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      try {
        // Initialize Branch SDK configuration
        branchio_dynamic_linking_akp5u6_library_values.FFLibraryValues()
            .branchApiKey = 'key_live_dyCbtxID0DMYXy8GGLsHEbgjrxl7Es3w';
        branchio_dynamic_linking_akp5u6_library_values.FFLibraryValues()
            .branchLinkDomain = 'linkedupclub.app.link';
        branchio_dynamic_linking_akp5u6_library_values.FFLibraryValues()
            .isTestMode = false;
        branchio_dynamic_linking_akp5u6_library_values.FFLibraryValues()
            .branchAlternateLinkDomain = 'linkedupclub-alternate.app.link';

        await branchio_dynamic_linking_akp5u6_actions.initBranch();
      } catch (e) {
        // Branch SDK initialization failed
      }
    }

    runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => appState,
        ),
      ],
      child: MyApp(),
    ));
  } catch (e) {
    // Error during app initialization
    // Run app with minimal configuration if initialization fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('App initialization failed'),
              const Text('Please restart the app'),
            ],
          ),
        ),
      ),
    ));
  }
}

/// Initialize push notifications asynchronously to avoid blocking app startup
void _initializePushNotificationsAsync() async {
  // Handle web platform FCM notifications
  if (kIsWeb) {
    try {
      // Listen for foreground FCM messages (when tab is open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('🔔 [WEB] FOREGROUND FCM NOTIFICATION RECEIVED!');
        print('   Title: ${message.notification?.title}');
        print('   Body: ${message.notification?.body}');
        print('   Data: ${message.data}');

        // Show browser notification for foreground messages (force show for FCM)
        WebNotificationService.instance.showMessageNotification(
          title: message.notification?.title ?? 'New Notification',
          body: message.notification?.body ?? 'You have a new notification',
          forceShow: true, // Always show FCM notifications
        );
      });

      // Listen for notification taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('🔔 [WEB] FCM notification tapped!');
        print('   Title: ${message.notification?.title}');
        print('   Data: ${message.data}');
      });

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        print('🔄 [WEB] FCM token refreshed: ${newToken.substring(0, 10)}...');
      });

      print('✅ Web FCM notification handlers initialized');
    } catch (e) {
      print('❌ Web FCM notification setup failed: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }
  // Handle macOS/iOS platforms
  else if (Platform.isMacOS || Platform.isIOS) {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request notification permission with more aggressive settings
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        carPlay: false,
        criticalAlert: false,
      );

      print(
          '🔔 Push notification authorization status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        print(
            '✅ Notifications authorized! Setting foreground presentation options...');

        // Show system banners while app is in foreground
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        print('✅ Foreground notification presentation options set!');

        // ❌ REMOVED: Don't interfere with APNS registration
        // The fcmTokenUserStream (line 298) and ensureFcmToken() handle this properly
        // await _getFCMTokenWithRetry(messaging);

        // Listen for foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('🔔 FOREGROUND NOTIFICATION RECEIVED!');
          print('   Title: ${message.notification?.title}');
          print('   Body: ${message.notification?.body}');
          print('   Data: ${message.data}');
          // Note: With setForegroundNotificationPresentationOptions, system will show notification
        });

        // Listen for notification taps
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          // Notification tapped
        });

        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          print('🔄 FCM token refreshed: ${newToken.substring(0, 10)}...');
        });
      } else {
        print(
            '❌ Notifications NOT authorized! Status: ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('❌ Push notification setup failed: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }
}

// ❌ DISABLED: These functions were interfering with APNS registration on macOS
// The proper token registration happens via:
// 1. fcmTokenUserStream (line 298) - automatic stream-based registration
// 2. ensureFcmToken() called from home/discover pages - manual registration
//
// /// Get FCM token with simple retry (only 2 attempts)
// Future<void> _getFCMTokenWithRetry(FirebaseMessaging messaging) async {
//   try {
//     // Try immediately first
//     String? apnsToken = await messaging.getAPNSToken();
//     if (apnsToken != null) {
//       await _getFCMTokenWhenReady(messaging);
//       return;
//     }
//
//     // Wait 5 seconds and try once more
//     Timer(Duration(seconds: 5), () async {
//       try {
//         String? apnsToken = await messaging.getAPNSToken();
//         if (apnsToken != null) {
//           await _getFCMTokenWhenReady(messaging);
//         }
//       } catch (e) {
//         // Error on second attempt
//       }
//     });
//   } catch (e) {
//     // Error in FCM token setup
//   }
// }
//
// /// Get FCM token when APNS is ready
// Future<void> _getFCMTokenWhenReady(FirebaseMessaging messaging) async {
//   try {
//     await messaging.getToken();
//     // FCM token obtained or null
//   } catch (e) {
//     // Error getting FCM token
//   }
// }

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use desktop-appropriate scroll physics for web and macOS
    if (kIsWeb || (!kIsWeb && Platform.isMacOS)) {
      return const BouncingScrollPhysics();
    }
    return super.getScrollPhysics(context);
  }

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Use desktop-appropriate scrollbars for web and macOS
    if (kIsWeb || (!kIsWeb && Platform.isMacOS)) {
      return Scrollbar(
        controller: details.controller,
        child: child,
      );
    }
    return super.buildScrollbar(context, child, details);
  }
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;

  final authUserSub = authenticatedUserStream.listen((user) {
    // RevenueCat disabled on macOS for App Store compliance
    if (!kIsWeb && !Platform.isMacOS) {
      revenue_cat.login(user?.uid);
    }
  });
  // ❌ DISABLED: Causes race condition with ensureFcmToken() called from home/discover
  // The manual ensureFcmToken() in home_widget.dart (line 71) handles token registration
  // final fcmTokenSub = fcmTokenUserStream.listen((_) {});

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = linkedupFirebaseUserStream()
      ..listen((user) {
        // Only update if the widget is still mounted to prevent state errors
        if (mounted) {
          _appStateNotifier.update(user);
        }
      });
    jwtTokenStream.listen((_) {});
    // Show loading page immediately, hide it when initialization is complete
    _initializeAppAsync();
  }

  @override
  void dispose() {
    authUserSub.cancel();
    // fcmTokenSub.cancel(); // Commented out since fcmTokenSub is disabled
    super.dispose();
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
      });

  /// Optimize app initialization to show loading page immediately
  Future<void> _initializeAppAsync() async {
    try {
      // Wait for essential services to initialize in parallel
      await Future.wait([
        // Wait for user stream to emit at least once (with graceful timeout handling)
        userStream.first.timeout(
          const Duration(milliseconds: 3000),
          onTimeout: () {
            // User stream timeout - continuing with initialization
            return linkedupFirebaseUserStream().first.then((user) => user);
          },
        ),
        // Keep loading page for at least 1000ms
        Future.delayed(const Duration(milliseconds: 1000)),
      ]);
    } catch (e) {
      // App initialization error - continue anyway
    } finally {
      // Always hide loading page, even if there's an error
      if (mounted) {
        _appStateNotifier.stopShowingSplashImage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Lona',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
        // Use platform-appropriate configurations
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}

class NavBarPage extends StatefulWidget {
  const NavBarPage({
    super.key,
    this.initialPage,
    this.page,
    this.disableResizeToAvoidBottomInset = false,
  });

  final String? initialPage;
  final Widget? page;
  final bool disableResizeToAvoidBottomInset;

  @override
  _NavBarPageState createState() => _NavBarPageState();
}

/// This is the private State class that goes with NavBarPage.
class _NavBarPageState extends State<NavBarPage> {
  String _currentPageName = 'Home';
  late Widget? _currentPage;
  bool _isChatOpen = false;

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;
  }

  void _setCurrentPageName(String pageName, Map<String, Widget> tabs) {
    // Ensure the page name exists in tabs, fallback to 'Home' if not
    if (tabs.containsKey(pageName)) {
      _currentPageName = pageName;
      // Clear news indicator when Announcements page is opened
      if (pageName == 'Announcements') {
        FFAppState().newsPageLastOpened = DateTime.now();
      }
      // Clear chat indicator when Chat page is opened
      if (pageName == 'DesktopChat' || pageName == 'MobileChat') {
        FFAppState().chatPageLastOpened = DateTime.now();
      }
    } else {
      _currentPageName = 'Home';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      'Home': const HomeWidget(),
      // 'Chat': const ChatWidget(), // Commented out - using MobileChat (now called Chat) instead
      'MobileChat': MobileChatWidget(
        onChatStateChanged: (isChatOpen) {
          setState(() {
            _isChatOpen = isChatOpen;
          });
        },
      ),
      'DesktopChat': const DesktopChatWidget(), // Desktop chat for macOS
      'AIAssistant': const AIAssistantWidget(),
      'MobileAssistant': const MobileAssistantWidget(), // Mobile AI Assistant
      // 'Discover': const DiscoverWidget(), // Commented out since Home serves the same purpose
      'Announcements': const FeedWidget(),
      // 'Settings': const ProfileWidget(),
      'ProfileSettings': const ProfileSettingsWidget(),
      'MobileSettings': const MobileSettingsWidget(),
    };

    // Create a mapping for the navbar items to their corresponding tab indices
    final navItemToIndex = {
      'Home': 0,
      // 'Chat': 1, // Commented out - using MobileChat instead
      'MobileChat': 1, // Chat (renamed from Mobile Chat) - for iOS
      'DesktopChat': 1, // Desktop Chat - for macOS
      'AIAssistant': 2, // Desktop AI Assistant
      'MobileAssistant': 2, // Mobile AI Assistant - for iOS
      // 'Discover': 3, // Commented out
      'Announcements': 3, // Updated indices
      'ProfileSettings': 4, // Settings
      'MobileSettings': 4, // Mobile Settings
    };

    final currentIndex = navItemToIndex[_currentPageName] ?? 0;

    // Platform-specific layout
    // Web and macOS use desktop layout with vertical sidebar
    // iOS uses mobile layout with bottom navigation
    if (!kIsWeb && Platform.isIOS) {
      return Scaffold(
        resizeToAvoidBottomInset: !widget.disableResizeToAvoidBottomInset,
        body: _currentPage ?? tabs[_currentPageName] ?? tabs['Home']!,
        bottomNavigationBar: _isChatOpen
            ? null
            : _buildHorizontalNavBar(tabs, currentIndex, navItemToIndex),
      );
    } else {
      // Web and macOS - Use desktop layout with vertical sidebar
      return Scaffold(
        resizeToAvoidBottomInset: !widget.disableResizeToAvoidBottomInset,
        body: Row(
          children: [
            // Vertical Navigation Bar
            _buildVerticalNavBar(tabs, currentIndex, navItemToIndex),
            // Main Content Area
            Expanded(
              child: _currentPage ?? tabs[_currentPageName] ?? tabs['Home']!,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildNewsUnreadIndicator() {
    return StreamBuilder<List<PostsRecord>>(
      stream: queryPostsRecord(
        queryBuilder: (posts) => posts
            .where('post_type', isEqualTo: 'News')
            .orderBy('created_at', descending: true)
            .limit(1),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final newsPosts = snapshot.data!;
        if (newsPosts.isEmpty) {
          return SizedBox.shrink();
        }

        final latestNews = newsPosts.first;
        final newsCreatedAt = latestNews.createdAt;
        if (newsCreatedAt == null) {
          return SizedBox.shrink();
        }

        // Check if there's new news within 48 hours
        final cutoff = DateTime.now().subtract(const Duration(hours: 48));
        if (newsCreatedAt.isBefore(cutoff)) {
          return SizedBox.shrink();
        }

        // Check if News page was opened after the latest news was posted
        final lastOpened = FFAppState().newsPageLastOpened;
        if (lastOpened != null && lastOpened.isAfter(newsCreatedAt)) {
          return SizedBox.shrink();
        }

        // Show red dot indicator
        return Positioned(
          right: -4,
          top: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(
                color: Color(0xFF2D3142), // Background color of navbar
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatUnreadIndicator() {
    if (currentUserReference == null) {
      return SizedBox.shrink();
    }

    return StreamBuilder<List<ChatsRecord>>(
      stream: queryChatsRecord(
        queryBuilder: (chats) => chats
            .where('members', arrayContains: currentUserReference)
            .orderBy('last_message_at', descending: true),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final chats = snapshot.data!;
        if (chats.isEmpty) {
          return SizedBox.shrink();
        }

        // Check if there's any unread message in any chat
        bool hasUnread = false;
        DateTime? latestUnreadTime;

        for (final chat in chats) {
          // Check if current user has unread messages in this chat
          if (chat.lastMessage.isNotEmpty &&
              chat.lastMessageSent != currentUserReference &&
              !chat.lastMessageSeen.contains(currentUserReference)) {
            hasUnread = true;
            if (chat.lastMessageAt != null) {
              if (latestUnreadTime == null ||
                  chat.lastMessageAt!.isAfter(latestUnreadTime)) {
                latestUnreadTime = chat.lastMessageAt;
              }
            }
          }
        }

        if (!hasUnread) {
          return SizedBox.shrink();
        }

        // Check if Chat page was opened after the latest unread message
        final lastOpened = FFAppState().chatPageLastOpened;
        if (lastOpened != null &&
            latestUnreadTime != null &&
            lastOpened.isAfter(latestUnreadTime)) {
          return SizedBox.shrink();
        }

        // Show red dot indicator
        return Positioned(
          right: -4,
          top: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(
                color: Color(0xFF2D3142), // Background color of navbar
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalNavBar(Map<String, Widget> tabs, int currentIndex,
      Map<String, int> navItemToIndex) {
    final navItems = [
      {
        'icon': Icons.home_rounded,
        'label': 'Home',
        'page': 'Home',
      },
      // {
      //   'icon': Icons.chat_rounded,
      //   'label': 'Chat',
      //   'page': 'Chat',
      // }, // Commented out - using DesktopChat for macOS and web
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'label': 'Chat',
        'page': 'DesktopChat', // Desktop chat for macOS and web
      },
      {
        'icon': 'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
        'label': 'LonaAI',
        'page': 'AIAssistant',
      },
      {
        'icon': Icons.campaign_rounded,
        'label': 'News',
        'page': 'Announcements',
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Settings',
        'page': 'ProfileSettings', // Desktop settings for macOS/web
      },
    ];

    return Container(
      width: 100,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Color(0xFF2D3142),
        border: Border(
          right: BorderSide(
            color: Color(0xFF374151),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Workspace Name at top (like Slack)
          if (currentUserReference != null)
            StreamBuilder<UsersRecord>(
              stream: UsersRecord.getDocument(currentUserReference ??
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc('placeholder')),
              builder: (context, snapshot) {
                if (!snapshot.hasData || currentUserReference == null) {
                  return SizedBox(height: 20);
                }

                final currentUser = snapshot.data!;

                // Get all workspace memberships
                return StreamBuilder<List<WorkspaceMembersRecord>>(
                  stream: queryWorkspaceMembersRecord(
                    queryBuilder: (q) =>
                        q.where('user_ref', isEqualTo: currentUserReference),
                  ),
                  builder: (context, membershipSnapshot) {
                    if (!membershipSnapshot.hasData) {
                      return SizedBox(height: 20);
                    }

                    final memberships = membershipSnapshot.data!;

                    // If no workspace, show message
                    if (!currentUser.hasCurrentWorkspaceRef()) {
                      return Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(
                            top: 16, bottom: 20, left: 8, right: 8),
                        padding:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFF374151),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No Workspace',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    // Show current workspace with switcher
                    final workspaceRef = currentUser.currentWorkspaceRef;
                    if (workspaceRef == null) {
                      return Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(
                            top: 16, bottom: 20, left: 8, right: 8),
                        padding:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFF374151),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No Workspace',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    return FutureBuilder<WorkspacesRecord>(
                      future: WorkspacesRecord.getDocumentOnce(workspaceRef),
                      builder: (context, workspaceSnapshot) {
                        final workspaceName = workspaceSnapshot.hasData
                            ? workspaceSnapshot.data?.name ?? 'Loading...'
                            : 'Loading...';

                        // If only one workspace, just show it (Slack style)
                        if (memberships.length <= 1) {
                          final workspace = workspaceSnapshot.data;
                          final hasLogo =
                              workspace?.logoUrl.isNotEmpty ?? false;

                          return Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(
                                top: 16, bottom: 20, left: 8, right: 8),
                            padding: EdgeInsets.symmetric(
                                vertical: 16, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Workspace logo or initial
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: hasLogo
                                        ? Colors.white
                                        : Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: hasLogo
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: workspace?.logoUrl ?? '',
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  Color(0xFF3B82F6),
                                                ),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) => Center(
                                              child: Text(
                                                workspaceName.isNotEmpty
                                                    ? workspaceName[0]
                                                        .toUpperCase()
                                                    : 'W',
                                                style: TextStyle(
                                                  color: Colors.white,
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
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  workspaceName,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Multiple workspaces - show dropdown (Slack style)
                        final workspace = workspaceSnapshot.data;
                        final hasLogo = workspace?.logoUrl.isNotEmpty ?? false;

                        return PopupMenuButton<DocumentReference>(
                          offset: Offset(100, 0),
                          child: Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(
                                top: 16, bottom: 20, left: 8, right: 8),
                            padding: EdgeInsets.symmetric(
                                vertical: 16, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Workspace logo or initial
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: hasLogo
                                        ? Colors.white
                                        : Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: hasLogo
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: workspace?.logoUrl ?? '',
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  Color(0xFF3B82F6),
                                                ),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) => Center(
                                              child: Text(
                                                workspaceName.isNotEmpty
                                                    ? workspaceName[0]
                                                        .toUpperCase()
                                                    : 'W',
                                                style: TextStyle(
                                                  color: Colors.white,
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
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  workspaceName,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.unfold_more_rounded,
                                      color: Color(0xFF9CA3AF),
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          onSelected: (workspaceRef) async {
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
                                ),
                              );

                              // Refresh the page
                              safeSetState(() {});
                            }
                          },
                          itemBuilder: (context) {
                            return memberships.map((membership) {
                              return PopupMenuItem<DocumentReference>(
                                value: membership.workspaceRef,
                                child: FutureBuilder<WorkspacesRecord>(
                                  future: WorkspacesRecord.getDocumentOnce(
                                    membership.workspaceRef ??
                                        FirebaseFirestore.instance
                                            .collection('workspaces')
                                            .doc('placeholder'),
                                  ),
                                  builder: (context, ws) {
                                    final name = ws.hasData
                                        ? ws.data?.name ?? 'Loading...'
                                        : 'Loading...';
                                    final isSelected =
                                        currentUser.currentWorkspaceRef?.id ==
                                            membership.workspaceRef?.id;

                                    return Row(
                                      children: [
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF3B82F6),
                                            size: 16,
                                          ),
                                        if (isSelected) SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            }).toList();
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          // Navigation Items
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: navItems.map((item) {
                final isSelected = navItemToIndex[item['page']] == currentIndex;

                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => safeSetState(() {
                        _currentPage = null;
                        _setCurrentPageName(item['page'] as String, tabs);
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(0xFF1F2937)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: Color(0xFF3B82F6),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon with unread indicator
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                item['icon'] is String
                                    ? Container(
                                        width: 24,
                                        height: 24,
                                        child: Image.asset(
                                          item['icon'] as String,
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : item['icon'] is IconData
                                        ? Icon(
                                            item['icon'] as IconData,
                                            color: isSelected
                                                ? Colors.white
                                                : Color(0xFFD1D5DB),
                                            size: 24,
                                          )
                                        : FaIcon(
                                            item['icon'] as IconData,
                                            color: isSelected
                                                ? Colors.white
                                                : Color(0xFFD1D5DB),
                                            size: 20,
                                          ),
                                // Red dot indicator for News button
                                if (item['page'] == 'Announcements')
                                  _buildNewsUnreadIndicator(),
                                // Red dot indicator for Chat button
                                if (item['page'] == 'DesktopChat')
                                  _buildChatUnreadIndicator(),
                              ],
                            ),
                            SizedBox(height: 4),
                            // Label
                            Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: isSelected
                                    ? Colors.white
                                    : Color(0xFFD1D5DB),
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Logout Button
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await authManager.signOut();
                  if (context.mounted) {
                    context.goNamedAuth('OnBoarding', context.mounted);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(0xFF374151),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logout Icon
                      Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(height: 4),
                      // Logout Label
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom spacing
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHorizontalNavBar(Map<String, Widget> tabs, int currentIndex,
      Map<String, int> navItemToIndex) {
    final navItems = [
      {
        'icon': Icons.home_rounded,
        'label': 'Home',
        'page': 'Home',
      },
      // {
      //   'icon': Icons.chat_rounded,
      //   'label': 'Chat',
      //   'page': 'Chat',
      // }, // Commented out - using MobileChat (now called Chat) instead
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'label': 'Chat',
        'page': 'MobileChat',
      },
      {
        'icon': 'assets/images/67b27b2cda06e9c69e5d000615c1153f80b09576.png',
        'label': 'LonaAI',
        'page': 'MobileAssistant',
      },
      {
        'icon': Icons.campaign_rounded,
        'label': 'News',
        'page': 'Announcements',
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Settings',
        'page': 'MobileSettings',
      },
    ];

    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: Color(0xFF2D3142),
        border: Border(
          top: BorderSide(
            color: Color(0xFF374151),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: navItems.map((item) {
            final isSelected = navItemToIndex[item['page']] == currentIndex;

            return Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => safeSetState(() {
                      _currentPage = null;
                      _setCurrentPageName(item['page'] as String, tabs);
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            isSelected ? Color(0xFF1F2937) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon with unread indicator
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              item['icon'] is String
                                  ? Container(
                                      width: 24,
                                      height: 24,
                                      child: Image.asset(
                                        item['icon'] as String,
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : item['icon'] is IconData
                                      ? Icon(
                                          item['icon'] as IconData,
                                          color: isSelected
                                              ? Colors.white
                                              : Color(0xFFD1D5DB),
                                          size: 24,
                                        )
                                      : FaIcon(
                                          item['icon'] as IconData,
                                          color: isSelected
                                              ? Colors.white
                                              : Color(0xFFD1D5DB),
                                          size: 22,
                                        ),
                              // Red dot indicator for News button
                              if (item['page'] == 'Announcements')
                                _buildNewsUnreadIndicator(),
                              // Red dot indicator for Chat button
                              if (item['page'] == 'MobileChat')
                                _buildChatUnreadIndicator(),
                            ],
                          ),
                          SizedBox(height: 4),
                          // Label
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color:
                                  isSelected ? Colors.white : Color(0xFFD1D5DB),
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
