// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ScheduleStruct extends FFFirebaseStruct {
  ScheduleStruct({
    String? name,
    List<SpeakerStruct>? speaker,
    LatLng? location,
    String? locationName,
    DateTime? startTime,
    DateTime? endTime,
    String? locationNote,
    String? description,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _name = name,
        _speaker = speaker,
        _location = location,
        _locationName = locationName,
        _startTime = startTime,
        _endTime = endTime,
        _locationNote = locationNote,
        _description = description,
        super(firestoreUtilData);

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  set name(String? val) => _name = val;

  bool hasName() => _name != null;

  // "speaker" field.
  List<SpeakerStruct>? _speaker;
  List<SpeakerStruct> get speaker => _speaker ?? const [];
  set speaker(List<SpeakerStruct>? val) => _speaker = val;

  void updateSpeaker(Function(List<SpeakerStruct>) updateFn) {
    updateFn(_speaker ??= []);
  }

  bool hasSpeaker() => _speaker != null;

  // "location" field.
  LatLng? _location;
  LatLng? get location => _location;
  set location(LatLng? val) => _location = val;

  bool hasLocation() => _location != null;

  // "location_name" field.
  String? _locationName;
  String get locationName => _locationName ?? '';
  set locationName(String? val) => _locationName = val;

  bool hasLocationName() => _locationName != null;

  // "start_time" field.
  DateTime? _startTime;
  DateTime? get startTime => _startTime;
  set startTime(DateTime? val) => _startTime = val;

  bool hasStartTime() => _startTime != null;

  // "end_time" field.
  DateTime? _endTime;
  DateTime? get endTime => _endTime;
  set endTime(DateTime? val) => _endTime = val;

  bool hasEndTime() => _endTime != null;

  // "location_note" field.
  String? _locationNote;
  String get locationNote => _locationNote ?? '';
  set locationNote(String? val) => _locationNote = val;

  bool hasLocationNote() => _locationNote != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  set description(String? val) => _description = val;

  bool hasDescription() => _description != null;

  static ScheduleStruct fromMap(Map<String, dynamic> data) => ScheduleStruct(
        name: data['name'] as String?,
        speaker: getStructList(
          data['speaker'],
          SpeakerStruct.fromMap,
        ),
        location: data['location'] as LatLng?,
        locationName: data['location_name'] as String?,
        startTime: data['start_time'] as DateTime?,
        endTime: data['end_time'] as DateTime?,
        locationNote: data['location_note'] as String?,
        description: data['description'] as String?,
      );

  static ScheduleStruct? maybeFromMap(dynamic data) =>
      data is Map ? ScheduleStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'name': _name,
        'speaker': _speaker?.map((e) => e.toMap()).toList(),
        'location': _location,
        'location_name': _locationName,
        'start_time': _startTime,
        'end_time': _endTime,
        'location_note': _locationNote,
        'description': _description,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'name': serializeParam(
          _name,
          ParamType.String,
        ),
        'speaker': serializeParam(
          _speaker,
          ParamType.DataStruct,
          isList: true,
        ),
        'location': serializeParam(
          _location,
          ParamType.LatLng,
        ),
        'location_name': serializeParam(
          _locationName,
          ParamType.String,
        ),
        'start_time': serializeParam(
          _startTime,
          ParamType.DateTime,
        ),
        'end_time': serializeParam(
          _endTime,
          ParamType.DateTime,
        ),
        'location_note': serializeParam(
          _locationNote,
          ParamType.String,
        ),
        'description': serializeParam(
          _description,
          ParamType.String,
        ),
      }.withoutNulls;

  static ScheduleStruct fromSerializableMap(Map<String, dynamic> data) =>
      ScheduleStruct(
        name: deserializeParam(
          data['name'],
          ParamType.String,
          false,
        ),
        speaker: deserializeStructParam<SpeakerStruct>(
          data['speaker'],
          ParamType.DataStruct,
          true,
          structBuilder: SpeakerStruct.fromSerializableMap,
        ),
        location: deserializeParam(
          data['location'],
          ParamType.LatLng,
          false,
        ),
        locationName: deserializeParam(
          data['location_name'],
          ParamType.String,
          false,
        ),
        startTime: deserializeParam(
          data['start_time'],
          ParamType.DateTime,
          false,
        ),
        endTime: deserializeParam(
          data['end_time'],
          ParamType.DateTime,
          false,
        ),
        locationNote: deserializeParam(
          data['location_note'],
          ParamType.String,
          false,
        ),
        description: deserializeParam(
          data['description'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ScheduleStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is ScheduleStruct &&
        name == other.name &&
        listEquality.equals(speaker, other.speaker) &&
        location == other.location &&
        locationName == other.locationName &&
        startTime == other.startTime &&
        endTime == other.endTime &&
        locationNote == other.locationNote &&
        description == other.description;
  }

  @override
  int get hashCode => const ListEquality().hash([
        name,
        speaker,
        location,
        locationName,
        startTime,
        endTime,
        locationNote,
        description
      ]);
}

ScheduleStruct createScheduleStruct({
  String? name,
  LatLng? location,
  String? locationName,
  DateTime? startTime,
  DateTime? endTime,
  String? locationNote,
  String? description,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ScheduleStruct(
      name: name,
      location: location,
      locationName: locationName,
      startTime: startTime,
      endTime: endTime,
      locationNote: locationNote,
      description: description,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ScheduleStruct? updateScheduleStruct(
  ScheduleStruct? schedule, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    schedule
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addScheduleStructData(
  Map<String, dynamic> firestoreData,
  ScheduleStruct? schedule,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (schedule == null) {
    return;
  }
  if (schedule.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && schedule.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final scheduleData = getScheduleFirestoreData(schedule, forFieldValue);
  final nestedData = scheduleData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = schedule.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getScheduleFirestoreData(
  ScheduleStruct? schedule, [
  bool forFieldValue = false,
]) {
  if (schedule == null) {
    return {};
  }
  final firestoreData = mapToFirestore(schedule.toMap());

  // Add any Firestore field values
  schedule.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getScheduleListFirestoreData(
  List<ScheduleStruct>? schedules,
) =>
    schedules?.map((e) => getScheduleFirestoreData(e, true)).toList() ?? [];
