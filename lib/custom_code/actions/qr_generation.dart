// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:qr_flutter/qr_flutter.dart';

Future<String?> qrGeneration(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final qrValidationResult = QrValidator.validate(
      data: url,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.Q,
    );

    if (qrValidationResult.status != QrValidationStatus.valid) {
      return null;
    }

    final painter = QrPainter.withQr(
      qr: qrValidationResult.qrCode!,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
      gapless: true,
    );

    final image = await painter.toImage(300);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final base64Image = base64Encode(bytes);
    return 'data:image/png;base64,$base64Image';
  } catch (e) {
    print('QR generation error: $e');
    return null;
  }
}
