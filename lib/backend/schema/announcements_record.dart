import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class AnnouncementsRecord extends FirestoreRecord {
  AnnouncementsRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "content" field.
  String? _content;
  String get content => _content ?? '';
  bool hasContent() => _content != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "created_by" field.
  DocumentReference? _createdBy;
  DocumentReference? get createdBy => _createdBy;
  bool hasCreatedBy() => _createdBy != null;

  // "creator_name" field.
  String? _creatorName;
  String get creatorName => _creatorName ?? '';
  bool hasCreatorName() => _creatorName != null;

  // "is_pinned" field.
  bool? _isPinned;
  bool get isPinned => _isPinned ?? false;
  bool hasIsPinned() => _isPinned != null;

  // "confirmed_by" field — list of user refs who have acknowledged.
  List<DocumentReference>? _confirmedBy;
  List<DocumentReference> get confirmedBy => _confirmedBy ?? const [];
  bool hasConfirmedBy() => _confirmedBy != null;

  /// Parent chat reference.
  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _content = snapshotData['content'] as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _createdBy = snapshotData['created_by'] as DocumentReference?;
    _creatorName = snapshotData['creator_name'] as String?;
    _isPinned = snapshotData['is_pinned'] as bool?;
    _confirmedBy = getDataList(snapshotData['confirmed_by']);
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('announcements')
          : FirebaseFirestore.instance.collectionGroup('announcements');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('announcements').doc(id);

  static Stream<AnnouncementsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => AnnouncementsRecord.fromSnapshot(s));

  static Future<AnnouncementsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => AnnouncementsRecord.fromSnapshot(s));

  static AnnouncementsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      AnnouncementsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static AnnouncementsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      AnnouncementsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'AnnouncementsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is AnnouncementsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createAnnouncementsRecordData({
  String? content,
  DateTime? createdAt,
  DocumentReference? createdBy,
  String? creatorName,
  bool? isPinned,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'content': content,
      'created_at': createdAt,
      'created_by': createdBy,
      'creator_name': creatorName,
      'is_pinned': isPinned,
    }.withoutNulls,
  );

  return firestoreData;
}

class AnnouncementsRecordDocumentEquality
    implements Equality<AnnouncementsRecord> {
  const AnnouncementsRecordDocumentEquality();

  @override
  bool equals(AnnouncementsRecord? e1, AnnouncementsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.content == e2?.content &&
        e1?.createdAt == e2?.createdAt &&
        e1?.createdBy == e2?.createdBy &&
        e1?.creatorName == e2?.creatorName &&
        e1?.isPinned == e2?.isPinned &&
        listEquality.equals(e1?.confirmedBy, e2?.confirmedBy);
  }

  @override
  int hash(AnnouncementsRecord? e) => const ListEquality().hash([
        e?.content,
        e?.createdAt,
        e?.createdBy,
        e?.creatorName,
        e?.isPinned,
        e?.confirmedBy,
      ]);

  @override
  bool isValidKey(Object? o) => o is AnnouncementsRecord;
}
