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
import 'package:google_fonts/google_fonts.dart';

class EventTicketingSelector extends StatefulWidget {
  const EventTicketingSelector({
    super.key,
    this.width,
    this.height,
    required this.eventId,
    required this.currentMode,
    this.onModeChanged,
  });

  final double? width;
  final double? height;
  final String eventId;
  final bool currentMode; // true = EventBrite, false = LinkedUp
  final Future Function(bool useEventbrite)? onModeChanged;

  @override
  State<EventTicketingSelector> createState() => _EventTicketingSelectorState();
}

class _EventTicketingSelectorState extends State<EventTicketingSelector> {
  late bool _useEventbriteTicketing;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _useEventbriteTicketing = widget.currentMode;
  }

  Future<void> _handleModeChange(bool useEventbrite) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      // Update the ticketing mode
      await updateEventTicketingMode(widget.eventId, useEventbrite);

      setState(() {
        _useEventbriteTicketing = useEventbrite;
      });

      // Call the callback if provided
      if (widget.onModeChanged != null) {
        await widget.onModeChanged!(useEventbrite);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            useEventbrite
                ? 'Switched to EventBrite ticketing'
                : 'Switched to LinkedUp ticketing',
          ),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );

      // If switching to LinkedUp, sync attendees
      if (!useEventbrite) {
        await syncEventbriteAttendees(widget.eventId);
      }
    } catch (e) {
      print('Error updating ticketing mode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update ticketing mode'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 200.0,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ticketing Mode',
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                  letterSpacing: 0.0,
                ),
          ),
          const SizedBox(height: 4.0),
          Text(
            'Choose how attendees will register for this event',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                ),
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: Row(
              children: [
                // EventBrite Option
                Expanded(
                  child: InkWell(
                    onTap: _isUpdating ? null : () => _handleModeChange(true),
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: _useEventbriteTicketing
                            ? const Color(0xFFFF6F00).withOpacity(0.1)
                            : FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: _useEventbriteTicketing
                              ? const Color(0xFFFF6F00)
                              : FlutterFlowTheme.of(context).alternate,
                          width: 2.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.calendar,
                            color: _useEventbriteTicketing
                                ? const Color(0xFFFF6F00)
                                : FlutterFlowTheme.of(context).secondaryText,
                            size: 32.0,
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'EventBrite',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  color: _useEventbriteTicketing
                                      ? const Color(0xFFFF6F00)
                                      : FlutterFlowTheme.of(context)
                                          .primaryText,
                                  letterSpacing: 0.0,
                                ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            'Use EventBrite\nfor ticketing',
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.inter(),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      fontSize: 11.0,
                                      letterSpacing: 0.0,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                // LinkedUp Option
                Expanded(
                  child: InkWell(
                    onTap: _isUpdating ? null : () => _handleModeChange(false),
                    borderRadius: BorderRadius.circular(12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: !_useEventbriteTicketing
                            ? FlutterFlowTheme.of(context)
                                .primary
                                .withOpacity(0.1)
                            : FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: !_useEventbriteTicketing
                              ? FlutterFlowTheme.of(context).primary
                              : FlutterFlowTheme.of(context).alternate,
                          width: 2.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.link,
                            color: !_useEventbriteTicketing
                                ? FlutterFlowTheme.of(context).primary
                                : FlutterFlowTheme.of(context).secondaryText,
                            size: 32.0,
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'LinkedUp',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  color: !_useEventbriteTicketing
                                      ? FlutterFlowTheme.of(context).primary
                                      : FlutterFlowTheme.of(context)
                                          .primaryText,
                                  letterSpacing: 0.0,
                                ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            'Use LinkedUp\nfor ticketing',
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.inter(),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      fontSize: 11.0,
                                      letterSpacing: 0.0,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isUpdating)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
