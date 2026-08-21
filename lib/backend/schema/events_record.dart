import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EventsRecord extends FirestoreRecord {
  EventsRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "location" field.
  String? _location;
  String get location => _location ?? '';
  bool hasLocation() => _location != null;

  // "latlng" field.
  LatLng? _latlng;
  LatLng? get latlng => _latlng;
  bool hasLatlng() => _latlng != null;

  // "start_date" field.
  DateTime? _startDate;
  DateTime? get startDate => _startDate;
  bool hasStartDate() => _startDate != null;

  // "end_date" field.
  DateTime? _endDate;
  DateTime? get endDate => _endDate;
  bool hasEndDate() => _endDate != null;

  // "creator_id" field.
  DocumentReference? _creatorId;
  DocumentReference? get creatorId => _creatorId;
  bool hasCreatorId() => _creatorId != null;

  // "cover_image_url" field.
  String? _coverImageUrl;
  String get coverImageUrl => _coverImageUrl ?? '';
  bool hasCoverImageUrl() => _coverImageUrl != null;

  // "is_private" field.
  bool? _isPrivate;
  bool get isPrivate => _isPrivate ?? false;
  bool hasIsPrivate() => _isPrivate != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "speakers" field.
  List<SpeakerStruct>? _speakers;
  List<SpeakerStruct> get speakers => _speakers ?? const [];
  bool hasSpeakers() => _speakers != null;

  // "is_trending" field.
  bool? _isTrending;
  bool get isTrending => _isTrending ?? false;
  bool hasIsTrending() => _isTrending != null;

  // "category" field.
  List<String>? _category;
  List<String> get category => _category ?? const [];
  bool hasCategory() => _category != null;

  // "dateSchedule" field.
  List<DateScheduleStruct>? _dateSchedule;
  List<DateScheduleStruct> get dateSchedule => _dateSchedule ?? const [];
  bool hasDateSchedule() => _dateSchedule != null;

  // "chat_groups" field.
  List<DocumentReference>? _chatGroups;
  List<DocumentReference> get chatGroups => _chatGroups ?? const [];
  bool hasChatGroups() => _chatGroups != null;

  // "participants" field.
  List<DocumentReference>? _participants;
  List<DocumentReference> get participants => _participants ?? const [];
  bool hasParticipants() => _participants != null;

  // "event_ref" field.
  DocumentReference? _eventRef;
  DocumentReference? get eventRef => _eventRef;
  bool hasEventRef() => _eventRef != null;

  // "main_group" field.
  DocumentReference? _mainGroup;
  DocumentReference? get mainGroup => _mainGroup;
  bool hasMainGroup() => _mainGroup != null;

  // "event_id" field.
  String? _eventId;
  String get eventId => _eventId ?? '';
  bool hasEventId() => _eventId != null;

  // "qr_code_url" field.
  String? _qrCodeUrl;
  String get qrCodeUrl => _qrCodeUrl ?? '';
  bool hasQrCodeUrl() => _qrCodeUrl != null;

  // "price" field.
  int? _price;
  int get price => _price ?? 0;
  bool hasPrice() => _price != null;

  // "ticket_deadline" field.
  DateTime? _ticketDeadline;
  DateTime? get ticketDeadline => _ticketDeadline;
  bool hasTicketDeadline() => _ticketDeadline != null;

  // "ticket_amount" field.
  int? _ticketAmount;
  int get ticketAmount => _ticketAmount ?? 0;
  bool hasTicketAmount() => _ticketAmount != null;

  // "eventbrite_id" field.
  String? _eventbriteId;
  String get eventbriteId => _eventbriteId ?? '';
  bool hasEventbriteId() => _eventbriteId != null;

  // "eventbrite_url" field.
  String? _eventbriteUrl;
  String get eventbriteUrl => _eventbriteUrl ?? '';
  bool hasEventbriteUrl() => _eventbriteUrl != null;

  // "use_eventbrite_ticketing" field.
  bool? _useEventbriteTicketing;
  bool get useEventbriteTicketing => _useEventbriteTicketing ?? false;
  bool hasUseEventbriteTicketing() => _useEventbriteTicketing != null;

  // "auto_synced" field.
  bool? _autoSynced;
  bool get autoSynced => _autoSynced ?? false;
  bool hasAutoSynced() => _autoSynced != null;

  // "last_attendee_sync" field.
  DateTime? _lastAttendeeSync;
  DateTime? get lastAttendeeSync => _lastAttendeeSync;
  bool hasLastAttendeeSync() => _lastAttendeeSync != null;

  // "ticketing_mode_updated" field.
  DateTime? _ticketingModeUpdated;
  DateTime? get ticketingModeUpdated => _ticketingModeUpdated;
  bool hasTicketingModeUpdated() => _ticketingModeUpdated != null;

  // "ticketing_mode_updated_by" field.
  String? _ticketingModeUpdatedBy;
  String get ticketingModeUpdatedBy => _ticketingModeUpdatedBy ?? '';
  bool hasTicketingModeUpdatedBy() => _ticketingModeUpdatedBy != null;

  // "event_link" field.
  String? _eventLink;
  String get eventLink => _eventLink ?? '';
  bool hasEventLink() => _eventLink != null;

  // "event_type" field.
  String? _eventType;
  String get eventType => _eventType ?? '';
  bool hasEventType() => _eventType != null;

  // "ticketing_method" field.
  String? _ticketingMethod;
  String get ticketingMethod => _ticketingMethod ?? '';
  bool hasTicketingMethod() => _ticketingMethod != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _description = snapshotData['description'] as String?;
    _location = snapshotData['location'] as String?;
    _latlng = snapshotData['latlng'] as LatLng?;
    _startDate = snapshotData['start_date'] as DateTime?;
    _endDate = snapshotData['end_date'] as DateTime?;
    _creatorId = snapshotData['creator_id'] as DocumentReference?;
    _coverImageUrl = snapshotData['cover_image_url'] as String?;
    _isPrivate = snapshotData['is_private'] as bool?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _speakers = getStructList(
      snapshotData['speakers'],
      SpeakerStruct.fromMap,
    );
    _isTrending = snapshotData['is_trending'] as bool?;
    _category = getDataList(snapshotData['category']);
    _dateSchedule = getStructList(
      snapshotData['dateSchedule'],
      DateScheduleStruct.fromMap,
    );
    _chatGroups = getDataList(snapshotData['chat_groups']);
    _participants = getDataList(snapshotData['participants']);
    _eventRef = snapshotData['event_ref'] as DocumentReference?;
    _mainGroup = snapshotData['main_group'] as DocumentReference?;
    _eventId = snapshotData['event_id'] as String?;
    _qrCodeUrl = snapshotData['qr_code_url'] as String?;
    _price = castToType<int>(snapshotData['price']);
    _ticketDeadline = snapshotData['ticket_deadline'] as DateTime?;
    _ticketAmount = castToType<int>(snapshotData['ticket_amount']);
    _eventbriteId = snapshotData['eventbrite_id'] as String?;
    _eventbriteUrl = snapshotData['eventbrite_url'] as String?;
    _useEventbriteTicketing = snapshotData['use_eventbrite_ticketing'] as bool?;
    _autoSynced = snapshotData['auto_synced'] as bool?;
    _lastAttendeeSync = snapshotData['last_attendee_sync'] as DateTime?;
    _ticketingModeUpdated = snapshotData['ticketing_mode_updated'] as DateTime?;
    _ticketingModeUpdatedBy =
        snapshotData['ticketing_mode_updated_by'] as String?;
    _eventLink = snapshotData['event_link'] as String?;
    _eventType = snapshotData['event_type'] as String?;
    _ticketingMethod = snapshotData['ticketing_method'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('events');

  static Stream<EventsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => EventsRecord.fromSnapshot(s));

  static Future<EventsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => EventsRecord.fromSnapshot(s));

  static EventsRecord fromSnapshot(DocumentSnapshot snapshot) => EventsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static EventsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      EventsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'EventsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is EventsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createEventsRecordData({
  String? title,
  String? description,
  String? location,
  LatLng? latlng,
  DateTime? startDate,
  DateTime? endDate,
  DocumentReference? creatorId,
  String? coverImageUrl,
  bool? isPrivate,
  DateTime? createdAt,
  bool? isTrending,
  DocumentReference? eventRef,
  DocumentReference? mainGroup,
  String? eventId,
  String? qrCodeUrl,
  int? price,
  DateTime? ticketDeadline,
  int? ticketAmount,
  String? eventbriteId,
  String? eventbriteUrl,
  bool? useEventbriteTicketing,
  bool? autoSynced,
  DateTime? lastAttendeeSync,
  DateTime? ticketingModeUpdated,
  String? ticketingModeUpdatedBy,
  String? eventLink,
  String? eventType,
  String? ticketingMethod,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'description': description,
      'location': location,
      'latlng': latlng,
      'start_date': startDate,
      'end_date': endDate,
      'creator_id': creatorId,
      'cover_image_url': coverImageUrl,
      'is_private': isPrivate,
      'created_at': createdAt,
      'is_trending': isTrending,
      'event_ref': eventRef,
      'main_group': mainGroup,
      'event_id': eventId,
      'qr_code_url': qrCodeUrl,
      'price': price,
      'ticket_deadline': ticketDeadline,
      'ticket_amount': ticketAmount,
      'eventbrite_id': eventbriteId,
      'eventbrite_url': eventbriteUrl,
      'use_eventbrite_ticketing': useEventbriteTicketing,
      'auto_synced': autoSynced,
      'last_attendee_sync': lastAttendeeSync,
      'ticketing_mode_updated': ticketingModeUpdated,
      'ticketing_mode_updated_by': ticketingModeUpdatedBy,
      'event_link': eventLink,
      'event_type': eventType,
      'ticketing_method': ticketingMethod,
    }.withoutNulls,
  );

  return firestoreData;
}

