import 'dart:async';
import 'dart:convert';

import 'serialization_util.dart';
import '/backend/backend.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../index.dart';
import '../../main.dart';

final _handledMessageIds = <String?>{};

class PushNotificationsHandler extends StatefulWidget {
  const PushNotificationsHandler({Key? key, required this.child})
      : super(key: key);

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

    final notification = await FirebaseMessaging.instance.getInitialMessage();
    if (notification != null) {
      await _handlePushNotification(notification);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handlePushNotification);
  }

  Future _handlePushNotification(RemoteMessage message) async {
    if (_handledMessageIds.contains(message.messageId)) {
      return;
    }
    _handledMessageIds.add(message.messageId);

    safeSetState(() => _loading = true);
    try {
      final initialPageName = message.data['initialPageName'] as String;
      final initialParameterData = getInitialParameterData(message.data);
      final parametersBuilder = parametersBuilderMap[initialPageName];
      if (parametersBuilder != null) {
        final parameterData = await parametersBuilder(initialParameterData);
        if (mounted) {
          context.pushNamed(
            initialPageName,
            pathParameters: parameterData.pathParameters,
            extra: parameterData.extra,
          );
        } else {
          appNavigatorKey.currentContext?.pushNamed(
            initialPageName,
            pathParameters: parameterData.pathParameters,
            extra: parameterData.extra,
          );
        }
      }
    } catch (e) {
      print('Error: $e');
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
      (data) async => ParameterData();
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
  'Discover': (data) async => ParameterData(
        allParams: {
          'isDeeplink': getParameter<bool>(data, 'isDeeplink'),
        },
      ),
  'Profile': ParameterData.none(),
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
  'Feed': ParameterData.none(),
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
