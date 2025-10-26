import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'serialization_util.dart';
import '../../auth/firebase_auth/auth_util.dart';
import '../cloud_functions/cloud_functions.dart';

import 'package:flutter/foundation.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

export 'push_notifications_handler.dart';
export 'serialization_util.dart';

const kUserPushNotificationsCollectionName = 'ff_user_push_notifications';

class UserTokenInfo {
  const UserTokenInfo(this.userPath, this.fcmToken);
  final String userPath;
  final String fcmToken;
}

Stream<UserTokenInfo> getFcmTokenStream(String userPath) => Stream.value(
        !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS))
    .where((shouldGetToken) => shouldGetToken)
    .asyncMap<String?>((_) async {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          // For macOS and iOS, we need to ensure APNS token is available first
          if (Platform.isMacOS || Platform.isIOS) {
            print('Waiting for APNS token for FCM token stream...');

            String? apnsToken;
            int maxRetries = 10;
            int retryCount = 0;

            while (apnsToken == null && retryCount < maxRetries) {
              try {
                apnsToken = await FirebaseMessaging.instance.getAPNSToken();
                if (apnsToken != null) {
                  print('APNS token available for FCM token stream');
                  break;
                }
              } catch (e) {
                print('Attempt ${retryCount + 1}: Waiting for APNS token - $e');
              }

              // Exponential backoff
              await Future.delayed(
                  Duration(milliseconds: 500 * (retryCount + 1)));
              retryCount++;
            }

            if (apnsToken == null) {
              print('Failed to get APNS token for FCM token stream');
              return null;
            }
          }
          return await FirebaseMessaging.instance.getToken();
        }
        return null;
      } catch (e) {
        print('Error getting FCM token: $e');
        return null;
      }
    })
    .switchMap((fcmToken) =>
        Stream.value(fcmToken).merge(FirebaseMessaging.instance.onTokenRefresh))
    .where((fcmToken) => fcmToken != null && fcmToken.isNotEmpty)
    .map((token) => UserTokenInfo(userPath, token!));

final fcmTokenUserStream = authenticatedUserStream
    .where((user) => user != null)
    .map((user) => user!.reference.path)
    .distinct()
    .switchMap(getFcmTokenStream)
    .map(
      (userTokenInfo) => makeCloudCall(
        'addFcmToken',
        {
          'userDocPath': userTokenInfo.userPath,
          'fcmToken': userTokenInfo.fcmToken,
          'deviceType': Platform.isIOS
              ? 'iOS'
              : Platform.isAndroid
                  ? 'Android'
                  : 'macOS',
        },
      ),
    );

void triggerPushNotification({
  required String? notificationTitle,
  required String? notificationText,
  String? notificationImageUrl,
  DateTime? scheduledTime,
  String? notificationSound,
  required List<DocumentReference> userRefs,
  required String initialPageName,
  required Map<String, dynamic> parameterData,
}) {
  if ((notificationTitle ?? '').isEmpty || (notificationText ?? '').isEmpty) {
    return;
  }
  final serializedParameterData = serializeParameterData(parameterData);
  final pushNotificationData = {
    'notification_title': notificationTitle,
    'notification_text': notificationText,
    if (notificationImageUrl != null)
      'notification_image_url': notificationImageUrl,
    if (scheduledTime != null) 'scheduled_time': scheduledTime,
    if (notificationSound != null) 'notification_sound': notificationSound,
    'user_refs': userRefs.map((u) => u.path).join(','),
    'initial_page_name': initialPageName,
    'parameter_data': serializedParameterData,
    'sender': currentUserReference,
    'timestamp': DateTime.now(),
  };

  print('🔍 About to create document in ff_user_push_notifications');
  print('🔍 Document data: $pushNotificationData');

  FirebaseFirestore.instance
      .collection(kUserPushNotificationsCollectionName)
      .add(pushNotificationData)
      .then((docRef) {
    print('✅ Document created successfully! ID: ${docRef.id}');
  }).catchError((error) {
    print('❌ Error creating document: $error');
  });
}
