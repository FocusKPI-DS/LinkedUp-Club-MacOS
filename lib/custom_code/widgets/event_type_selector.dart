// Automatic FlutterFlow imports
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
// Imports other custom widgets
// Imports custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!
import 'package:google_fonts/google_fonts.dart';

class EventTypeSelector extends StatefulWidget {
  const EventTypeSelector({
    super.key,
    this.width,
    this.height,
    this.initialValue,
    required this.onChanged,
  });

  final double? width;
  final double? height;
  final String? initialValue;
  final Future Function(String changeText) onChanged;

  @override
  _EventTypeSelectorState createState() => _EventTypeSelectorState();
}

class _EventTypeSelectorState extends State<EventTypeSelector> {
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialValue ?? 'physical';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Event Type',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                        ),
                        color: const Color(0xFF374151),
                        fontSize: 14.0,
                        letterSpacing: 0.0,
                      ),
                ),
                TextSpan(
                  text: '*',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).tertiary,
                    fontSize: 14.0,
                  ),
                ),
              ],
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                    ),
                    fontSize: 14.0,
                    letterSpacing: 0.0,
                  ),
            ),
          ),
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              children: [
                _buildEventTypeOption(
                  context,
                  'physical',
                  'Physical Event',
                  'In-person event at a physical location',
                  Icons.location_on,
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                _buildEventTypeOption(
                  context,
                  'virtual',
                  'Virtual Event',
                  'Online-only event (video conference, webinar)',
                  Icons.computer,
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                _buildEventTypeOption(
                  context,
                  'hybrid',
                  'Hybrid Event',
                  'Both in-person and online attendance options',
                  Icons.hub,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedType == 'virtual'
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: _selectedType == 'virtual'
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedType == 'virtual'
                        ? 'Virtual events can use Apple Pay for tickets'
                        : 'Physical/hybrid events will use Stripe for payment processing',
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedType == 'virtual'
                          ? const Color(0xFF1E40AF)
                          : const Color(0xFF92400E),
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

  Widget _buildEventTypeOption(
    BuildContext context,
    String value,
    String title,
    String description,
    IconData icon,
  ) {
    bool isSelected = _selectedType == value;

    return InkWell(
      onTap: () async {
        setState(() {
          _selectedType = value;
        });
        await widget.onChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        color: isSelected
            ? FlutterFlowTheme.of(context).primary.withOpacity(0.1)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? FlutterFlowTheme.of(context).primary
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? FlutterFlowTheme.of(context).primary
                  : FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
