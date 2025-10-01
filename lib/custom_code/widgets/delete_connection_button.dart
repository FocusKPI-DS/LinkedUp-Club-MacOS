// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!

import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class DeleteConnectionButton extends StatefulWidget {
  const DeleteConnectionButton({
    super.key,
    this.width,
    this.height,
    required this.targetUser,
    this.onDeleted,
  });

  final double? width;
  final double? height;
  final UsersRecord targetUser;
  final Future Function()? onDeleted;

  @override
  _DeleteConnectionButtonState createState() => _DeleteConnectionButtonState();
}

class _DeleteConnectionButtonState extends State<DeleteConnectionButton> {
  bool _isLoading = false;

  Future<void> _deleteConnection() async {
    // Show confirmation dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Connection',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  fontSize: 20.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          content: Text(
            'Are you sure you want to remove ${widget.targetUser.displayName} from your connections? You will need to send a new connection request to reconnect.',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.normal,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.normal,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.normal,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.normal,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text(
                'Yes, Delete',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).error,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get references
      DocumentReference currentUserRef = currentUserReference!;
      DocumentReference targetUserRef = widget.targetUser.reference;

      // Create batch for atomic operations
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Remove target user from current user's friends list
      batch.update(currentUserRef, {
        'friends': FieldValue.arrayRemove([targetUserRef]),
      });

      // Remove current user from target user's friends list
      batch.update(targetUserRef, {
        'friends': FieldValue.arrayRemove([currentUserRef]),
      });

      // Delete any user memo records between these users
      // Delete memo from current user to target user
      QuerySnapshot currentUserMemos = await FirebaseFirestore.instance
          .collection('userMemo')
          .where('owner_ref', isEqualTo: currentUserRef)
          .where('target_ref', isEqualTo: targetUserRef)
          .get();

      for (DocumentSnapshot doc in currentUserMemos.docs) {
        batch.delete(doc.reference);
      }

      // Delete memo from target user to current user
      QuerySnapshot targetUserMemos = await FirebaseFirestore.instance
          .collection('userMemo')
          .where('owner_ref', isEqualTo: targetUserRef)
          .where('target_ref', isEqualTo: currentUserRef)
          .get();

      for (DocumentSnapshot doc in targetUserMemos.docs) {
        batch.delete(doc.reference);
      }

      // Find and delete the direct chat between these users if it exists
      QuerySnapshot chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('is_group', isEqualTo: false)
          .where('members', arrayContains: currentUserRef)
          .get();

      for (DocumentSnapshot chatDoc in chatsSnapshot.docs) {
        Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
        List<dynamic> members = chatData['members'] ?? [];

        // Check if this is a direct chat between these two users
        if (members.length == 2 && members.contains(targetUserRef)) {
          // Delete all messages in this chat
          QuerySnapshot messagesSnapshot =
              await chatDoc.reference.collection('messages').get();

          for (DocumentSnapshot messageDoc in messagesSnapshot.docs) {
            batch.delete(messageDoc.reference);
          }

          // Delete the chat itself
          batch.delete(chatDoc.reference);
        }
      }

      // Commit all changes
      await batch.commit();

      // Call the onDeleted callback if provided
      if (widget.onDeleted != null) {
        await widget.onDeleted!();
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Connection removed successfully'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );

      // Navigate back
      Navigator.of(context).pop();
    } catch (error) {
      print('Error deleting connection: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error removing connection. Please try again.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 50.0,
      child: FFButtonWidget(
        onPressed: _isLoading ? null : _deleteConnection,
        text: _isLoading ? 'Deleting...' : 'Delete Connection',
        options: FFButtonOptions(
          width: double.infinity,
          height: 50.0,
          padding: const EdgeInsets.all(8.0),
          iconPadding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
          color: FlutterFlowTheme.of(context).secondaryBackground,
          textStyle: FlutterFlowTheme.of(context).titleMedium.override(
                font: GoogleFonts.inter(
                  fontWeight:
                      FlutterFlowTheme.of(context).titleMedium.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                ),
                color: const Color(0xFFEF4444),
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).titleMedium.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
              ),
          elevation: 0.0,
          borderSide: const BorderSide(
            color: Color(0xFFEF4444),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
          disabledColor: FlutterFlowTheme.of(context).accent2,
        ),
      ),
    );
  }
}
