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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> deleteUserData() async {
  try {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      print('❌ No signed-in user found.');
      return;
    }

    final uid = currentUser.uid;
    final userRef = firestore.collection('users').doc(uid);

    // 🧹 1. Delete from collections that use user_ref (DocumentReference)
    final docRefTargets = [
      {'collection': 'user_memo', 'field': 'owner_ref'},
      {'collection': 'user_memo', 'field': 'target_ref'},
      {'collection': 'reports', 'field': 'reported_by'},
      {'collection': 'reports', 'field': 'reported_user'},
      {'collection': 'posts', 'field': 'author_ref'},
      {'collection': 'invitation_code', 'field': 'inviter_ref'},
    ];

    for (final entry in docRefTargets) {
      final snapshot = await firestore
          .collection(entry['collection']!)
          .where(entry['field']!, isEqualTo: userRef)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        print('🗑 Deleted ${doc.id} from ${entry['collection']}');
      }
    }

    // 🧹 2. Clean subcollections (event participants, post comments)
    final eventDocs = await firestore.collection('events').get();
    for (final event in eventDocs.docs) {
      final participants = await event.reference
          .collection('participant')
          .where('user_ref', isEqualTo: userRef)
          .get();
      for (final p in participants.docs) {
        await p.reference.delete();
      }
    }

    final postDocs = await firestore.collection('posts').get();
    for (final post in postDocs.docs) {
      final comments = await post.reference
          .collection('comments')
          .where('user_ref', isEqualTo: userRef)
          .get();
      for (final comment in comments.docs) {
        await comment.reference.delete();
      }

      // Remove from liked_by / saved_by
      await post.reference.update({
        'liked_by': FieldValue.arrayRemove([userRef]),
        'saved_by': FieldValue.arrayRemove([userRef]),
      });
    }

    // 🧹 3. Handle chats: delete only if user is creator, otherwise remove them
    final chatDocs = await firestore.collection('chats').get();
    for (final chat in chatDocs.docs) {
      final data = chat.data();
      final createdBy = data['created_by'];
      final isCreator =
          createdBy is DocumentReference && createdBy.path == userRef.path;

      if (isCreator) {
        await chat.reference.delete();
        print('🗑 Deleted chat ${chat.id} (user was creator)');
      } else {
        await chat.reference.update({
          'members': FieldValue.arrayRemove([userRef]),
          'blocked_user': FieldValue.arrayRemove([userRef]),
          'last_message_seen': FieldValue.arrayRemove([userRef]),
        });
        print('🚫 Removed user from chat ${chat.id}');
      }

      // Delete messages sent by this user
      final messages = await chat.reference
          .collection('messages')
          .where('sender_ref', isEqualTo: userRef)
          .get();
      for (final msg in messages.docs) {
        await msg.reference.delete();
      }
    }

    // 🧹 4. Delete events created by this user
    final hostedEvents = await firestore
        .collection('events')
        .where('creator_id', isEqualTo: userRef)
        .get();
    for (final event in hostedEvents.docs) {
      await event.reference.delete();
    }

    // 🧹 5. Delete user document
    await userRef.delete();
    print('✅ Firestore user document deleted');

    // 🧹 6. Try to delete Firebase Auth account (ignore reauth errors)
    // Try to delete Auth user with reauthentication if needed
    try {
      await currentUser.delete();
      print('✅ Firebase Auth user deleted');
    } catch (e) {
      print('⚠️ Firebase Auth delete failed: $e');

      if (e.toString().contains('requires-recent-login')) {
        // You must reauthenticate first
        final email = currentUser.email;

        // ⚠️ Replace this with how you collect the password
        final password =
            'user-password'; // ← You must securely collect this from user

        if (email != null && password.isNotEmpty) {
          try {
            final cred =
                EmailAuthProvider.credential(email: email, password: password);
            await currentUser.reauthenticateWithCredential(cred);
            await currentUser.delete();
            print('✅ Firebase Auth user deleted after reauth');
          } catch (reauthError) {
            print('❌ Reauthentication failed: $reauthError');
          }
        } else {
          print('⚠️ Cannot reauthenticate: email or password missing');
        }
      }
    }
  } catch (e) {
    print('❌ Error during user deletion: $e');
  }
}
