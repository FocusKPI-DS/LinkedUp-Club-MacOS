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
import 'package:barcode_widget/barcode_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:linkedup/auth/firebase_auth/auth_util.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';

class EventTicketReceipt extends StatefulWidget {
  const EventTicketReceipt({
    Key? key,
    this.width,
    this.height,
    required this.paymentId,
  }) : super(key: key);

  final double? width;
  final double? height;
  final String paymentId;

  @override
  _EventTicketReceiptState createState() => _EventTicketReceiptState();
}

class _EventTicketReceiptState extends State<EventTicketReceipt> {
  final GlobalKey _globalKey = GlobalKey();
  Map<String, dynamic>? _paymentData;
  Map<String, dynamic>? _eventData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentData();
  }

  Future<void> _loadPaymentData() async {
    try {
      // Load payment data
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payment_history')
          .doc(widget.paymentId)
          .get();

      if (paymentDoc.exists) {
        _paymentData = paymentDoc.data();

        // Load event data
        if (_paymentData!['event_ref'] != null) {
          final eventDoc =
              await (_paymentData!['event_ref'] as DocumentReference).get();
          if (eventDoc.exists) {
            _eventData = eventDoc.data() as Map<String, dynamic>;
          }
        }
      }
    } catch (e) {
      print('Error loading payment data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Uint8List?> _captureTicket() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing ticket: $e');
      return null;
    }
  }

  Future<void> _downloadTicket() async {
    try {
      // Give the layout one frame to settle
      await Future.delayed(const Duration(milliseconds: 120));

      // Capture
      final Uint8List? imageBytes = await _captureTicket();
      if (imageBytes == null) {
        throw Exception('Failed to capture ticket image');
      }

      // Save to app Documents dir (safe on iOS/Android, no extra perms)
      final directory = await getApplicationDocumentsDirectory();
      final String fileName =
          'LinkedUp_Ticket_${widget.paymentId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${directory.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      debugPrint('Ticket saved to: ${file.path}');

      if (!mounted) return;

      // Prompt to open
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Download complete'),
          content: Text('Open “$fileName” now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open'),
            ),
          ],
        ),
      );

      if (shouldOpen == true) {
        final result =
            await OpenFilex.open(file.path); // hands off to OS viewer
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Couldn’t open ticket: ${result.message}')),
          );
        }
        return;
      }

      // If user tapped "Later", still show success feedback
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Ticket saved successfully.')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      debugPrint('Download error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download ticket: $e'),
          backgroundColor: FlutterFlowTheme.of(context).error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy • h:mm a').format(timestamp.toDate());
    }
    return 'N/A';
  }

  String _formatAmount(int? amountInCents) {
    if (amountInCents == null || amountInCents == 0) {
      return 'Free';
    }
    return '\$${(amountInCents / 100).toStringAsFixed(2)}';
  }

  Widget _buildTicketUI() {
    final ticketId = _paymentData?['transaction_id'] ?? widget.paymentId;
    final qrData =
        'ticket:${widget.paymentId}:${currentUserUid}:${_eventData?['event_id'] ?? ''}';

    return RepaintBoundary(
      key: _globalKey,
      child: Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with event image
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                image: DecorationImage(
                  image: CachedNetworkImageProvider(
                    _eventData?['cover_image_url'] ??
                        'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _eventData?['title'] ?? 'Event Ticket',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _formatDate(_eventData?['start_date']),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Ticket details
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // QR Code
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      data: qrData,
                      width: 150,
                      height: 150,
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      errorBuilder: (context, error) => Container(
                        width: 150,
                        height: 150,
                        color: FlutterFlowTheme.of(context).accent2,
                        child: Center(
                          child: Text(
                            'QR Error',
                            style: FlutterFlowTheme.of(context).bodySmall,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Ticket ID
                  Text(
                    'TICKET ID',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    ticketId.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 1.2,
                    ),
                  ),

                  SizedBox(height: 20),

                  // Divider with dots
                  Row(
                    children: List.generate(
                      20,
                      (index) => Expanded(
                        child: Container(
                          height: 1,
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          color: index % 2 == 0
                              ? FlutterFlowTheme.of(context).accent3
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Ticket info grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          'ATTENDEE',
                          currentUserDisplayName.isNotEmpty
                              ? currentUserDisplayName
                              : 'Guest',
                          Icons.person,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: FlutterFlowTheme.of(context).accent3,
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'TICKET TYPE',
                          _paymentData?['amount'] == 0 ? 'FREE' : 'PAID',
                          Icons.confirmation_number,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          'LOCATION',
                          _eventData?['location'] ?? 'N/A',
                          Icons.location_on,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: FlutterFlowTheme.of(context).accent3,
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'AMOUNT',
                          _formatAmount(_paymentData?['amount']),
                          Icons.attach_money,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Purchase date
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          FlutterFlowTheme.of(context).accent1.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: FlutterFlowTheme.of(context).success,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Purchased on ${_formatDate(_paymentData?['purchased_at'])}',
                          style: GoogleFonts.inter(
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FlutterFlowTheme.of(context).primaryText,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 400,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              FlutterFlowTheme.of(context).primary,
            ),
          ),
        ),
      );
    }

    if (_paymentData == null) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: FlutterFlowTheme.of(context).error,
              ),
              SizedBox(height: 16),
              Text(
                'Ticket not found',
                style: FlutterFlowTheme.of(context).headlineSmall,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: widget.width ?? double.infinity,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Add top padding
            SizedBox(height: 8),

            // Ticket
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _buildTicketUI(),
            ),

            // Download button
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: ElevatedButton.icon(
                onPressed: _downloadTicket,
                icon: Icon(Icons.download, color: Colors.white),
                label: Text(
                  'Download Ticket',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlutterFlowTheme.of(context).primary,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            // Extra bottom padding to prevent cutoff
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
