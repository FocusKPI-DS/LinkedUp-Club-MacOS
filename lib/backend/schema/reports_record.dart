import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ReportsRecord extends FirestoreRecord {
  ReportsRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "reported_by" field.
  DocumentReference? _reportedBy;
  DocumentReference? get reportedBy => _reportedBy;
  bool hasReportedBy() => _reportedBy != null;

  // "reported_user" field.
  DocumentReference? _reportedUser;
  DocumentReference? get reportedUser => _reportedUser;
  bool hasReportedUser() => _reportedUser != null;

  // "message_ref" field.
  DocumentReference? _messageRef;
  DocumentReference? get messageRef => _messageRef;
  bool hasMessageRef() => _messageRef != null;

  // "chat_group" field.
  DocumentReference? _chatGroup;
  DocumentReference? get chatGroup => _chatGroup;
  bool hasChatGroup() => _chatGroup != null;

  // "timestamp" field.
  DateTime? _timestamp;
  DateTime? get timestamp => _timestamp;
  bool hasTimestamp() => _timestamp != null;

  // "reason" field.
  String? _reason;
  String get reason => _reason ?? '';
  bool hasReason() => _reason != null;

  void _initializeFields() {
    _reportedBy = snapshotData['reported_by'] as DocumentReference?;
    _reportedUser = snapshotData['reported_user'] as DocumentReference?;
    _messageRef = snapshotData['message_ref'] as DocumentReference?;
    _chatGroup = snapshotData['chat_group'] as DocumentReference?;
    _timestamp = snapshotData['timestamp'] as DateTime?;
    _reason = snapshotData['reason'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('reports');

  static Stream<ReportsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ReportsRecord.fromSnapshot(s));

  static Future<ReportsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ReportsRecord.fromSnapshot(s));

  static ReportsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ReportsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ReportsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ReportsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ReportsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ReportsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createReportsRecordData({
  DocumentReference? reportedBy,
  DocumentReference? reportedUser,
  DocumentReference? messageRef,
  DocumentReference? chatGroup,
  DateTime? timestamp,
  String? reason,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'reported_by': reportedBy,
      'reported_user': reportedUser,
      'message_ref': messageRef,
      'chat_group': chatGroup,
      'timestamp': timestamp,
      'reason': reason,
    }.withoutNulls,
  );

  return firestoreData;
}

class ReportsRecordDocumentEquality implements Equality<ReportsRecord> {
  const ReportsRecordDocumentEquality();

  @override
  bool equals(ReportsRecord? e1, ReportsRecord? e2) {
    return e1?.reportedBy == e2?.reportedBy &&
        e1?.reportedUser == e2?.reportedUser &&
        e1?.messageRef == e2?.messageRef &&
        e1?.chatGroup == e2?.chatGroup &&
        e1?.timestamp == e2?.timestamp &&
        e1?.reason == e2?.reason;
  }

  @override
  int hash(ReportsRecord? e) => const ListEquality().hash([
        e?.reportedBy,
        e?.reportedUser,
        e?.messageRef,
        e?.chatGroup,
        e?.timestamp,
        e?.reason
      ]);

  @override
  bool isValidKey(Object? o) => o is ReportsRecord;
}
