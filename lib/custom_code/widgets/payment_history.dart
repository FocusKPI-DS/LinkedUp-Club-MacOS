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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:linkedup/auth/firebase_auth/auth_util.dart';
import 'package:intl/intl.dart';
import 'event_ticket_receipt.dart';

class PaymentHistory extends StatefulWidget {
  const PaymentHistory({
    super.key,
    this.width,
    this.height,
    this.onEventTap,
  });

  final double? width;
  final double? height;
  final Future Function(String? eventId)? onEventTap;

  @override
  _PaymentHistoryState createState() => _PaymentHistoryState();
}

class _PaymentHistoryState extends State<PaymentHistory> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadPayments();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_hasMore && !_isLoading) {
        _loadMorePayments();
      }
    }
  }

  Future<void> _loadPayments() async {
    if (currentUserReference == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('payment_history')
          .where('user_ref', isEqualTo: currentUserReference)
          .orderBy('purchased_at', descending: true)
          .limit(_limit);

      QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;

        List<Map<String, dynamic>> payments = [];
        for (var doc in snapshot.docs) {
          Map<String, dynamic> payment = doc.data() as Map<String, dynamic>;
          payment['id'] = doc.id;

          // Fetch event details
          if (payment['event_ref'] != null) {
            DocumentSnapshot eventDoc =
                await (payment['event_ref'] as DocumentReference).get();
            if (eventDoc.exists) {
              payment['event_data'] = eventDoc.data();
            }
          }

          payments.add(payment);
        }

        setState(() {
          _payments = payments;
          _hasMore = snapshot.docs.length == _limit;
        });
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    } catch (e) {
      print('Error loading payments: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePayments() async {
    if (currentUserReference == null || _lastDocument == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('payment_history')
          .where('user_ref', isEqualTo: currentUserReference)
          .orderBy('purchased_at', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_limit);

      QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;

        List<Map<String, dynamic>> payments = [];
        for (var doc in snapshot.docs) {
          Map<String, dynamic> payment = doc.data() as Map<String, dynamic>;
          payment['id'] = doc.id;

          // Fetch event details
          if (payment['event_ref'] != null) {
            DocumentSnapshot eventDoc =
                await (payment['event_ref'] as DocumentReference).get();
            if (eventDoc.exists) {
              payment['event_data'] = eventDoc.data();
            }
          }

          payments.add(payment);
        }

        setState(() {
          _payments.addAll(payments);
          _hasMore = snapshot.docs.length == _limit;
        });
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    } catch (e) {
      print('Error loading more payments: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatAmount(int amountInCents) {
    if (amountInCents == 0) {
      return 'Free';
    }
    return '\$${(amountInCents / 100).toStringAsFixed(2)}';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
    }
    return 'N/A';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  void _showTicketReceipt(String paymentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).accent3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
              ),
            ),
            // Ticket receipt
            Expanded(
              child: EventTicketReceipt(
                paymentId: paymentId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final eventData = payment['event_data'] as Map<String, dynamic>?;
    final bool isFree = (payment['amount'] ?? 0) == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          // Show ticket receipt when tapped
          _showTicketReceipt(payment['id']);

          // Also call the event tap callback if provided
          if (widget.onEventTap != null) {
            widget.onEventTap!(payment['event_id']);
          }
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: const [
              BoxShadow(
                blurRadius: 4,
                color: Color(0x1A000000),
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: CachedNetworkImage(
                    imageUrl: eventData?['cover_image_url'] ??
                        'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fevent.jpg?alt=media&token=3e30709d-40ff-4e86-a702-5c9c2068fa8d',
                    width: 80.0,
                    height: 80.0,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 80.0,
                      height: 80.0,
                      color: FlutterFlowTheme.of(context).accent2,
                      child: Center(
                        child: SizedBox(
                          width: 20.0,
                          height: 20.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              FlutterFlowTheme.of(context).primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 80.0,
                      height: 80.0,
                      color: FlutterFlowTheme.of(context).accent2,
                      child: Icon(
                        Icons.event,
                        color: FlutterFlowTheme.of(context).secondaryText,
                        size: 30.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                // Payment Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Title
                      Text(
                        payment['event_title'] ?? 'Unknown Event',
                        style: FlutterFlowTheme.of(context).bodyLarge.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4.0),
                      // Date
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: FlutterFlowTheme.of(context).secondaryText,
                            size: 14.0,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            _formatDate(payment['purchased_at']),
                            style:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.inter(),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      fontSize: 13.0,
                                      letterSpacing: 0.0,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      // Price and Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Price
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: isFree
                                  ? FlutterFlowTheme.of(context)
                                      .success
                                      .withOpacity(0.1)
                                  : FlutterFlowTheme.of(context)
                                      .primary
                                      .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              _formatAmount(payment['amount'] ?? 0),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: isFree
                                        ? FlutterFlowTheme.of(context).success
                                        : FlutterFlowTheme.of(context).primary,
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          // Status
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                      payment['status'] ?? 'pending')
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              (payment['status'] ?? 'pending').toUpperCase(),
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    color: _getStatusColor(
                                        payment['status'] ?? 'pending'),
                                    fontSize: 11.0,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      // Transaction ID (if not free)
                      if (!isFree && payment['transaction_id'] != null) ...[
                        const SizedBox(height: 4.0),
                        Text(
                          'ID: ${payment['transaction_id']}',
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                font: GoogleFonts.inter(),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 11.0,
                                letterSpacing: 0.0,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64.0,
            color: FlutterFlowTheme.of(context).secondaryText,
          ),
          const SizedBox(height: 16.0),
          Text(
            'No Payment History',
            style: FlutterFlowTheme.of(context).headlineSmall.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                  fontSize: 20.0,
                  letterSpacing: 0.0,
                ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Your ticket purchases will appear here',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(),
                  color: FlutterFlowTheme.of(context).secondaryText,
                  fontSize: 14.0,
                  letterSpacing: 0.0,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Container(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 16.0, 8.0),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment History',
                        style: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                              fontSize: 20.0,
                              letterSpacing: 0.0,
                            ),
                      ),
                      Text(
                        'View all your event ticket purchases',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.inter(),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              fontSize: 12.0,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading && _payments.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  )
                : _payments.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPayments,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _payments.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _payments.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 24.0,
                                          height: 24.0,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.0,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'No more payments',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                font: GoogleFonts.inter(),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 12.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                ),
                              );
                            }
                            return _buildPaymentCard(_payments[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
