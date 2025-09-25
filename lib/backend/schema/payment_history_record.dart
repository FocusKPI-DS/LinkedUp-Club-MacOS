import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PaymentHistoryRecord extends FirestoreRecord {
  PaymentHistoryRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "user_ref" field.
  DocumentReference? _userRef;
  DocumentReference? get userRef => _userRef;
  bool hasUserRef() => _userRef != null;

  // "event_ref" field.
  DocumentReference? _eventRef;
  DocumentReference? get eventRef => _eventRef;
  bool hasEventRef() => _eventRef != null;

  // "event_id" field.
  String? _eventId;
  String get eventId => _eventId ?? '';
  bool hasEventId() => _eventId != null;

  // "event_title" field.
  String? _eventTitle;
  String get eventTitle => _eventTitle ?? '';
  bool hasEventTitle() => _eventTitle != null;

  // "amount" field.
  double? _amount;
  double get amount => _amount ?? 0.0;
  bool hasAmount() => _amount != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "transaction_id" field.
  String? _transactionId;
  String get transactionId => _transactionId ?? '';
  bool hasTransactionId() => _transactionId != null;

  // "payment_method" field.
  String? _paymentMethod;
  String get paymentMethod => _paymentMethod ?? '';
  bool hasPaymentMethod() => _paymentMethod != null;

  // "purchased_at" field.
  DateTime? _purchasedAt;
  DateTime? get purchasedAt => _purchasedAt;
  bool hasPurchasedAt() => _purchasedAt != null;

  // "event_date" field.
  DateTime? _eventDate;
  DateTime? get eventDate => _eventDate;
  bool hasEventDate() => _eventDate != null;

  void _initializeFields() {
    _userRef = snapshotData['user_ref'] as DocumentReference?;
    _eventRef = snapshotData['event_ref'] as DocumentReference?;
    _eventId = snapshotData['event_id'] as String?;
    _eventTitle = snapshotData['event_title'] as String?;
    _amount = castToType<double>(snapshotData['amount']);
    _status = snapshotData['status'] as String?;
    _transactionId = snapshotData['transaction_id'] as String?;
    _paymentMethod = snapshotData['payment_method'] as String?;
    _purchasedAt = snapshotData['purchased_at'] as DateTime?;
    _eventDate = snapshotData['event_date'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('payment_history');

  static Stream<PaymentHistoryRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => PaymentHistoryRecord.fromSnapshot(s));

  static Future<PaymentHistoryRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => PaymentHistoryRecord.fromSnapshot(s));

  static PaymentHistoryRecord fromSnapshot(DocumentSnapshot snapshot) =>
      PaymentHistoryRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static PaymentHistoryRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      PaymentHistoryRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'PaymentHistoryRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is PaymentHistoryRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createPaymentHistoryRecordData({
  DocumentReference? userRef,
  DocumentReference? eventRef,
  String? eventId,
  String? eventTitle,
  double? amount,
  String? status,
  String? transactionId,
  String? paymentMethod,
  DateTime? purchasedAt,
  DateTime? eventDate,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'user_ref': userRef,
      'event_ref': eventRef,
      'event_id': eventId,
      'event_title': eventTitle,
      'amount': amount,
      'status': status,
      'transaction_id': transactionId,
      'payment_method': paymentMethod,
      'purchased_at': purchasedAt,
      'event_date': eventDate,
    }.withoutNulls,
  );

  return firestoreData;
}

class PaymentHistoryRecordDocumentEquality
    implements Equality<PaymentHistoryRecord> {
  const PaymentHistoryRecordDocumentEquality();

  @override
  bool equals(PaymentHistoryRecord? e1, PaymentHistoryRecord? e2) {
    return e1?.userRef == e2?.userRef &&
        e1?.eventRef == e2?.eventRef &&
        e1?.eventId == e2?.eventId &&
        e1?.eventTitle == e2?.eventTitle &&
        e1?.amount == e2?.amount &&
        e1?.status == e2?.status &&
        e1?.transactionId == e2?.transactionId &&
        e1?.paymentMethod == e2?.paymentMethod &&
        e1?.purchasedAt == e2?.purchasedAt &&
        e1?.eventDate == e2?.eventDate;
  }

  @override
  int hash(PaymentHistoryRecord? e) => const ListEquality().hash([
        e?.userRef,
        e?.eventRef,
        e?.eventId,
        e?.eventTitle,
        e?.amount,
        e?.status,
        e?.transactionId,
        e?.paymentMethod,
        e?.purchasedAt,
        e?.eventDate
      ]);

  @override
  bool isValidKey(Object? o) => o is PaymentHistoryRecord;
}
