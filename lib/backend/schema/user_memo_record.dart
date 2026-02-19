import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UserMemoRecord extends FirestoreRecord {
  UserMemoRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "owner_ref" field.
  DocumentReference? _ownerRef;
  DocumentReference? get ownerRef => _ownerRef;
  bool hasOwnerRef() => _ownerRef != null;

  // "target_ref" field.
  DocumentReference? _targetRef;
  DocumentReference? get targetRef => _targetRef;
  bool hasTargetRef() => _targetRef != null;

  // "memo_text" field.
  String? _memoText;
  String get memoText => _memoText ?? '';
  bool hasMemoText() => _memoText != null;

  // "memo_image" field.
  String? _memoImage;
  String get memoImage => _memoImage ?? '';
  bool hasMemoImage() => _memoImage != null;

  // "updated_at" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  // "chat_ref" field.
  DocumentReference? _chatRef;
  DocumentReference? get chatRef => _chatRef;
  bool hasChatRef() => _chatRef != null;

  void _initializeFields() {
    _ownerRef = snapshotData['owner_ref'] as DocumentReference?;
    _targetRef = snapshotData['target_ref'] as DocumentReference?;
    _memoText = snapshotData['memo_text'] as String?;
    _memoImage = snapshotData['memo_image'] as String?;
    _updatedAt = snapshotData['updated_at'] as DateTime?;
    _chatRef = snapshotData['chat_ref'] as DocumentReference?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('user_memo');

  static Stream<UserMemoRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UserMemoRecord.fromSnapshot(s));

  static Future<UserMemoRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UserMemoRecord.fromSnapshot(s));

  static UserMemoRecord fromSnapshot(DocumentSnapshot snapshot) =>
      UserMemoRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UserMemoRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UserMemoRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UserMemoRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UserMemoRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUserMemoRecordData({
  DocumentReference? ownerRef,
  DocumentReference? targetRef,
  String? memoText,
  String? memoImage,
  DateTime? updatedAt,
  DocumentReference? chatRef,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'owner_ref': ownerRef,
      'target_ref': targetRef,
      'memo_text': memoText,
      'memo_image': memoImage,
      'updated_at': updatedAt,
      'chat_ref': chatRef,
    }.withoutNulls,
  );

  return firestoreData;
}

class UserMemoRecordDocumentEquality implements Equality<UserMemoRecord> {
  const UserMemoRecordDocumentEquality();

  @override
  bool equals(UserMemoRecord? e1, UserMemoRecord? e2) {
    return e1?.ownerRef == e2?.ownerRef &&
        e1?.targetRef == e2?.targetRef &&
        e1?.memoText == e2?.memoText &&
        e1?.memoImage == e2?.memoImage &&
        e1?.updatedAt == e2?.updatedAt &&
        e1?.chatRef == e2?.chatRef;
  }

  @override
  int hash(UserMemoRecord? e) => const ListEquality().hash([
        e?.ownerRef,
        e?.targetRef,
        e?.memoText,
        e?.memoImage,
        e?.updatedAt,
        e?.chatRef
      ]);

  @override
  bool isValidKey(Object? o) => o is UserMemoRecord;
}
