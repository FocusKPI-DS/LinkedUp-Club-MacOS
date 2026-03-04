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

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> handleDeletedContent(
  BuildContext context,
  String?
      contentPath, // Can be either a path like 'events/abc123' or just an ID
  String? contentType, // Optional hint about content type
) async {
  // Universal content checker that handles deleted/cancelled content gracefully

  try {
    if (contentPath == null || contentPath.isEmpty) {
      return false;
    }

    DocumentSnapshot? docSnapshot;
    String? collection;
    String? docId;

    // Parse the content path
    if (contentPath.contains('/')) {
      // Full path provided (e.g., 'events/abc123' or 'chats/xyz789')
      final parts = contentPath.split('/');
      if (parts.length >= 2) {
        collection = parts[0];
        docId = parts[1];
      }
    } else {
      // Just an ID provided, use content type hint
      docId = contentPath;

      // Try to determine collection from content type or context
      if (contentType != null) {
        switch (contentType.toLowerCase()) {
          case 'event':
          case 'events':
            collection = 'events';
            break;
          case 'chat':
          case 'chats':
          case 'group':
            collection = 'chats';
            break;
          case 'user':
          case 'users':
            collection = 'users';
            break;
          case 'post':
          case 'posts':
            collection = 'posts';
            break;
          case 'participant':
            // For participant, we need event reference
            // This is a special case handled separately
            break;
        }
      }
    }

    // Fetch the document if we have collection and ID
    if (collection != null && docId != null) {
      docSnapshot = await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .get();
    }

    // Check if document exists
    if (docSnapshot == null || !docSnapshot.exists) {
      // Show appropriate message based on content type
      String message = '';
      if (collection != null) {
        switch (collection.toLowerCase()) {
          case 'events':
            message = 'This event has been cancelled or deleted.';
            break;
          case 'chats':
            message = 'This chat or group has been deleted.';
            break;
          case 'users':
            message = 'This user account no longer exists.';
            break;
          case 'posts':
            message = 'This post has been deleted.';
            break;
          default:
            message = 'This content is no longer available.';
        }
      } else {
        message = 'This content is no longer available.';
      }

      // Show snackbar with message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.0,
            ),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Go Back',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );

      // Navigate back after a delay
      await Future.delayed(const Duration(seconds: 2));
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      return false; // Content doesn't exist
    }

    // Check if content is marked as deleted/cancelled (optional fields)
    Map<String, dynamic>? data = docSnapshot.data() as Map<String, dynamic>?;
    if (data != null) {
      // Check for various deletion/cancellation flags
      bool isDeleted = data['is_deleted'] ?? false;
      bool isCancelled = data['is_cancelled'] ?? false;
      bool isArchived = data['is_archived'] ?? false;
      bool isInactive = data['is_inactive'] ?? false;

      if (isDeleted || isCancelled || isArchived || isInactive) {
        String status = isDeleted
            ? 'deleted'
            : isCancelled
                ? 'cancelled'
                : isArchived
                    ? 'archived'
                    : 'inactive';

        String message = '';
        if (collection != null) {
          switch (collection.toLowerCase()) {
            case 'events':
              message = 'This event has been $status.';
              break;
            case 'chats':
              message = 'This chat has been $status.';
              break;
            case 'users':
              message = 'This user account has been $status.';
              break;
            case 'posts':
              message = 'This post has been $status.';
              break;
            default:
              message = 'This content has been $status.';
          }
        } else {
          message = 'This content has been $status.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.0,
              ),
            ),
            backgroundColor: FlutterFlowTheme.of(context).warning,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Go Back',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );

        // Navigate back after a delay
        await Future.delayed(const Duration(seconds: 2));
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        return false; // Content is marked as deleted/cancelled
      }
    }

    return true; // Content exists and is active
  } catch (e) {
    print('Error checking content: $e');

    // Show generic error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Unable to load content. Please try again.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.0,
          ),
        ),
        backgroundColor: FlutterFlowTheme.of(context).error,
        duration: const Duration(seconds: 3),
      ),
    );

    return false;
  }
}