class EventsRecordDocumentEquality implements Equality<EventsRecord> {
  const EventsRecordDocumentEquality();

  @override
  bool equals(EventsRecord? e1, EventsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.title == e2?.title &&
        e1?.description == e2?.description &&
        e1?.location == e2?.location &&
        e1?.latlng == e2?.latlng &&
        e1?.startDate == e2?.startDate &&
        e1?.endDate == e2?.endDate &&
        e1?.creatorId == e2?.creatorId &&
        e1?.coverImageUrl == e2?.coverImageUrl &&
        e1?.isPrivate == e2?.isPrivate &&
        e1?.createdAt == e2?.createdAt &&
        listEquality.equals(e1?.speakers, e2?.speakers) &&
        e1?.isTrending == e2?.isTrending &&
        listEquality.equals(e1?.category, e2?.category) &&
        listEquality.equals(e1?.dateSchedule, e2?.dateSchedule) &&
        listEquality.equals(e1?.chatGroups, e2?.chatGroups) &&
        listEquality.equals(e1?.participants, e2?.participants) &&
        e1?.eventRef == e2?.eventRef &&
        e1?.mainGroup == e2?.mainGroup &&
        e1?.eventId == e2?.eventId &&
        e1?.qrCodeUrl == e2?.qrCodeUrl &&
        e1?.price == e2?.price &&
        e1?.ticketDeadline == e2?.ticketDeadline &&
        e1?.ticketAmount == e2?.ticketAmount &&
        e1?.eventbriteId == e2?.eventbriteId &&
        e1?.eventbriteUrl == e2?.eventbriteUrl &&
        e1?.useEventbriteTicketing == e2?.useEventbriteTicketing &&
        e1?.autoSynced == e2?.autoSynced &&
        e1?.lastAttendeeSync == e2?.lastAttendeeSync &&
        e1?.ticketingModeUpdated == e2?.ticketingModeUpdated &&
        e1?.ticketingModeUpdatedBy == e2?.ticketingModeUpdatedBy &&
        e1?.eventLink == e2?.eventLink &&
        e1?.eventType == e2?.eventType &&
        e1?.ticketingMethod == e2?.ticketingMethod;
  }

  @override
  int hash(EventsRecord? e) => const ListEquality().hash([
        e?.title,
        e?.description,
        e?.location,
        e?.latlng,
        e?.startDate,
        e?.endDate,
        e?.creatorId,
        e?.coverImageUrl,
        e?.isPrivate,
        e?.createdAt,
        e?.speakers,
        e?.isTrending,
        e?.category,
        e?.dateSchedule,
        e?.chatGroups,
        e?.participants,
        e?.eventRef,
        e?.mainGroup,
        e?.eventId,
        e?.qrCodeUrl,
        e?.price,
        e?.ticketDeadline,
        e?.ticketAmount,
        e?.eventbriteId,
        e?.eventbriteUrl,
        e?.useEventbriteTicketing,
        e?.autoSynced,
        e?.lastAttendeeSync,
        e?.ticketingModeUpdated,
        e?.ticketingModeUpdatedBy,
        e?.eventLink,
        e?.eventType,
        e?.ticketingMethod
      ]);

  @override
  bool isValidKey(Object? o) => o is EventsRecord;
}
