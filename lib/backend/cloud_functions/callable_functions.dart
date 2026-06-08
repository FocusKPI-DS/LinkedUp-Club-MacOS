import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Firebase project / Functions region (matches deployed Node functions).
const kFirebaseFunctionsProjectId = 'linkedup-c3e29';
const kFirebaseFunctionsRegion = 'us-central1';

/// `cloud_functions` has no Windows/Linux plugin — use Callable HTTP protocol.
bool get useDesktopCallableHttp =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux);

/// Invoke a Firebase Callable function on all platforms.
Future<dynamic> invokeCloudFunction(
  String name, {
  Map<String, dynamic>? data,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final payload = data ?? {};

  if (!useDesktopCallableHttp) {
    final result = await FirebaseFunctions.instance
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: timeout),
        )
        .call(payload);
    return result.data;
  }

  return _invokeCallableViaHttp(name, payload, timeout);
}

Future<dynamic> _invokeCallableViaHttp(
  String name,
  Map<String, dynamic> data,
  Duration timeout,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'User must be signed in',
    );
  }

  final token = await user.getIdToken();
  final uri = Uri.parse(
    'https://$kFirebaseFunctionsRegion-$kFirebaseFunctionsProjectId.cloudfunctions.net/$name',
  );

  final response = await http
      .post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'data': data}),
      )
      .timeout(timeout);

  dynamic decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (_) {
    throw FirebaseFunctionsException(
      code: 'internal',
      message: 'Invalid response from Cloud Function (HTTP ${response.statusCode})',
    );
  }

  if (decoded is Map && decoded['error'] != null) {
    final err = decoded['error'];
    if (err is Map) {
      throw FirebaseFunctionsException(
        code: _httpErrorStatusToCode(err['status']?.toString()),
        message: err['message']?.toString() ?? 'Cloud Function error',
        details: err['details'],
      );
    }
  }

  if (response.statusCode >= 400) {
    throw FirebaseFunctionsException(
      code: 'internal',
      message: 'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  if (decoded is Map && decoded.containsKey('result')) {
    return decoded['result'];
  }

  return decoded;
}

String _httpErrorStatusToCode(String? status) {
  if (status == null || status.isEmpty) {
    return 'internal';
  }
  return status.toLowerCase().replaceAll('_', '-');
}
