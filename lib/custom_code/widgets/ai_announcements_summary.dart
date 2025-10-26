// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:google_fonts/google_fonts.dart';

class AIAnnouncementsSummary extends StatelessWidget {
  const AIAnnouncementsSummary({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 320.0, // Increased height to prevent overflow
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            blurRadius: 8.0,
            color: const Color(0x1A000000),
            offset: const Offset(0.0, 2.0),
          ),
        ],
      ),
      child: SingleChildScrollView(
        // Add scroll to prevent overflow
        child: Padding(
          padding: const EdgeInsets.all(12.0), // Further reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32.0,
                    height: 32.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 20.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI-Generated Announcements Summary',
                          style:
                              FlutterFlowTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: const Color(0xFF2D3748),
                                    fontSize:
                                        MediaQuery.of(context).size.width < 600
                                            ? 16.0
                                            : 18.0,
                                    letterSpacing: 0.0,
                                  ),
                        ),
                        Text(
                          'Smart Digest',
                          style:
                              FlutterFlowTheme.of(context).bodySmall.override(
                                    font: GoogleFonts.inter(),
                                    color: const Color(0xFF718096),
                                    fontSize:
                                        MediaQuery.of(context).size.width < 600
                                            ? 12.0
                                            : 14.0,
                                    letterSpacing: 0.0,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Updated 5 minutes ago',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.inter(),
                          color: const Color(0xFF9C27B0),
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 11.0
                              : 12.0,
                          letterSpacing: 0.0,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0), // Further reduced spacing

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      icon: Icons.campaign,
                      iconColor: const Color(0xFF3182CE),
                      backgroundColor: const Color(0xFFEBF8FF),
                      number: '12',
                      title: 'New Announcements',
                      subtitle: 'This week',
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      icon: Icons.star,
                      iconColor: const Color(0xFF38A169),
                      backgroundColor: const Color(0xFFF0FFF4),
                      number: '8',
                      title: 'High Priority',
                      subtitle: 'Require attention',
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      icon: Icons.event_available,
                      iconColor: const Color(0xFFDD6B20),
                      backgroundColor: const Color(0xFFFFF5F5),
                      number: '5',
                      title: 'Upcoming Events',
                      subtitle: 'Next 30 days',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0), // Further reduced spacing

              // Key Insights
              Row(
                children: [
                  Icon(
                    Icons.insights,
                    color: const Color(0xFF3182CE),
                    size: 20.0,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'Key Insights',
                    style: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                          ),
                          color: const Color(0xFF2D3748),
                          letterSpacing: 0.0,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0), // Further reduced spacing

              // Insights List
              Column(
                children: [
                  _buildInsightItem(
                    context,
                    color: const Color(0xFF3182CE),
                    text: 'Q4 strategy meeting scheduled for all team leads',
                  ),
                  const SizedBox(height: 4.0), // Further reduced spacing
                  _buildInsightItem(
                    context,
                    color: const Color(0xFF38A169),
                    text: 'New employee welcome program launching next month',
                  ),
                  const SizedBox(height: 4.0), // Further reduced spacing
                  _buildInsightItem(
                    context,
                    color: const Color(0xFFDD6B20),
                    text: 'Holiday schedule and office closure dates announced',
                  ),
                  const SizedBox(height: 4.0), // Further reduced spacing
                  _buildInsightItem(
                    context,
                    color: const Color(0xFF9C27B0),
                    text: 'New security protocols effective immediately',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0), // Reduced padding
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24.0,
          ),
          const SizedBox(height: 6.0), // Reduced spacing
          Text(
            number,
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                  ),
                  color: const Color(0xFF2D3748),
                  letterSpacing: 0.0,
                ),
          ),
          const SizedBox(height: 2.0), // Reduced spacing
          Text(
            title,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                  ),
                  color: const Color(0xFF2D3748),
                  letterSpacing: 0.0,
                ),
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: const Color(0xFF718096),
                  letterSpacing: 0.0,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(
    BuildContext context, {
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: Text(
            text,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(),
                  color: const Color(0xFF2D3748),
                  letterSpacing: 0.0,
                ),
          ),
        ),
      ],
    );
  }
}
