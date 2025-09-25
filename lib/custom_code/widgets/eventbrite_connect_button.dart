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

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:google_fonts/google_fonts.dart';

class EventbriteConnectButton extends StatefulWidget {
  const EventbriteConnectButton({
    super.key,
    this.width,
    this.height,
    this.onConnectCallback,
  });

  final double? width;
  final double? height;
  final Future Function()? onConnectCallback;

  @override
  State<EventbriteConnectButton> createState() =>
      _EventbriteConnectButtonState();
}

class _EventbriteConnectButtonState extends State<EventbriteConnectButton> {
  bool _isLoading = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  @override
  void didUpdateWidget(EventbriteConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check connection status whenever the widget updates
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    // Check if user has already connected EventBrite
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .get();

    if (userDoc.exists) {
      final data = userDoc.data();
      setState(() {
        _isConnected = data?['eventbrite_connected'] ?? false;
      });
    }
  }

  Future<void> _handleConnect() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Call the EventBrite OAuth action
      await eventbriteOAuthConnect();

      // Call callback if provided
      if (widget.onConnectCallback != null) {
        await widget.onConnectCallback!();
      }

      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      print('Error connecting to EventBrite: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to EventBrite. Please try again.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDisconnect() async {
    // Show confirmation dialog
    final bool? shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Disconnect EventBrite?'),
          content: Text(
              'Are you sure you want to disconnect your EventBrite account? You\'ll need to reconnect to sync events again.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Disconnect',
                style: TextStyle(color: FlutterFlowTheme.of(context).error),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDisconnect != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update user document to remove EventBrite connection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .update({
        'eventbrite_connected': false,
        'eventbrite_access_token': FieldValue.delete(),
        'eventbrite_refresh_token': FieldValue.delete(),
        'eventbrite_user_id': FieldValue.delete(),
        'eventbrite_user_name': FieldValue.delete(),
        'eventbrite_connected_at': FieldValue.delete(),
      });

      setState(() {
        _isConnected = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disconnected from EventBrite'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );
    } catch (e) {
      print('Error disconnecting from EventBrite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to disconnect. Please try again.'),
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
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 56.0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isConnected
              ? [Color(0xFF28A745), Color(0xFF218838)]
              : [Color(0xFFFF6F00), Color(0xFFE65100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: (_isConnected ? Color(0xFF28A745) : Color(0xFFFF6F00))
                .withOpacity(0.3),
            blurRadius: 8.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading
              ? null
              : () async {
                  if (_isConnected) {
                    // If connected, call the callback (which navigates to dashboard)
                    if (widget.onConnectCallback != null) {
                      await widget.onConnectCallback!();
                    }
                  } else {
                    // If not connected, start the connection process
                    await _handleConnect();
                  }
                },
          onLongPress: _isLoading || !_isConnected
              ? null
              : () async {
                  // Long press to disconnect
                  await _handleDisconnect();
                },
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2.0,
                    ),
                  )
                else
                  FaIcon(
                    _isConnected
                        ? FontAwesomeIcons.checkCircle
                        : FontAwesomeIcons.calendar,
                    color: Colors.white,
                    size: 20.0,
                  ),
                SizedBox(width: 12.0),
                Text(
                  _isLoading
                      ? 'Connecting...'
                      : (_isConnected
                          ? 'View EventBrite Events'
                          : 'Connect EventBrite'),
                  style: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                        color: Colors.white,
                        fontSize: 16.0,
                        letterSpacing: 0.0,
                      ),
                ),
                if (!_isLoading) ...[
                  SizedBox(width: 8.0),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16.0,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
