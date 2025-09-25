import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'payment_history_page_model.dart';
export 'payment_history_page_model.dart';

class PaymentHistoryPageWidget extends StatefulWidget {
  const PaymentHistoryPageWidget({super.key});

  static String routeName = 'PaymentHistoryPage';
  static String routePath = '/paymentHistoryPage';

  @override
  State<PaymentHistoryPageWidget> createState() =>
      _PaymentHistoryPageWidgetState();
}

class _PaymentHistoryPageWidgetState extends State<PaymentHistoryPageWidget> {
  late PaymentHistoryPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PaymentHistoryPageModel());

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
        body: SafeArea(
          top: true,
          child: Align(
            alignment: AlignmentDirectional(0.0, 0.0),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 650.0,
              ),
              decoration: BoxDecoration(),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: custom_widgets.PaymentHistory(
                  width: double.infinity,
                  height: double.infinity,
                  onEventTap: (eventId) async {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
