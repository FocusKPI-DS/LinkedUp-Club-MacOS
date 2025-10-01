// Automatic FlutterFlow imports
import '/backend/backend.dart';
import 'index.dart'; // Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import '/auth/firebase_auth/auth_util.dart';
import 'dart:io';

// Hybrid payment system that chooses the appropriate method
Future<PurchaseResultStruct> purchaseEventTicketHybrid(
  String eventId,
  String eventTitle,
  int priceInCents,
  DocumentReference eventRef,
  String eventType, // 'physical', 'hybrid', 'virtual'
  String eventLocation, // Physical address or 'online'
) async {
  try {
    // For free events, always use direct registration
    if (priceInCents == 0) {
      return await _processFreeTicket(eventId, eventTitle, eventRef);
    }

    // Determine payment method based on platform and event type
    bool shouldUseAppleIAP = _shouldUseAppleIAP(eventType, eventLocation);

    if (shouldUseAppleIAP && Platform.isIOS) {
      // Use Apple In-App Purchase for virtual events on iOS
      return await _purchaseWithAppleIAP(
          eventId, eventTitle, priceInCents, eventRef);
    } else {
      // Use Stripe for physical/hybrid events or non-iOS platforms
      return await _purchaseWithStripe(
          eventId, eventTitle, priceInCents, eventRef);
    }
  } catch (e) {
    print("Error in hybrid purchase: $e");
    return createPurchaseResultStruct(
      success: false,
      message: 'Failed to process payment',
      error: e.toString(),
    );
  }
}

bool _shouldUseAppleIAP(String eventType, String eventLocation) {
  // Use Apple IAP for virtual-only events
  if (eventType.toLowerCase() == 'virtual' &&
      eventLocation.toLowerCase() == 'online') {
    return true;
  }

  // Use Stripe for physical and hybrid events
  return false;
}

Future<PurchaseResultStruct> _purchaseWithAppleIAP(
  String eventId,
  String eventTitle,
  int priceInCents,
  DocumentReference eventRef,
) async {
  // This would integrate with in_app_purchase package
  // For now, return not implemented
  return createPurchaseResultStruct(
    success: false,
    message: 'Apple In-App Purchase integration needed',
    error: 'NOT_IMPLEMENTED',
  );
}

Future<PurchaseResultStruct> _purchaseWithStripe(
  String eventId,
  String eventTitle,
  int priceInCents,
  DocumentReference eventRef,
) async {
  // Use the Stripe implementation from purchase_event_ticket_stripe.dart
  return await purchaseEventTicketStripe(
      eventId, eventTitle, priceInCents, eventRef);
}

Future<PurchaseResultStruct> _processFreeTicket(
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

  return createPurchaseResultStruct(
    success: true,
    message: 'Successfully registered for free event',
    transactionId: 'free_${DateTime.now().millisecondsSinceEpoch}',
  );
}
