import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/custom_code/actions/auto_connect_company.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum ConnectionRequestOutcome {
  cancelled,
  sent,
  autoAccepted,
  acceptedIncoming,
}

class ConnectionRequestException implements Exception {
  const ConnectionRequestException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// LinkedIn-style connection requests: optional intro note, chat only after accept.
class ConnectionRequestHelpers {
  static const int maxNoteLength = 300;
  static const String notesField = 'friend_request_notes';

  static String? noteFrom(UsersRecord recipient, DocumentReference senderRef) {
    final note = recipient.friendRequestNotes[senderRef.id]?.trim();
    if (note == null || note.isEmpty) return null;
    return note;
  }

  static Widget noteBanner(String? note) {
    if (note == null || note.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Note',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: Color(0xFF94A3B8),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w400,
              color: Color(0xFF334155),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows the optional-note dialog, then sends (or auto-accepts) the request.
  static Future<ConnectionRequestOutcome> promptAndSend({
    required BuildContext context,
    required UsersRecord targetUser,
  }) async {
    final meRef = currentUserReference;
    if (meRef == null) {
      throw const ConnectionRequestException('You are not signed in');
    }

    final currentUser = await fsGetUserOnce(meRef);
    if (_contains(currentUser.friends, targetUser.reference)) {
      throw ConnectionRequestException(
        'You are already connected with ${targetUser.displayName}',
      );
    }
    if (_contains(currentUser.sentRequests, targetUser.reference)) {
      throw ConnectionRequestException(
        'Connection request already sent to ${targetUser.displayName}',
      );
    }

    if (_contains(currentUser.friendRequests, targetUser.reference)) {
      await accept(targetUser);
      return ConnectionRequestOutcome.acceptedIncoming;
    }

    final target = await fsGetUserOnce(targetUser.reference);
    if (_shouldAutoAccept(sender: currentUser, target: target)) {
      await fsArrayUnion(meRef, 'friends', [target.reference]);
      await fsArrayUnion(target.reference, 'friends', [meRef]);
      await fsArrayRemove(meRef, 'sent_requests', [target.reference]);
      await fsArrayRemove(target.reference, 'friend_requests', [meRef]);
      return ConnectionRequestOutcome.autoAccepted;
    }

    if (!context.mounted) return ConnectionRequestOutcome.cancelled;

    final note = await promptForNote(
      context,
      recipientName: target.displayName.isNotEmpty
          ? target.displayName
          : 'this person',
    );
    if (note == null) return ConnectionRequestOutcome.cancelled;

    await fsArrayUnion(meRef, 'sent_requests', [target.reference]);
    await fsArrayUnion(target.reference, 'friend_requests', [meRef]);
    if (note.isNotEmpty) {
      try {
        await _setNote(
          recipientRef: target.reference,
          senderId: meRef.id,
          note: note,
        );
      } catch (e) {
        debugPrint('Failed to save connection request note: $e');
      }
    }

    actions.sendConnectionRequestEmail(
      recipientEmail: target.email,
      recipientName: target.displayName,
      senderName: currentUser.displayName,
    );

    return ConnectionRequestOutcome.sent;
  }

  static Future<String?> promptForNote(
    BuildContext context, {
    required String recipientName,
  }) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: Text(
              'Connect with $recipientName',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            content: SizedBox(
              width: 380,
              child: StatefulBuilder(
                builder: (context, setState) {
                  final remaining = maxNoteLength - controller.text.length;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add an optional note. They’ll see it with your request. You can message freely after they accept.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        maxLength: maxNoteLength,
                        maxLines: 4,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Hi, I’d like to connect because…',
                          hintStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          counterText: '$remaining left',
                          counterStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: const Text(
                  'Send',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  static Future<void> accept(UsersRecord sender) async {
    final meRef = currentUserReference;
    if (meRef == null) {
      throw const ConnectionRequestException('You are not signed in');
    }
    final currentUser = await fsGetUserOnce(meRef);
    if (_contains(currentUser.friends, sender.reference)) {
      throw ConnectionRequestException(
        'You are already connected with ${sender.displayName}',
      );
    }
    if (!_contains(currentUser.friendRequests, sender.reference)) {
      throw ConnectionRequestException(
        'No pending request from ${sender.displayName}',
      );
    }

    await fsArrayUnion(meRef, 'friends', [sender.reference]);
    await fsArrayRemove(meRef, 'friend_requests', [sender.reference]);
    await fsArrayRemove(meRef, 'sent_requests', [sender.reference]);
    await fsArrayUnion(sender.reference, 'friends', [meRef]);
    await fsArrayRemove(sender.reference, 'sent_requests', [meRef]);
    await _clearNote(recipientRef: meRef, senderId: sender.reference.id);
  }

  static Future<void> decline(UsersRecord sender) async {
    final meRef = currentUserReference;
    if (meRef == null) {
      throw const ConnectionRequestException('You are not signed in');
    }
    final currentUser = await fsGetUserOnce(meRef);
    if (!_contains(currentUser.friendRequests, sender.reference)) {
      throw ConnectionRequestException(
        'No pending request from ${sender.displayName}',
      );
    }

    await fsArrayRemove(meRef, 'friend_requests', [sender.reference]);
    try {
      await fsArrayRemove(sender.reference, 'sent_requests', [meRef]);
    } catch (_) {}
    await _clearNote(recipientRef: meRef, senderId: sender.reference.id);
  }

  static Future<void> cancel(UsersRecord target) async {
    final meRef = currentUserReference;
    if (meRef == null) {
      throw const ConnectionRequestException('You are not signed in');
    }
    final currentUser = await fsGetUserOnce(meRef);
    if (_contains(currentUser.friends, target.reference)) {
      throw ConnectionRequestException(
        'You are already connected with ${target.displayName}',
      );
    }
    if (!_contains(currentUser.sentRequests, target.reference)) {
      throw ConnectionRequestException(
        'No pending request to ${target.displayName}',
      );
    }

    await fsArrayRemove(meRef, 'sent_requests', [target.reference]);
    try {
      await fsArrayRemove(target.reference, 'friend_requests', [meRef]);
    } catch (_) {}
    await _clearNote(recipientRef: target.reference, senderId: meRef.id);
  }

  static String? successMessage(
    ConnectionRequestOutcome outcome,
    String displayName,
  ) {
    switch (outcome) {
      case ConnectionRequestOutcome.cancelled:
        return null;
      case ConnectionRequestOutcome.sent:
        return 'Connection request sent to $displayName';
      case ConnectionRequestOutcome.autoAccepted:
      case ConnectionRequestOutcome.acceptedIncoming:
        return 'Connected with $displayName!';
    }
  }

  static bool _shouldAutoAccept({
    required UsersRecord sender,
    required UsersRecord target,
  }) {
    if (target.autoAcceptAllRequests) return true;
    final senderDomain = getEmailDomain(sender.email);
    final targetDomain = getEmailDomain(target.email);
    if (target.autoAcceptSameCompany &&
        senderDomain != null &&
        senderDomain == targetDomain &&
        isCompanyEmail(sender.email)) {
      return true;
    }
    if (senderDomain != null &&
        target.autoAcceptEmailDomains.contains(senderDomain)) {
      return true;
    }
    return false;
  }

  static bool _contains(List<DocumentReference> list, DocumentReference ref) {
    return list.any((item) => item.path == ref.path);
  }

  static Future<void> _setNote({
    required DocumentReference recipientRef,
    required String senderId,
    required String note,
  }) async {
    final recipient = await fsGetUserOnce(recipientRef);
    final notes = Map<String, String>.from(recipient.friendRequestNotes);
    notes[senderId] = note;
    await fsPatchDocument(recipientRef, {notesField: notes});
  }

  static Future<void> _clearNote({
    required DocumentReference recipientRef,
    required String senderId,
  }) async {
    try {
      final recipient = await fsGetUserOnce(recipientRef);
      if (!recipient.friendRequestNotes.containsKey(senderId)) return;
      final notes = Map<String, String>.from(recipient.friendRequestNotes)
        ..remove(senderId);
      await fsPatchDocument(recipientRef, {notesField: notes});
    } catch (_) {}
  }
}
