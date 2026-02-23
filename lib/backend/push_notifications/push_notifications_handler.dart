import 'dart:async';
import 'dart:convert';

import 'serialization_util.dart';
import '/backend/backend.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import '../../flutter_flow/nav/nav.dart' show appNavigatorKey;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

final _handledMessageIds = <String?>{};

/// Shared function to handle notification navigation
/// Can be called from PushNotificationsHandler or main.dart
Future<void> handleNotificationNavigation(RemoteMessage message) async {
  print('🔍 handleNotificationNavigation called');
  print('   Message ID: ${message.messageId}');
  print('   Full data: ${message.data}');

  // Prevent duplicate handling
  if (_handledMessageIds.contains(message.messageId)) {
    print('⚠️ Message already handled: ${message.messageId}');
    return;
  }
  _handledMessageIds.add(message.messageId);
  print('✅ Message ID added to handled set');

  try {
    var initialPageName = message.data['initialPageName'] as String?;
    print('   Extracted initialPageName: $initialPageName');
    print('   Full message.data: ${message.data}');
    if (initialPageName == null || initialPageName.isEmpty) {
      print(
          '⚠️ No initialPageName in notification data. Keys: ${message.data.keys}');
      return;
    }

    // Map ChatDetail to MobileChat for iOS (to show tab bar)
    if (initialPageName == 'ChatDetail') {
      print('   Mapping ChatDetail to MobileChat for tab bar support');
      initialPageName = 'MobileChat';
    }

    final initialParameterData = getInitialParameterData(message.data);
    print('   Initial parameter data: $initialParameterData');

    // Check if this is a tab page (should be shown within NavBarPage)
    // But exclude MobileChat if it has parameters (needs to open specific chat)
    final tabPages = {
      'Home',
      'DesktopChat',
      'Gmail',
      'GmailMobile',
      'AIAssistant',
      'MobileAssistant',
      'Announcements',
      'Connections',
      'ProfileSettings',
      'MobileSettings'
    };

    // MobileChat is a tab page, but if it has parameters, navigate to the route instead
    final hasParameters = initialParameterData.isNotEmpty;
    final isTabPage = tabPages.contains(initialPageName) ||
        (initialPageName == 'MobileChat' && !hasParameters);

    if (isTabPage && initialPageName != 'MobileChat') {
      // For tab pages (except MobileChat with params), navigate to root route which will show NavBarPage
      // Then we'll use go with a query parameter to set the tab
      print('   Detected tab page: $initialPageName');
      print('   hasParameters: $hasParameters');
      print('   initialParameterData: $initialParameterData');
      final navigatorContext = appNavigatorKey.currentContext;
      if (navigatorContext != null) {
        try {
          // Navigate to root with the tab name as a query parameter
          // This will be handled by the root route to show the correct tab
          print('   Navigating to root with tab=$initialPageName');
          // Use goNamed with queryParameters - this should work with FFRoute
          navigatorContext.goNamed(
            '_initialize',
            queryParameters: {'tab': initialPageName},
          );
          print(
              '✅ Successfully navigated to tab page $initialPageName with tab bar');
        } catch (e, stackTrace) {
          print('❌ Navigation failed for tab page: $e');
          print('   Stack trace: $stackTrace');
          // Fallback: just go to root
          try {
            GoRouter.of(navigatorContext).go('/');
            print('✅ Navigated to root as fallback');
          } catch (e2) {
            print('❌ Fallback navigation also failed: $e2');
          }
        }
      } else {
        print('⚠️ Navigator context is null for tab page navigation');
      }
      return;
    }

    // For MobileChat with parameters, navigate to the route (not tab)
    if (initialPageName == 'MobileChat' && hasParameters) {
      print('   MobileChat with parameters - navigating to route with chat');
    }

    final parametersBuilder = parametersBuilderMap[initialPageName];
    print('   Parameters builder found: ${parametersBuilder != null}');

    if (parametersBuilder != null) {
      final parameterData = await parametersBuilder(initialParameterData);
      print(
          '   Parameter data: ${parameterData.pathParameters}, extra: ${parameterData.extra}');

      // Use appNavigatorKey to navigate (works even without context)
      final navigatorContext = appNavigatorKey.currentContext;
      if (navigatorContext != null) {
        print('   Attempting to navigate to: $initialPageName');
        print('   Using GoRouter: ${GoRouter.of(navigatorContext)}');
        print('   Path parameters: ${parameterData.pathParameters}');
        print('   Extra: ${parameterData.extra}');
        try {
          // Try pushNamed first (adds to stack, better for notifications)
          navigatorContext.pushNamed(
            initialPageName,
            pathParameters: parameterData.pathParameters,
            extra: parameterData.extra,
          );
          print('✅ Successfully navigated to $initialPageName using pushNamed');
        } catch (e, stackTrace) {
          print('❌ Navigation failed for $initialPageName: $e');
          print('   Stack trace: $stackTrace');
          // Try goNamed as fallback
          try {
            print('   Trying goNamed as fallback...');
            GoRouter.of(navigatorContext).goNamed(
              initialPageName,
              pathParameters: parameterData.pathParameters,
              extra: parameterData.extra,
            );
            print('✅ Successfully navigated with goNamed');
          } catch (e2) {
            print('❌ goNamed also failed: $e2');
          }
        }
      } else {
        print('⚠️ Navigator context is null, retrying in 500ms...');
        // Retry after a short delay if context isn't ready
        Future.delayed(const Duration(milliseconds: 500), () async {
          final retryContext = appNavigatorKey.currentContext;
          if (retryContext != null) {
            print('   Retry: Attempting to navigate to: $initialPageName');
            try {
              // Use pushNamed (adds to stack)
              retryContext.pushNamed(
                initialPageName!,
                pathParameters: parameterData.pathParameters,
                extra: parameterData.extra,
              );
              print('✅ Successfully navigated to $initialPageName (retry)');
            } catch (e, stackTrace) {
              print('❌ Navigation failed on retry for $initialPageName: $e');
              print('   Stack trace: $stackTrace');
              // Try goNamed as fallback
              try {
                print('   Retry: Trying goNamed as fallback...');
                GoRouter.of(retryContext).goNamed(
                  initialPageName!,
                  pathParameters: parameterData.pathParameters,
                  extra: parameterData.extra,
                );
                print('✅ Successfully navigated with goNamed (retry)');
              } catch (e2) {
                print('❌ goNamed also failed on retry: $e2');
              }
            }
          } else {
            print('❌ Navigator context still null after retry');
          }
        });
      }
    } else {
      print('⚠️ No parameter builder for: $initialPageName');
      print('   Available builders: ${parametersBuilderMap.keys.toList()}');
    }
  } catch (e) {
    print('❌ Navigation error: $e');
  }
}

