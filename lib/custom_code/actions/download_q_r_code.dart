// Automatic FlutterFlow imports
// Imports other custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'dart:io';
import 'dart:ui' as ui;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

Future<bool> downloadQRCode(String qrData, String fileName) async {
  try {
    // Request storage permission
    PermissionStatus permission;
    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied) {
        permission = await Permission.storage.request();
        if (permission.isDenied) {
          return false;
        }
      }

      // For Android 13+ (API 33+), use photos permission
      if (await Permission.photos.isDenied) {
        permission = await Permission.photos.request();
        if (permission.isDenied) {
          return false;
        }
      }
    } else if (Platform.isIOS) {
      if (await Permission.photos.isDenied) {
        permission = await Permission.photos.request();
        if (permission.isDenied) {
          return false;
        }
      }
    }

    // Create a QR painter directly
    final painter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
      color: Colors.black,
      emptyColor: Colors.white,
    );

    // Create image from painter
    const size = 512.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Paint the QR code
    painter.paint(canvas, const Size(size, size));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    // Save to gallery using image_gallery_saver_plus
    final result = await ImageGallerySaverPlus.saveImage(
      pngBytes,
      quality: 100,
      name: fileName.isEmpty
          ? "QR_Code_${DateTime.now().millisecondsSinceEpoch}"
          : fileName,
    );

    return result['isSuccess'] == true;
  } catch (e) {
    print('Error downloading QR code: $e');
    return false;
  }
}
