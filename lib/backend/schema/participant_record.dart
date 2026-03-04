import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ParticipantRecord extends FirestoreRecord {
  ParticipantRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "user_id" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  // "user_ref" field.
  DocumentReference? _userRef;
  DocumentReference? get userRef => _userRef;
  bool hasUserRef() => _userRef != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "joined_at" field.
  DateTime? _joinedAt;
  DateTime? get joinedAt => _joinedAt;
  bool hasJoinedAt() => _joinedAt != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "image" field.
  String? _image;
  String get image => _image ?? '';
  bool hasImage() => _image != null;

  // "bio" field.
  String? _bio;
  String get bio => _bio ?? '';
  bool hasBio() => _bio != null;

  // "role" field.
  String? _role;
  String get role => _role ?? '';
  bool hasRole() => _role != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _userId = snapshotData['user_id'] as String?;
    _userRef = snapshotData['user_ref'] as DocumentReference?;
    _name = snapshotData['name'] as String?;
    _joinedAt = snapshotData['joined_at'] as DateTime?;
    _status = snapshotData['status'] as String?;
    _image = snapshotData['image'] as String?;
    _bio = snapshotData['bio'] as String?;
    _role = snapshotData['role'] as String?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('participant')
          : FirebaseFirestore.instance.collectionGroup('participant');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('participant').doc(id);

  static Stream<ParticipantRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ParticipantRecord.fromSnapshot(s));

  static Future<ParticipantRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ParticipantRecord.fromSnapshot(s));

  static ParticipantRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ParticipantRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ParticipantRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ParticipantRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ParticipantRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ParticipantRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createParticipantRecordData({
  String? userId,
  DocumentReference? userRef,
  String? name,
  DateTime? joinedAt,
  String? status,
  String? image,
  String? bio,
  String? role,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'user_id': userId,
      'user_ref': userRef,
      'name': name,
      'joined_at': joinedAt,
      'status': status,
      'image': image,
      'bio': bio,
      'role': role,
    }.withoutNulls,
  );

  return firestoreData;
}

class ParticipantRecordDocumentEquality implements Equality<ParticipantRecord> {
  const ParticipantRecordDocumentEquality();

  @override
  bool equals(ParticipantRecord? e1, ParticipantRecord? e2) {
    return e1?.userId == e2?.userId &&
        e1?.userRef == e2?.userRef &&
        e1?.name == e2?.name &&
        e1?.joinedAt == e2?.joinedAt &&
        e1?.status == e2?.status &&
        e1?.image == e2?.image &&
        e1?.bio == e2?.bio &&
        e1?.role == e2?.role;
  }

  @override
  int hash(ParticipantRecord? e) => const ListEquality().hash([
        e?.userId,
        e?.userRef,
        e?.name,
        e?.joinedAt,
        e?.status,
        e?.image,
        e?.bio,
        e?.role
      ]);

  @override
  bool isValidKey(Object? o) => o is ParticipantRecord;
}
