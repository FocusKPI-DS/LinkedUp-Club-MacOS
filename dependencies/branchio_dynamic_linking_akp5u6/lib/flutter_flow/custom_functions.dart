import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ff_commons/flutter_flow/lat_lng.dart';
import 'package:ff_commons/flutter_flow/place.dart';
import 'package:ff_commons/flutter_flow/uploaded_file.dart';
import '/library_values.dart';

/// Generates a properties map for creating Branch smart links, including
/// metadata like channel, feature, campaign, stage, tags, alias, and custom
/// parameters.
///
/// Use this to organize and enrich links with analytics-friendly attributes
/// and control how links behave and appear.
dynamic createLinkProperties(
  String? channel,
  String? feature,
  String? campaign,
  String? stage,
  List<String>? tags,
  String? alias,
  int? matchDuration,
  dynamic customParams,
) {
// channel: Where the link is distributed (e.g. "email", "social", "web")
// feature: Feature in the app this link relates to (e.g. "invite", "share", "promo")
// campaign:	Marketing campaign name (e.g. "black_friday", "launch2025")
// stage: Funnel stage (e.g. "new_user", "checkout")
// tags:	List of tags to categorize this link (e.g. ["flutter", "beta"])
// alias:	Custom short URL suffix (e.g. yourapp.com/my-launch)
// matchDuration:	Time in milliseconds to match link to app open (e.g. 7200000 = 2hrs)
// customParams:	Any additional custom params (optional)

  final Map<String, String> result = {};

  if (channel != null) result['channel'] = channel;
  if (feature != null) result['feature'] = feature;
  if (campaign != null) result['campaign'] = campaign;
  if (stage != null) result['stage'] = stage;
  if (alias != null) result['alias'] = alias;
  if (matchDuration != null)
    result['match_duration'] = matchDuration.toString();

  // Optional: flatten tags into numbered keys (Branch SDK expects a list, so handle this upstream if needed)
  if (tags != null) {
    for (var i = 0; i < tags.length; i++) {
      result['tags[$i]'] = tags[i];
    }
  }

  // Merge in any custom user-defined key/values
  if (customParams != null) {
    customParams.forEach((key, value) {
      if (value != null) {
        result[key] = value.toString();
      }
    });
  }

  return result;
}

/// Returns true if the 'page' value in the link data matches the target.
///
/// Use this to check which screen the link intends to open. Ensure to include
/// 'page' in your link data while creating it in Branch.
bool isTargetingPage(
  dynamic linkDataJson,
  String targetPage,
) {
  if (linkDataJson is Map && linkDataJson.containsKey('page')) {
    final page = linkDataJson['page'];
    return page is String && page.toLowerCase() == targetPage.toLowerCase();
  }
  return false;
}

/// Retrieve the full original Branch URL from the link data.
///
/// Provide the linkData as the input parameter.
String? getReferringLink(dynamic linkDataJson) {
  if (linkDataJson != null &&
      linkDataJson is Map &&
      linkDataJson.containsKey('~referring_link')) {
    final link = linkDataJson['~referring_link'];
    if (link is String) return link;
  }
  return null;
}

/// Retrieves a value from the link data by key.
///
/// Useful for safely accessing optional metadata like 'campaign' or
/// 'productId'.
dynamic getLinkDataValue(
  dynamic linkData,
  String key,
) {
  if (linkData is Map && linkData.containsKey(key)) {
    return linkData[key];
  }
  return null;
}

/// Retrieves the original route path (e.g.
///
/// /page/:id) attached to the Branch link.
String? getCanonicalIdentifierFromLink(dynamic linkDataJson) {
  if (linkDataJson is Map &&
      linkDataJson.containsKey('\$canonical_identifier')) {
    final id = linkDataJson['\$canonical_identifier'];
    if (id is String) return id;
  }
  return null;
}

/// Extracts the last segment of a URI path (e.g.
///
/// a document ID or any ID) from a link URL.
String? getLastPathSegment(String? link) {
  if (link == null || link.isEmpty) return null;
  try {
    final uri = Uri.parse(link);
    final segments = uri.pathSegments;
    return segments.isNotEmpty ? segments.last : null;
  } catch (_) {
    return null;
  }
}

/// Checks whether a given routeName exists as a substring within the
/// canonicalIdentifier.
///
/// This is useful when deep links include query parameters or long paths
/// (e.g., "/detailPage?productRef=..."), but you only care about matching the
/// base route name.
bool containsRouteName(
  String canonicalIdentifier,
  String routeName,
) {
  return canonicalIdentifier.contains(routeName);
}
