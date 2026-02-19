// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
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
