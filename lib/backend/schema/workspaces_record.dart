import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class WorkspacesRecord extends FirestoreRecord {
  WorkspacesRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "slug" field.
  String? _slug;
  String get slug => _slug ?? '';
  bool hasSlug() => _slug != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "logo_url" field.
  String? _logoUrl;
  String get logoUrl => _logoUrl ?? '';
  bool hasLogoUrl() => _logoUrl != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "is_active" field.
  bool? _isActive;
  bool get isActive => _isActive ?? true;
  bool hasIsActive() => _isActive != null;

  // "workspace_type" field.
  String? _workspaceType;
  String get workspaceType => _workspaceType ?? '';
  bool hasWorkspaceType() => _workspaceType != null;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _slug = snapshotData['slug'] as String?;
    _description = snapshotData['description'] as String?;
    _logoUrl = snapshotData['logo_url'] as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _isActive = snapshotData['is_active'] as bool?;
    _workspaceType = snapshotData['workspace_type'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('workspaces');

  static Stream<WorkspacesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => WorkspacesRecord.fromSnapshot(s));

  static Future<WorkspacesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => WorkspacesRecord.fromSnapshot(s));

  static WorkspacesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      WorkspacesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static WorkspacesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      WorkspacesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'WorkspacesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is WorkspacesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createWorkspacesRecordData({
  String? name,
  String? slug,
  String? description,
  String? logoUrl,
  DateTime? createdAt,
  bool? isActive,
  String? workspaceType,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'slug': slug,
      'description': description,
      'logo_url': logoUrl,
      'created_at': createdAt,
      'is_active': isActive,
      'workspace_type': workspaceType,
    }.withoutNulls,
  );

  return firestoreData;
}

class WorkspacesRecordDocumentEquality implements Equality<WorkspacesRecord> {
  const WorkspacesRecordDocumentEquality();

  @override
  bool equals(WorkspacesRecord? e1, WorkspacesRecord? e2) {
    return e1?.name == e2?.name &&
        e1?.slug == e2?.slug &&
        e1?.description == e2?.description &&
        e1?.logoUrl == e2?.logoUrl &&
        e1?.createdAt == e2?.createdAt &&
        e1?.isActive == e2?.isActive &&
        e1?.workspaceType == e2?.workspaceType;
  }

  @override
  int hash(WorkspacesRecord? e) => const ListEquality().hash([
        e?.name,
        e?.slug,
        e?.description,
        e?.logoUrl,
        e?.createdAt,
        e?.isActive,
        e?.workspaceType
      ]);

  @override
  bool isValidKey(Object? o) => o is WorkspacesRecord;
}
