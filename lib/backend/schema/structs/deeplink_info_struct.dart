// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class DeeplinkInfoStruct extends FFFirebaseStruct {
  DeeplinkInfoStruct({
    String? userInvite,
    String? invitationCode,
    String? eventId,
    String? inviteType,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _userInvite = userInvite,
        _invitationCode = invitationCode,
        _eventId = eventId,
        _inviteType = inviteType,
        super(firestoreUtilData);

  // "userInvite" field.
  String? _userInvite;
  String get userInvite => _userInvite ?? '';
  set userInvite(String? val) => _userInvite = val;

  bool hasUserInvite() => _userInvite != null;

  // "invitationCode" field.
  String? _invitationCode;
  String get invitationCode => _invitationCode ?? '';
  set invitationCode(String? val) => _invitationCode = val;

  bool hasInvitationCode() => _invitationCode != null;

  // "eventId" field.
  String? _eventId;
  String get eventId => _eventId ?? '';
  set eventId(String? val) => _eventId = val;

  bool hasEventId() => _eventId != null;

  // "inviteType" field.
  String? _inviteType;
  String get inviteType => _inviteType ?? '';
  set inviteType(String? val) => _inviteType = val;

  bool hasInviteType() => _inviteType != null;

  static DeeplinkInfoStruct fromMap(Map<String, dynamic> data) =>
      DeeplinkInfoStruct(
        userInvite: data['userInvite'] as String?,
        invitationCode: data['invitationCode'] as String?,
        eventId: data['eventId'] as String?,
        inviteType: data['inviteType'] as String?,
      );

  static DeeplinkInfoStruct? maybeFromMap(dynamic data) => data is Map
      ? DeeplinkInfoStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'userInvite': _userInvite,
        'invitationCode': _invitationCode,
        'eventId': _eventId,
        'inviteType': _inviteType,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'userInvite': serializeParam(
          _userInvite,
          ParamType.String,
        ),
        'invitationCode': serializeParam(
          _invitationCode,
          ParamType.String,
        ),
        'eventId': serializeParam(
          _eventId,
          ParamType.String,
        ),
        'inviteType': serializeParam(
          _inviteType,
          ParamType.String,
        ),
      }.withoutNulls;

  static DeeplinkInfoStruct fromSerializableMap(Map<String, dynamic> data) =>
      DeeplinkInfoStruct(
        userInvite: deserializeParam(
          data['userInvite'],
          ParamType.String,
          false,
        ),
        invitationCode: deserializeParam(
          data['invitationCode'],
          ParamType.String,
          false,
        ),
        eventId: deserializeParam(
          data['eventId'],
          ParamType.String,
          false,
        ),
        inviteType: deserializeParam(
          data['inviteType'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'DeeplinkInfoStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is DeeplinkInfoStruct &&
        userInvite == other.userInvite &&
        invitationCode == other.invitationCode &&
        eventId == other.eventId &&
        inviteType == other.inviteType;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([userInvite, invitationCode, eventId, inviteType]);
}

DeeplinkInfoStruct createDeeplinkInfoStruct({
  String? userInvite,
  String? invitationCode,
  String? eventId,
  String? inviteType,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    DeeplinkInfoStruct(
      userInvite: userInvite,
      invitationCode: invitationCode,
      eventId: eventId,
      inviteType: inviteType,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

DeeplinkInfoStruct? updateDeeplinkInfoStruct(
  DeeplinkInfoStruct? deeplinkInfo, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    deeplinkInfo
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addDeeplinkInfoStructData(
  Map<String, dynamic> firestoreData,
  DeeplinkInfoStruct? deeplinkInfo,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (deeplinkInfo == null) {
    return;
  }
  if (deeplinkInfo.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && deeplinkInfo.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final deeplinkInfoData =
      getDeeplinkInfoFirestoreData(deeplinkInfo, forFieldValue);
  final nestedData =
      deeplinkInfoData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = deeplinkInfo.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getDeeplinkInfoFirestoreData(
  DeeplinkInfoStruct? deeplinkInfo, [
  bool forFieldValue = false,
]) {
  if (deeplinkInfo == null) {
    return {};
  }
  final firestoreData = mapToFirestore(deeplinkInfo.toMap());

  // Add any Firestore field values
  deeplinkInfo.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getDeeplinkInfoListFirestoreData(
  List<DeeplinkInfoStruct>? deeplinkInfos,
) =>
    deeplinkInfos?.map((e) => getDeeplinkInfoFirestoreData(e, true)).toList() ??
    [];
