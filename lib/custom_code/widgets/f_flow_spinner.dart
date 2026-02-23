// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

class FFlowSpinner extends StatefulWidget {
  const FFlowSpinner({
    super.key,
    this.width,
    this.height,
    this.spinnerWidth,
    this.spinnerHeight,
    this.strokeWidth,
    this.backgroundColor,
    this.spinnerColor,
  });

  final double? width;
  final double? height;
  final double? spinnerWidth;
  final double? spinnerHeight;
  final double? strokeWidth;
  final Color? backgroundColor;
  final Color? spinnerColor;

  @override
  _FFlowSpinnerState createState() => _FFlowSpinnerState();
}

class _FFlowSpinnerState extends State<FFlowSpinner> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor ??
          FlutterFlowTheme.of(context).primaryBackground,
      child: Center(
        child: SizedBox(
          width: widget.spinnerWidth ?? 50,
          height: widget.spinnerHeight ?? 50,
          child: CircularProgressIndicator(
            strokeWidth: widget.strokeWidth ?? 4.0,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.spinnerColor ?? FlutterFlowTheme.of(context).secondary,
            ),
          ),
        ),
      ),
    );
  }
}
