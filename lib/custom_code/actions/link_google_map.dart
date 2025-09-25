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

import 'package:url_launcher/url_launcher.dart';

Future linkGoogleMap(LatLng? latLng) async {
  if (latLng == null) return;

  final double lat = latLng.latitude;
  final double lng = latLng.longitude;

  final Uri uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
  );

  if (await canLaunch(uri.toString())) {
    await launch(uri.toString());
  } else {
    // Optional: fallback toast/snackbar
    debugPrint('Could not launch Google Maps.');
  }
}
