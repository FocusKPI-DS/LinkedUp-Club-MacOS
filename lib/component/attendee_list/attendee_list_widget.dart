import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'attendee_list_model.dart';
export 'attendee_list_model.dart';

class AttendeeListWidget extends StatefulWidget {
  const AttendeeListWidget({
    super.key,
    this.image,
    this.name,
    this.bio,
    bool? isMutual,
    this.addFriend,
    this.removeRequest,
    bool? isClick,
    this.user,
  })  : isMutual = isMutual ?? false,
        isClick = isClick ?? false;

  final String? image;
  final String? name;
  final String? bio;
  final bool isMutual;
  final Future Function()? addFriend;
  final Future Function()? removeRequest;
  final bool isClick;
  final UsersRecord? user;

  @override
  State<AttendeeListWidget> createState() => _AttendeeListWidgetState();
}

class _AttendeeListWidgetState extends State<AttendeeListWidget>
    with TickerProviderStateMixin {
  late AttendeeListModel _model;

  var hasIconButtonTriggered = false;
  var hasButtonTriggered = false;
  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AttendeeListModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.isclick = widget.isClick;
      safeSetState(() {});
    });

    animationsMap.addAll({
      'iconButtonOnActionTriggerAnimation': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: false,
        effectsBuilder: () => [
          FlipEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 1.5,
            end: 2.0,
          ),
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
          ),
        ],
      ),
      'buttonOnActionTriggerAnimation': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: false,
        effectsBuilder: () => [
          FlipEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: 1.5,
            end: 2.0,
          ),
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
          ),
        ],
      ),
    });
    setupAnimations(
      animationsMap.values.where((anim) =>
          anim.trigger == AnimationTrigger.onActionTrigger ||
          !anim.applyInitialState),
      this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
      child: InkWell(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () async {
          context.pushNamed(
            UserProfileDetailWidget.routeName,
            queryParameters: {
              'user': serializeParam(
                widget.user,
                ParamType.Document,
              ),
            }.withoutNulls,
            extra: <String, dynamic>{
              'user': widget.user,
            },
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12.0, 12.0, 12.0, 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Stack(
                      alignment: const AlignmentDirectional(1.0, 1.0),
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24.0),
                          child: Image.network(
                            valueOrDefault<String>(
                              widget.image,
                              'https://firebasestorage.googleapis.com/v0/b/linkedup-c3e29.firebasestorage.app/o/asset%2Fjurica-koletic-7YVZYZeITc8-unsplash.jpg?alt=media&token=d05a38c8-e024-4624-bdb3-82e4f7c6afab',
                            ),
                            width: 48.0,
                            height: 48.0,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          valueOrDefault<String>(
                            widget.name,
                            'N/A',
                          ).maybeHandleOverflow(
                            maxChars: 15,
                            replacement: '…',
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: const Color(0xFF1F2937),
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                        ),
                        AutoSizeText(
                          valueOrDefault<String>(
                            widget.bio,
                            'N/A',
                          ).maybeHandleOverflow(
                            maxChars: 15,
                            replacement: '…',
                          ),
                          maxLines: 1,
                          minFontSize: 9.0,
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.normal,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 14.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.normal,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                      ].divide(const SizedBox(height: 4.0)),
                    ),
                  ].divide(const SizedBox(width: 12.0)),
                ),
                if (widget.isMutual == false)
                  Builder(
                    builder: (context) {
                      if (_model.isclick == false) {
                        return FlutterFlowIconButton(
                          borderRadius: 32.0,
                          buttonSize: 40.0,
                          fillColor: FlutterFlowTheme.of(context).primary,
                          icon: Icon(
                            Icons.person_add_alt_1,
                            color: FlutterFlowTheme.of(context).info,
                            size: 24.0,
                          ),
                          onPressed: () async {
                            await widget.addFriend?.call();
                            _model.isclick = true;
                            safeSetState(() {});
                            if (animationsMap[
                                    'buttonOnActionTriggerAnimation'] !=
                                null) {
                              safeSetState(() => hasButtonTriggered = true);
                              SchedulerBinding.instance.addPostFrameCallback(
                                  (_) async => await animationsMap[
                                          'buttonOnActionTriggerAnimation']!
                                      .controller
                                      .forward(from: 0.0));
                            }
                          },
                        ).animateOnActionTrigger(
                            animationsMap[
                                'iconButtonOnActionTriggerAnimation']!,
                            hasBeenTriggered: hasIconButtonTriggered);
                      } else {
                        return FFButtonWidget(
                          onPressed: () async {
                            await widget.removeRequest?.call();
                            _model.isclick = false;
                            safeSetState(() {});
                            if (animationsMap[
                                    'iconButtonOnActionTriggerAnimation'] !=
                                null) {
                              safeSetState(() => hasIconButtonTriggered = true);
                              SchedulerBinding.instance.addPostFrameCallback(
                                  (_) async => await animationsMap[
                                          'iconButtonOnActionTriggerAnimation']!
                                      .controller
                                      .forward(from: 0.0));
                            }
                          },
                          text: 'Pending',
                          icon: const Icon(
                            Icons.timer_sharp,
                            size: 15.0,
                          ),
                          options: FFButtonOptions(
                            height: 30.0,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            iconPadding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color: FlutterFlowTheme.of(context).warning,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color: Colors.white,
                                  fontSize: 12.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                            elevation: 0.0,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ).animateOnActionTrigger(
                            animationsMap['buttonOnActionTriggerAnimation']!,
                            hasBeenTriggered: hasButtonTriggered);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
