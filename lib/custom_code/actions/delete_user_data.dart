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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

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

    // 🧹 6. Delete Firebase Auth account
    // Must handle different auth providers for reauthentication
    try {
      await currentUser.delete();
      print('✅ Firebase Auth user deleted');
    } catch (e) {
      print('⚠️ Firebase Auth delete failed (first attempt): $e');

      if (e.toString().contains('requires-recent-login')) {
        // Need to reauthenticate based on the sign-in provider
        bool reauthSuccess = false;
        final providerData = currentUser.providerData;
        final providerIds = providerData.map((p) => p.providerId).toList();
        print('🔑 User providers: $providerIds');

        // Try Google reauthentication
        if (providerIds.contains('google.com')) {
          try {
            if (kIsWeb) {
              // Web: use popup-based reauthentication
              final googleProvider = GoogleAuthProvider();
              await currentUser.reauthenticateWithPopup(googleProvider);
            } else {
              // Native: use google_sign_in package
              final GoogleSignIn googleSignIn = GoogleSignIn();
              final googleUser = await googleSignIn.signIn();
              if (googleUser != null) {
                final googleAuth = await googleUser.authentication;
                final credential = GoogleAuthProvider.credential(
                  accessToken: googleAuth.accessToken,
                  idToken: googleAuth.idToken,
                );
                await currentUser.reauthenticateWithCredential(credential);
              }
            }
            reauthSuccess = true;
          } catch (googleError) {
            print('⚠️ Google reauthentication failed: $googleError');
          }
        }

        // Try Apple reauthentication
        if (!reauthSuccess && providerIds.contains('apple.com')) {
          try {
            final appleProvider = AppleAuthProvider();
            if (kIsWeb) {
              await currentUser.reauthenticateWithPopup(appleProvider);
            } else {
              await currentUser.reauthenticateWithProvider(appleProvider);
            }
            reauthSuccess = true;
          } catch (appleError) {
            print('⚠️ Apple reauthentication failed: $appleError');
          }
        }

        // Try email/password reauthentication (only if password provider exists)
        // Note: we cannot reauthenticate email users without their password input
        if (!reauthSuccess && providerIds.contains('password')) {
          print('⚠️ Email/password user requires manual reauthentication - cannot auto-delete Auth account');
        }

        // Attempt delete after reauthentication
        if (reauthSuccess) {
          try {
            await currentUser.delete();
            print('✅ Firebase Auth user deleted after reauthentication');
          } catch (deleteError) {
            print('❌ Firebase Auth delete still failed after reauth: $deleteError');
          }
        } else {
          print('⚠️ Could not reauthenticate - Firebase Auth account may remain. User data has been cleaned from Firestore.');
        }
      }
    }
  } catch (e) {
    print('❌ Error during user deletion: $e');
  }
}
