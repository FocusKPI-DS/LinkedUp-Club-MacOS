import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'speaker_info_model.dart';
export 'speaker_info_model.dart';

class SpeakerInfoWidget extends StatefulWidget {
  const SpeakerInfoWidget({
    super.key,
    this.image,
    this.name,
    this.role,
  });

  final String? image;
  final String? name;
  final String? role;

  @override
  State<SpeakerInfoWidget> createState() => _SpeakerInfoWidgetState();
}

class _SpeakerInfoWidgetState extends State<SpeakerInfoWidget> {
  late SpeakerInfoModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SpeakerInfoModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Container(
        width: 170.0,
        constraints: const BoxConstraints(
          maxHeight: 230.0,
        ),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(17.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 130.0,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: Image.network(
                      valueOrDefault<String>(
                        widget.image,
                        'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fdefault-user.png?alt=media&token=35d4da12-13b0-4f43-8b8e-375e6e126683',
                      ),
                    ).image,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              AutoSizeText(
                widget.name!,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: const Color(0xFF1F2937),
                      fontSize: 14.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w500,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
              AutoSizeText(
                widget.role!,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.normal,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: const Color(0xFF1F2937),
                      fontSize: 12.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.normal,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
            ].divide(const SizedBox(height: 8.0)),
          ),
        ),
      ),
    );
  }
}
