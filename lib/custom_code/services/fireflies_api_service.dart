// Fireflies.ai – Cloud Functions only. API key stays on the server.

import 'package:cloud_functions/cloud_functions.dart';

/// Lightweight transcript item for list display.
class FirefliesTranscriptItem {
  const FirefliesTranscriptItem({
    required this.id,
    required this.title,
    this.date,
    this.duration,
  });

  final String id;
  final String title;
  final String? date;
  final int? duration;

  factory FirefliesTranscriptItem.fromJson(Map<String, dynamic> json) {
    final dateVal = json['date'];
    String? dateStr;
    if (dateVal != null) {
      if (dateVal is String) {
        dateStr = dateVal;
      } else if (dateVal is num) {
        dateStr = DateTime.fromMillisecondsSinceEpoch(dateVal.toInt())
            .toIso8601String();
      }
    }
    // JSON numbers often come as double; safely coerce to int for duration
    int? duration;
    final durationVal = json['duration'];
    if (durationVal != null && durationVal is num) {
      duration = durationVal.toInt();
    }
    return FirefliesTranscriptItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      date: dateStr,
      duration: duration,
    );
  }
}

/// Result of fetching transcripts (list + optional error for UX).
class FirefliesTranscriptsResult {
  const FirefliesTranscriptsResult({
    required this.transcripts,
    this.errorMessage,
  });

  final List<FirefliesTranscriptItem> transcripts;
  final String? errorMessage;

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

// ========== Cloud Functions (secure, works across all devices) ==========

/// Connect Fireflies for the group. Admin only. Key is stored on the server only.
/// Returns { success: true } or { success: false, error: string }.
Future<Map<String, dynamic>> firefliesConnectViaCloud(
    String chatId, String apiKey) async {
  try {
    final response = await FirebaseFunctions.instance
        .httpsCallable('firefliesConnect')
        .call({'chatId': chatId, 'apiKey': apiKey});
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    return data..['success'] = true;
  } on FirebaseFunctionsException catch (e) {
    return {'success': false, 'error': e.message ?? e.code};
  }
}

/// Disconnect Fireflies for the group. Admin only.
Future<Map<String, dynamic>> firefliesDisconnectViaCloud(String chatId) async {
  try {
    final response = await FirebaseFunctions.instance
        .httpsCallable('firefliesDisconnect')
        .call({'chatId': chatId});
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    return data..['success'] = true;
  } on FirebaseFunctionsException catch (e) {
    return {'success': false, 'error': e.message ?? e.code};
  }
}

/// Returns whether Fireflies is connected for this group.
Future<bool> firefliesGetConnectionStatusViaCloud(String chatId) async {
  try {
    final response = await FirebaseFunctions.instance
        .httpsCallable('firefliesGetConnectionStatus')
        .call({'chatId': chatId});
    final data = response.data is Map ? response.data as Map : null;
    return data?['connected'] == true;
  } catch (_) {
    return false;
  }
}

/// Fetch transcripts via Cloud Function (no API key on client).
Future<FirefliesTranscriptsResult> firefliesGetTranscriptsViaCloud(
  String chatId, {
  int limit = 5,
  int skip = 0,
}) async {
  try {
    final response = await FirebaseFunctions.instance
        .httpsCallable('firefliesGetTranscripts')
        .call({'chatId': chatId, 'limit': limit, 'skip': skip});
    final res = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    if (res['connected'] != true) {
      return const FirefliesTranscriptsResult(transcripts: []);
    }
    final raw = res['transcripts'];
    if (raw == null || raw is! List) {
      return const FirefliesTranscriptsResult(transcripts: []);
    }
    final transcripts = raw
        .map((e) => FirefliesTranscriptItem.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
    return FirefliesTranscriptsResult(transcripts: transcripts);
  } on FirebaseFunctionsException catch (e) {
    return FirefliesTranscriptsResult(
      transcripts: [],
      errorMessage: e.message ?? e.code,
    );
  } catch (e) {
    return FirefliesTranscriptsResult(
      transcripts: [],
      errorMessage: e.toString(),
    );
  }
}

/// Fetch a single transcript (summary, action items, etc.) from Fireflies and store in Firestore.
/// Returns { success: true, transcript: {...} } or throws / returns error.
Future<Map<String, dynamic>> firefliesFetchAndStoreTranscriptViaCloud(
  String chatId,
  String transcriptId,
) async {
  try {
    final response = await FirebaseFunctions.instance
        .httpsCallable('firefliesFetchAndStoreTranscript')
        .call({'chatId': chatId, 'transcriptId': transcriptId});
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    return data;
  } on FirebaseFunctionsException catch (e) {
    return {'success': false, 'error': e.message ?? e.code};
  }
}

/// Process manual transcription with OpenAI and store in manualTranscripts.
/// Call with chatId and the pasted transcription text. Updates chat's manual_meeting_transcription and posts LonaAI summary.
Future<Map<String, dynamic>> manualTranscriptProcessViaCloud(
  String chatId,
  String transcriptionText,
) async {
  try {
    final response = await FirebaseFunctions.instance
        .httpsCallable('manualTranscriptProcess')
        .call({
      'chatId': chatId,
      'transcriptionText': transcriptionText,
    });
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    return data;
  } on FirebaseFunctionsException catch (e) {
    return {'success': false, 'error': e.message ?? e.code};
  }
}
