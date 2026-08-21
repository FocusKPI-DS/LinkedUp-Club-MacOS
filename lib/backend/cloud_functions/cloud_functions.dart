import 'package:cloud_functions/cloud_functions.dart';

import '/backend/cloud_functions/callable_functions.dart';

Future<Map<String, dynamic>> makeCloudCall(
  String callName,
  Map<String, dynamic> input,
) async {
  try {
    final response = await invokeCloudFunction(callName, data: input);
    return response is Map
        ? Map<String, dynamic>.from(response as Map)
        : {};
  } on FirebaseFunctionsException catch (e) {
    print(
      'Cloud call error!\n $callName'
      'Code: ${e.code}\n'
      'Details: ${e.details}\n'
      'Message: ${e.message}',
    );
  } catch (e) {
    print('Cloud call error:$callName $e');
  }
  return {};
}
