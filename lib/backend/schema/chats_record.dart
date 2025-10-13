import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ChatsRecord extends FirestoreRecord {
  ChatsRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "is_group" field.
  bool? _isGroup;
  bool get isGroup => _isGroup ?? false;
  bool hasIsGroup() => _isGroup != null;

  // "created_by" field.
  DocumentReference? _createdBy;
  DocumentReference? get createdBy => _createdBy;
  bool hasCreatedBy() => _createdBy != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "event_ref" field.
  DocumentReference? _eventRef;
  DocumentReference? get eventRef => _eventRef;
  bool hasEventRef() => _eventRef != null;

  // "members" field.
  List<DocumentReference>? _members;
  List<DocumentReference> get members => _members ?? const [];
  bool hasMembers() => _members != null;

  // "chat_image_url" field.
  String? _chatImageUrl;
  String get chatImageUrl => _chatImageUrl ?? '';
  bool hasChatImageUrl() => _chatImageUrl != null;

  // "last_message" field.
  String? _lastMessage;
  String get lastMessage => _lastMessage ?? '';
  bool hasLastMessage() => _lastMessage != null;

  // "last_message_at" field.
  DateTime? _lastMessageAt;
  DateTime? get lastMessageAt => _lastMessageAt;
  bool hasLastMessageAt() => _lastMessageAt != null;

  // "is_pin" field.
  bool? _isPin;
  bool get isPin => _isPin ?? false;
  bool hasIsPin() => _isPin != null;

  // "last_message_seen" field.
  List<DocumentReference>? _lastMessageSeen;
  List<DocumentReference> get lastMessageSeen => _lastMessageSeen ?? const [];
  bool hasLastMessageSeen() => _lastMessageSeen != null;

  // "last_message_sent" field.
  DocumentReference? _lastMessageSent;
  DocumentReference? get lastMessageSent => _lastMessageSent;
  bool hasLastMessageSent() => _lastMessageSent != null;

  // "last_message_type" field.
  MessageType? _lastMessageType;
  MessageType? get lastMessageType => _lastMessageType;
  bool hasLastMessageType() => _lastMessageType != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "is_private" field.
  bool? _isPrivate;
  bool get isPrivate => _isPrivate ?? false;
  bool hasIsPrivate() => _isPrivate != null;

  // "admin" field.
  DocumentReference? _admin;
  DocumentReference? get admin => _admin;
  bool hasAdmin() => _admin != null;

  // "search_names" field.
  List<String>? _searchNames;
  List<String> get searchNames => _searchNames ?? const [];
  bool hasSearchNames() => _searchNames != null;

  // "blocked_user" field.
  List<DocumentReference>? _blockedUser;
  List<DocumentReference> get blockedUser => _blockedUser ?? const [];
  bool hasBlockedUser() => _blockedUser != null;

  // "reminder_frequency" field.
  int? _reminderFrequency;
  int get reminderFrequency => _reminderFrequency ?? 0;
  bool hasReminderFrequency() => _reminderFrequency != null;

  // "last_seen" field.
  DocumentReference? _lastSeen;
  DocumentReference? get lastSeen => _lastSeen;
  bool hasLastSeen() => _lastSeen != null;

  // "workspace_ref" field.
  DocumentReference? _workspaceRef;
  DocumentReference? get workspaceRef => _workspaceRef;
  bool hasWorkspaceRef() => _workspaceRef != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _isGroup = snapshotData['is_group'] as bool?;
    _createdBy = snapshotData['created_by'] as DocumentReference?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _eventRef = snapshotData['event_ref'] as DocumentReference?;
    _members = getDataList(snapshotData['members']);
    _chatImageUrl = snapshotData['chat_image_url'] as String?;
    _lastMessage = snapshotData['last_message'] as String?;
    _lastMessageAt = snapshotData['last_message_at'] as DateTime?;
    _isPin = snapshotData['is_pin'] as bool?;
    _lastMessageSeen = getDataList(snapshotData['last_message_seen']);
    _lastMessageSent = snapshotData['last_message_sent'] as DocumentReference?;
    _lastMessageType = snapshotData['last_message_type'] is MessageType
        ? snapshotData['last_message_type']
        : deserializeEnum<MessageType>(snapshotData['last_message_type']);
    _description = snapshotData['description'] as String?;
    _isPrivate = snapshotData['is_private'] as bool?;
    _admin = snapshotData['admin'] as DocumentReference?;
    _searchNames = getDataList(snapshotData['search_names']);
    _blockedUser = getDataList(snapshotData['blocked_user']);
    _reminderFrequency = castToType<int>(snapshotData['reminder_frequency']);
    _lastSeen = snapshotData['last_seen'] as DocumentReference?;
    _workspaceRef = snapshotData['workspace_ref'] as DocumentReference?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('chats');

  static Stream<ChatsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ChatsRecord.fromSnapshot(s));

  static Future<ChatsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ChatsRecord.fromSnapshot(s));

  static ChatsRecord fromSnapshot(DocumentSnapshot snapshot) => ChatsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ChatsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ChatsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ChatsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ChatsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createChatsRecordData({
  String? title,
  bool? isGroup,
  DocumentReference? createdBy,
  DateTime? createdAt,
  DocumentReference? eventRef,
  String? chatImageUrl,
  String? lastMessage,
  DateTime? lastMessageAt,
  bool? isPin,
  DocumentReference? lastMessageSent,
  MessageType? lastMessageType,
  String? description,
  bool? isPrivate,
  DocumentReference? admin,
  int? reminderFrequency,
  DocumentReference? lastSeen,
  DocumentReference? workspaceRef,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'is_group': isGroup,
      'created_by': createdBy,
      'created_at': createdAt,
      'event_ref': eventRef,
      'chat_image_url': chatImageUrl,
      'last_message': lastMessage,
      'last_message_at': lastMessageAt,
      'is_pin': isPin,
      'last_message_sent': lastMessageSent,
      'last_message_type': lastMessageType,
      'description': description,
      'is_private': isPrivate,
      'admin': admin,
      'reminder_frequency': reminderFrequency,
      'last_seen': lastSeen,
      'workspace_ref': workspaceRef,
    }.withoutNulls,
  );

  return firestoreData;
}

