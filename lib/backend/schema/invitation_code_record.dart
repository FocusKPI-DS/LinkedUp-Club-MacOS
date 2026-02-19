import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class InvitationCodeRecord extends FirestoreRecord {
  InvitationCodeRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "code" field.
  String? _code;
  String get code => _code ?? '';
  bool hasCode() => _code != null;

  void _initializeFields() {
    _code = snapshotData['code'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('invitation_code');

  static Stream<InvitationCodeRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => InvitationCodeRecord.fromSnapshot(s));

  static Future<InvitationCodeRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => InvitationCodeRecord.fromSnapshot(s));

  static InvitationCodeRecord fromSnapshot(DocumentSnapshot snapshot) =>
      InvitationCodeRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static InvitationCodeRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      InvitationCodeRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'InvitationCodeRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is InvitationCodeRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createInvitationCodeRecordData({
  String? code,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'code': code,
    }.withoutNulls,
  );

  return firestoreData;
}

class InvitationCodeRecordDocumentEquality
    implements Equality<InvitationCodeRecord> {
  const InvitationCodeRecordDocumentEquality();

  @override
  bool equals(InvitationCodeRecord? e1, InvitationCodeRecord? e2) {
    return e1?.code == e2?.code;
  }

  @override
  int hash(InvitationCodeRecord? e) => const ListEquality().hash([e?.code]);

  @override
  bool isValidKey(Object? o) => o is InvitationCodeRecord;
}
