import 'dart:async';

import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class BlockedUsersRecord extends FirestoreRecord {
  BlockedUsersRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "blocker_user" field.
  DocumentReference? _blockerUser;
  DocumentReference? get blockerUser => _blockerUser;
  bool hasBlockerUser() => _blockerUser != null;

  // "blocked_user" field.
  DocumentReference? _blockedUser;
  DocumentReference? get blockedUser => _blockedUser;
  bool hasBlockedUser() => _blockedUser != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  void _initializeFields() {
    _blockerUser = snapshotData['blocker_user'] as DocumentReference?;
    _blockedUser = snapshotData['blocked_user'] as DocumentReference?;
    _createdAt = snapshotData['created_at'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('blocked_users');

  static Stream<BlockedUsersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => BlockedUsersRecord.fromSnapshot(s));

  static Future<BlockedUsersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => BlockedUsersRecord.fromSnapshot(s));

  static BlockedUsersRecord fromSnapshot(DocumentSnapshot snapshot) =>
      BlockedUsersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static BlockedUsersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      BlockedUsersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'BlockedUsersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is BlockedUsersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createBlockedUsersRecordData({
  DocumentReference? blockerUser,
  DocumentReference? blockedUser,
  DateTime? createdAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'blocker_user': blockerUser,
      'blocked_user': blockedUser,
      'created_at': createdAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class BlockedUsersRecordDocumentEquality implements Equality<BlockedUsersRecord> {
  const BlockedUsersRecordDocumentEquality();

  @override
  bool equals(BlockedUsersRecord? e1, BlockedUsersRecord? e2) {
    return e1?.blockerUser == e2?.blockerUser &&
        e1?.blockedUser == e2?.blockedUser &&
        e1?.createdAt == e2?.createdAt;
  }

  @override
  int hash(BlockedUsersRecord? e) => const ListEquality()
      .hash([e?.blockerUser, e?.blockedUser, e?.createdAt]);

  @override
  bool isValidKey(Object? o) => o is BlockedUsersRecord;
}