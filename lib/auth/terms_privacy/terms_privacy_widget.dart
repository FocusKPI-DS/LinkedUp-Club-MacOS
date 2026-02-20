import '/flutter_flow/flutter_flow_util.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'terms_privacy_model.dart';
export 'terms_privacy_model.dart';

/// Create a page of Terms of Use and Privacy Policy.
///
/// Make it one page but leble 2 parts
class TermsPrivacyWidget extends StatefulWidget {
  const TermsPrivacyWidget({
    super.key,
    bool? isTerm,
  }) : isTerm = isTerm ?? false;

  final bool isTerm;

  static String routeName = 'TermsPrivacy';
  static String routePath = '/termsPrivacy';

  @override
  State<TermsPrivacyWidget> createState() => _TermsPrivacyWidgetState();
}

class _TermsPrivacyWidgetState extends State<TermsPrivacyWidget> {
  late TermsPrivacyModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TermsPrivacyModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (widget.isTerm == true) {
        await _model.columnController?.animateTo(
          0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.ease,
        );
      } else {
        await _model.columnController?.animateTo(
          _model.columnController!.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.ease,
        );
      }
    });

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
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          automaticallyImplyLeading: false,
          leading: InkWell(
            splashColor: Colors.transparent,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () async {
              context.safePop();
            },
            child: Container(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                child: Icon(
                  Icons.arrow_back,
                  color: FlutterFlowTheme.of(context).primary,
                  size: 24.0,
                ),
              ),
            ),
          ),
          title: Container(
            child: Text(
              'Legal Information',
              style: FlutterFlowTheme.of(context).headlineMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).primaryText,
                    fontSize: 22.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
            ),
          ),
          actions: const [],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: Align(
            alignment: const AlignmentDirectional(0.0, 0.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                controller: _model.columnController,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        maxWidth: 650.0,
                      ),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 8.0,
                            color: Color(0x1A000000),
                            offset: Offset(
                              0.0,
                              2.0,
                            ),
                          )
                        ],
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      12.0, 0.0, 12.0, 0.0),
                                  child: Icon(
                                    Icons.gavel,
                                    color: FlutterFlowTheme.of(context).primary,
                                    size: 28.0,
                                  ),
                                ),
                                Text(
                                  'Terms of Use',
                                  style: FlutterFlowTheme.of(context)
                                      .headlineSmall
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .headlineSmall
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                        fontSize: 24.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .headlineSmall
                                            .fontStyle,
                                      ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  0.0, 8.0, 0.0, 16.0),
                              child: Text(
                                'Last updated: June 15, 2025',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      fontSize: 14.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '1. Acceptance of Terms',
                                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'By accessing and using this application, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 16.0),
                                
                                Text(
                                  '2. Content Moderation and Community Guidelines',
                                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'Zero Tolerance Policy',
                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  'We maintain a strict zero-tolerance policy for objectionable content including but not limited to:',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  '• Harassment, bullying, or threatening behavior\n• Hate speech or discriminatory content\n• Nudity, sexual content, or inappropriate material\n• Spam, scams, or fraudulent activities\n• Violence or illegal activities',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 12.0),
                                Text(
                                  'User Responsibilities: Users are responsible for all content they post and must ensure it complies with these guidelines.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'Enforcement: Violation of these guidelines will result in immediate content removal and may lead to account suspension or permanent ban.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'Reporting: Users can report inappropriate content, and all reports will be reviewed promptly.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 16.0),
                                
                                Text(
                                  '3. Use License',
                                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'Permission is granted to temporarily download one copy of the materials on our application for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 16.0),
                                
                                Text(
                                  '4. Disclaimer',
                                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'The materials on our application are provided on an "as is" basis. We make no warranties, expressed or implied, and hereby disclaim and negate all other warranties including, without limitation, implied warranties or conditions of merchantability.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 16.0),
                                
                                Text(
                                  '5. Limitations',
                                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'In no event shall our company or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use the materials on our application.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 24.0),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        maxWidth: 650.0,
                      ),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 8.0,
                            color: Color(0x1A000000),
                            offset: Offset(
                              0.0,
                              2.0,
                            ),
                          )
                        ],
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      12.0, 0.0, 12.0, 0.0),
                                  child: Icon(
                                    Icons.shield,
                                    color: FlutterFlowTheme.of(context).accent1,
                                    size: 28.0,
                                  ),
                                ),
                                Text(
                                  'Privacy Policy',
                                  style: FlutterFlowTheme.of(context)
                                      .headlineSmall
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .headlineSmall
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .accent1,
                                        fontSize: 24.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .headlineSmall
                                            .fontStyle,
                                      ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  0.0, 8.0, 0.0, 16.0),
                              child: Text(
                                'Last updated: June 15, 2025',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      fontSize: 14.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Information We Collect',
                                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'We collect information you provide directly to us, such as when you create an account, use our services, or contact us for support. This may include your name, email address, and usage data.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 16.0),
                                
                                Text(
                                  'How We Use Your Information',
                                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'We use the information we collect to:',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  '• Provide, maintain, and improve our services\n• Process transactions\n• Send communications\n• Ensure the security of our platform',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 16.0),
                                
                                Text(
                                  'Information Sharing',
                                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except as described in this policy or as required by law.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 16.0),
                                
                                Text(
                                  'Data Security',
                                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet is 100% secure.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 16.0),
                                
                                Text(
                                  'Contact Us',
                                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  'If you have any questions about these Terms of Use or Privacy Policy, please contact us at:',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  '📧 danz@focuskpi.com',
                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontWeight: FontWeight.bold,
                                    color: FlutterFlowTheme.of(context).primary,
                                  ),
                                ),
                                Text(
                                  'Or through our support channels within the application.',
                                  style: FlutterFlowTheme.of(context).bodyMedium,
                                ),
                                const SizedBox(height: 24.0),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ].divide(const SizedBox(height: 25.0)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
