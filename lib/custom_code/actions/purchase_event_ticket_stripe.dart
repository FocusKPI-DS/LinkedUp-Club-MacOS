// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:cloud_firestore/cloud_firestore.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// This is a more flexible approach using Stripe Checkout or Payment Links
// You'll need to set up a Cloud Function to handle Stripe payments

Future<PurchaseResultStruct> purchaseEventTicketStripe(
  String eventId,
  String eventTitle,
  int priceInCents,
  DocumentReference eventRef,
) async {
  try {
    // For free events, bypass payment processing
    if (priceInCents == 0) {
      // Create payment history record for free event
      await FirebaseFirestore.instance.collection('payment_history').add({
        'user_ref': currentUserReference,
        'event_ref': eventRef,
        'event_id': eventId,
        'event_title': eventTitle,
        'amount': 0,
        'currency': 'USD',
        'payment_method': 'free',
        'status': 'completed',
        'transaction_id': 'free_${DateTime.now().millisecondsSinceEpoch}',
        'purchased_at': FieldValue.serverTimestamp(),
      });

      // Add user to event participants
      await eventRef.update({
        'participants': FieldValue.arrayUnion([currentUserReference]),
      });

      // Create participant record
      await eventRef.collection('participant').add({
        'user_ref': currentUserReference,
        'userId': currentUserUid,
        'name': currentUserDisplayName,
        'image': currentUserPhoto,
        'bio': '',
        'joined_at': FieldValue.serverTimestamp(),
        'status': 'joined',
        'ticket_type': 'free',
      });

      return createPurchaseResultStruct(
        success: true,
        message: 'Successfully registered for free event',
        transactionId: 'free_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    // For paid events, create a payment session through your backend
    // This requires setting up a Cloud Function that creates Stripe Checkout sessions

    try {
      // Call your Cloud Function to create a Stripe Checkout session
      // Replace this URL with your actual Cloud Function URL
      final response = await http.post(
        Uri.parse(
            'https://us-central1-linkedup-c3e29.cloudfunctions.net/createStripeCheckout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentUserUid',
        },
        body: json.encode({
          'eventId': eventId,
          'eventTitle': eventTitle,
          'priceInCents': priceInCents,
          'userId': currentUserUid,
          'userEmail': currentUserEmail,
          'eventRef': eventRef.path,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Store pending payment record
        await FirebaseFirestore.instance.collection('payment_history').add({
          'user_ref': currentUserReference,
          'event_ref': eventRef,
          'event_id': eventId,
          'event_title': eventTitle,
          'amount': priceInCents,
          'currency': 'USD',
          'payment_method': 'stripe',
          'status': 'pending',
          'stripe_session_id': data['sessionId'],
          'checkout_url': data['checkoutUrl'],
          'created_at': FieldValue.serverTimestamp(),
        });

        // Return success with checkout URL
        // The app should open this URL in a webview or browser
        return createPurchaseResultStruct(
          success: true,
          message: data['checkoutUrl'], // Return the checkout URL
          transactionId: data['sessionId'],
        );
      } else {
        return createPurchaseResultStruct(
          success: false,
          message: 'Failed to create payment session',
          error: 'HTTP_ERROR_${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error creating Stripe checkout: $e');
      return createPurchaseResultStruct(
        success: false,
        message: 'Failed to process payment',
        error: e.toString(),
      );
    }
  } catch (e) {
    print("Error purchasing ticket: $e");
    return createPurchaseResultStruct(
      success: false,
      message: 'Failed to purchase ticket',
      error: e.toString(),
    );
  }
}

// Alternative: Direct in-app payment using stored payment methods
Future<PurchaseResultStruct> purchaseEventTicketDirect(
  String eventId,
  String eventTitle,
  int priceInCents,
  DocumentReference eventRef,
) async {
  try {
    // For free events
    if (priceInCents == 0) {
      await _processFreeTicket(eventId, eventTitle, eventRef);
      return createPurchaseResultStruct(
        success: true,
        message: 'Successfully registered for free event',
        transactionId: 'free_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    // For paid events, process through your payment backend
    // This would typically involve:
    // 1. Getting the user's saved payment method
    // 2. Creating a payment intent on your backend
    // 3. Confirming the payment
    // 4. Recording the transaction

    // For now, we'll create a pending transaction
    final transactionId = 'txn_${DateTime.now().millisecondsSinceEpoch}';

    await FirebaseFirestore.instance.collection('payment_history').add({
      'user_ref': currentUserReference,
      'event_ref': eventRef,
      'event_id': eventId,
      'event_title': eventTitle,
      'amount': priceInCents,
      'currency': 'USD',
      'payment_method': 'card',
      'status': 'pending',
      'transaction_id': transactionId,
      'created_at': FieldValue.serverTimestamp(),
    });

    // In a real implementation, you would:
    // 1. Process the payment through your backend
    // 2. Wait for confirmation
    // 3. Update the payment status
    // 4. Add user to event participants on success

    return createPurchaseResultStruct(
      success: false,
      message: 'Payment processing not yet implemented',
      error: 'NOT_IMPLEMENTED',
    );
  } catch (e) {
    print("Error processing payment: $e");
    return createPurchaseResultStruct(
      success: false,
      message: 'Failed to process payment',
      error: e.toString(),
    );
  }
}

Future<void> _processFreeTicket(
  String eventId,
  String eventTitle,
  DocumentReference eventRef,
) async {
  // Create payment history record
  await FirebaseFirestore.instance.collection('payment_history').add({
    'user_ref': currentUserReference,
    'event_ref': eventRef,
    'event_id': eventId,
    'event_title': eventTitle,
    'amount': 0,
    'currency': 'USD',
    'payment_method': 'free',
    'status': 'completed',
    'transaction_id': 'free_${DateTime.now().millisecondsSinceEpoch}',
    'purchased_at': FieldValue.serverTimestamp(),
  });

  // Add user to event participants
  await eventRef.update({
    'participants': FieldValue.arrayUnion([currentUserReference]),
  });

  // Create participant record
  await eventRef.collection('participant').add({
    'user_ref': currentUserReference,
    'userId': currentUserUid,
    'name': currentUserDisplayName,
    'image': currentUserPhoto,
    'bio': '',
    'joined_at': FieldValue.serverTimestamp(),
    'status': 'joined',
    'ticket_type': 'free',
  });
}
