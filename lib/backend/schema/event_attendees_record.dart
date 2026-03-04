import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EventAttendeesRecord extends FirestoreRecord {
  EventAttendeesRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "event_id" field.
  String? _eventId;
  String get eventId => _eventId ?? '';
  bool hasEventId() => _eventId != null;

  // "event_ref" field.
  DocumentReference? _eventRef;
  DocumentReference? get eventRef => _eventRef;
  bool hasEventRef() => _eventRef != null;

  // "eventbrite_attendee_id" field.
  String? _eventbriteAttendeeId;
  String get eventbriteAttendeeId => _eventbriteAttendeeId ?? '';
  bool hasEventbriteAttendeeId() => _eventbriteAttendeeId != null;

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "first_name" field.
  String? _firstName;
  String get firstName => _firstName ?? '';
  bool hasFirstName() => _firstName != null;

  // "last_name" field.
  String? _lastName;
  String get lastName => _lastName ?? '';
  bool hasLastName() => _lastName != null;

  // "ticket_class" field.
  String? _ticketClass;
  String get ticketClass => _ticketClass ?? '';
  bool hasTicketClass() => _ticketClass != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "user_ref" field.
  DocumentReference? _userRef;
  DocumentReference? get userRef => _userRef;
  bool hasUserRef() => _userRef != null;

  // "is_pending_verification" field.
  bool? _isPendingVerification;
  bool get isPendingVerification => _isPendingVerification ?? false;
  bool hasIsPendingVerification() => _isPendingVerification != null;

  // "synced_at" field.
  DateTime? _syncedAt;
  DateTime? get syncedAt => _syncedAt;
  bool hasSyncedAt() => _syncedAt != null;

  // "checked_in" field.
  bool? _checkedIn;
  bool get checkedIn => _checkedIn ?? false;
  bool hasCheckedIn() => _checkedIn != null;

  // "cancelled" field.
  bool? _cancelled;
  bool get cancelled => _cancelled ?? false;
  bool hasCancelled() => _cancelled != null;

  void _initializeFields() {
    _eventId = snapshotData['event_id'] as String?;
    _eventRef = snapshotData['event_ref'] as DocumentReference?;
    _eventbriteAttendeeId = snapshotData['eventbrite_attendee_id'] as String?;
    _email = snapshotData['email'] as String?;
    _name = snapshotData['name'] as String?;
    _firstName = snapshotData['first_name'] as String?;
    _lastName = snapshotData['last_name'] as String?;
    _ticketClass = snapshotData['ticket_class'] as String?;
    _status = snapshotData['status'] as String?;
    _userRef = snapshotData['user_ref'] as DocumentReference?;
    _isPendingVerification = snapshotData['is_pending_verification'] as bool?;
    _syncedAt = snapshotData['synced_at'] as DateTime?;
    _checkedIn = snapshotData['checked_in'] as bool?;
    _cancelled = snapshotData['cancelled'] as bool?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('event_attendees');

  static Stream<EventAttendeesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => EventAttendeesRecord.fromSnapshot(s));

  static Future<EventAttendeesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => EventAttendeesRecord.fromSnapshot(s));

  static EventAttendeesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      EventAttendeesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static EventAttendeesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      EventAttendeesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'EventAttendeesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is EventAttendeesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createEventAttendeesRecordData({
  String? eventId,
  DocumentReference? eventRef,
  String? eventbriteAttendeeId,
  String? email,
  String? name,
  String? firstName,
  String? lastName,
  String? ticketClass,
  String? status,
  DocumentReference? userRef,
  bool? isPendingVerification,
  DateTime? syncedAt,
  bool? checkedIn,
  bool? cancelled,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'event_id': eventId,
      'event_ref': eventRef,
      'eventbrite_attendee_id': eventbriteAttendeeId,
      'email': email,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'ticket_class': ticketClass,
      'status': status,
      'user_ref': userRef,
      'is_pending_verification': isPendingVerification,
      'synced_at': syncedAt,
      'checked_in': checkedIn,
      'cancelled': cancelled,
    }.withoutNulls,
  );

  return firestoreData;
}

class EventAttendeesRecordDocumentEquality
    implements Equality<EventAttendeesRecord> {
  const EventAttendeesRecordDocumentEquality();

  @override
  bool equals(EventAttendeesRecord? e1, EventAttendeesRecord? e2) {
    return e1?.eventId == e2?.eventId &&
        e1?.eventRef == e2?.eventRef &&
        e1?.eventbriteAttendeeId == e2?.eventbriteAttendeeId &&
        e1?.email == e2?.email &&
        e1?.name == e2?.name &&
        e1?.firstName == e2?.firstName &&
        e1?.lastName == e2?.lastName &&
        e1?.ticketClass == e2?.ticketClass &&
        e1?.status == e2?.status &&
        e1?.userRef == e2?.userRef &&
        e1?.isPendingVerification == e2?.isPendingVerification &&
        e1?.syncedAt == e2?.syncedAt &&
        e1?.checkedIn == e2?.checkedIn &&
        e1?.cancelled == e2?.cancelled;
  }

  @override
  int hash(EventAttendeesRecord? e) => const ListEquality().hash([
        e?.eventId,
        e?.eventRef,
        e?.eventbriteAttendeeId,
        e?.email,
        e?.name,
        e?.firstName,
        e?.lastName,
        e?.ticketClass,
        e?.status,
        e?.userRef,
        e?.isPendingVerification,
        e?.syncedAt,
        e?.checkedIn,
        e?.cancelled
      ]);

  @override
  bool isValidKey(Object? o) => o is EventAttendeesRecord;
}
