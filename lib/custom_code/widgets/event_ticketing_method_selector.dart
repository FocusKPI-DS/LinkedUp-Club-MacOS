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

class EventTicketingMethodSelector extends StatefulWidget {
  const EventTicketingMethodSelector({
    super.key,
    this.width,
    this.height,
    this.onSelectionChanged,
    this.initialEventType,
    this.initialTicketingMethod,
  });

  final double? width;
  final double? height;
  final Future Function(String eventType, String ticketingMethod)?
      onSelectionChanged;
  final String? initialEventType;
  final String? initialTicketingMethod;

  @override
  _EventTicketingMethodSelectorState createState() =>
      _EventTicketingMethodSelectorState();
}

class _EventTicketingMethodSelectorState
    extends State<EventTicketingMethodSelector> {
  String _selectedEventType = 'physical'; // physical, virtual, hybrid
  String _selectedTicketingMethod = 'stripe'; // stripe, revenuecat, free

  @override
  void initState() {
    super.initState();
    _selectedEventType = widget.initialEventType ?? 'physical';
    _selectedTicketingMethod = widget.initialTicketingMethod ?? 'stripe';
  }

  void _updateSelection() {
    if (widget.onSelectionChanged != null) {
      widget.onSelectionChanged!(_selectedEventType, _selectedTicketingMethod);
    }
  }

  Widget _buildEventTypeCard(
      String type, String title, String description, IconData icon) {
    final isSelected = _selectedEventType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEventType = type;
          // Auto-select appropriate ticketing method
          if (type == 'virtual') {
            _selectedTicketingMethod = 'revenuecat';
          } else {
            _selectedTicketingMethod = 'stripe';
          }
        });
        _updateSelection();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? FlutterFlowTheme.of(context).primary.withOpacity(0.1)
              : FlutterFlowTheme.of(context).secondaryBackground,
          border: Border.all(
            color: isSelected
                ? FlutterFlowTheme.of(context).primary
                : FlutterFlowTheme.of(context).accent3,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? FlutterFlowTheme.of(context).primary
                      : FlutterFlowTheme.of(context).secondaryText,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? FlutterFlowTheme.of(context).primary
                          : FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketingMethodCard(String method, String title,
      String description, IconData icon, Color iconColor) {
    final isSelected = _selectedTicketingMethod == method;
    final isEnabled =
        (_selectedEventType == 'virtual' && method == 'revenuecat') ||
            (_selectedEventType != 'virtual' && method == 'stripe') ||
            (method == 'free');

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled
            ? () {
                setState(() {
                  _selectedTicketingMethod = method;
                });
                _updateSelection();
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected && isEnabled
                ? FlutterFlowTheme.of(context).primary.withOpacity(0.1)
                : FlutterFlowTheme.of(context).secondaryBackground,
            border: Border.all(
              color: isSelected && isEnabled
                  ? FlutterFlowTheme.of(context).primary
                  : FlutterFlowTheme.of(context).accent3,
              width: isSelected && isEnabled ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected && isEnabled
                        ? FlutterFlowTheme.of(context).primary
                        : iconColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected && isEnabled
                            ? FlutterFlowTheme.of(context).primary
                            : FlutterFlowTheme.of(context).primaryText,
                      ),
                    ),
                  ),
                  if (isSelected && isEnabled)
                    Icon(
                      Icons.check_circle,
                      color: FlutterFlowTheme.of(context).primary,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Type',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          const SizedBox(height: 12),

          // Event Type Selection
          Column(
            children: [
              _buildEventTypeCard(
                'physical',
                'Physical Event',
                'In-person event with physical location',
                Icons.location_on,
              ),
              const SizedBox(height: 8),
              _buildEventTypeCard(
                'virtual',
                'Virtual Event',
                'Online event via video conference',
                Icons.videocam,
              ),
              const SizedBox(height: 8),
              _buildEventTypeCard(
                'hybrid',
                'Hybrid Event',
                'Both in-person and online attendance',
                Icons.merge_type,
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'Ticketing Method',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          const SizedBox(height: 12),

          // Ticketing Method Selection
          Column(
            children: [
              _buildTicketingMethodCard(
                'free',
                'Free Event',
                'No payment required - instant registration',
                Icons.free_breakfast,
                Colors.green,
              ),
              const SizedBox(height: 8),
              _buildTicketingMethodCard(
                'stripe',
                'Stripe Payment',
                'Credit card payments for physical/hybrid events',
                Icons.credit_card,
                Colors.purple,
              ),
              const SizedBox(height: 8),
              _buildTicketingMethodCard(
                'revenuecat',
                'Apple/Google Pay',
                'In-app purchases for virtual events only',
                Icons.phone_android,
                Colors.blue,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Info Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).accent1.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: FlutterFlowTheme.of(context).accent1,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: FlutterFlowTheme.of(context).primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getInfoText(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInfoText() {
    if (_selectedEventType == 'virtual' &&
        _selectedTicketingMethod == 'revenuecat') {
      return 'Virtual events use Apple/Google Pay for seamless mobile payments.';
    } else if (_selectedEventType == 'physical' &&
        _selectedTicketingMethod == 'stripe') {
      return 'Physical events use Stripe for secure credit card processing.';
    } else if (_selectedEventType == 'hybrid' &&
        _selectedTicketingMethod == 'stripe') {
      return 'Hybrid events use Stripe to handle both in-person and online attendees.';
    } else if (_selectedTicketingMethod == 'free') {
      return 'Free events allow instant registration without payment processing.';
    } else {
      return 'Select your event type and preferred payment method.';
    }
  }
}
