// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class DateScheduleStruct extends FFFirebaseStruct {
  DateScheduleStruct({
    String? date,
    List<ScheduleStruct>? schedule,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _date = date,
        _schedule = schedule,
        super(firestoreUtilData);

  // "date" field.
  String? _date;
  String get date => _date ?? '';
  set date(String? val) => _date = val;

  bool hasDate() => _date != null;

  // "schedule" field.
  List<ScheduleStruct>? _schedule;
  List<ScheduleStruct> get schedule => _schedule ?? const [];
  set schedule(List<ScheduleStruct>? val) => _schedule = val;

  void updateSchedule(Function(List<ScheduleStruct>) updateFn) {
    updateFn(_schedule ??= []);
  }

  bool hasSchedule() => _schedule != null;

  static DateScheduleStruct fromMap(Map<String, dynamic> data) =>
      DateScheduleStruct(
        date: data['date'] as String?,
        schedule: getStructList(
          data['schedule'],
          ScheduleStruct.fromMap,
        ),
      );

  static DateScheduleStruct? maybeFromMap(dynamic data) => data is Map
      ? DateScheduleStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'date': _date,
        'schedule': _schedule?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'date': serializeParam(
          _date,
          ParamType.String,
        ),
        'schedule': serializeParam(
          _schedule,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static DateScheduleStruct fromSerializableMap(Map<String, dynamic> data) =>
      DateScheduleStruct(
        date: deserializeParam(
          data['date'],
          ParamType.String,
          false,
        ),
        schedule: deserializeStructParam<ScheduleStruct>(
          data['schedule'],
          ParamType.DataStruct,
          true,
          structBuilder: ScheduleStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'DateScheduleStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is DateScheduleStruct &&
        date == other.date &&
        listEquality.equals(schedule, other.schedule);
  }

  @override
  int get hashCode => const ListEquality().hash([date, schedule]);
}

DateScheduleStruct createDateScheduleStruct({
  String? date,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    DateScheduleStruct(
      date: date,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

DateScheduleStruct? updateDateScheduleStruct(
  DateScheduleStruct? dateSchedule, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    dateSchedule
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addDateScheduleStructData(
  Map<String, dynamic> firestoreData,
  DateScheduleStruct? dateSchedule,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (dateSchedule == null) {
    return;
  }
  if (dateSchedule.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && dateSchedule.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final dateScheduleData =
      getDateScheduleFirestoreData(dateSchedule, forFieldValue);
  final nestedData =
      dateScheduleData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = dateSchedule.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getDateScheduleFirestoreData(
  DateScheduleStruct? dateSchedule, [
  bool forFieldValue = false,
]) {
  if (dateSchedule == null) {
    return {};
  }
  final firestoreData = mapToFirestore(dateSchedule.toMap());

  // Add any Firestore field values
  dateSchedule.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getDateScheduleListFirestoreData(
  List<DateScheduleStruct>? dateSchedules,
) =>
    dateSchedules?.map((e) => getDateScheduleFirestoreData(e, true)).toList() ??
    [];
