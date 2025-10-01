// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';

Future<EventsRecord?> passDeeplinkData(String? linkUrl) async {
  if (linkUrl == null || linkUrl.isEmpty) {
    print('[Deeplink] ❌ No link URL provided.');
    return null;
  }

  try {
    final uri = Uri.parse(linkUrl);
    final segments = uri.pathSegments;

    // Expected format: /event/{eventId}/{inviteCode}
    if (segments.length < 3 || segments[0].toLowerCase() != 'event') {
      print(
          '[Deeplink] ❌ Invalid format: Expected /event/{eventId}/{inviteCode}');
      return null;
    }

    final eventId = segments[1];
    final inviteCodeStr = segments[2];

    final eventRef =
        FirebaseFirestore.instance.collection('events').doc(eventId);
    final eventSnap = await eventRef.get();

    if (!eventSnap.exists) {
      print('[Deeplink] ❌ Event not found: $eventId');
      return null;
    }

    final inviteCode = int.tryParse(inviteCodeStr);
    if (inviteCode == null) {
      print('[Deeplink] ❌ Invalid invitation code: "$inviteCodeStr"');
      return null;
    }

    final eventRecord = EventsRecord.fromSnapshot(eventSnap);

    // ✅ Only save invitedCode if needed
    FFAppState().update(() {
      FFAppState().invitedCode = inviteCode;
    });

    print('[Deeplink] ✅ Found event: "$eventId", invitedCode: $inviteCode');
    return eventRecord;
  } catch (e, stack) {
    print('[Deeplink] ❌ Error parsing deeplink: $e\n$stack');
    return null;
  }
}
