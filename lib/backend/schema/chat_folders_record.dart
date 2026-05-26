import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ChatFoldersRecord extends FirestoreRecord {
  ChatFoldersRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "chat_ids" field — ordered list of chat document IDs in this folder.
  List<String>? _chatIds;
  List<String> get chatIds => _chatIds ?? const [];
  bool hasChatIds() => _chatIds != null;

  // "order" field — sort position among folders.
  int? _order;
  int get order => _order ?? 0;
  bool hasOrder() => _order != null;

  // "is_collapsed" field — whether the folder is collapsed in UI.
  bool? _isCollapsed;
  bool get isCollapsed => _isCollapsed ?? false;
  bool hasIsCollapsed() => _isCollapsed != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "updated_at" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  /// Parent user reference.
  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _chatIds = getDataList(snapshotData['chat_ids']);
    _order = castToType<int>(snapshotData['order']);
    _isCollapsed = snapshotData['is_collapsed'] as bool?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _updatedAt = snapshotData['updated_at'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('chat_folders')
          : FirebaseFirestore.instance.collectionGroup('chat_folders');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('chat_folders').doc(id);

  static Stream<ChatFoldersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ChatFoldersRecord.fromSnapshot(s));

  static Future<ChatFoldersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ChatFoldersRecord.fromSnapshot(s));

  static ChatFoldersRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ChatFoldersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ChatFoldersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ChatFoldersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ChatFoldersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ChatFoldersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createChatFoldersRecordData({
  String? name,
  int? order,
  bool? isCollapsed,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'order': order,
      'is_collapsed': isCollapsed,
      'created_at': createdAt,
      'updated_at': updatedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class ChatFoldersRecordDocumentEquality
    implements Equality<ChatFoldersRecord> {
  const ChatFoldersRecordDocumentEquality();

  @override
  bool equals(ChatFoldersRecord? e1, ChatFoldersRecord? e2) {
    const listEquality = ListEquality();
    return e1?.name == e2?.name &&
        listEquality.equals(e1?.chatIds, e2?.chatIds) &&
        e1?.order == e2?.order &&
        e1?.isCollapsed == e2?.isCollapsed &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt;
  }

  @override
  int hash(ChatFoldersRecord? e) => const ListEquality().hash([
        e?.name,
        e?.chatIds,
        e?.order,
        e?.isCollapsed,
        e?.createdAt,
        e?.updatedAt,
      ]);

  @override
  bool isValidKey(Object? o) => o is ChatFoldersRecord;
}
