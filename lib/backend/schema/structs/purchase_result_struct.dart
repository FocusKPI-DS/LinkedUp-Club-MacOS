// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class PurchaseResultStruct extends FFFirebaseStruct {
  PurchaseResultStruct({
    bool? success,
    String? message,
    String? error,
    String? transactionId,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _success = success,
        _message = message,
        _error = error,
        _transactionId = transactionId,
        super(firestoreUtilData);

  // "success" field.
  bool? _success;
  bool get success => _success ?? false;
  set success(bool? val) => _success = val;

  bool hasSuccess() => _success != null;

  // "message" field.
  String? _message;
  String get message => _message ?? '';
  set message(String? val) => _message = val;

  bool hasMessage() => _message != null;

  // "error" field.
  String? _error;
  String get error => _error ?? '';
  set error(String? val) => _error = val;

  bool hasError() => _error != null;

  // "transaction_id" field.
  String? _transactionId;
  String get transactionId => _transactionId ?? '';
  set transactionId(String? val) => _transactionId = val;

  bool hasTransactionId() => _transactionId != null;

  static PurchaseResultStruct fromMap(Map<String, dynamic> data) =>
      PurchaseResultStruct(
        success: data['success'] as bool?,
        message: data['message'] as String?,
        error: data['error'] as String?,
        transactionId: data['transaction_id'] as String?,
      );

  static PurchaseResultStruct? maybeFromMap(dynamic data) => data is Map
      ? PurchaseResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'message': _message,
        'error': _error,
        'transaction_id': _transactionId,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'success': serializeParam(
          _success,
          ParamType.bool,
        ),
        'message': serializeParam(
          _message,
          ParamType.String,
        ),
        'error': serializeParam(
          _error,
          ParamType.String,
        ),
        'transaction_id': serializeParam(
          _transactionId,
          ParamType.String,
        ),
      }.withoutNulls;

  static PurchaseResultStruct fromSerializableMap(Map<String, dynamic> data) =>
      PurchaseResultStruct(
        success: deserializeParam(
          data['success'],
          ParamType.bool,
          false,
        ),
        message: deserializeParam(
          data['message'],
          ParamType.String,
          false,
        ),
        error: deserializeParam(
          data['error'],
          ParamType.String,
          false,
        ),
        transactionId: deserializeParam(
          data['transaction_id'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'PurchaseResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is PurchaseResultStruct &&
        success == other.success &&
        message == other.message &&
        error == other.error &&
        transactionId == other.transactionId;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([success, message, error, transactionId]);
}

PurchaseResultStruct createPurchaseResultStruct({
  bool? success,
  String? message,
  String? error,
  String? transactionId,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    PurchaseResultStruct(
      success: success,
      message: message,
      error: error,
      transactionId: transactionId,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

PurchaseResultStruct? updatePurchaseResultStruct(
  PurchaseResultStruct? purchaseResult, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    purchaseResult
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addPurchaseResultStructData(
  Map<String, dynamic> firestoreData,
  PurchaseResultStruct? purchaseResult,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (purchaseResult == null) {
    return;
  }
  if (purchaseResult.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && purchaseResult.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final purchaseResultData =
      getPurchaseResultFirestoreData(purchaseResult, forFieldValue);
  final nestedData =
      purchaseResultData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = purchaseResult.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getPurchaseResultFirestoreData(
  PurchaseResultStruct? purchaseResult, [
  bool forFieldValue = false,
]) {
  if (purchaseResult == null) {
    return {};
  }
  final firestoreData = mapToFirestore(purchaseResult.toMap());

  // Add any Firestore field values
  purchaseResult.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getPurchaseResultListFirestoreData(
  List<PurchaseResultStruct>? purchaseResults,
) =>
    purchaseResults
        ?.map((e) => getPurchaseResultFirestoreData(e, true))
        .toList() ??
    [];
