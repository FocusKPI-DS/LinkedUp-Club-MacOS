import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

import '/flutter_flow/flutter_flow_util.dart';

const kPermissionStateToBool = {
  PermissionStatus.granted: true,
  PermissionStatus.limited: true,
  PermissionStatus.denied: false,
  PermissionStatus.restricted: false,
  PermissionStatus.permanentlyDenied: false,
};

const cameraPermission = Permission.camera;
const photoLibraryPermission = Permission.photos;
const microphonePermission = Permission.microphone;
const locationPermission = Permission.location;

Future<bool> getPermissionStatus(Permission setting) async {
  // Skip permission checks on web and macOS to avoid plugin errors
  if (kIsWeb) {
    return true; // Assume permissions are granted on web (handled by browser)
  }
  if (!kIsWeb && Platform.isMacOS) {
    return true; // Assume permissions are granted on macOS
  }

  try {
    final status = await setting.status;
    return kPermissionStateToBool[status]!;
  } catch (e) {
    // If permission check fails, assume granted to prevent crashes
    return true;
  }
}

Future<void> requestPermission(Permission setting) async {
  // Skip permission requests on web and macOS to avoid plugin errors
  if (kIsWeb) {
    return; // No-op on web (handled by browser)
  }
  if (!kIsWeb && Platform.isMacOS) {
    return; // No-op on macOS
  }

  try {
    if (setting == Permission.photos && isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 32) {
        await Permission.storage.request();
      } else {
        await Permission.photos.request();
      }
    }
    await setting.request();
  } catch (e) {
    // If permission request fails, silently continue
  }
}
