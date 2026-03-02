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

import 'package:google_fonts/google_fonts.dart';

class InvitationSkipButton extends StatefulWidget {
  const InvitationSkipButton({
    super.key,
    this.width,
    this.height,
    this.onSkip,
  });

  final double? width;
  final double? height;
  final Future Function()? onSkip;

  @override
  _InvitationSkipButtonState createState() => _InvitationSkipButtonState();
}

class _InvitationSkipButtonState extends State<InvitationSkipButton> {
  bool _isProcessing = false;

  Future<void> _handleSkip() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Show confirmation dialog
      final shouldSkip = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              'Skip Invitation Code?',
              style: FlutterFlowTheme.of(context).headlineSmall.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                    letterSpacing: 0.0,
                  ),
            ),
            content: Text(
              'You can skip the invitation code and continue with full access to LinkedUp.\n\nWould you like to continue without an invitation code?',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(),
                    letterSpacing: 0.0,
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancel',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                        ),
                        color: FlutterFlowTheme.of(context).secondaryText,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: FlutterFlowTheme.of(context).primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Continue',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                        color: Colors.white,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
            ],
          );
        },
      );

      if (shouldSkip == true) {
        // Note: User skipped invitation - this will be handled in the signup page

        // Call the onSkip callback if provided
        if (widget.onSkip != null) {
          await widget.onSkip!();
        }

        // Navigate to signup page
        context.goNamed(
          'SignUp',
          queryParameters: {
            'skippedInvite': serializeParam(
              true,
              ParamType.bool,
            ),
          }.withoutNulls,
          extra: <String, dynamic>{
            kTransitionInfoKey: const TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.fade,
            ),
          },
        );
      }
    } catch (e) {
      print('Error skipping invitation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('An error occurred. Please try again.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 50.0,
      child: OutlinedButton(
        onPressed: _isProcessing ? null : _handleSkip,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: FlutterFlowTheme.of(context).accent3,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: _isProcessing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).primary,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_forward,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Skip for now',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                          ),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontSize: 14.0,
                          letterSpacing: 0.0,
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}
