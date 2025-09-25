import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

import 'package:branchio_dynamic_linking_akp5u6/library_values.dart'
    as branchio_dynamic_linking_akp5u6_library_values;
import 'package:linkedup/backend/schema/enums/enums.dart';
import 'package:linkedup/backend/schema/structs/index.dart';

class FFLibraryValues {
  static FFLibraryValues _instance = FFLibraryValues._internal();

  factory FFLibraryValues() {
    return _instance;
  }

  FFLibraryValues._internal();

  static void reset() {
    _instance = FFLibraryValues._internal();
  }
}
