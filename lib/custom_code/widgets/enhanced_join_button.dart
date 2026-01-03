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

import '/flutter_flow/flutter_flow_widgets.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class EnhancedJoinButton extends StatefulWidget {
  const EnhancedJoinButton({
    super.key,
    this.width,
    this.height,
    required this.eventDoc,
    required this.onSuccess,
    required this.onError,
  });

  final double? width;
  final double? height;
  final EventsRecord eventDoc;
  final Future Function()? onSuccess;
  final Future Function(String error)? onError;

  @override
  _EnhancedJoinButtonState createState() => _EnhancedJoinButtonState();
}

class _EnhancedJoinButtonState extends State<EnhancedJoinButton> {
  bool _isLoading = false;
  bool _hasJoined = false;

  @override
  void initState() {
    super.initState();
    _checkIfJoined();
  }

  Future<void> _checkIfJoined() async {
    if (currentUserReference != null &&
        widget.eventDoc.participants.contains(currentUserReference)) {
      setState(() {
        _hasJoined = true;
      });
    }
  }

  Future<void> _handlePurchase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simple join - add user to event participants
      await widget.eventDoc.reference.update({
        'participants': FieldValue.arrayUnion([currentUserReference]),
      });

      // Create participant record
      await widget.eventDoc.reference.collection('participant').add({
        'user_ref': currentUserReference,
        'userId': currentUserUid,
        'name': currentUserDisplayName,
        'image': currentUserPhoto,
        'bio': '',
        'joined_at': FieldValue.serverTimestamp(),
        'status': 'joined',
      });

      setState(() {
        _hasJoined = true;
      });
      
      if (widget.onSuccess != null) {
        await widget.onSuccess!();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully joined event!',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: FlutterFlowTheme.of(context).success,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (widget.onError != null) {
        await widget.onError!(e.toString());
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'An error occurred: ${e.toString()}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLeave() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Remove from participants
      await widget.eventDoc.reference.update({
        'participants': FieldValue.arrayRemove([currentUserReference]),
      });

      // Delete participant record
      final participantDocs = await widget.eventDoc.reference
          .collection('participant')
          .where('user_ref', isEqualTo: currentUserReference)
          .get();

      for (var doc in participantDocs.docs) {
        await doc.reference.delete();
      }

      setState(() {
        _hasJoined = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'You have left the event',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to leave event',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getButtonText() {
    if (_hasJoined) {
      return 'Leave Event';
    }
    if (widget.eventDoc.price == 0) {
      return 'Join Free';
    }
    return 'Buy Ticket - \$${widget.eventDoc.price}';
  }

  Color _getButtonColor() {
    if (_hasJoined) {
      return const Color(0xFFFA000F); // Red for leave
    }
    return const Color(0xFF2563EB); // Blue for join/buy
  }

  @override
  Widget build(BuildContext context) {
    // Don't show button if user is the creator
    if (widget.eventDoc.creatorId == currentUserReference) {
      return const SizedBox.shrink();
    }

    return FFButtonWidget(
      onPressed:
          _isLoading ? null : (_hasJoined ? _handleLeave : _handlePurchase),
      text: _isLoading ? 'Processing...' : _getButtonText(),
      icon: _isLoading
          ? null
          : (_hasJoined
              ? null
              : (widget.eventDoc.price > 0
                  ? const Icon(Icons.shopping_cart, size: 18)
                  : null)),
      options: FFButtonOptions(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 50.0,
        padding: const EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
        iconPadding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 0.0),
        color: _getButtonColor(),
        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
              font: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
              ),
              color: Colors.white,
              fontSize: 16.0,
              letterSpacing: 0.0,
            ),
        elevation: 2.0,
        borderRadius: BorderRadius.circular(8.0),
        disabledColor: FlutterFlowTheme.of(context).secondaryText,
      ),
      showLoadingIndicator: _isLoading,
    );
  }
}