class PushNotificationsHandler extends StatefulWidget {
  const PushNotificationsHandler({super.key, required this.child});

  final Widget child;

  @override
  _PushNotificationsHandlerState createState() =>
      _PushNotificationsHandlerState();
}

class _PushNotificationsHandlerState extends State<PushNotificationsHandler> {
  bool _loading = false;

  Future handleOpenedPushNotification() async {
    if (isWeb) {
      return;
    }

    print('🔍 PushNotificationsHandler: Setting up listeners...');
    final notification = await FirebaseMessaging.instance.getInitialMessage();
    if (notification != null) {
      print('🔍 PushNotificationsHandler: Found initial message');
      await _handlePushNotification(notification);
    }
    print('🔍 PushNotificationsHandler: Registering onMessageOpenedApp...');
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('🔍 PushNotificationsHandler: onMessageOpenedApp triggered');
      print('   Message ID: ${message.messageId}');
      print('   Data: ${message.data}');
      print('   initialPageName: ${message.data['initialPageName']}');
      print('   parameterData: ${message.data['parameterData']}');
      _handlePushNotification(message);
    });
    print('✅ PushNotificationsHandler: Listeners registered');
  }

  Future _handlePushNotification(RemoteMessage message) async {
    safeSetState(() => _loading = true);
    try {
      await handleNotificationNavigation(message);
    } finally {
      safeSetState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      handleOpenedPushNotification();
    });
  }

  @override
  Widget build(BuildContext context) => _loading
      ? Container(
          color: FlutterFlowTheme.of(context).primary,
          child: Center(
            child: Image.asset(
              'assets/images/Logo_2.png',
              width: 200.0,
              fit: BoxFit.contain,
            ),
          ),
        )
      : widget.child;
}

class ParameterData {
  const ParameterData(
      {this.requiredParams = const {}, this.allParams = const {}});
  final Map<String, String?> requiredParams;
  final Map<String, dynamic> allParams;

