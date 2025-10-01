import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Import for macOS camera delegate
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:image_picker_macos/image_picker_macos.dart';

import '/custom_code/actions/index.dart' as actions;
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';
import 'backend/push_notifications/push_notifications_util.dart';
import 'backend/firebase/firebase_config.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/nav/nav.dart';
import 'flutter_flow/revenue_cat_util.dart' as revenue_cat;
import 'index.dart';

import 'package:branchio_dynamic_linking_akp5u6/custom_code/actions/index.dart'
    as branchio_dynamic_linking_akp5u6_actions;
import 'package:branchio_dynamic_linking_akp5u6/library_values.dart'
    as branchio_dynamic_linking_akp5u6_library_values;
import 'package:linkedup/backend/schema/structs/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    GoRouter.optionURLReflectsImperativeAPIs = true;

    // Configure image picker for macOS
    if (Platform.isMacOS) {
      ImagePickerPlatform.instance = ImagePickerMacOS();
    }

    // Only use path URL strategy on web
    if (kIsWeb) {
      usePathUrlStrategy();
    }

    // Initialize Firebase first
    await initFirebase();

    // Initialize push notifications asynchronously (non-blocking)
    _initializePushNotificationsAsync();

    // Initialize app state
    final appState = FFAppState();
    await appState.initializePersistedState();

    // Initialize RevenueCat with error handling (disabled on macOS for App Store review)
    if (!Platform.isMacOS) {
      try {
        await revenue_cat.initialize(
          "appl_gYrKTEbjDTBkjDuoTAZxGQtSKMW",
          "goog_JKqkobkHgNHXsFahQSZcGrElrkO",
          loadDataAfterLaunch: true,
        );
      } catch (e) {
        print('RevenueCat initialization failed: $e');
      }
    } else {
      print('RevenueCat disabled on macOS for App Store compliance');
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
        print('App badge setup failed: $e');
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
        print('Branch SDK initialization failed: $e');
      }
    } else {
      print('Branch SDK not supported on this platform');
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
    print('Error during app initialization: $e');
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
              Text('Error: $e'),
            ],
          ),
        ),
      ),
    ));
  }
}

/// Initialize push notifications asynchronously to avoid blocking app startup
void _initializePushNotificationsAsync() async {
  if (!kIsWeb && (Platform.isMacOS || Platform.isIOS)) {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request notification permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Show system banners while app is in foreground
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // For macOS, wait a bit for APNS token
        if (Platform.isMacOS) {
          await Future.delayed(const Duration(seconds: 2));
        }

        // Get and print FCM token
        try {
          final token = await messaging.getToken();
          print('FCM token: $token');
        } catch (e) {
          print('Error getting FCM token: $e');
        }

        // Listen for foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print(
              '📱 Foreground message: ${message.notification?.title} — ${message.notification?.body}');
        });

        // Listen for notification taps
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          print('🔔 Notification tapped with data: ${message.data}');
        });

        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          print('🔄 FCM token refreshed: $newToken');
        });
      }
    } catch (e) {
      print('Push notification setup failed: $e');
    }
  }
}

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
    // Use platform-appropriate scroll physics
    if (Platform.isMacOS) {
      return const BouncingScrollPhysics();
    }
    return super.getScrollPhysics(context);
  }

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Use platform-appropriate scrollbars
    if (Platform.isMacOS) {
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
    if (!Platform.isMacOS) {
      revenue_cat.login(user?.uid);
    }
  });
  final fcmTokenSub = fcmTokenUserStream.listen((_) {});

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = linkedupFirebaseUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
      });
    jwtTokenStream.listen((_) {});
    // Show loading page immediately, hide it when initialization is complete
    _initializeAppAsync();
  }

  @override
  void dispose() {
    authUserSub.cancel();
    fcmTokenSub.cancel();
    super.dispose();
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
      });

  /// Optimize app initialization to show loading page immediately
  Future<void> _initializeAppAsync() async {
    // Wait for essential services to initialize in parallel
    await Future.wait([
      // Wait for user stream to emit at least once
      userStream.first.timeout(
        const Duration(milliseconds: 1200),
      ),
      // Keep loading page for exactly 1000ms as requested
      Future.delayed(const Duration(milliseconds: 1000)),
    ]);

    // Hide loading page once initialization is complete
    if (mounted) {
      _appStateNotifier.stopShowingSplashImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Linkedup',
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
        // Add macOS-specific configurations
        platform: TargetPlatform.macOS,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
        platform: TargetPlatform.macOS,
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
  String _currentPageName = 'Chat';
  late Widget? _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      'Chat': const ChatWidget(),
      'Discover': const DiscoverWidget(),
      // 'Event': EventWidget(),
      'Feed': const FeedWidget(),
      'Profile': const ProfileWidget(),
    };
    final currentIndex = tabs.keys.toList().indexOf(_currentPageName);

    return Scaffold(
      resizeToAvoidBottomInset: !widget.disableResizeToAvoidBottomInset,
      body: _currentPage ?? tabs[_currentPageName],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => safeSetState(() {
          _currentPage = null;
          _currentPageName = tabs.keys.toList()[i];
        }),
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        selectedItemColor: FlutterFlowTheme.of(context).primary,
        unselectedItemColor: FlutterFlowTheme.of(context).secondaryText,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              Icons.chat_rounded,
              size: 24.0,
            ),
            label: 'Chat',
            tooltip: '',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(
              FontAwesomeIcons.solidCompass,
              size: 20.0,
            ),
            label: 'Discover',
            tooltip: '',
          ),
          // BottomNavigationBarItem(
          //   icon: FaIcon(
          //     FontAwesomeIcons.solidCalendarAlt,
          //     size: 20.0,
          //   ),
          //   label: 'Event',
          //   tooltip: '',
          // ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.groups_sharp,
              size: 30.0,
            ),
            label: 'Feed',
            tooltip: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_2,
              size: 28.0,
            ),
            label: 'Profile',
            tooltip: '',
          )
        ],
      ),
    );
  }
}
