import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/push_notifications/push_notifications_util.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_media_display.dart';
import '/flutter_flow/flutter_flow_pdf_viewer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_video_player.dart';
import '/flutter_flow/upload_data.dart';
import '/pages/chat/chat_component/chat_thread/chat_thread_widget.dart';
import 'dart:async';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/permissions_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'chat_thread_component_model.dart';
export 'chat_thread_component_model.dart';

///
///
class ChatThreadComponentWidget extends StatefulWidget {
  const ChatThreadComponentWidget({
    super.key,
    required this.chatReference,
    this.onMessageLongPress,
  });

  final ChatsRecord? chatReference;
  final Function(MessagesRecord)? onMessageLongPress;

  @override
  State<ChatThreadComponentWidget> createState() =>
      _ChatThreadComponentWidgetState();
}

class _ChatThreadComponentWidgetState extends State<ChatThreadComponentWidget>
    with TickerProviderStateMixin {
  late ChatThreadComponentModel _model;

  var hasContainerTriggered1 = false;
  var hasContainerTriggered2 = false;
  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  void _insertFormat(String before, String after) {
    final controller = _model.messageTextController;
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0) return;

    final selectedText = text.substring(start, end);
    final newText = text.substring(0, start) +
        before +
        selectedText +
        after +
        text.substring(end);

    // If text was selected, position cursor after the formatted text
    // If no text selected, position cursor between the formatting symbols
    final newCursorPosition = selectedText.isEmpty
        ? start + before.length // Position between symbols for typing
        : start +
            before.length +
            selectedText.length +
            after.length; // Position after formatted text

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );

    safeSetState(() {});
    _model.messageFocusNode?.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatThreadComponentModel());

    _model.messageTextController ??= TextEditingController();
    _model.messageFocusNode ??= FocusNode();

    animationsMap.addAll({
      'containerOnActionTriggerAnimation1': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: false,
        effectsBuilder: () => [
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 300.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
      'containerOnActionTriggerAnimation2': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: false,
        effectsBuilder: () => [
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 600.0.ms,
            begin: const Offset(0.6, 0.6),
            end: const Offset(1.0, 1.0),
          ),
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 600.0.ms,
            duration: 600.0.ms,
            begin: const Offset(1.0, 1.0),
            end: const Offset(0.6, 0.6),
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
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        _model.select = false;
        safeSetState(() {});
      },
      child: Container(
        decoration: const BoxDecoration(),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: StreamBuilder<List<MessagesRecord>>(
                    stream: queryMessagesRecord(
                      parent: widget.chatReference?.reference,
                      queryBuilder: (messagesRecord) => messagesRecord
                          .orderBy('created_at', descending: true),
                    ),
                    builder: (context, snapshot) {
                      // Customize what your widget looks like when it's loading.
                      if (!snapshot.hasData) {
                        return Center(
                          child: SizedBox(
                            width: 50.0,
                            height: 50.0,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ),
                        );
                      }
                      List<MessagesRecord> listViewMessagesRecordList =
                          snapshot.data!;

                      return InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await actions.closekeyboard();
                        },
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          reverse: true,
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          itemCount: listViewMessagesRecordList.length,
                          itemBuilder: (context, listViewIndex) {
                            final listViewMessagesRecord =
                                listViewMessagesRecordList[listViewIndex];
                            return Container(
                              child: wrapWithModel(
                                model: _model.chatThreadModels.getModel(
                                  listViewMessagesRecord.reference.id,
                                  listViewIndex,
                                ),
                                updateCallback: () => safeSetState(() {}),
                                child: ChatThreadWidget(
                                  key: Key(
                                    'Key6sf_${listViewMessagesRecord.reference.id}',
                                  ),
                                  message: listViewMessagesRecord,
                                  senderImage:
                                      listViewMessagesRecord.senderPhoto,
                                  name: listViewMessagesRecord.senderName,
                                  chatRef: widget.chatReference!.reference,
                                  userRef: listViewMessagesRecord.senderRef!,
                                  action: () async {
                                    _model.select = false;
                                    safeSetState(() {});
                                  },
                                  onMessageLongPress: widget.onMessageLongPress,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Divider(
                      height: 1.0,
                      thickness: 1.0,
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 0.0, 0.0, 16.0),
                        child: InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            _model.select = false;
                            safeSetState(() {});
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            16.0, 12.0, 0.0, 0.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if ((_model
                                                  .uploadedFileUrls_uploadData
                                                  .isNotEmpty) ==
                                              true)
                                            Builder(
                                              builder: (context) {
                                                final uploadedImages =
                                                    _model.images.toList();

                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: List.generate(
                                                      uploadedImages.length,
                                                      (uploadedImagesIndex) {
                                                    final uploadedImagesItem =
                                                        uploadedImages[
                                                            uploadedImagesIndex];
                                                    return SizedBox(
                                                      width: 140.0,
                                                      height: 120.0,
                                                      child: Stack(
                                                        alignment:
                                                            const AlignmentDirectional(
                                                                0.0, 0.0),
                                                        children: [
                                                          FlutterFlowMediaDisplay(
                                                            path:
                                                                uploadedImagesItem,
                                                            imageBuilder:
                                                                (path) =>
                                                                    ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8.0),
                                                              child:
                                                                  CachedNetworkImage(
                                                                fadeInDuration:
                                                                    const Duration(
                                                                        milliseconds:
                                                                            500),
                                                                fadeOutDuration:
                                                                    const Duration(
                                                                        milliseconds:
                                                                            500),
                                                                imageUrl: path,
                                                                width: 120.0,
                                                                height: 100.0,
                                                                fit: BoxFit
                                                                    .cover,
                                                              ),
                                                            ),
                                                            videoPlayerBuilder:
                                                                (path) =>
                                                                    FlutterFlowVideoPlayer(
                                                              path: path,
                                                              width: 300.0,
                                                              autoPlay: false,
                                                              looping: true,
                                                              showControls:
                                                                  true,
                                                              allowFullScreen:
                                                                  true,
                                                              allowPlaybackSpeedMenu:
                                                                  false,
                                                            ),
                                                          ),
                                                          Align(
                                                            alignment:
                                                                const AlignmentDirectional(
                                                                    1.12,
                                                                    -0.95),
                                                            child:
                                                                FlutterFlowIconButton(
                                                              borderColor:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .error,
                                                              borderRadius:
                                                                  20.0,
                                                              borderWidth: 2.0,
                                                              buttonSize: 40.0,
                                                              fillColor: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primaryBackground,
                                                              icon: Icon(
                                                                Icons
                                                                    .delete_outline_rounded,
                                                                color: Colors
                                                                    .black,
                                                                size: 24.0,
                                                              ),
                                                              onPressed:
                                                                  () async {
                                                                _model.removeFromImages(
                                                                    uploadedImagesItem);
                                                                safeSetState(
                                                                    () {});
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).divide(const SizedBox(
                                                      width: 5.0)),
                                                );
                                              },
                                            ),
                                          if (_model.file != null &&
                                              _model.file != '')
                                            SizedBox(
                                              width: 160.0,
                                              height: 120.0,
                                              child: Stack(
                                                alignment:
                                                    const AlignmentDirectional(
                                                        0.0, 0.0),
                                                children: [
                                                  FlutterFlowPdfViewer(
                                                    networkPath: _model.file!,
                                                    height: 300.0,
                                                    horizontalScroll: false,
                                                  ),
                                                  Align(
                                                    alignment:
                                                        const AlignmentDirectional(
                                                            1.0, -0.95),
                                                    child:
                                                        FlutterFlowIconButton(
                                                      borderColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      borderRadius: 20.0,
                                                      borderWidth: 2.0,
                                                      buttonSize: 40.0,
                                                      fillColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryBackground,
                                                      icon: Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        color: Colors.black,
                                                        size: 24.0,
                                                      ),
                                                      onPressed: () async {
                                                        safeSetState(() {
                                                          _model.isDataUploading_uploadDataFile =
                                                              false;
                                                          _model.uploadedLocalFile_uploadDataFile =
                                                              FFUploadedFile(
                                                                  bytes: Uint8List
                                                                      .fromList(
                                                                          []));
                                                          _model.uploadedFileUrl_uploadDataFile =
                                                              '';
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (_model.audiopath != null &&
                                              _model.audiopath != '')
                                            SizedBox(
                                              width: 300.0,
                                              height: 110.0,
                                              child: Stack(
                                                alignment:
                                                    const AlignmentDirectional(
                                                        0.0, 0.0),
                                                children: [
                                                  SizedBox(
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    child: custom_widgets
                                                        .LinkedUpPlayer(
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      audioPath:
                                                          _model.audiopath!,
                                                      isLocal: true,
                                                    ),
                                                  ),
                                                  Align(
                                                    alignment:
                                                        const AlignmentDirectional(
                                                            -1.0, 1.0),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsetsDirectional
                                                              .fromSTEB(25.0,
                                                              0.0, 0.0, 5.0),
                                                      child:
                                                          FlutterFlowIconButton(
                                                        borderColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        borderRadius: 20.0,
                                                        borderWidth: 2.0,
                                                        buttonSize: 30.0,
                                                        fillColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryBackground,
                                                        icon: Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .error,
                                                          size: 14.0,
                                                        ),
                                                        onPressed: () async {
                                                          _model.audiopath =
                                                              null;
                                                          safeSetState(() {});
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (_model
                                                  .uploadedFileUrl_uploadDataCamera !=
                                              '')
                                            SizedBox(
                                              width: 140.0,
                                              height: 120.0,
                                              child: Stack(
                                                alignment:
                                                    const AlignmentDirectional(
                                                        0.0, 0.0),
                                                children: [
                                                  FlutterFlowMediaDisplay(
                                                    path: _model.image!,
                                                    imageBuilder: (path) =>
                                                        ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                      child: CachedNetworkImage(
                                                        fadeInDuration:
                                                            const Duration(
                                                                milliseconds:
                                                                    500),
                                                        fadeOutDuration:
                                                            const Duration(
                                                                milliseconds:
                                                                    500),
                                                        imageUrl: path,
                                                        width: 120.0,
                                                        height: 100.0,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                    videoPlayerBuilder: (path) =>
                                                        FlutterFlowVideoPlayer(
                                                      path: path,
                                                      width: 300.0,
                                                      autoPlay: false,
                                                      looping: true,
                                                      showControls: true,
                                                      allowFullScreen: true,
                                                      allowPlaybackSpeedMenu:
                                                          false,
                                                    ),
                                                  ),
                                                  Align(
                                                    alignment:
                                                        const AlignmentDirectional(
                                                            1.36, -0.95),
                                                    child:
                                                        FlutterFlowIconButton(
                                                      borderColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                      borderRadius: 20.0,
                                                      borderWidth: 2.0,
                                                      buttonSize: 40.0,
                                                      fillColor:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryBackground,
                                                      icon: Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        color: Colors.black,
                                                        size: 24.0,
                                                      ),
                                                      onPressed: () async {
                                                        safeSetState(() {
                                                          _model.isDataUploading_uploadDataCamera =
                                                              false;
                                                          _model.uploadedLocalFile_uploadDataCamera =
                                                              FFUploadedFile(
                                                                  bytes: Uint8List
                                                                      .fromList(
                                                                          []));
                                                          _model.uploadedFileUrl_uploadDataCamera =
                                                              '';
                                                        });

                                                        _model.image = null;
                                                        safeSetState(() {});
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ]
                                            .divide(const SizedBox(width: 8.0))
                                            .addToStart(
                                                const SizedBox(width: 16.0))
                                            .addToEnd(
                                                const SizedBox(width: 16.0)),
                                      ),
                                    ),
                                  ),
                                  if (_model.isSendingImage == true)
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              16.0, 0.0, 0.0, 0.0),
                                      child: Container(
                                        width: 120.0,
                                        height: 130.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(9.0),
                                          child: SizedBox(
                                            width: double.infinity,
                                            height: double.infinity,
                                            child: custom_widgets.FFlowSpinner(
                                              width: double.infinity,
                                              height: double.infinity,
                                              backgroundColor:
                                                  Colors.transparent,
                                              spinnerColor:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  if (_model.isMention == true)
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              16.0, 0.0, 16.0, 0.0),
                                      child: InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          safeSetState(() {
                                            _model.messageTextController?.text =
                                                '@linkai';
                                          });
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          height: 50.0,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                          ),
                                          child: Align(
                                            alignment:
                                                const AlignmentDirectional(
                                                    -1.0, 0.0),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .fromSTEB(
                                                      50.0, 0.0, 0.0, 0.0),
                                              child: Text(
                                                '@linkai',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      fontSize: 16.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ).animateOnActionTrigger(
                                          animationsMap[
                                              'containerOnActionTriggerAnimation1']!,
                                          hasBeenTriggered:
                                              hasContainerTriggered1),
                                    ),
                                  // Formatting toolbar
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            16.0, 4.0, 16.0, 0.0),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.format_bold,
                                              size: 18, color: Colors.black),
                                          tooltip: 'Bold',
                                          onPressed: () =>
                                              _insertFormat('**', '**'),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.format_italic,
                                              size: 18, color: Colors.black),
                                          tooltip: 'Italic',
                                          onPressed: () =>
                                              _insertFormat('*', '*'),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.code,
                                              size: 18, color: Colors.black),
                                          tooltip: 'Code',
                                          onPressed: () =>
                                              _insertFormat('`', '`'),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.link,
                                              size: 18, color: Colors.black),
                                          tooltip: 'Link',
                                          onPressed: () =>
                                              _insertFormat('[', '](url)'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Align(
                                    alignment:
                                        const AlignmentDirectional(0.0, 0.0),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 150.0,
                                      ),
                                      decoration: const BoxDecoration(),
                                      child: Padding(
                                        padding: const EdgeInsetsDirectional
                                            .fromSTEB(16.0, 0.0, 16.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            FlutterFlowIconButton(
                                              borderRadius: 16.0,
                                              buttonSize: 38.0,
                                              icon: const Icon(
                                                Icons.add,
                                                color: Color(0xFF6B7280),
                                                size: 20.0,
                                              ),
                                              onPressed: () async {
                                                _model.select = true;
                                                safeSetState(() {});
                                              },
                                            ),
                                            Expanded(
                                              child: SizedBox(
                                                width: 200.0,
                                                child: TextFormField(
                                                  controller: _model
                                                      .messageTextController,
                                                  focusNode:
                                                      _model.messageFocusNode,
                                                  onChanged: (_) =>
                                                      EasyDebounce.debounce(
                                                    '_model.messageTextController',
                                                    const Duration(
                                                        milliseconds: 0),
                                                    () async {
                                                      _model.isMention = functions
                                                          .checkmention(_model
                                                              .messageTextController
                                                              .text)!;
                                                      safeSetState(() {});
                                                      if (_model.isMention ==
                                                          true) {
                                                        if (animationsMap[
                                                                'containerOnActionTriggerAnimation1'] !=
                                                            null) {
                                                          safeSetState(() =>
                                                              hasContainerTriggered1 =
                                                                  true);
                                                          SchedulerBinding
                                                              .instance
                                                              .addPostFrameCallback((_) async =>
                                                                  await animationsMap[
                                                                          'containerOnActionTriggerAnimation1']!
                                                                      .controller
                                                                      .forward(
                                                                          from:
                                                                              0.0));
                                                        }
                                                      }
                                                    },
                                                  ),
                                                  onFieldSubmitted: (_) async {
                                                    safeSetState(() {
                                                      _model.messageTextController
                                                              ?.text =
                                                          '${_model.messageTextController.text}\\n';
                                                    });
                                                  },
                                                  autofocus: false,
                                                  obscureText: false,
                                                  decoration: InputDecoration(
                                                    isDense: false,
                                                    labelStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .labelMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                    hintText:
                                                        'Start typing here...',
                                                    hintStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .labelMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .accent2,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .accent2,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    errorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors.black,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    focusedErrorBorder:
                                                        OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors.black,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                    filled: true,
                                                    fillColor: FlutterFlowTheme
                                                            .of(context)
                                                        .secondaryBackground,
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                                  maxLines: null,
                                                  cursorColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryText,
                                                  validator: _model
                                                      .messageTextControllerValidator
                                                      .asValidator(context),
                                                ),
                                              ),
                                            ),
                                            Builder(
                                              builder: (context) {
                                                if (_model.isSending == false) {
                                                  return FlutterFlowIconButton(
                                                    borderRadius: 32.0,
                                                    buttonSize: 40.0,
                                                    fillColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primary,
                                                    icon: Icon(
                                                      Icons.send_rounded,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .info,
                                                      size: 20.0,
                                                    ),
                                                    onPressed: ((_model
                                                                    .messageTextController
                                                                    .text ==
                                                                '') &&
                                                            (_model.audiopath ==
                                                                    null ||
                                                                _model.audiopath ==
                                                                    '') &&
                                                            (_model
                                                                        .image ==
                                                                    null ||
                                                                _model
                                                                        .image ==
                                                                    '') &&
                                                            !(_model.images
                                                                .isNotEmpty) &&
                                                            !(_model.images
                                                                .isNotEmpty) &&
                                                            (_model.file ==
                                                                    null ||
                                                                _model.file ==
                                                                    ''))
                                                        ? null
                                                        : () async {
                                                            final firestoreBatch =
                                                                FirebaseFirestore
                                                                    .instance
                                                                    .batch();
                                                            try {
                                                              _model.isSending =
                                                                  true;
                                                              safeSetState(
                                                                  () {});
                                                              if (!((_model
                                                                          .messageTextController
                                                                          .text ==
                                                                      '') &&
                                                                  (_model.image ==
                                                                          null ||
                                                                      _model.image ==
                                                                          '') &&
                                                                  (_model.audiopath ==
                                                                          null ||
                                                                      _model.audiopath ==
                                                                          '') &&
                                                                  !(_model
                                                                      .images
                                                                      .isNotEmpty))) {
                                                                _model.isValid =
                                                                    await actions
                                                                        .checkValidWords(
                                                                  _model
                                                                      .messageTextController
                                                                      .text,
                                                                );
                                                                if (_model
                                                                        .isValid ==
                                                                    true) {
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                      content:
                                                                          Text(
                                                                        '⚠️ Message blocked due to inappropriate content.',
                                                                        style:
                                                                            TextStyle(
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                        ),
                                                                      ),
                                                                      duration: const Duration(
                                                                          milliseconds:
                                                                              4000),
                                                                      backgroundColor:
                                                                          FlutterFlowTheme.of(context)
                                                                              .secondary,
                                                                    ),
                                                                  );
                                                                } else {
                                                                  if (_model.audiopath !=
                                                                          null &&
                                                                      _model.audiopath !=
                                                                          '') {
                                                                    _model.netwoekURL =
                                                                        await actions
                                                                            .uploadAudioToStorage(
                                                                      _model
                                                                          .audiopath,
                                                                    );
                                                                    _model.audioMainUrl =
                                                                        _model
                                                                            .netwoekURL;
                                                                    safeSetState(
                                                                        () {});
                                                                  } else {
                                                                    if (functions.containsAIMention(_model
                                                                            .messageTextController
                                                                            .text) ==
                                                                        true) {
                                                                      unawaited(
                                                                        () async {
                                                                          await actions
                                                                              .callAIAgent(
                                                                            widget.chatReference!.reference.id,
                                                                            _model.messageTextController.text,
                                                                          );
                                                                        }(),
                                                                      );
                                                                    }
                                                                  }

                                                                  _model.addToUserSend(
                                                                      currentUserReference!);
                                                                  safeSetState(
                                                                      () {});

                                                                  firestoreBatch.update(
                                                                      widget
                                                                          .chatReference!
                                                                          .reference,
                                                                      {
                                                                        ...createChatsRecordData(
                                                                          lastMessage: widget.chatReference?.isGroup == true
                                                                              ? '$currentUserDisplayName: ${() {
                                                                                  if (_model.image != null && _model.image != '') {
                                                                                    return 'Sent Image';
                                                                                  } else if (_model.audiopath != null && _model.audiopath != '') {
                                                                                    return 'Sent Voice Message';
                                                                                  } else if (_model.file != null && _model.file != '') {
                                                                                    return 'Sent File';
                                                                                  } else {
                                                                                    return _model.messageTextController.text;
                                                                                  }
                                                                                }()}'
                                                                              : () {
                                                                                  if (_model.image != null && _model.image != '') {
                                                                                    return 'Sent Image';
                                                                                  } else if (_model.audiopath != null && _model.audiopath != '') {
                                                                                    return 'Sent Voice Message';
                                                                                  } else if (_model.file != null && _model.file != '') {
                                                                                    return 'Sent File';
                                                                                  } else {
                                                                                    return _model.messageTextController.text;
                                                                                  }
                                                                                }(),
                                                                          lastMessageAt:
                                                                              getCurrentTimestamp,
                                                                          lastMessageSent:
                                                                              currentUserReference,
                                                                          lastMessageType: _model.image == null || _model.image == ''
                                                                              ? MessageType.text
                                                                              : MessageType.image,
                                                                        ),
                                                                        ...mapToFirestore(
                                                                          {
                                                                            'last_message_seen':
                                                                                _model.userSend,
                                                                          },
                                                                        ),
                                                                      });

                                                                  var messagesRecordReference =
                                                                      MessagesRecord.createDoc(widget
                                                                          .chatReference!
                                                                          .reference);
                                                                  firestoreBatch
                                                                      .set(
                                                                          messagesRecordReference,
                                                                          {
                                                                        ...createMessagesRecordData(
                                                                          senderRef:
                                                                              currentUserReference,
                                                                          content: _model
                                                                              .messageTextController
                                                                              .text,
                                                                          createdAt:
                                                                              getCurrentTimestamp,
                                                                          messageType:
                                                                              () {
                                                                            if (_model.image == null ||
                                                                                _model.image == '') {
                                                                              return MessageType.text;
                                                                            } else if (_model.audiopath != null && _model.audiopath != '') {
                                                                              return MessageType.voice;
                                                                            } else {
                                                                              return MessageType.image;
                                                                            }
                                                                          }(),
                                                                          image: _model.image != null && _model.image != ''
                                                                              ? _model.image
                                                                              : null,
                                                                          audio:
                                                                              _model.audiopath,
                                                                          attachmentUrl: _model.file != null && _model.file != ''
                                                                              ? _model.file
                                                                              : '',
                                                                          audioPath:
                                                                              _model.audioMainUrl,
                                                                          senderName:
                                                                              currentUserDisplayName,
                                                                          senderPhoto:
                                                                              currentUserPhoto,
                                                                        ),
                                                                        ...mapToFirestore(
                                                                          {
                                                                            'images': _model.images.isNotEmpty
                                                                                ? _model.images
                                                                                : functions.getEmptyListImagePath(),
                                                                          },
                                                                        ),
                                                                      });
                                                                  _model.newChat =
                                                                      MessagesRecord
                                                                          .getDocumentFromData({
                                                                    ...createMessagesRecordData(
                                                                      senderRef:
                                                                          currentUserReference,
                                                                      content: _model
                                                                          .messageTextController
                                                                          .text,
                                                                      createdAt:
                                                                          getCurrentTimestamp,
                                                                      messageType:
                                                                          () {
                                                                        if (_model.image ==
                                                                                null ||
                                                                            _model.image ==
                                                                                '') {
                                                                          return MessageType
                                                                              .text;
                                                                        } else if (_model.audiopath !=
                                                                                null &&
                                                                            _model.audiopath !=
                                                                                '') {
                                                                          return MessageType
                                                                              .voice;
                                                                        } else {
                                                                          return MessageType
                                                                              .image;
                                                                        }
                                                                      }(),
                                                                      image: _model.image != null &&
                                                                              _model.image !=
                                                                                  ''
                                                                          ? _model
                                                                              .image
                                                                          : null,
                                                                      audio: _model
                                                                          .audiopath,
                                                                      attachmentUrl: _model.file != null &&
                                                                              _model.file !=
                                                                                  ''
                                                                          ? _model
                                                                              .file
                                                                          : '',
                                                                      audioPath:
                                                                          _model
                                                                              .audioMainUrl,
                                                                      senderName:
                                                                          currentUserDisplayName,
                                                                      senderPhoto:
                                                                          currentUserPhoto,
                                                                    ),
                                                                    ...mapToFirestore(
                                                                      {
                                                                        'images': _model.images.isNotEmpty
                                                                            ? _model.images
                                                                            : functions.getEmptyListImagePath(),
                                                                      },
                                                                    ),
                                                                  }, messagesRecordReference);
                                                                  triggerPushNotification(
                                                                    notificationTitle:
                                                                        'New Message',
                                                                    notificationText:
                                                                        '$currentUserDisplayName has sent ${widget.chatReference?.lastMessageType?.name}',
                                                                    notificationImageUrl: _model.image !=
                                                                                null &&
                                                                            _model.image !=
                                                                                ''
                                                                        ? _model
                                                                            .image
                                                                        : '',
                                                                    notificationSound:
                                                                        'default',
                                                                    userRefs: widget
                                                                        .chatReference!
                                                                        .members
                                                                        .where((e) =>
                                                                            e !=
                                                                            currentUserReference)
                                                                        .toList(),
                                                                    initialPageName:
                                                                        'ChatDetail',
                                                                    parameterData: {
                                                                      'chatDoc':
                                                                          widget
                                                                              .chatReference,
                                                                    },
                                                                  );
                                                                  safeSetState(
                                                                      () {
                                                                    _model
                                                                        .messageTextController
                                                                        ?.clear();
                                                                  });
                                                                  _model.audiopath =
                                                                      null;
                                                                  _model.select =
                                                                      false;
                                                                  _model.image =
                                                                      null;
                                                                  _model.file =
                                                                      null;
                                                                  _model.images =
                                                                      [];
                                                                  safeSetState(
                                                                      () {});
                                                                  safeSetState(
                                                                      () {
                                                                    _model.isDataUploading_uploadData =
                                                                        false;
                                                                    _model.uploadedLocalFiles_uploadData =
                                                                        [];
                                                                    _model.uploadedFileUrls_uploadData =
                                                                        [];
                                                                  });

                                                                  safeSetState(
                                                                      () {
                                                                    _model.isDataUploading_uploadDataCamera =
                                                                        false;
                                                                    _model.uploadedLocalFile_uploadDataCamera =
                                                                        FFUploadedFile(
                                                                            bytes:
                                                                                Uint8List.fromList([]));
                                                                    _model.uploadedFileUrl_uploadDataCamera =
                                                                        '';
                                                                  });

                                                                  safeSetState(
                                                                      () {
                                                                    _model.isDataUploading_uploadDataFile =
                                                                        false;
                                                                    _model.uploadedLocalFile_uploadDataFile =
                                                                        FFUploadedFile(
                                                                            bytes:
                                                                                Uint8List.fromList([]));
                                                                    _model.uploadedFileUrl_uploadDataFile =
                                                                        '';
                                                                  });
                                                                }
                                                              }
                                                              _model.isSending =
                                                                  false;
                                                              safeSetState(
                                                                  () {});
                                                            } finally {
                                                              await firestoreBatch
                                                                  .commit();
                                                            }

                                                            safeSetState(() {});
                                                          },
                                                  );
                                                } else {
                                                  return Container(
                                                    width: 40.0,
                                                    height: 40.0,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              5.0),
                                                      child: SizedBox(
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                        child: custom_widgets
                                                            .FFlowSpinner(
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              double.infinity,
                                                          backgroundColor:
                                                              Colors
                                                                  .transparent,
                                                          spinnerColor:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .secondaryBackground,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ].divide(const SizedBox(width: 12.0)),
                                        ),
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
                  ],
                ),
              ]
                  .divide(const SizedBox(height: 16.0))
                  .addToStart(const SizedBox(height: 8.0))
                  .addToEnd(const SizedBox(height: 8.0)),
            ),
            Align(
              alignment: const AlignmentDirectional(-0.8, 0.65),
              child: Container(
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Builder(
                  builder: (context) {
                    if (_model.audio == false) {
                      return Visibility(
                        visible: _model.select == true,
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 150.0,
                          ),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 8.0,
                                color: Color(0x33000000),
                                offset: Offset(
                                  0.0,
                                  4.0,
                                ),
                                spreadRadius: 0.0,
                              )
                            ],
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 16.0, 16.0, 16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Media',
                                  textAlign: TextAlign.center,
                                  style: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontStyle,
                                      ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Temporarily commented out voice feature
                                    // InkWell(
                                    //   splashColor: Colors.transparent,
                                    //   focusColor: Colors.transparent,
                                    //   hoverColor: Colors.transparent,
                                    //   highlightColor: Colors.transparent,
                                    //   onTap: () async {
                                    //     _model.audio = true;
                                    //     safeSetState(() {});
                                    //   },
                                    //   child: Row(
                                    //     mainAxisSize: MainAxisSize.max,
                                    //     mainAxisAlignment:
                                    //         MainAxisAlignment.start,
                                    //     children: [
                                    //       Container(
                                    //         width: 30.0,
                                    //         decoration: BoxDecoration(),
                                    //         child: Align(
                                    //           alignment: AlignmentDirectional(
                                    //               -1.0, 0.0),
                                    //           child: Icon(
                                    //             Icons.mic_rounded,
                                    //             color:
                                    //                 FlutterFlowTheme.of(context)
                                    //                     .primary,
                                    //             size: 24.0,
                                    //           ),
                                    //         ),
                                    //       ),
                                    //       Container(
                                    //         width: 50.0,
                                    //         decoration: BoxDecoration(),
                                    //         child: Text(
                                    //           'Voice',
                                    //           style:
                                    //               FlutterFlowTheme.of(context)
                                    //                   .bodyMedium
                                    //                   .override(
                                    //                     font: GoogleFonts.inter(
                                    //                       fontWeight:
                                    //                           FlutterFlowTheme.of(
                                    //                                   context)
                                    //                               .bodyMedium
                                    //                               .fontWeight,
                                    //                       fontStyle:
                                    //                           FlutterFlowTheme.of(
                                    //                                   context)
                                    //                               .bodyMedium
                                    //                               .fontStyle,
                                    //                     ),
                                    //                     letterSpacing: 0.0,
                                    //                     fontWeight:
                                    //                         FlutterFlowTheme.of(
                                    //                                 context)
                                    //                             .bodyMedium
                                    //                             .fontWeight,
                                    //                     fontStyle:
                                    //                         FlutterFlowTheme.of(
                                    //                                 context)
                                    //                             .bodyMedium
                                    //                             .fontStyle,
                                    //                   ),
                                    //         ),
                                    //       ),
                                    //     ],
                                    //   ),
                                    // ),
                                    Container(
                                      width: double.infinity,
                                      height: 1.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.isSendingImage = true;
                                        _model.select = false;
                                        safeSetState(() {});
                                        final selectedMedia = await selectMedia(
                                          mediaSource: MediaSource.photoGallery,
                                          multiImage: true,
                                        );
                                        if (selectedMedia != null &&
                                            selectedMedia.every((m) =>
                                                validateFileFormat(
                                                    m.storagePath, context))) {
                                          safeSetState(() => _model
                                                  .isDataUploading_uploadData =
                                              true);
                                          var selectedUploadedFiles =
                                              <FFUploadedFile>[];

                                          var downloadUrls = <String>[];
                                          try {
                                            selectedUploadedFiles =
                                                selectedMedia
                                                    .map((m) => FFUploadedFile(
                                                          name: m.storagePath
                                                              .split('/')
                                                              .last,
                                                          bytes: m.bytes,
                                                          height: m.dimensions
                                                              ?.height,
                                                          width: m.dimensions
                                                              ?.width,
                                                          blurHash: m.blurHash,
                                                        ))
                                                    .toList();

                                            downloadUrls = (await Future.wait(
                                              selectedMedia.map(
                                                (m) async => await uploadData(
                                                    m.storagePath, m.bytes),
                                              ),
                                            ))
                                                .where((u) => u != null)
                                                .map((u) => u!)
                                                .toList();
                                          } finally {
                                            _model.isDataUploading_uploadData =
                                                false;
                                          }
                                          if (selectedUploadedFiles.length ==
                                                  selectedMedia.length &&
                                              downloadUrls.length ==
                                                  selectedMedia.length) {
                                            safeSetState(() {
                                              _model.uploadedLocalFiles_uploadData =
                                                  selectedUploadedFiles;
                                              _model.uploadedFileUrls_uploadData =
                                                  downloadUrls;
                                            });
                                          } else {
                                            safeSetState(() {});
                                            return;
                                          }
                                        }

                                        if ((_model.uploadedFileUrls_uploadData
                                                .isNotEmpty) ==
                                            true) {
                                          _model.images = _model
                                              .uploadedFileUrls_uploadData
                                              .toList()
                                              .cast<String>();
                                          safeSetState(() {});
                                        }
                                        _model.isSendingImage = false;
                                        safeSetState(() {});
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 30.0,
                                            decoration: const BoxDecoration(),
                                            child: Align(
                                              alignment:
                                                  const AlignmentDirectional(
                                                      -1.0, 0.0),
                                              child: Icon(
                                                Icons.image_rounded,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                size: 24.0,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 50.0,
                                            decoration: const BoxDecoration(),
                                            child: Text(
                                              'Image',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      height: 1.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.isSendingImage = true;
                                        _model.select = false;
                                        safeSetState(() {});
                                        final selectedMedia =
                                            await selectMediaWithSourceBottomSheet(
                                          context: context,
                                          allowPhoto: true,
                                          allowVideo: true,
                                        );
                                        if (selectedMedia != null &&
                                            selectedMedia.every((m) =>
                                                validateFileFormat(
                                                    m.storagePath, context))) {
                                          safeSetState(() => _model
                                                  .isDataUploading_uploadDataCamera =
                                              true);
                                          var selectedUploadedFiles =
                                              <FFUploadedFile>[];

                                          var downloadUrls = <String>[];
                                          try {
                                            selectedUploadedFiles =
                                                selectedMedia
                                                    .map((m) => FFUploadedFile(
                                                          name: m.storagePath
                                                              .split('/')
                                                              .last,
                                                          bytes: m.bytes,
                                                          height: m.dimensions
                                                              ?.height,
                                                          width: m.dimensions
                                                              ?.width,
                                                          blurHash: m.blurHash,
                                                        ))
                                                    .toList();

                                            downloadUrls = (await Future.wait(
                                              selectedMedia.map(
                                                (m) async => await uploadData(
                                                    m.storagePath, m.bytes),
                                              ),
                                            ))
                                                .where((u) => u != null)
                                                .map((u) => u!)
                                                .toList();
                                          } finally {
                                            _model.isDataUploading_uploadDataCamera =
                                                false;
                                          }
                                          if (selectedUploadedFiles.length ==
                                                  selectedMedia.length &&
                                              downloadUrls.length ==
                                                  selectedMedia.length) {
                                            safeSetState(() {
                                              _model.uploadedLocalFile_uploadDataCamera =
                                                  selectedUploadedFiles.first;
                                              _model.uploadedFileUrl_uploadDataCamera =
                                                  downloadUrls.first;
                                            });
                                          } else {
                                            safeSetState(() {});
                                            return;
                                          }
                                        }

                                        if (_model
                                                .uploadedFileUrl_uploadDataCamera !=
                                            '') {
                                          _model.image = _model
                                              .uploadedFileUrl_uploadDataCamera;
                                          safeSetState(() {});
                                        }
                                        _model.isSendingImage = false;
                                        safeSetState(() {});
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 30.0,
                                            decoration: const BoxDecoration(),
                                            child: Align(
                                              alignment:
                                                  const AlignmentDirectional(
                                                      -1.0, 0.0),
                                              child: Icon(
                                                Icons.camera_alt,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                size: 24.0,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 60.0,
                                            decoration: const BoxDecoration(),
                                            child: Text(
                                              'Camera',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      height: 1.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                    InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        final selectedFiles = await selectFiles(
                                          allowedExtensions: ['pdf'],
                                          multiFile: false,
                                        );
                                        if (selectedFiles != null) {
                                          safeSetState(() => _model
                                                  .isDataUploading_uploadDataFile =
                                              true);
                                          var selectedUploadedFiles =
                                              <FFUploadedFile>[];

                                          var downloadUrls = <String>[];
                                          try {
                                            showUploadMessage(
                                              context,
                                              'Uploading file...',
                                              showLoading: true,
                                            );
                                            selectedUploadedFiles =
                                                selectedFiles
                                                    .map((m) => FFUploadedFile(
                                                          name: m.storagePath
                                                              .split('/')
                                                              .last,
                                                          bytes: m.bytes,
                                                        ))
                                                    .toList();

                                            downloadUrls = (await Future.wait(
                                              selectedFiles.map(
                                                (f) async => await uploadData(
                                                    f.storagePath, f.bytes),
                                              ),
                                            ))
                                                .where((u) => u != null)
                                                .map((u) => u!)
                                                .toList();
                                          } finally {
                                            ScaffoldMessenger.of(context)
                                                .hideCurrentSnackBar();
                                            _model.isDataUploading_uploadDataFile =
                                                false;
                                          }
                                          if (selectedUploadedFiles.length ==
                                                  selectedFiles.length &&
                                              downloadUrls.length ==
                                                  selectedFiles.length) {
                                            safeSetState(() {
                                              _model.uploadedLocalFile_uploadDataFile =
                                                  selectedUploadedFiles.first;
                                              _model.uploadedFileUrl_uploadDataFile =
                                                  downloadUrls.first;
                                            });
                                            showUploadMessage(
                                              context,
                                              'Success!',
                                            );
                                          } else {
                                            safeSetState(() {});
                                            showUploadMessage(
                                              context,
                                              'Failed to upload file',
                                            );
                                            return;
                                          }
                                        }

                                        _model.select = false;
                                        safeSetState(() {});
                                        _model.file = _model
                                            .uploadedFileUrl_uploadDataFile;
                                        safeSetState(() {});
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 30.0,
                                            decoration: const BoxDecoration(),
                                            child: Align(
                                              alignment:
                                                  const AlignmentDirectional(
                                                      -1.0, 0.0),
                                              child: Icon(
                                                Icons.attach_file_rounded,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                size: 24.0,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 50.0,
                                            decoration: const BoxDecoration(),
                                            child: Text(
                                              'File',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ].divide(const SizedBox(height: 8.0)),
                                ),
                              ].divide(const SizedBox(height: 12.0)),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return Stack(
                        alignment: const AlignmentDirectional(1.0, -1.0),
                        children: [
                          Align(
                            alignment: const AlignmentDirectional(0.0, 0.0),
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                              ),
                              alignment: const AlignmentDirectional(0.0, 0.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment:
                                          const AlignmentDirectional(0.0, 0.0),
                                      child: Container(
                                        decoration: const BoxDecoration(),
                                        child: InkWell(
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          hoverColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          onTap: () async {
                                            if (_model.recording == false) {
                                              _model.recording = true;
                                              _model.text =
                                                  'Tap the mic to stop recording your voice.';
                                              safeSetState(() {});
                                              await requestPermission(
                                                  microphonePermission);
                                              if (await getPermissionStatus(
                                                  microphonePermission)) {
                                                await startAudioRecording(
                                                  context,
                                                  audioRecorder:
                                                      _model.audioRecorder ??=
                                                          AudioRecorder(),
                                                );
                                              }
                                              if (animationsMap[
                                                      'containerOnActionTriggerAnimation2'] !=
                                                  null) {
                                                safeSetState(() =>
                                                    hasContainerTriggered2 =
                                                        true);
                                                SchedulerBinding.instance
                                                    .addPostFrameCallback(
                                                        (_) async => animationsMap[
                                                                'containerOnActionTriggerAnimation2']!
                                                            .controller
                                                          ..reset()
                                                          ..repeat());
                                              }
                                            } else {
                                              _model.recording = false;
                                              safeSetState(() {});
                                              if (animationsMap[
                                                      'containerOnActionTriggerAnimation2'] !=
                                                  null) {
                                                animationsMap[
                                                        'containerOnActionTriggerAnimation2']!
                                                    .controller
                                                    .reset();
                                              }
                                              await stopAudioRecording(
                                                audioRecorder:
                                                    _model.audioRecorder,
                                                audioName: 'recordedFileBytes',
                                                onRecordingComplete:
                                                    (audioFilePath,
                                                        audioBytes) {
                                                  _model.stop = audioFilePath;
                                                  _model.recordedFileBytes =
                                                      audioBytes;
                                                },
                                              );

                                              _model.audiopath = functions
                                                  .converAudioPathToString(
                                                      _model.stop);
                                              _model.audio = false;
                                              _model.select = false;
                                              safeSetState(() {});
                                            }

                                            safeSetState(() {});
                                          },
                                          child: Container(
                                            width: 80.0,
                                            height: 80.0,
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.mic,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              size: 32.0,
                                            ),
                                          ),
                                        ).animateOnActionTrigger(
                                            animationsMap[
                                                'containerOnActionTriggerAnimation2']!,
                                            hasBeenTriggered:
                                                hasContainerTriggered2),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    valueOrDefault<String>(
                                      _model.text,
                                      'Tap the mic to record your voice.',
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_model.recording == false)
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  0.0, 9.0, 16.0, 0.0),
                              child: InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () async {
                                  _model.audio = false;
                                  safeSetState(() {});
                                },
                                child: Icon(
                                  Icons.close_sharp,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