  Map<String, String> get pathParameters => Map.fromEntries(
        requiredParams.entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
  Map<String, dynamic> get extra => Map.fromEntries(
        allParams.entries.where((e) => e.value != null),
      );

  static Future<ParameterData> Function(Map<String, dynamic>) none() =>
      (data) async => const ParameterData();
}

final parametersBuilderMap =
    <String, Future<ParameterData> Function(Map<String, dynamic>)>{
  'Login': (data) async => ParameterData(
        allParams: {
          'isInvitation': getParameter<bool>(data, 'isInvitation'),
        },
      ),
  'SignUp': (data) async => ParameterData(
        allParams: {
          'isDeeplink': getParameter<bool>(data, 'isDeeplink'),
          'skippedInvite': getParameter<bool>(data, 'skippedInvite'),
        },
      ),
  'Event': ParameterData.none(),
  'EventDetail': (data) async {
    final allParams = {
      'eventId': getParameter<String>(data, 'eventId'),
      'payment': getParameter<String>(data, 'payment'),
      'sessionId': getParameter<String>(data, 'sessionId'),
    };
    return ParameterData(
      requiredParams: {
        'eventId': serializeParam(
          allParams['eventId'],
          ParamType.String,
        ),
      },
      allParams: allParams,
    );
  },
  'onBoarding': ParameterData.none(),
  'Welcome': ParameterData.none(),
  'ForgotPassword': ParameterData.none(),
  'OnboardingProfile': (data) async => ParameterData(
        allParams: {
          'deeplink': getParameter<bool>(data, 'deeplink'),
        },
      ),
  'Home': ParameterData.none(),
  'Settings': ParameterData.none(),
  'CreateEvent': (data) async => ParameterData(
        allParams: {
          'event': await getDocumentParameter<EventsRecord>(
              data, 'event', EventsRecord.fromSnapshot),
        },
      ),
  'InvitationCode': (data) async => ParameterData(
        allParams: {
          'isDeeplink': getParameter<bool>(data, 'isDeeplink'),
        },
      ),
  'EditProfile': ParameterData.none(),
  'Search': ParameterData.none(),
  'Contact': ParameterData.none(),
  'FAQs': ParameterData.none(),
  'PrivacyAndPolicy': ParameterData.none(),
  'GroupChatDetail': (data) async => ParameterData(
        allParams: {
          'chatDoc': await getDocumentParameter<ChatsRecord>(
              data, 'chatDoc', ChatsRecord.fromSnapshot),
        },
      ),
  'UserProfileDetail': (data) async => ParameterData(
        allParams: {
          'user': await getDocumentParameter<UsersRecord>(
              data, 'user', UsersRecord.fromSnapshot),
        },
      ),
  'Chat': ParameterData.none(),
  'ChatGroupCreation': (data) async => ParameterData(
        allParams: {
          'isEdit': getParameter<bool>(data, 'isEdit'),
          'chatDoc': await getDocumentParameter<ChatsRecord>(
              data, 'chatDoc', ChatsRecord.fromSnapshot),
        },
      ),
  'AllAttendees': (data) async => ParameterData(
        allParams: {
          'event': await getDocumentParameter<EventsRecord>(
              data, 'event', EventsRecord.fromSnapshot),
        },
      ),
  'ContactsList': ParameterData.none(),
  'ChatDetail': (data) async => ParameterData(
        allParams: {
          'chatDoc': await getDocumentParameter<ChatsRecord>(
              data, 'chatDoc', ChatsRecord.fromSnapshot),
        },
      ),
  'MobileChat': (data) async => ParameterData(
        allParams: {
          'chatDoc': await getDocumentParameter<ChatsRecord>(
              data, 'chatDoc', ChatsRecord.fromSnapshot),
        },
      ),
  'AllUsers': ParameterData.none(),
  'SearchChat': ParameterData.none(),
  'TermsPrivacy': (data) async => ParameterData(
        allParams: {
          'isTerm': getParameter<bool>(data, 'isTerm'),
        },
      ),
  'postDetail': (data) async => ParameterData(
        allParams: {
          'postDoc': await getDocumentParameter<PostsRecord>(
              data, 'postDoc', PostsRecord.fromSnapshot),
        },
      ),
  'Announcements': ParameterData.none(),
  'CreatePost': (data) async => ParameterData(
        allParams: {
          'image': getParameter<String>(data, 'image'),
          'caption': getParameter<String>(data, 'caption'),
          'feeling': getParameter<String>(data, 'feeling'),
          'isEdit': getParameter<bool>(data, 'isEdit'),
          'postDoc': getParameter<DocumentReference>(data, 'postDoc'),
        },
      ),
  'AllPendingRequests': ParameterData.none(),
  'fullImage': ParameterData.none(),
  'QRScanPage': ParameterData.none(),
  'NotificationPage': ParameterData.none(),
  'EventbriteDashboard': ParameterData.none(),
  'PaymentHistoryPage': ParameterData.none(),
  'PaymentSuccess': (data) async {
    final allParams = {
      'eventId': getParameter<String>(data, 'eventId'),
      'payment': getParameter<String>(data, 'payment'),
      'sessionId': getParameter<String>(data, 'sessionId'),
    };
    return ParameterData(
      requiredParams: {
        'eventId': serializeParam(
          allParams['eventId'],
          ParamType.String,
        ),
      },
      allParams: allParams,
    );
  },
  'Connections': ParameterData.none(),
};

Map<String, dynamic> getInitialParameterData(Map<String, dynamic> data) {
  try {
    final parameterDataStr = data['parameterData'];
    if (parameterDataStr == null ||
        parameterDataStr is! String ||
        parameterDataStr.isEmpty) {
      return {};
    }
    return jsonDecode(parameterDataStr) as Map<String, dynamic>;
  } catch (e) {
    print('Error parsing parameter data: $e');
    return {};
  }
}
