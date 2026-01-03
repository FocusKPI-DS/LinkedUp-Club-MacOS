import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
import '/pages/desktop_chat/chat_controller.dart';
import '/pages/gmail/gmail_widget.dart';
import '/pages/gmail/gmail_mobile_widget.dart';
import '/pages/connections/connections_widget.dart';
import 'package:get/get.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';
import 'backend/backend.dart';
import 'backend/firebase/firebase_config.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/nav/nav.dart';
import 'index.dart';

import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:branchio_dynamic_linking_akp5u6/library_values.dart'
    as branchio_dynamic_linking_akp5u6_library_values;
import 'package:linkedup/backend/schema/structs/index.dart';
import 'package:linkedup/custom_code/services/web_notification_service.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:share_plus/share_plus.dart';

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

    // Gmail prefetch will be triggered when user authentication is confirmed
    // via authenticatedUserStream listener

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

// Flag to prevent duplicate prefetch calls
bool _gmailPrefetchTriggered = false;

/// Trigger Gmail prefetch if user is authenticated and Gmail is connected
/// This is called from authenticatedUserStream listener to ensure user is fully authenticated
void _triggerGmailPrefetchIfConnected() async {
  // Prevent duplicate calls
  if (_gmailPrefetchTriggered) {
    return;
  }

  try {
    // Small delay to ensure auth token is ready
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if user is authenticated
    if (currentUser == null || currentUserUid.isEmpty) {
      return;
    }

    // Check if Gmail is connected by reading user document
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .get();

      if (!userDoc.exists) {
        return;
      }

      final userData = userDoc.data();
      if (userData == null || userData['gmail_connected'] != true) {
        return;
      }

      // Mark as triggered to prevent duplicate calls
      _gmailPrefetchTriggered = true;

      // Trigger priority prefetch (top 10 emails) - fire and forget
      actions.gmailPrefetchPriority().then((result) {
        // Reset flag on error so it can retry on next auth event
        if (result == null || result['success'] != true) {
          _gmailPrefetchTriggered = false;
        }
      }).catchError((error) {
        // Reset flag on error so it can retry on next auth event
        _gmailPrefetchTriggered = false;
      });
    } catch (e) {
      // Error checking Gmail connection (non-critical)
    }
  } catch (e) {
    // Initialization error (non-critical)
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

        // Explicitly register for remote notifications on iOS
        if (Platform.isIOS) {
          // Register for remote notifications after permission is granted
          try {
            // Use method channel to explicitly register for remote notifications
            // Delay to ensure method channel is ready
            Future.delayed(const Duration(milliseconds: 500), () async {
              try {
                const platform = MethodChannel('com.linkedup.notifications');
                await platform.invokeMethod('registerForRemoteNotifications');
                print('✅ iOS: Explicitly registered for remote notifications');
              } catch (e) {
                print('⚠️ iOS: Method channel call failed (non-critical): $e');
              }
            });
            
            // Force registration by getting FCM token (this triggers APNS registration)
            final fcmToken = await messaging.getToken();
            if (fcmToken != null) {
              print('✅ iOS: FCM token obtained: ${fcmToken.substring(0, 20)}...');
              
              // CRITICAL: Save FCM token to Firestore if user is logged in
              // This ensures notifications can be sent to this device
              if (currentUserReference != null) {
                try {
                  await actions.ensureFcmToken(currentUserReference!);
                  print('✅ iOS: FCM token saved to Firestore');
                } catch (e) {
                  print('⚠️ iOS: Failed to save FCM token to Firestore: $e');
                }
              } else {
                print('⚠️ iOS: User not logged in, FCM token not saved (will be saved on login)');
              }
            }
            
            // Also check for APNS token - this helps trigger registration
            final apnsToken = await messaging.getAPNSToken();
            if (apnsToken != null) {
              print('✅ iOS: APNS token available: ${apnsToken.substring(0, apnsToken.length > 20 ? 20 : apnsToken.length)}...');
            } else {
              print('⚠️ iOS: APNS token not yet available (check Xcode console for native logs)');
              // Retry after a short delay
              Future.delayed(const Duration(seconds: 2), () async {
                try {
                  final retryApnsToken = await messaging.getAPNSToken();
                  if (retryApnsToken != null) {
                    print('✅ iOS: APNS token available after retry: ${retryApnsToken.substring(0, 20)}...');
                  }
                } catch (e) {
                  print('⚠️ iOS: APNS token retry failed: $e');
                }
              });
            }
          } catch (e) {
            print('⚠️ iOS: Token check failed: $e');
            print('   Note: Native iOS logs appear in Xcode console, not Flutter console');
          }
        }

        // Listen for foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('🔔 FOREGROUND NOTIFICATION RECEIVED!');
          print('   Title: ${message.notification?.title}');
          print('   Body: ${message.notification?.body}');
          print('   Data: ${message.data}');
          print('   Message ID: ${message.messageId}');
          print('   Sent Time: ${message.sentTime}');
          // Note: With setForegroundNotificationPresentationOptions, system will show notification
        });

        // Listen for notification taps (when app is opened from notification)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          print('📱 NOTIFICATION TAPPED - App opened from notification');
          print('   Title: ${message.notification?.title}');
          print('   Body: ${message.notification?.body}');
          print('   Data: ${message.data}');
        });

        // Check if app was opened from a notification (when app was terminated)
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          print('📱 APP OPENED FROM NOTIFICATION (terminated state)');
          print('   Title: ${initialMessage.notification?.title}');
          print('   Data: ${initialMessage.data}');
        }

        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          print('🔄 FCM token refreshed: ${newToken.substring(0, 10)}...');
          // Save new token to Firestore if user is logged in
          if (currentUserReference != null) {
            Future.delayed(const Duration(seconds: 1), () async {
              try {
                await actions.ensureFcmToken(currentUserReference!);
                print('✅ Refreshed FCM token saved to Firestore');
              } catch (e) {
                print('⚠️ Failed to save refreshed FCM token: $e');
              }
            });
          }
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
  ThemeMode _themeMode = ThemeMode.light; // Force light mode - never use dark mode

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
    // Trigger Gmail prefetch when user is authenticated
    if (user != null && user.uid.isNotEmpty) {
      _triggerGmailPrefetchIfConnected();
      
      // Ensure FCM token is saved when user logs in
      // This handles the case where token was obtained before login
      Future.delayed(const Duration(seconds: 1), () async {
        try {
          if (currentUserReference != null) {
            await actions.ensureFcmToken(currentUserReference!);
            print('✅ FCM token ensured after user login');
          }
        } catch (e) {
          print('⚠️ Failed to ensure FCM token after login: $e');
        }
      });
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
        // Always force light mode - ignore any attempts to change to dark or system mode
        _themeMode = ThemeMode.light;
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
class _NavBarPageState extends State<NavBarPage> with WidgetsBindingObserver {
  String _currentPageName = 'Home';
  late Widget? _currentPage;

  // Persistent MobileChatWidget to preserve state across parent rebuilds
  late final Widget _mobileChatWidget;

  // Presence system for online status (like Slack)
  Timer? _inactivityTimer;
  static const Duration _inactivityThreshold = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;

    // Initialize MobileChatWidget once to preserve its state
    _mobileChatWidget = const MobileChatWidget(
      key: ValueKey('mobile_chat_widget'),
    );

    // Initialize presence system after a delay to ensure user is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 500), () {
        _initializePresence();
      });
    });
  }

  // Initialize presence system (like Slack)
  void _initializePresence() {
    if (currentUserReference == null) {
      return;
    }
    _updateOnlineStatus(true);
    _resetInactivityTimer();
  }

  // Track user activity and reset inactivity timer
  void _trackActivity() {
    _resetInactivityTimer();
    if (currentUserReference != null) {
      UsersRecord.getDocumentOnce(currentUserReference!).then((user) {
        if (!user.isOnline) {
          _updateOnlineStatus(true);
        }
      });
    }
  }

  // Reset inactivity timer (10 minutes like Slack)
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityThreshold, () {
      _updateOnlineStatus(false);
    });
  }

  // Update online status in Firestore
  Future<void> _updateOnlineStatus(bool isOnline) async {
    if (currentUserReference == null) return;

    try {
      await currentUserReference!.update({
        'is_online': isOnline,
      });
    } catch (e) {
      // Silently fail - don't spam console
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _trackActivity();
        _updateOnlineStatus(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _updateOnlineStatus(false);
        _inactivityTimer?.cancel();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _updateOnlineStatus(false);
    super.dispose();
  }

  void _setCurrentPageName(String pageName, Map<String, Widget> tabs) {
    // Ensure the page name exists in tabs, fallback to 'Home' if not
    if (tabs.containsKey(pageName)) {
      _currentPageName = pageName;
      // Clear news indicator when Announcements page is opened (desktop only)
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
    // Track activity when widget is built (user is interacting)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackActivity();
    });

    final tabs = {
      'Home': const HomeWidget(),
      // 'Chat': const ChatWidget(), // Commented out - using MobileChat (now called Chat) instead
      'MobileChat': _mobileChatWidget, // Use stored instance to preserve state
      'DesktopChat': DesktopChatWidget(), // Desktop chat for macOS
      'Gmail': const GmailWidget(), // Gmail page for macOS
      'GmailMobile': const GmailMobileWidget(), // Gmail mobile page for iOS
      'AIAssistant': const AIAssistantWidget(),
      'MobileAssistant': const MobileAssistantWidget(), // Mobile AI Assistant
      // 'Discover': const DiscoverWidget(), // Commented out since Home serves the same purpose
      'Announcements': const FeedWidget(), // Keep for desktop
      'Connections': const ConnectionsWidget(), // Connections page for iOS
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
      'Gmail': 2, // Gmail - for macOS
      'GmailMobile': 2, // Gmail Mobile - for iOS
      'AIAssistant': 3, // Desktop AI Assistant
      'MobileAssistant': 3, // Mobile AI Assistant - for iOS
      // 'Discover': 3, // Commented out
      'Announcements': 3, // News - for desktop (keep for desktop)
      'Connections': 3, // Connections - for iOS (updated to index 3)
      'ProfileSettings': 4, // Settings - for macOS
      'MobileSettings': 4, // Settings - for iOS (updated to index 4)
    };

    final currentIndex = navItemToIndex[_currentPageName] ?? 0;

    // Platform-specific layout
    // Web and macOS use desktop layout with vertical sidebar
    // iOS uses mobile layout with bottom navigation
    if (!kIsWeb && Platform.isIOS) {
      return StreamBuilder<UsersRecord?>(
        stream: currentUserReference != null 
            ? UsersRecord.getDocument(currentUserReference!)
            : Stream.value(null),
        builder: (context, userSnapshot) {
          int connectionRequestCount = 0;
          if (userSnapshot.hasData && userSnapshot.data != null) {
            connectionRequestCount = userSnapshot.data!.friendRequests.length;
          }

          // Map tab indices to page names (5 items: Home, Chat, Mail, Connections, Settings)
          final pageNames = [
            'Home',
            'MobileChat',
            'GmailMobile',
            'Connections',
            'MobileSettings'
          ];

          // Build items with dynamic label for Connections
          final items = <AdaptiveNavigationDestination>[
            AdaptiveNavigationDestination(
              icon: 'house.fill',
              label: 'Home',
            ),
            AdaptiveNavigationDestination(
              icon: 'message.fill',
              label: 'Chat',
            ),
            AdaptiveNavigationDestination(
              icon: 'envelope.fill',
              label: 'Mail',
            ),
            AdaptiveNavigationDestination(
              icon: 'person.2.fill',
              label: connectionRequestCount > 0 
                  ? 'Connections (${connectionRequestCount > 99 ? '99+' : connectionRequestCount})'
                  : 'Connections',
              addSpacerAfter: true,
            ),
            AdaptiveNavigationDestination(
              icon: 'gearshape.fill',
              label: 'Settings',
            ),
          ];

          return AdaptiveScaffold(
            body: _currentPage ?? tabs[_currentPageName] ?? tabs['Home']!,
            bottomNavigationBar: AdaptiveBottomNavigationBar(
              useNativeBottomBar: true,
              items: items,
              selectedIndex: currentIndex,
              selectedItemColor: const Color.fromARGB(255, 2, 156, 252),
              unselectedItemColor: CupertinoColors.systemGrey, // Lighter gray for unselected icons
              onTap: (i) => safeSetState(() {
                _currentPage = null;
                _setCurrentPageName(pageNames[i], tabs);
              }),
            ),
          );
        },
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

    // Try to use ChatController if available, otherwise fall back to chat-level counting
    try {
      final chatController = Get.find<ChatController>();

      return StreamBuilder<int>(
        stream: chatController.getTotalUnreadMessageCount(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return SizedBox.shrink();
          }

          final unreadCount = snapshot.data!;

          if (unreadCount == 0) {
            return SizedBox.shrink();
          }

          // Show blue badge with total unread message count
          return Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: unreadCount > 99 ? 4 : 3, vertical: 3),
              decoration: BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
              constraints: BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: unreadCount > 99 ? 8 : 9,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      // ChatController not available, use fallback method
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

          // Count chats with unread messages (fallback)
          int unreadChatCount = 0;
          for (final chat in chats) {
            if (chat.lastMessage.isNotEmpty &&
                chat.lastMessageSent != currentUserReference &&
                !chat.lastMessageSeen.contains(currentUserReference)) {
              unreadChatCount++;
            }
          }

          if (unreadChatCount == 0) {
            return SizedBox.shrink();
          }

          // Show blue badge with count
          return Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
              constraints: BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Center(
                child: Text(
                  unreadChatCount > 99 ? '99+' : '$unreadChatCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildNavItemWithTooltip({
    required Map<String, dynamic> item,
    required bool isSelected,
    required Map<String, int> navItemToIndex,
    required int currentIndex,
    required Map<String, Widget> tabs,
    required void Function(VoidCallback) safeSetState,
  }) {
    return _NavItemWithTooltip(
      item: item,
      isSelected: isSelected,
      onTap: () => safeSetState(() {
        _currentPage = null;
        _setCurrentPageName(item['page'] as String, tabs);
      }),
      buildNewsUnreadIndicator: _buildNewsUnreadIndicator,
      buildChatUnreadIndicator: _buildChatUnreadIndicator,
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
        'icon': Icons.mail_outline_rounded,
        'label': 'Gmail',
        'page': 'Gmail', // Gmail for macOS and web
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
    ];

    // Settings button (separated to place at bottom)
    final settingsItem = {
      'icon': Icons.settings_outlined,
      'label': 'Settings',
      'page': 'ProfileSettings', // Desktop settings for macOS/web
    };

    return Container(
      width: 70,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // User Profile Photo at top
          if (currentUserReference != null)
            Container(
              margin: EdgeInsets.only(top: 16, bottom: 20),
              child: InkWell(
                onTap: () {
                  context.pushNamed(MobileSettingsWidget.routeName);
                },
                borderRadius: BorderRadius.circular(24),
                child: StreamBuilder<UsersRecord>(
                  stream: UsersRecord.getDocument(currentUserReference!),
                  builder: (context, userSnapshot) {
                    final isOnline = userSnapshot.hasData &&
                        userSnapshot.data != null &&
                        userSnapshot.data!.isOnline;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        currentUserPhoto.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: currentUserPhoto,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 48,
                                    height: 48,
                                    color: Color(0xFFE5E7EB),
                                    child: Icon(
                                      Icons.person,
                                      color: Color(0xFF64748B),
                                      size: 24,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    width: 48,
                                    height: 48,
                                    color: Color(0xFF2563EB),
                                    child: Center(
                                      child: Text(
                                        currentUserDisplayName.isNotEmpty
                                            ? currentUserDisplayName[0]
                                                .toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF2563EB),
                                ),
                                child: Center(
                                  child: Text(
                                    currentUserDisplayName.isNotEmpty
                                        ? currentUserDisplayName[0]
                                            .toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                        // Green dot indicator for online status (like Slack)
                        if (isOnline)
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Color(0xFF10B981), // Green color
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF10B981).withOpacity(0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          // Navigation Items - Top 40% of navbar
          Expanded(
            flex: 4, // TWEAK: Flex value for top 40% - currently 4 (40% = 4/10)
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: navItems.map((item) {
                final isSelected = navItemToIndex[item['page']] == currentIndex;

                return _buildNavItemWithTooltip(
                  item: item,
                  isSelected: isSelected,
                  navItemToIndex: navItemToIndex,
                  currentIndex: currentIndex,
                  tabs: tabs,
                  safeSetState: safeSetState,
                );
              }).toList(),
            ),
          ),
          // Spacer to push settings and logout to bottom - 60% of navbar
          Expanded(
            flex:
                6, // TWEAK: Flex value for bottom 60% - currently 6 (60% = 6/10)
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Horizontal divider line above Settings
                Container(
                  width: 75,
                  height: 1,
                  margin: EdgeInsets.only(
                      bottom:
                          16), // TWEAK: Spacing above Settings - currently 16px
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 120, 125,
                        142), // TWEAK: Divider color - currently light grey
                  ),
                ),
                // Settings Button
                Builder(
                  builder: (context) {
                    final isSelected =
                        navItemToIndex[settingsItem['page']] == currentIndex;
                    return StatefulBuilder(
                      builder: (context, setState) {
                        bool isHovered = false;

                        return MouseRegion(
                          onEnter: (_) => setState(() => isHovered = true),
                          onExit: (_) => setState(() => isHovered = false),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                // TWEAK: Square size - currently 48x48 (perfect square)
                                width: 48,
                                height: 48,
                                margin: EdgeInsets.only(
                                    bottom:
                                        12), // TWEAK: Spacing between Settings and Logout
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => safeSetState(() {
                                      _currentPage = null;
                                      _setCurrentPageName(
                                          settingsItem['page'] as String, tabs);
                                    }),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      // TWEAK: Square size - currently 48x48 (perfect square)
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Color.fromRGBO(250, 252, 255,
                                                1) // Very light cyan tint
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected
                                            ? Border.all(
                                                color: Color.fromRGBO(230, 235,
                                                    245, 1), // Light border
                                                width: 1,
                                              )
                                            : null,
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Color.fromRGBO(
                                                      16,
                                                      184,
                                                      239,
                                                      0.08), // Subtle cyan shadow
                                                  blurRadius: 4,
                                                  offset: Offset(0, 1),
                                                  spreadRadius: 0,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          settingsItem['icon'] as IconData,
                                          color:
                                              Color(0xFF64748B), // Always grey
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Tooltip on hover
                              if (isHovered)
                                Positioned(
                                  left: 60, // Position to the right of the icon
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: Material(
                                      elevation: 8,
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.transparent,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.15),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          settingsItem['label'] as String,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                // Logout Button
                StatefulBuilder(
                  builder: (context, setState) {
                    bool isHovered = false;

                    return MouseRegion(
                      onEnter: (_) => setState(() => isHovered = true),
                      onExit: (_) => setState(() => isHovered = false),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            // TWEAK: Square size - currently 48x48 (perfect square)
                            width: 48,
                            height: 48,
                            margin: EdgeInsets.zero,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  await authManager.signOut();
                                  if (context.mounted) {
                                    context.goNamedAuth(
                                        'OnBoarding', context.mounted);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  // TWEAK: Square size - currently 48x48 (perfect square)
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.logout,
                                      color: Color(0xFF64748B),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Tooltip on hover
                          if (isHovered)
                            Positioned(
                              left: 60, // Position to the right of the icon
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.transparent,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'Logout',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Bottom spacing
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUnderConstructionPage() {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        useNativeToolbar:
            true, // Enable native iOS 26 UIToolbar with Liquid Glass effects
      ),
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Home heading in top left
            Positioned(
              top: 16,
              left: 16,
              child: Text(
                'Home',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label,
                ),
              ),
            ),
            // Main content centered
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.hammer_fill,
                      size: 80,
                      color: CupertinoColors.systemGrey,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Under Construction',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.label,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This page is currently being built.\nPlease check back soon!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.secondaryLabel,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Small round invite button in top right
            Positioned(
              top: 60,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  print('🔘 Invite button tapped!');
                  _showInviteDialog(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 234, 237,
                        239), // Grey background matching unselected tab bar items
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    color: const Color.fromARGB(255, 2, 156,
                        252), // Blue icon matching selected tab bar color
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) async {
    print('🔘 Invite button tapped!');
    try {
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
            onPressed: () {
              print('❌ Cancel pressed');
            },
          ),
          AlertAction(
            title: 'Share',
            style: AlertActionStyle.primary,
            onPressed: () {
              print('✅ Share pressed');
              _shareInviteMessage(context);
            },
          ),
        ],
      );
    } catch (e) {
      print('❌ Error showing invite dialog: $e');
    }
  }

  Future<void> _shareInviteMessage(BuildContext context) async {
    // Open native iOS share sheet (like WhatsApp)
    final size = MediaQuery.of(context).size;
    final sharePositionOrigin = Rect.fromLTWH(
      size.width / 2 - 100,
      size.height / 2,
      200,
      100,
    );

    await Share.share(
      'Hey! I\'ve been using this app named Lona for communication, and it\'s amazing! It really boosts productivity and makes team collaboration so much easier. You should check it out!\n\nDownload here: https://apps.apple.com/us/app/lona-club/id6747595642',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  AdaptiveBottomNavigationBar _buildHorizontalNavBar(Map<String, Widget> tabs,
      int currentIndex, Map<String, int> navItemToIndex) {
    // Map tab indices to page names (5 items: Home, Chat, Mail, Connections, Settings)
    final pageNames = [
      'Home',
      'MobileChat',
      'GmailMobile',
      'Connections',
      'MobileSettings'
    ];

    return AdaptiveBottomNavigationBar(
      useNativeBottomBar:
          true, // Enable native iOS 26 UITabBar with Liquid Glass effects
      items: [
        AdaptiveNavigationDestination(
          icon: 'house.fill',
          label: 'Home',
        ),
        AdaptiveNavigationDestination(
          icon: 'message.fill',
          label: 'Chat',
        ),
        AdaptiveNavigationDestination(
          icon: 'envelope.fill',
          label: 'Mail',
        ),
        AdaptiveNavigationDestination(
          icon: 'person.2.fill',
          label: 'Connections',
          addSpacerAfter:
              true, // Add spacing to separate Settings from other items
        ),
        AdaptiveNavigationDestination(
          icon: 'gearshape.fill',
          label: 'Settings',
        ),
      ],
      selectedIndex: currentIndex,
      selectedItemColor: const Color.fromARGB(255, 2, 156, 252),
      unselectedItemColor: CupertinoColors.systemGrey, // Lighter gray for unselected icons
      onTap: (i) => safeSetState(() {
        _currentPage = null;
        _setCurrentPageName(pageNames[i], tabs);
      }),
    );
  }

  AdaptiveBottomNavigationBar _buildHorizontalNavBarWithBadge(Map<String, Widget> tabs,
      int currentIndex, Map<String, int> navItemToIndex) {
    // Map tab indices to page names (5 items: Home, Chat, Mail, Connections, Settings)
    final pageNames = [
      'Home',
      'MobileChat',
      'GmailMobile',
      'Connections',
      'MobileSettings'
    ];

    // Get connection request count - use a default value for now
    int connectionRequestCount = 0;
    if (currentUserReference != null) {
      // We'll use a StreamBuilder wrapper instead
      // For now, return the nav bar without count, we'll wrap it in the build method
    }

    // Build items - show count in label if there are requests
    final items = <AdaptiveNavigationDestination>[
      AdaptiveNavigationDestination(
        icon: 'house.fill',
        label: 'Home',
      ),
      AdaptiveNavigationDestination(
        icon: 'message.fill',
        label: 'Chat',
      ),
      AdaptiveNavigationDestination(
        icon: 'envelope.fill',
        label: 'Mail',
      ),
      AdaptiveNavigationDestination(
        icon: 'person.2.fill',
        label: connectionRequestCount > 0 
            ? 'Connections (${connectionRequestCount > 99 ? '99+' : connectionRequestCount})'
            : 'Connections',
        addSpacerAfter: true,
      ),
      AdaptiveNavigationDestination(
        icon: 'gearshape.fill',
        label: 'Settings',
      ),
    ];

    return AdaptiveBottomNavigationBar(
      useNativeBottomBar: true,
      items: items,
      selectedIndex: currentIndex,
      selectedItemColor: const Color.fromARGB(255, 2, 156, 252),
      unselectedItemColor: CupertinoColors.systemGrey, // Lighter gray for unselected icons
      onTap: (i) => safeSetState(() {
        _currentPage = null;
        _setCurrentPageName(pageNames[i], tabs);
      }),
    );
  }
}

class _NavItemWithTooltip extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget Function() buildNewsUnreadIndicator;
  final Widget Function() buildChatUnreadIndicator;

  const _NavItemWithTooltip({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.buildNewsUnreadIndicator,
    required this.buildChatUnreadIndicator,
  });

  @override
  State<_NavItemWithTooltip> createState() => _NavItemWithTooltipState();
}

class _NavItemWithTooltipState extends State<_NavItemWithTooltip> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _iconKey = GlobalKey();

  void _showTooltip() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);
    final renderBox = _iconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx, // Start at left edge of icon
        top: position.dy +
            size.height +
            8, // TWEAK: Gap below icon - currently 8px (increase to move down, decrease to move up)
        child: SizedBox(
          width: size.width, // Match icon width
          child: Align(
            alignment: Alignment.center, // Center the tooltip
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(6),
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  widget.item['label'] as String,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showTooltip(),
      onExit: (_) => _hideTooltip(),
      child: Container(
        key: _iconKey,
        // TWEAK: Square size - currently 48x48 (perfect square)
        width: 48,
        height: 48,
        margin: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              // TWEAK: Square size - currently 48x48 (perfect square)
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? Color.fromRGBO(250, 252, 255, 1) // Very light cyan tint
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: widget.isSelected
                    ? Border.all(
                        color: Color.fromRGBO(230, 235, 245, 1), // Light border
                        width: 1,
                      )
                    : null,
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: Color.fromRGBO(
                              16, 184, 239, 0.08), // Subtle cyan shadow
                          blurRadius: 4,
                          offset: Offset(0, 1),
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    widget.item['icon'] is String
                        ? Center(
                            child: Container(
                              // TWEAK: Icon size for image assets - currently 28
                              width: 28,
                              height: 28,
                              child: Image.asset(
                                widget.item['icon'] as String,
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        : widget.item['icon'] is IconData
                            ? Icon(
                                widget.item['icon'] as IconData,
                                color: Color(0xFF64748B), // Always grey
                                // TWEAK: Icon size for IconData - currently 28
                                size: 28,
                              )
                            : FaIcon(
                                widget.item['icon'] as IconData,
                                color: Color(0xFF64748B), // Always grey
                                // TWEAK: Icon size for FaIcon - currently 24
                                size: 24,
                              ),
                    // Red dot indicator for News button
                    if (widget.item['page'] == 'Announcements')
                      widget.buildNewsUnreadIndicator(),
                    // Red dot indicator for Chat button
                    if (widget.item['page'] == 'DesktopChat')
                      widget.buildChatUnreadIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
