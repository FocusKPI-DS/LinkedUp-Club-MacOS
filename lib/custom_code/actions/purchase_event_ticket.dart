// Automatic FlutterFlow imports
import '/backend/backend.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
import 'package:purchases_flutter/purchases_flutter.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';

Future<PurchaseResultStruct> purchaseEventTicket(
  String eventId,
  String eventTitle,
  int priceInCents,
  DocumentReference eventRef,
  String? eventType, // physical, virtual, or hybrid
) async {
  try {
    // For free events, bypass payment systems
    if (priceInCents == 0) {
      return await _processFreeTicket(
        eventId: eventId,
        eventTitle: eventTitle,
        eventRef: eventRef,
      );
    }

    // Determine payment method based on event type and platform
    bool useApplePay = false;

    if (Platform.isIOS) {
      // On iOS, use Apple Pay (RevenueCat) for virtual events only
      // Use Stripe for physical and hybrid events
      useApplePay = (eventType == 'virtual');
    } else {
      // On Android and Web, always use Stripe
      useApplePay = false;
    }

    if (useApplePay) {
      // Use RevenueCat for virtual events on iOS
      return await _processRevenueCatPayment(
        eventId: eventId,
        eventTitle: eventTitle,
        priceInCents: priceInCents,
        eventRef: eventRef,
      );
    } else {
      // Use Stripe for physical/hybrid events or non-iOS platforms
      return await _processStripePayment(
        eventId: eventId,
        eventTitle: eventTitle,
        priceInCents: priceInCents,
        eventRef: eventRef,
        eventType: eventType ?? 'physical',
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

// Process free ticket registration
Future<PurchaseResultStruct> _processFreeTicket({
  required String eventId,
  required String eventTitle,
  required DocumentReference eventRef,
}) async {
  try {
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
  } catch (e) {
    return createPurchaseResultStruct(
      success: false,
      message: 'Failed to register for event',
      error: e.toString(),
    );
  }
}

// Process payment via RevenueCat (for virtual events on iOS)
Future<PurchaseResultStruct> _processRevenueCatPayment({
  required String eventId,
  required String eventTitle,
  required int priceInCents,
  required DocumentReference eventRef,
}) async {
  try {
    // Get offerings from RevenueCat
    Offerings offerings = await Purchases.getOfferings();

    // Find the appropriate package based on price tier
    String tierProductId = _getPriceTierProductId(priceInCents);
    Package? package;

    for (var offering in offerings.all.values) {
      var tierPackage = offering.availablePackages.firstWhere(
        (pkg) => pkg.identifier == tierProductId,
        orElse: () => offering.availablePackages.first,
      );
      package = tierPackage;
      break;
    }

    if (package == null) {
      return createPurchaseResultStruct(
        success: false,
        message: 'No ticket package available for this price point',
        error: 'PACKAGE_NOT_FOUND',
      );
    }

    // Make the purchase
    CustomerInfo customerInfo = await Purchases.purchasePackage(package);

    // Check if purchase was successful
    if (customerInfo.entitlements.active.isNotEmpty) {
      // Create payment history record
      await FirebaseFirestore.instance.collection('payment_history').add({
        'user_ref': currentUserReference,
        'event_ref': eventRef,
        'event_id': eventId,
        'event_title': eventTitle,
        'amount': priceInCents,
        'currency': 'USD',
        'payment_method': 'apple_pay',
        'status': 'completed',
        'transaction_id': customerInfo.originalPurchaseDate ??
            DateTime.now().toIso8601String(),
        'purchased_at': FieldValue.serverTimestamp(),
        'revenue_cat_data': {
          'customer_id': customerInfo.originalAppUserId,
          'product_id': package.storeProduct.identifier,
          'entitlements': customerInfo.entitlements.active.keys.toList(),
        },
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
        'ticket_type': 'paid',
        'ticket_price': priceInCents,
        'payment_method': 'apple_pay',
      });

      return createPurchaseResultStruct(
        success: true,
        message: 'Ticket purchased successfully',
        transactionId: customerInfo.originalPurchaseDate,
      );
    } else {
      return createPurchaseResultStruct(
        success: false,
        message: 'Purchase was not completed',
        error: 'PURCHASE_INCOMPLETE',
      );
    }
  } on PurchasesErrorCode catch (e) {
    String errorMessage = _getRevenueCatErrorMessage(e);
    return createPurchaseResultStruct(
      success: false,
      message: errorMessage,
      error: e.toString(),
    );
  }
}

// Process payment via Stripe (for physical/hybrid events)
Future<PurchaseResultStruct> _processStripePayment({
  required String eventId,
  required String eventTitle,
  required int priceInCents,
  required DocumentReference eventRef,
  required String eventType,
}) async {
  try {
    // Get the current user's email
    String userEmail = currentUserEmail;
    if (userEmail.isEmpty) {
      return createPurchaseResultStruct(
        success: false,
        message: 'Please ensure you are logged in with a valid email',
        error: 'EMAIL_REQUIRED',
      );
    }

    // Get event details for Stripe
    final eventDoc = await eventRef.get();
    final eventData = eventDoc.data() as Map<String, dynamic>?;

    // Use Firebase callable function instead of HTTP request
    final callable =
        FirebaseFunctions.instance.httpsCallable('createStripeCheckout');

    try {
      final result = await callable.call({
        'eventId': eventId,
        'eventTitle': eventTitle,
        'priceInCents': priceInCents,
        'userId': currentUserUid,
        'userEmail': userEmail,
        'eventRef': eventRef.path,
        'eventType': eventType,
        'eventCoverImage': eventData?['cover_image_url'] ?? '',
        'eventDate':
            eventData?['start_date']?.toDate()?.toIso8601String() ?? '',
      });

      final data = result.data as Map<String, dynamic>;
      final checkoutUrl = data['checkoutUrl'] ?? data['url'];

      // Open Stripe Checkout in browser
      if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
        await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        );

        // Return pending status - webhook will handle completion
        return createPurchaseResultStruct(
          success: true,
          message: 'Redirecting to payment page...',
          transactionId: data['sessionId'],
        );
      } else {
        return createPurchaseResultStruct(
          success: false,
          message: 'Could not open payment page',
          error: 'LAUNCH_ERROR',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      print('Firebase function error: ${e.code} - ${e.message}');
      return createPurchaseResultStruct(
        success: false,
        message: e.message ?? 'Failed to create payment session',
        error: e.code,
      );
    }
  } catch (e) {
    return createPurchaseResultStruct(
      success: false,
      message: 'Payment processing error',
      error: e.toString(),
    );
  }
}

String _getPriceTierProductId(int priceInCents) {
  // Map price ranges to 3 simple tiers for RevenueCat
  if (priceInCents <= 2500) {
    return 'basic_tier'; // $0-25
  } else if (priceInCents <= 10000) {
    return 'standard_tier'; // $25-100
  } else {
    return 'premium_tier'; // $100+
  }
}

String _getRevenueCatErrorMessage(PurchasesErrorCode error) {
  switch (error) {
    case PurchasesErrorCode.purchaseCancelledError:
      return 'Purchase was cancelled';
    case PurchasesErrorCode.purchaseNotAllowedError:
      return 'Purchase not allowed';
    case PurchasesErrorCode.purchaseInvalidError:
      return 'Invalid purchase';
    case PurchasesErrorCode.productNotAvailableForPurchaseError:
      return 'Product not available for purchase';
    case PurchasesErrorCode.productAlreadyPurchasedError:
      return 'You have already purchased a ticket for this event';
    case PurchasesErrorCode.receiptAlreadyInUseError:
      return 'Receipt already in use';
    case PurchasesErrorCode.missingReceiptFileError:
      return 'Missing receipt file';
    case PurchasesErrorCode.networkError:
      return 'Network error. Please check your connection';
    case PurchasesErrorCode.invalidCredentialsError:
      return 'Invalid credentials';
    case PurchasesErrorCode.unexpectedBackendResponseError:
      return 'Unexpected response from server';
    case PurchasesErrorCode.invalidAppUserIdError:
      return 'Invalid user ID';
    case PurchasesErrorCode.operationAlreadyInProgressError:
      return 'Operation already in progress';
    case PurchasesErrorCode.unknownBackendError:
      return 'Unknown backend error';
    default:
      return 'An error occurred: ${error.toString()}';
  }
}
