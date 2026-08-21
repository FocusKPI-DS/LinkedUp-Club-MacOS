import 'dart:async';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ReminderDigestsRecord extends FirestoreRecord {
  ReminderDigestsRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "chat_ref" field.
  DocumentReference? _chatRef;
  DocumentReference? get chatRef => _chatRef;
  bool hasChatRef() => _chatRef != null;

  // "group_name" field.
  String? _groupName;
  String get groupName => _groupName ?? '';
  bool hasGroupName() => _groupName != null;

  // "intro_text" field.
  String? _introText;
  String get introText => _introText ?? '';
  bool hasIntroText() => _introText != null;

  // "overdue_count" field.
  int? _overdueCount;
  int get overdueCount => _overdueCount ?? 0;
  bool hasOverdueCount() => _overdueCount != null;

  // "tasks" field (array of maps: title, priority, description, involved_people, due_date, created_time, action_item_ref).
  List<Map<String, dynamic>>? _tasks;
  List<Map<String, dynamic>> get tasks => _tasks ?? const [];
  bool hasTasks() => _tasks != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  void _initializeFields() {
    _chatRef = snapshotData['chat_ref'] as DocumentReference?;
    _groupName = snapshotData['group_name'] as String?;
    _introText = snapshotData['intro_text'] as String?;
    _overdueCount = snapshotData['overdue_count'] as int?;
    final tasksRaw = snapshotData['tasks'];
    if (tasksRaw is List) {
      _tasks = tasksRaw
          .map((e) =>
              e is Map<String, dynamic> ? Map<String, dynamic>.from(e) : <String, dynamic>{})
          .toList();
    } else {
      _tasks = const [];
    }
    _createdAt = snapshotData['created_at'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('reminder_digests');

  static Stream<ReminderDigestsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ReminderDigestsRecord.fromSnapshot(s));

  static Future<ReminderDigestsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ReminderDigestsRecord.fromSnapshot(s));

  static ReminderDigestsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ReminderDigestsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ReminderDigestsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ReminderDigestsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ReminderDigestsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ReminderDigestsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}
