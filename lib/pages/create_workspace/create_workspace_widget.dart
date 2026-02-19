import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_workspace_model.dart';
export 'create_workspace_model.dart';

class CreateWorkspaceWidget extends StatefulWidget {
  const CreateWorkspaceWidget({Key? key}) : super(key: key);

  @override
  _CreateWorkspaceWidgetState createState() => _CreateWorkspaceWidgetState();
}

class _CreateWorkspaceWidgetState extends State<CreateWorkspaceWidget> {
  late CreateWorkspaceModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CreateWorkspaceModel());

    _model.workspaceNameController ??= TextEditingController();
    _model.descriptionController ??= TextEditingController();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: true,
          title: Text(
            'Create New Workspace',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  fontFamily: 'Inter',
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
          ),
          centerTitle: false,
          elevation: 0,
        ),
        body: SafeArea(
          top: true,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Workspace Creation Form
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Text(
                          'Set up your new workspace',
                          style: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .override(
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create a workspace where your team can collaborate and communicate.',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                        SizedBox(height: 32),

                        // Workspace Name Field
                        Text(
                          'Workspace Name',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _model.workspaceNameController,
                          autofocus: false,
                          obscureText: false,
                          decoration: InputDecoration(
                            hintText: 'Enter workspace name...',
                            hintStyle:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).primary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).error,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).error,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0,
                                  ),
                          validator: _model.workspaceNameControllerValidator
                              .asValidator(context),
                        ),
                        SizedBox(height: 24),

                        // Description Field
                        Text(
                          'Description (Optional)',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _model.descriptionController,
                          autofocus: false,
                          obscureText: false,
                          decoration: InputDecoration(
                            hintText: 'Describe what this workspace is for...',
                            hintStyle:
                                FlutterFlowTheme.of(context).bodySmall.override(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).primary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).error,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).error,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0,
                                  ),
                          maxLines: 4,
                          validator: _model.descriptionControllerValidator
                              .asValidator(context),
                        ),
                        SizedBox(height: 32),

                        // Info Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: FlutterFlowTheme.of(context).primary,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You will be the owner of this workspace and can invite team members later.',
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          context.safePop();
                        },
                        text: 'Cancel',
                        options: FFButtonOptions(
                          height: 48,
                          padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                          iconPadding:
                              EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          textStyle: FlutterFlowTheme.of(context)
                              .titleSmall
                              .override(
                                fontFamily: 'Inter',
                                color: FlutterFlowTheme.of(context).primaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                          elevation: 0,
                          borderSide: BorderSide(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          await _createWorkspace();
                        },
                        text: 'Create Workspace',
                        options: FFButtonOptions(
                          height: 48,
                          padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                          iconPadding:
                              EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                          elevation: 0,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createWorkspace() async {
    if (_model.workspaceNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a workspace name')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current user
      final currentUser = currentUserReference;
      if (currentUser == null) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to create a workspace')),
        );
        return;
      }

      // Create workspace document
      final workspaceData = {
        'name': _model.workspaceNameController.text.trim(),
        'description': _model.descriptionController.text.trim(),
        'created_time': getCurrentTimestamp,
        'owner_ref': currentUser,
        'logo_url': '',
        'member_count': 1,
      };

      final workspaceRef = await FirebaseFirestore.instance
          .collection('workspaces')
          .add(workspaceData);

      // Add current user as owner to workspace members
      final memberData = {
        'user_ref': currentUser,
        'workspace_ref': workspaceRef,
        'role': 'owner',
        'joined_time': getCurrentTimestamp,
      };

      await FirebaseFirestore.instance
          .collection('workspace_members')
          .add(memberData);

      // Update user's current workspace
      await currentUser.update({
        'current_workspace_ref': workspaceRef,
      });

      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close create workspace page

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workspace created successfully!')),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating workspace: $e')),
      );
    }
  }
}
