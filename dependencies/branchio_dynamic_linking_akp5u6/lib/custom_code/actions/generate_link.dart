// Automatic FlutterFlow imports
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';

Future<String?> generateLink(
  String canonicalIdentifier,
  String title,
  String? description,
  dynamic metadata,
  dynamic linkProperties,
) async {
  // Add your function code here!

  try {
    // Step 1: Build metadata object
    final contentMetaData = BranchContentMetaData();
    if (metadata is Map<String, dynamic>) {
      metadata.forEach((key, value) {
        contentMetaData.addCustomMetadata(key, value);
      });
    }

    // Step 2: Create BranchUniversalObject
    final buo = BranchUniversalObject(
      canonicalIdentifier: canonicalIdentifier,
      title: title,
      contentDescription: description ?? '',
      contentMetadata: contentMetaData,
    );

    // Step 3: Build BranchLinkProperties via constructor
    final props = BranchLinkProperties(
      channel: linkProperties['channel'],
      feature: linkProperties['feature'],
      campaign: linkProperties['campaign'],
      stage: linkProperties['stage'],
    );

    // Step 4: Add custom control parameters
    if (linkProperties is Map<String, String>) {
      linkProperties.forEach((key, value) {
        if (!['channel', 'feature', 'campaign', 'stage'].contains(key)) {
          props.addControlParam('\$$key', value);
        }
      });
    }

    // Step 5: Generate short link
    final response = await FlutterBranchSdk.getShortUrl(
      buo: buo,
      linkProperties: props,
    );

    return response.success ? response.result : null;
  } catch (e) {
    print('[Branch] Link generation failed: $e');
    return null;
  }
}
