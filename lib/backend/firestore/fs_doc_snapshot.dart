import 'package:cloud_firestore/cloud_firestore.dart';

/// Lightweight document snapshot for REST polling (same API surface as
/// [DocumentSnapshot.data] / [DocumentSnapshot.id] used in AI assistant UI).
class FsDocSnapshot {
  FsDocSnapshot({
    required this.id,
    required this.reference,
    required Map<String, dynamic> data,
  }) : _data = data;

  final String id;
  final DocumentReference reference;
  final Map<String, dynamic> _data;

  Map<String, dynamic>? data() => _data;

  factory FsDocSnapshot.fromQuery(QueryDocumentSnapshot<Map<String, dynamic>> snap) {
    return FsDocSnapshot(
      id: snap.id,
      reference: snap.reference,
      data: snap.data(),
    );
  }

  factory FsDocSnapshot.fromRecord({
    required DocumentReference reference,
    required Map<String, dynamic> data,
  }) {
    return FsDocSnapshot(
      id: reference.id,
      reference: reference,
      data: data,
    );
  }
}
