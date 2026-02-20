// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!


Future<bool> seperateDate(
  DateTime? startDate,
  DateTime? endDate,
) async {
  // Return false if input invalid
  if (startDate == null || endDate == null) return false;

  // Prepare
  DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
  DateTime finalDate = DateTime(endDate.year, endDate.month, endDate.day);

  List<DateScheduleStruct> dateSchedules = [];

  // Loop through each day and generate struct
  while (!current.isAfter(finalDate)) {
    String dateStr = DateFormat('yyyy-MM-dd').format(current);

    dateSchedules.add(DateScheduleStruct(
      date: dateStr,
      schedule: [],
    ));

    current = current.add(const Duration(days: 1));
  }

  // Set to FFAppState
  FFAppState().scheduleDate = dateSchedules;
  FFAppState().update(() {});

  return true;
}
