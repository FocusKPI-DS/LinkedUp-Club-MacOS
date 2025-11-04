import 'dart:async';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ActionItemsRecord extends FirestoreRecord {
  ActionItemsRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "group_name" field.
  String? _groupName;
  String get groupName => _groupName ?? '';
  bool hasGroupName() => _groupName != null;

  // "priority" field.
  String? _priority;
  String get priority => _priority ?? '';
  bool hasPriority() => _priority != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "user_ref" field.
  DocumentReference? _userRef;
  DocumentReference? get userRef => _userRef;
  bool hasUserRef() => _userRef != null;

  // "workspace_ref" field.
  DocumentReference? _workspaceRef;
  DocumentReference? get workspaceRef => _workspaceRef;
  bool hasWorkspaceRef() => _workspaceRef != null;

  // "chat_ref" field.
  DocumentReference? _chatRef;
  DocumentReference? get chatRef => _chatRef;
  bool hasChatRef() => _chatRef != null;

  // "involved_people" field.
  List<String>? _involvedPeople;
  List<String> get involvedPeople => _involvedPeople ?? const [];
  bool hasInvolvedPeople() => _involvedPeople != null;

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  // "last_summary_at" field.
  DateTime? _lastSummaryAt;
  DateTime? get lastSummaryAt => _lastSummaryAt;
  bool hasLastSummaryAt() => _lastSummaryAt != null;

  // "due_date" field.
  DateTime? _dueDate;
  DateTime? get dueDate => _dueDate;
  bool hasDueDate() => _dueDate != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _groupName = snapshotData['group_name'] as String?;
    _priority = snapshotData['priority'] as String?;
    _status = snapshotData['status'] as String?;
    _userRef = snapshotData['user_ref'] as DocumentReference?;
    _workspaceRef = snapshotData['workspace_ref'] as DocumentReference?;
    _chatRef = snapshotData['chat_ref'] as DocumentReference?;
    _involvedPeople = getDataList(snapshotData['involved_people']);
    _createdTime = snapshotData['created_time'] as DateTime?;
    _lastSummaryAt = snapshotData['last_summary_at'] as DateTime?;
    _dueDate = snapshotData['due_date'] as DateTime?;
    _description = snapshotData['description'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('action_items');

  static Stream<ActionItemsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ActionItemsRecord.fromSnapshot(s));

  static Future<ActionItemsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ActionItemsRecord.fromSnapshot(s));

  static ActionItemsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ActionItemsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ActionItemsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ActionItemsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ActionItemsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ActionItemsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createActionItemsRecordData({
  String? title,
  String? groupName,
  String? priority,
  String? status,
  DocumentReference? userRef,
  DocumentReference? workspaceRef,
  DocumentReference? chatRef,
  List<String>? involvedPeople,
  DateTime? createdTime,
  DateTime? lastSummaryAt,
  DateTime? dueDate,
  String? description,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'group_name': groupName,
      'priority': priority,
      'status': status,
      'user_ref': userRef,
      'workspace_ref': workspaceRef,
      'chat_ref': chatRef,
      'involved_people': involvedPeople,
      'created_time': createdTime,
      'last_summary_at': lastSummaryAt,
      'due_date': dueDate,
      'description': description,
    }.withoutNulls,
  );

  return firestoreData;
}
