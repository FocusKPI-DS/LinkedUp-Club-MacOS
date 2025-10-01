import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PostsRecord extends FirestoreRecord {
  PostsRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "author_ref" field.
  DocumentReference? _authorRef;
  DocumentReference? get authorRef => _authorRef;
  bool hasAuthorRef() => _authorRef != null;

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  bool hasText() => _text != null;

  // "image_url" field.
  String? _imageUrl;
  String get imageUrl => _imageUrl ?? '';
  bool hasImageUrl() => _imageUrl != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "like_count" field.
  int? _likeCount;
  int get likeCount => _likeCount ?? 0;
  bool hasLikeCount() => _likeCount != null;

  // "comment_count" field.
  int? _commentCount;
  int get commentCount => _commentCount ?? 0;
  bool hasCommentCount() => _commentCount != null;

  // "liked_by" field.
  List<DocumentReference>? _likedBy;
  List<DocumentReference> get likedBy => _likedBy ?? const [];
  bool hasLikedBy() => _likedBy != null;

  // "post_type" field.
  String? _postType;
  String get postType => _postType ?? '';
  bool hasPostType() => _postType != null;

  // "author_image" field.
  String? _authorImage;
  String get authorImage => _authorImage ?? '';
  bool hasAuthorImage() => _authorImage != null;

  // "author_name" field.
  String? _authorName;
  String get authorName => _authorName ?? '';
  bool hasAuthorName() => _authorName != null;

  // "saved_by" field.
  List<DocumentReference>? _savedBy;
  List<DocumentReference> get savedBy => _savedBy ?? const [];
  bool hasSavedBy() => _savedBy != null;

  void _initializeFields() {
    _authorRef = snapshotData['author_ref'] as DocumentReference?;
    _text = snapshotData['text'] as String?;
    _imageUrl = snapshotData['image_url'] as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _likeCount = castToType<int>(snapshotData['like_count']);
    _commentCount = castToType<int>(snapshotData['comment_count']);
    _likedBy = getDataList(snapshotData['liked_by']);
    _postType = snapshotData['post_type'] as String?;
    _authorImage = snapshotData['author_image'] as String?;
    _authorName = snapshotData['author_name'] as String?;
    _savedBy = getDataList(snapshotData['saved_by']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('posts');

  static Stream<PostsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => PostsRecord.fromSnapshot(s));

  static Future<PostsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => PostsRecord.fromSnapshot(s));

  static PostsRecord fromSnapshot(DocumentSnapshot snapshot) => PostsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static PostsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      PostsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'PostsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is PostsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createPostsRecordData({
  DocumentReference? authorRef,
  String? text,
  String? imageUrl,
  DateTime? createdAt,
  int? likeCount,
  int? commentCount,
  String? postType,
  String? authorImage,
  String? authorName,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'author_ref': authorRef,
      'text': text,
      'image_url': imageUrl,
      'created_at': createdAt,
      'like_count': likeCount,
      'comment_count': commentCount,
      'post_type': postType,
      'author_image': authorImage,
      'author_name': authorName,
    }.withoutNulls,
  );

  return firestoreData;
}

class PostsRecordDocumentEquality implements Equality<PostsRecord> {
  const PostsRecordDocumentEquality();

  @override
  bool equals(PostsRecord? e1, PostsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.authorRef == e2?.authorRef &&
        e1?.text == e2?.text &&
        e1?.imageUrl == e2?.imageUrl &&
        e1?.createdAt == e2?.createdAt &&
        e1?.likeCount == e2?.likeCount &&
        e1?.commentCount == e2?.commentCount &&
        listEquality.equals(e1?.likedBy, e2?.likedBy) &&
        e1?.postType == e2?.postType &&
        e1?.authorImage == e2?.authorImage &&
        e1?.authorName == e2?.authorName &&
        listEquality.equals(e1?.savedBy, e2?.savedBy);
  }

  @override
  int hash(PostsRecord? e) => const ListEquality().hash([
        e?.authorRef,
        e?.text,
        e?.imageUrl,
        e?.createdAt,
        e?.likeCount,
        e?.commentCount,
        e?.likedBy,
        e?.postType,
        e?.authorImage,
        e?.authorName,
        e?.savedBy
      ]);

  @override
  bool isValidKey(Object? o) => o is PostsRecord;
}
