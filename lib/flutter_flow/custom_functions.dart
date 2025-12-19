import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ff_commons/flutter_flow/lat_lng.dart';
import 'package:ff_commons/flutter_flow/place.dart';
import 'package:ff_commons/flutter_flow/uploaded_file.dart';
import '/backend/backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:branchio_dynamic_linking_akp5u6/flutter_flow/custom_functions.dart'
    as branchio_dynamic_linking_akp5u6_functions;

String? shiftSchedule(DateTime? time) {
  String? shiftSchedule(DateTime? time) {
    if (time == null) return null;

    final hour = time.hour;

    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 17) {
      return 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'evening';
    } else {
      return 'night';
    }
  }
  return null;
}

String? convertTRawTime(
  DateTime? start,
  DateTime? end,
) {
  if (start == null || end == null) return null;

  final diff = end.difference(start);
  final hours = diff.inHours;
  final minutes = diff.inMinutes % 60;

  if (hours > 0 && minutes > 0) {
    return '${hours}h ${minutes}m';
  } else if (hours > 0) {
    return '${hours}h';
  } else {
    return '${minutes}m';
  }
}

bool textContaintext(
  String searchIN,
  String searchFOR,
) {
  return searchIN.toLowerCase().contains(searchFOR.toLowerCase());
}

bool todayEvent(
  DateTime? eventCreateAt,
  DateTime? currentUserDate,
) {
  if (eventCreateAt == null || currentUserDate == null) return false;

  // Compare only the year, month, and day
  return eventCreateAt.year == currentUserDate.year &&
      eventCreateAt.month == currentUserDate.month &&
      eventCreateAt.day == currentUserDate.day;
}

bool? checkEventNull(DocumentReference? eventRef) {
  // check if the eventRef == null or not
  return eventRef == null;
}

String? converAudioPathToString(String? audio) {
  if (audio == null || audio.isEmpty) return null;
  print(audio);
  return audio;
}

List<DocumentReference> getFriends(
  List<DocumentReference> chatMembers,
  List<DocumentReference> allFriends,
) {
  // Retrieve the list of document reference of users (from allFriends) that are not in chatMembers and return the list
  return allFriends.where((friend) => !chatMembers.contains(friend)).toList();
}

List<DocumentReference>? getMutualfriend(
  List<DocumentReference> currentUserFriends,
  List<DocumentReference>? allFriends,
) {
  if (allFriends == null) return [];

  return currentUserFriends
      .where((ref) => allFriends.any((f) => f.path == ref.path))
      .toList();
}

bool? shouldShowEventByDateRange(
  DateTime? eventDate,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  List<String>? eventCategory,
  String? selectedCategory,
  LatLng? location,
  LatLng? eventLocation,
) {
  if (eventDate == null) return false;

  final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
  final startDay = rangeStart != null
      ? DateTime(rangeStart.year, rangeStart.month, rangeStart.day)
      : null;
  final endDay = rangeEnd != null
      ? DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day)
      : null;

  final hasStart = startDay != null;
  final hasEnd = endDay != null;
  final hasCategory = selectedCategory != null && selectedCategory.isNotEmpty;

  final isWithinDateRange = () {
    if (hasStart && hasEnd) {
      return eventDay.compareTo(startDay) >= 0 &&
          eventDay.compareTo(endDay) <= 0;
    } else if (hasStart) {
      return eventDay.compareTo(startDay) >= 0;
    } else if (hasEnd) {
      return eventDay.compareTo(endDay) <= 0;
    } else {
      return true;
    }
  }();

  final isCategoryMatch =
      hasCategory ? (eventCategory ?? []).contains(selectedCategory) : true;

  final isNearby = () {
    if (location == null || eventLocation == null) return true;

    double degToRad(double degree) => degree * math.pi / 180;
    double calculateDistanceInKm(LatLng start, LatLng end) {
      const earthRadiusKm = 6371.0;
      final dLat = degToRad(end.latitude - start.latitude);
      final dLon = degToRad(end.longitude - start.longitude);
      final lat1 = degToRad(start.latitude);
      final lat2 = degToRad(end.latitude);

      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1) *
              math.cos(lat2) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return earthRadiusKm * c;
    }

    final distance = calculateDistanceInKm(location, eventLocation);
    return distance <= 10;
  }();

  return isWithinDateRange && isCategoryMatch && isNearby;
}

bool containsAIMention(String? messageText) {
  if (messageText == null || messageText.isEmpty) {
    return false;
  }

  // Check if message contains @linkai (case insensitive)
  // You can add more AI agent names here if needed
  final aiMentions = ['@linkai'];

  final lowerMessage = messageText.toLowerCase();

  for (final mention in aiMentions) {
    if (lowerMessage.contains(mention.toLowerCase())) {
      return true;
    }
  }

  return false;
}

bool? checkmention(String? string) {
  if (string == null) return false;

  final trimmed = string.trimLeft();

  return trimmed == '@' || trimmed.toLowerCase() == '@linkai';
}

/// Extract the mention query after @ symbol
/// Returns the text after the last @ symbol for filtering members
String? extractMentionQuery(String? text) {
  if (text == null || text.isEmpty) return null;
  
  // Find the last @ symbol
  final lastAtIndex = text.lastIndexOf('@');
  if (lastAtIndex == -1) return null;
  
  // Check if @ is at the start or preceded by whitespace
  if (lastAtIndex > 0) {
    final charBeforeAt = text[lastAtIndex - 1];
    if (charBeforeAt != ' ' && charBeforeAt != '\n') {
      return null; // @ is in the middle of a word
    }
  }
  
  // Extract text after @
  final afterAt = text.substring(lastAtIndex + 1);
  
  // Check if there's a space after the @ (which means mention is complete)
  if (afterAt.contains(' ') || afterAt.contains('\n')) {
    return null;
  }
  
  return afterAt.toLowerCase();
}

/// Check if text contains an active mention being typed
bool hasActiveMention(String? text) {
  return extractMentionQuery(text) != null;
}

bool? locationNear(
  LatLng? eventLocation,
  LatLng? userLocation,
) {
  if (eventLocation == null || userLocation == null) return false;

  const earthRadius = 6371000; // meters
  final dLat =
      (eventLocation.latitude - userLocation.latitude) * (math.pi / 180);
  final dLon =
      (eventLocation.longitude - userLocation.longitude) * (math.pi / 180);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(userLocation.latitude * (math.pi / 180)) *
          math.cos(eventLocation.latitude * (math.pi / 180)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  final distanceInMeters = earthRadius * c;

  return distanceInMeters <= 10000; // true if within 10km
}

bool isDateScheduleNull(List<DateScheduleStruct>? thisSchedule) {
  return thisSchedule == null;
}

List<ScheduleStruct> getScheduleFromEvent(EventsRecord? event) {
  if (event?.dateSchedule != null && event!.dateSchedule.isNotEmpty) {
    final firstDateSchedule = event.dateSchedule.first;
    return firstDateSchedule.schedule!.toList();
    }
  return [];
}

String? getDateFromEvent(EventsRecord? event) {
  if (event?.dateSchedule != null && event!.dateSchedule.isNotEmpty) {
    final firstDateSchedule = event.dateSchedule.first;
    return firstDateSchedule.date ?? '';
  }
  return '';
}

List<String> getEmptyListImagePath() {
  return [];
}
