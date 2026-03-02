import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'eventbrite_dashboard_model.dart';
export 'eventbrite_dashboard_model.dart';

class EventbriteDashboardWidget extends StatefulWidget {
  const EventbriteDashboardWidget({super.key});

  static String routeName = 'EventbriteDashboard';
  static String routePath = '/eventbriteDashboard';

  @override
  State<EventbriteDashboardWidget> createState() =>
      _EventbriteDashboardWidgetState();
}

class _EventbriteDashboardWidgetState extends State<EventbriteDashboardWidget> {
  late EventbriteDashboardModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EventbriteDashboardModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Align(
              alignment: const AlignmentDirectional(-1.0, 0.0),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0.0, 50.0, 0.0, 0.0),
                child: FlutterFlowIconButton(
                  borderRadius: 8.0,
                  buttonSize: 64.0,
                  fillColor: Colors.transparent,
                  icon: Icon(
                    Icons.chevron_left,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 32.0,
                  ),
                  onPressed: () async {
                    context.safePop();
                  },
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: const AlignmentDirectional(0.0, 0.0),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 650.0,
                  ),
                  decoration: const BoxDecoration(),
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: custom_widgets.EventbriteDashboard(
                        width: double.infinity,
                        height: double.infinity,
                        onEventSync: (eventId) async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Event synced successfully!',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15.0,
                                ),
                              ),
                              duration: const Duration(milliseconds: 2000),
                              backgroundColor:
                                  FlutterFlowTheme.of(context).success,
                            ),
                          );
                        },
                        onSettingsClick: (eventId) async {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
