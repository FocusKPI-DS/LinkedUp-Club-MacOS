import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MessagesRecord extends FirestoreRecord {
  MessagesRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "sender_ref" field.
  DocumentReference? _senderRef;
  DocumentReference? get senderRef => _senderRef;
  bool hasSenderRef() => _senderRef != null;

  // "content" field.
  String? _content;
  String get content => _content ?? '';
  bool hasContent() => _content != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "is_read_by" field.
  List<DocumentReference>? _isReadBy;
  List<DocumentReference> get isReadBy => _isReadBy ?? const [];
  bool hasIsReadBy() => _isReadBy != null;

  // "reply_to" field.
  String? _replyTo;
  String get replyTo => _replyTo ?? '';
  bool hasReplyTo() => _replyTo != null;

  // "attachment_url" field.
  String? _attachmentUrl;
  String get attachmentUrl => _attachmentUrl ?? '';
  bool hasAttachmentUrl() => _attachmentUrl != null;

  // "message_type" field.
  MessageType? _messageType;
  MessageType? get messageType => _messageType;
  bool hasMessageType() => _messageType != null;

  // "video" field.
  String? _video;
  String get video => _video ?? '';
  bool hasVideo() => _video != null;

  // "audio" field.
  String? _audio;
  String get audio => _audio ?? '';
  bool hasAudio() => _audio != null;

  // "audio_path" field.
  String? _audioPath;
  String get audioPath => _audioPath ?? '';
  bool hasAudioPath() => _audioPath != null;

  // "sender_name" field.
  String? _senderName;
  String get senderName => _senderName ?? '';
  bool hasSenderName() => _senderName != null;

  // "sender_photo" field.
  String? _senderPhoto;
  String get senderPhoto => _senderPhoto ?? '';
  bool hasSenderPhoto() => _senderPhoto != null;

  // "image" field.
  String? _image;
  String get image => _image ?? '';
  bool hasImage() => _image != null;

  // "images" field.
  List<String>? _images;
  List<String> get images => _images ?? const [];
  bool hasImages() => _images != null;

  // "reactions_by_user" field: map of userId -> list of emojis.
  Map<String, List<String>>? _reactionsByUser;
  Map<String, List<String>> get reactionsByUser => _reactionsByUser ?? const {};
  bool hasReactionsByUser() => _reactionsByUser != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _senderRef = snapshotData['sender_ref'] as DocumentReference?;
    _content = snapshotData['content'] as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _isReadBy = getDataList(snapshotData['is_read_by']);
    _replyTo = snapshotData['reply_to'] as String?;
    _attachmentUrl = snapshotData['attachment_url'] as String?;
    _messageType = snapshotData['message_type'] is MessageType
        ? snapshotData['message_type']
        : deserializeEnum<MessageType>(snapshotData['message_type']);
    _video = snapshotData['video'] as String?;
    _audio = snapshotData['audio'] as String?;
    _audioPath = snapshotData['audio_path'] as String?;
    _senderName = snapshotData['sender_name'] as String?;
    _senderPhoto = snapshotData['sender_photo'] as String?;
    _image = snapshotData['image'] as String?;
    _images = getDataList(snapshotData['images']);
    final rbU = snapshotData['reactions_by_user'];
    if (rbU is Map) {
      final Map<String, List<String>> parsed = {};
      rbU.forEach((key, value) {
        final k = key.toString();
        if (value is List) {
          parsed[k] = value.map((e) => e.toString()).toList();
        } else if (value != null) {
          parsed[k] = [value.toString()];
        }
      });
      _reactionsByUser = parsed.isEmpty ? null : parsed;
    } else {
      _reactionsByUser = null;
    }
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('messages')
          : FirebaseFirestore.instance.collectionGroup('messages');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('messages').doc(id);

  static Stream<MessagesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MessagesRecord.fromSnapshot(s));

  static Future<MessagesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MessagesRecord.fromSnapshot(s));

  static MessagesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MessagesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MessagesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MessagesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MessagesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MessagesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMessagesRecordData({
  DocumentReference? senderRef,
  String? content,
  DateTime? createdAt,
  String? replyTo,
  String? attachmentUrl,
  MessageType? messageType,
  String? video,
  String? audio,
  String? audioPath,
  String? senderName,
  String? senderPhoto,
  String? image,
  Map<String, List<String>>? reactionsByUser,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'sender_ref': senderRef,
      'content': content,
      'created_at': createdAt,
      'reply_to': replyTo,
      'attachment_url': attachmentUrl,
      'message_type': messageType,
      'video': video,
      'audio': audio,
      'audio_path': audioPath,
      'sender_name': senderName,
      'sender_photo': senderPhoto,
      'image': image,
      'reactions_by_user': reactionsByUser,
    }.withoutNulls,
  );

  return firestoreData;
}

class MessagesRecordDocumentEquality implements Equality<MessagesRecord> {
  const MessagesRecordDocumentEquality();

  @override
  bool equals(MessagesRecord? e1, MessagesRecord? e2) {
    const listEquality = ListEquality();
    return e1?.senderRef == e2?.senderRef &&
        e1?.content == e2?.content &&
        e1?.createdAt == e2?.createdAt &&
        listEquality.equals(e1?.isReadBy, e2?.isReadBy) &&
        e1?.replyTo == e2?.replyTo &&
        e1?.attachmentUrl == e2?.attachmentUrl &&
        e1?.messageType == e2?.messageType &&
        e1?.video == e2?.video &&
        e1?.audio == e2?.audio &&
        e1?.audioPath == e2?.audioPath &&
        e1?.senderName == e2?.senderName &&
        e1?.senderPhoto == e2?.senderPhoto &&
        e1?.image == e2?.image &&
        listEquality.equals(e1?.images, e2?.images);
  }

  @override
  int hash(MessagesRecord? e) => const ListEquality().hash([
        e?.senderRef,
        e?.content,
        e?.createdAt,
        e?.isReadBy,
        e?.replyTo,
        e?.attachmentUrl,
        e?.messageType,
        e?.video,
        e?.audio,
        e?.audioPath,
        e?.senderName,
        e?.senderPhoto,
        e?.image,
        e?.images
      ]);

  @override
  bool isValidKey(Object? o) => o is MessagesRecord;
}
