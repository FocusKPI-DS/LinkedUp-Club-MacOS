import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class WorkspaceMembersRecord extends FirestoreRecord {
  WorkspaceMembersRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "workspace_ref" field.
  DocumentReference? _workspaceRef;
  DocumentReference? get workspaceRef => _workspaceRef;
  bool hasWorkspaceRef() => _workspaceRef != null;

  // "user_ref" field.
  DocumentReference? _userRef;
  DocumentReference? get userRef => _userRef;
  bool hasUserRef() => _userRef != null;

  // "role" field.
  String? _role;
  String get role => _role ?? '';
  bool hasRole() => _role != null;

  // "joined_at" field.
  DateTime? _joinedAt;
  DateTime? get joinedAt => _joinedAt;
  bool hasJoinedAt() => _joinedAt != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "is_default" field.
  bool? _isDefault;
  bool get isDefault => _isDefault ?? false;
  bool hasIsDefault() => _isDefault != null;

  void _initializeFields() {
    _workspaceRef = snapshotData['workspace_ref'] as DocumentReference?;
    _userRef = snapshotData['user_ref'] as DocumentReference?;
    _role = snapshotData['role'] as String?;
    _joinedAt = snapshotData['joined_at'] as DateTime?;
    _status = snapshotData['status'] as String?;
    _isDefault = snapshotData['is_default'] as bool?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('workspace_members');

  static Stream<WorkspaceMembersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => WorkspaceMembersRecord.fromSnapshot(s));

  static Future<WorkspaceMembersRecord> getDocumentOnce(
          DocumentReference ref) =>
      ref.get().then((s) => WorkspaceMembersRecord.fromSnapshot(s));

  static WorkspaceMembersRecord fromSnapshot(DocumentSnapshot snapshot) =>
      WorkspaceMembersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static WorkspaceMembersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      WorkspaceMembersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'WorkspaceMembersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is WorkspaceMembersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createWorkspaceMembersRecordData({
  DocumentReference? workspaceRef,
  DocumentReference? userRef,
  String? role,
  DateTime? joinedAt,
  String? status,
  bool? isDefault,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'workspace_ref': workspaceRef,
      'user_ref': userRef,
      'role': role,
      'joined_at': joinedAt,
      'status': status,
      'is_default': isDefault,
    }.withoutNulls,
  );

  return firestoreData;
}

class WorkspaceMembersRecordDocumentEquality
    implements Equality<WorkspaceMembersRecord> {
  const WorkspaceMembersRecordDocumentEquality();

  @override
  bool equals(WorkspaceMembersRecord? e1, WorkspaceMembersRecord? e2) {
    return e1?.workspaceRef == e2?.workspaceRef &&
        e1?.userRef == e2?.userRef &&
        e1?.role == e2?.role &&
        e1?.joinedAt == e2?.joinedAt &&
        e1?.status == e2?.status &&
        e1?.isDefault == e2?.isDefault;
  }

  @override
  int hash(WorkspaceMembersRecord? e) => const ListEquality().hash([
        e?.workspaceRef,
        e?.userRef,
        e?.role,
        e?.joinedAt,
        e?.status,
        e?.isDefault
      ]);

  @override
  bool isValidKey(Object? o) => o is WorkspaceMembersRecord;
}
