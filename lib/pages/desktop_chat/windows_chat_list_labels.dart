import 'package:cloud_firestore/cloud_firestore.dart';

import '/pages/desktop_chat/desktop_safe_user_builder.dart';

/// Sidebar DM title without Firestore (Windows/Linux list stability).
String windowsChatDmListLabel({
  required DocumentReference otherUserRef,
  String? cachedName,
}) {
  if (otherUserRef.path.contains('ai_agent_summerai')) {
    return 'Summer';
  }
  if (cachedName != null && cachedName.isNotEmpty) {
    return cachedName;
  }
  return 'Direct Chat';
}

bool get windowsChatListSkipUserFetch => DesktopSafeUserBuilder.useOnceFetch;
