// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class SpeakerStruct extends FFFirebaseStruct {
  SpeakerStruct({
    String? image,
    String? name,
    String? role,
    bool? isFeature,
    DocumentReference? speakerRef,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _image = image,
        _name = name,
        _role = role,
        _isFeature = isFeature,
        _speakerRef = speakerRef,
        super(firestoreUtilData);

  // "image" field.
  String? _image;
  String get image => _image ?? '';
  set image(String? val) => _image = val;

  bool hasImage() => _image != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  set name(String? val) => _name = val;

  bool hasName() => _name != null;

  // "role" field.
  String? _role;
  String get role => _role ?? '';
  set role(String? val) => _role = val;

  bool hasRole() => _role != null;

  // "is_feature" field.
  bool? _isFeature;
  bool get isFeature => _isFeature ?? false;
  set isFeature(bool? val) => _isFeature = val;

  bool hasIsFeature() => _isFeature != null;

  // "speaker_ref" field.
  DocumentReference? _speakerRef;
  DocumentReference? get speakerRef => _speakerRef;
  set speakerRef(DocumentReference? val) => _speakerRef = val;

  bool hasSpeakerRef() => _speakerRef != null;

  static SpeakerStruct fromMap(Map<String, dynamic> data) => SpeakerStruct(
        image: data['image'] as String?,
        name: data['name'] as String?,
        role: data['role'] as String?,
        isFeature: data['is_feature'] as bool?,
        speakerRef: data['speaker_ref'] as DocumentReference?,
      );

  static SpeakerStruct? maybeFromMap(dynamic data) =>
      data is Map ? SpeakerStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'image': _image,
        'name': _name,
        'role': _role,
        'is_feature': _isFeature,
        'speaker_ref': _speakerRef,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'image': serializeParam(
          _image,
          ParamType.String,
        ),
        'name': serializeParam(
          _name,
          ParamType.String,
        ),
        'role': serializeParam(
          _role,
          ParamType.String,
        ),
        'is_feature': serializeParam(
          _isFeature,
          ParamType.bool,
        ),
        'speaker_ref': serializeParam(
          _speakerRef,
          ParamType.DocumentReference,
        ),
      }.withoutNulls;

  static SpeakerStruct fromSerializableMap(Map<String, dynamic> data) =>
      SpeakerStruct(
        image: deserializeParam(
          data['image'],
          ParamType.String,
          false,
        ),
        name: deserializeParam(
          data['name'],
          ParamType.String,
          false,
        ),
        role: deserializeParam(
          data['role'],
          ParamType.String,
          false,
        ),
        isFeature: deserializeParam(
          data['is_feature'],
          ParamType.bool,
          false,
        ),
        speakerRef: deserializeParam(
          data['speaker_ref'],
          ParamType.DocumentReference,
          false,
          collectionNamePath: ['users'],
        ),
      );

  @override
  String toString() => 'SpeakerStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is SpeakerStruct &&
        image == other.image &&
        name == other.name &&
        role == other.role &&
        isFeature == other.isFeature &&
        speakerRef == other.speakerRef;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([image, name, role, isFeature, speakerRef]);
}

SpeakerStruct createSpeakerStruct({
  String? image,
  String? name,
  String? role,
  bool? isFeature,
  DocumentReference? speakerRef,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    SpeakerStruct(
      image: image,
      name: name,
      role: role,
      isFeature: isFeature,
      speakerRef: speakerRef,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

SpeakerStruct? updateSpeakerStruct(
  SpeakerStruct? speaker, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    speaker
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addSpeakerStructData(
  Map<String, dynamic> firestoreData,
  SpeakerStruct? speaker,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (speaker == null) {
    return;
  }
  if (speaker.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && speaker.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final speakerData = getSpeakerFirestoreData(speaker, forFieldValue);
  final nestedData = speakerData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = speaker.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getSpeakerFirestoreData(
  SpeakerStruct? speaker, [
  bool forFieldValue = false,
]) {
  if (speaker == null) {
    return {};
  }
  final firestoreData = mapToFirestore(speaker.toMap());

  // Add any Firestore field values
  speaker.firestoreUtilData.fieldValues.forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getSpeakerListFirestoreData(
  List<SpeakerStruct>? speakers,
) =>
    speakers?.map((e) => getSpeakerFirestoreData(e, true)).toList() ?? [];