class ChatsRecordDocumentEquality implements Equality<ChatsRecord> {
  const ChatsRecordDocumentEquality();

  @override
  bool equals(ChatsRecord? e1, ChatsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.title == e2?.title &&
        e1?.isGroup == e2?.isGroup &&
        e1?.createdBy == e2?.createdBy &&
        e1?.createdAt == e2?.createdAt &&
        e1?.eventRef == e2?.eventRef &&
        listEquality.equals(e1?.members, e2?.members) &&
        e1?.chatImageUrl == e2?.chatImageUrl &&
        e1?.lastMessage == e2?.lastMessage &&
        e1?.lastMessageAt == e2?.lastMessageAt &&
        e1?.isPin == e2?.isPin &&
        listEquality.equals(e1?.lastMessageSeen, e2?.lastMessageSeen) &&
        e1?.lastMessageSent == e2?.lastMessageSent &&
        e1?.lastMessageType == e2?.lastMessageType &&
        e1?.description == e2?.description &&
        e1?.isPrivate == e2?.isPrivate &&
        e1?.admin == e2?.admin &&
        listEquality.equals(e1?.searchNames, e2?.searchNames) &&
        listEquality.equals(e1?.blockedUser, e2?.blockedUser) &&
        e1?.reminderFrequency == e2?.reminderFrequency &&
        e1?.lastSeen == e2?.lastSeen &&
        e1?.workspaceRef == e2?.workspaceRef;
  }

  @override
  int hash(ChatsRecord? e) => const ListEquality().hash([
        e?.title,
        e?.isGroup,
        e?.createdBy,
        e?.createdAt,
        e?.eventRef,
        e?.members,
        e?.chatImageUrl,
        e?.lastMessage,
        e?.lastMessageAt,
        e?.isPin,
        e?.lastMessageSeen,
        e?.lastMessageSent,
        e?.lastMessageType,
        e?.description,
        e?.isPrivate,
        e?.admin,
        e?.searchNames,
        e?.blockedUser,
        e?.reminderFrequency,
        e?.lastSeen,
        e?.workspaceRef
      ]);

  @override
  bool isValidKey(Object? o) => o is ChatsRecord;
}
