import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/custom_code/services/fireflies_api_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'meeting_transcripts_panel_model.dart';
export 'meeting_transcripts_panel_model.dart';

/// Standalone Meeting Transcripts panel (Fireflies connect, list, manual input).
/// Used in the desktop header popup and no longer in Group Info.
class MeetingTranscriptsPanelWidget extends StatefulWidget {
  const MeetingTranscriptsPanelWidget({
    super.key,
    required this.chatDoc,
    this.onClose,
    this.showCloseButton = false,
  });

  final ChatsRecord chatDoc;
  final VoidCallback? onClose;
  final bool showCloseButton;

  @override
  State<MeetingTranscriptsPanelWidget> createState() =>
      _MeetingTranscriptsPanelWidgetState();
}

class _MeetingTranscriptsPanelWidgetState
    extends State<MeetingTranscriptsPanelWidget> {
  late MeetingTranscriptsPanelModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MeetingTranscriptsPanelModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.chatDoc.admin == currentUserReference;
    final chatId = widget.chatDoc.reference.id;
    if (chatId.isNotEmpty && !_model.firefliesKeyLoadAttempted) {
      _model.firefliesKeyLoadAttempted = true;
      firefliesGetConnectionStatusViaCloud(chatId).then((connected) {
        if (mounted && _model.firefliesConnected != connected) {
          _model.firefliesConnected = connected;
          setState(() {});
        }
      });
    }
    final hasApiKey = _model.firefliesConnected;

    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/idjU1WbcfM_logos.svg',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Meeting Transcripts',
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            color: Colors.black,
                            fontSize: 16.0,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    _model.firefliesShowManualInput =
                        !_model.firefliesShowManualInput;
                    setState(() {});
                  },
                  child: Text(
                    _model.firefliesShowManualInput
                        ? 'Transcripts'
                        : 'Manual Input?',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          color: const Color(0xFF3B82F6),
                          fontSize: 14.0,
                        ),
                  ),
                ),
                if (widget.showCloseButton && widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isAdmin) ...[
              if (!hasApiKey) ...[
                Text(
                  'Connect your Fireflies account to show meeting transcripts here. Only group admins can connect.',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.inter(),
                        color: const Color(0xFF6B7280),
                        fontSize: 13.0,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _model.firefliesApiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Paste your Fireflies API key',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 10.0),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.0,
                  ),
                ),
                const SizedBox(height: 10),
                FFButtonWidget(
                  onPressed: () async {
                    final key =
                        _model.firefliesApiKeyController?.text.trim() ?? '';
                    if (key.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter your Fireflies API key'),
                          backgroundColor: Color(0xFF6B7280),
                        ),
                      );
                      return;
                    }
                    try {
                      _model.firefliesTranscriptsLoading = true;
                      _model.firefliesError = null;
                      setState(() {});
                      final result = await firefliesConnectViaCloud(
                          widget.chatDoc.reference.id, key);
                      if (result['success'] != true) {
                        final err =
                            result['error'] as String? ?? 'Invalid API key';
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                        return;
                      }
                      _model.firefliesConnected = true;
                      _model.firefliesInitialLoadDone = true;
                      final transcriptsResult =
                          await firefliesGetTranscriptsViaCloud(
                        widget.chatDoc.reference.id,
                        limit: MeetingTranscriptsPanelModel.firefliesPageSize,
                        skip: 0,
                      );
                      _model.firefliesTranscripts =
                          transcriptsResult.transcripts;
                      _model.firefliesHasMore =
                          transcriptsResult.transcripts.length >=
                              MeetingTranscriptsPanelModel.firefliesPageSize;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fireflies connected'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    } finally {
                      _model.firefliesTranscriptsLoading = false;
                      setState(() {});
                    }
                  },
                  text: 'Connect',
                  options: FFButtonOptions(
                    height: 40.0,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        20.0, 0.0, 20.0, 0.0),
                    color: const Color(0xFF3B82F6),
                    textStyle:
                        FlutterFlowTheme.of(context).labelMedium.override(
                              font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600),
                              color: Colors.white,
                              fontSize: 14.0,
                            ),
                    elevation: 0,
                    borderSide: const BorderSide(
                      color: Colors.transparent,
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: const Color(0xFF059669),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connected',
                            style: FlutterFlowTheme.of(context).bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600),
                                  color: const Color(0xFF059669),
                                  fontSize: 14.0,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final res = await firefliesDisconnectViaCloud(
                            widget.chatDoc.reference.id);
                        if (res['success'] == true) {
                          _model.firefliesConnected = false;
                          _model.firefliesTranscripts = [];
                          _model.firefliesHasMore = true;
                          _model.firefliesInitialLoadDone = false;
                          _model.firefliesAutoLoadScheduled = false;
                          _model.firefliesApiKeyController?.clear();
                          _model.firefliesSearchController?.clear();
                          setState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fireflies disconnected'),
                                backgroundColor: Color(0xFF6B7280),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.link_off, size: 18),
                      label: const Text('Disconnect'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ] else if (!hasApiKey) ...[
              Text(
                'Fireflies is not connected for this group. Ask a group admin to connect.',
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(),
                      color: const Color(0xFF6B7280),
                      fontSize: 13.0,
                    ),
              ),
            ],
            if (hasApiKey || _model.firefliesShowManualInput) ...[
              const SizedBox(height: 8),
              if (_model.firefliesShowManualInput)
                _buildManualInput()
              else
                _buildFirefliesContent(chatId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFirefliesContent(String chatId) {
    if (!_model.firefliesInitialLoadDone &&
        !_model.firefliesTranscriptsLoading &&
        !_model.firefliesAutoLoadScheduled &&
        _model.firefliesTranscripts.isEmpty) {
      _model.firefliesAutoLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (!_model.firefliesInitialLoadDone &&
            _model.firefliesTranscripts.isEmpty &&
            _model.firefliesConnected) {
          _model.firefliesTranscriptsLoading = true;
          _model.firefliesError = null;
          setState(() {});
          final result = await firefliesGetTranscriptsViaCloud(
            chatId,
            limit: MeetingTranscriptsPanelModel.firefliesPageSize,
            skip: 0,
          );
          if (!mounted) return;
          _model.firefliesTranscriptsLoading = false;
          _model.firefliesInitialLoadDone = true;
          if (result.hasError) {
            _model.firefliesError = result.errorMessage;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.errorMessage ?? 'Failed to load'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          } else {
            _model.firefliesTranscripts = result.transcripts;
            _model.firefliesHasMore = result.transcripts.length >=
                MeetingTranscriptsPanelModel.firefliesPageSize;
          }
          setState(() {});
        }
      });
    }

    if (_model.firefliesTranscriptsLoading &&
        _model.firefliesTranscripts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          ),
        ),
      );
    }
    if (_model.firefliesInitialLoadDone &&
        _model.firefliesTranscripts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Text(
            'No transcripts yet. Record a meeting with Fireflies to see them here.',
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: const Color(0xFF6B7280),
                  fontSize: 13.0,
                ),
          ),
        ),
      );
    }
    return _buildTranscriptsList(chatId);
  }

  Widget _buildManualInput() {
    if (!_model.manualMeetingTranscriptionInitialized &&
        _model.manualMeetingTranscriptionController != null) {
      _model.manualMeetingTranscriptionInitialized = true;
      _model.manualMeetingTranscriptionController!.text =
          widget.chatDoc.manualMeetingTranscription;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Paste or type meeting notes for this group.',
          style: FlutterFlowTheme.of(context).bodySmall.override(
                font: GoogleFonts.inter(),
                color: const Color(0xFF6B7280),
                fontSize: 13.0,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _model.manualMeetingTranscriptionController,
          maxLines: 6,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter meeting transcription or notes...',
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF9CA3AF),
              fontSize: 14.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 12.0,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.0,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 10),
        FFButtonWidget(
          onPressed: () async {
            final text =
                _model.manualMeetingTranscriptionController?.text ?? '';
            if (text.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter some text to process'),
                    backgroundColor: Color(0xFFF59E0B),
                  ),
                );
              }
              return;
            }
            setState(() => _model.manualTranscriptSaving = true);
            try {
              final result = await manualTranscriptProcessViaCloud(
                widget.chatDoc.reference.id,
                text,
              );
              if (context.mounted) {
                setState(() => _model.manualTranscriptSaving = false);
                final success = result['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Transcript processed: summary and action items saved'
                        : result['error']?.toString() ?? 'Failed to process'),
                    backgroundColor:
                        success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              } else {
                setState(() => _model.manualTranscriptSaving = false);
              }
            } catch (e) {
              if (context.mounted) {
                setState(() => _model.manualTranscriptSaving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save: $e'),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            }
          },
          text: _model.manualTranscriptSaving ? 'Generating…' : 'Generate',
          options: FFButtonOptions(
            height: 40.0,
            padding:
                const EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
            color: const Color(0xFF3B82F6),
            textStyle: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  color: Colors.white,
                  fontSize: 14.0,
                ),
            elevation: 0,
            borderSide:
                const BorderSide(color: Colors.transparent, width: 1.0),
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ],
    );
  }

  List<FirefliesTranscriptItem> _getFilteredTranscripts() {
    final query =
        _model.firefliesSearchController?.text.trim().toLowerCase() ?? '';
    if (query.isEmpty) {
      return _model.firefliesTranscripts
          .cast<FirefliesTranscriptItem>()
          .toList();
    }
    return _model.firefliesTranscripts
        .cast<FirefliesTranscriptItem>()
        .where((t) => t.title.toLowerCase().contains(query))
        .toList();
  }

  Widget _buildTranscriptsList(String chatId) {
    final filtered = _getFilteredTranscripts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _model.firefliesSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search transcripts...',
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFF9CA3AF),
              fontSize: 14.0,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            isDense: true,
          ),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.0,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _model.firefliesSearchController?.text.trim().isEmpty ?? true
                  ? '${_model.firefliesTranscripts.length} transcript(s)'
                  : '${filtered.length} of ${_model.firefliesTranscripts.length}',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(),
                    color: const Color(0xFF6B7280),
                  ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              onPressed: () async {
                _model.firefliesTranscripts = [];
                _model.firefliesHasMore = true;
                _model.firefliesTranscriptsLoading = true;
                setState(() {});
                final result = await firefliesGetTranscriptsViaCloud(
                  chatId,
                  limit: MeetingTranscriptsPanelModel.firefliesPageSize,
                  skip: 0,
                );
                _model.firefliesTranscriptsLoading = false;
                if (!result.hasError) {
                  _model.firefliesTranscripts = result.transcripts;
                  _model.firefliesHasMore = result.transcripts.length >=
                      MeetingTranscriptsPanelModel.firefliesPageSize;
                }
                setState(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filtered.length +
                ((_model.firefliesHasMore || _model.firefliesTranscriptsLoading)
                    ? 1
                    : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
                if (index >= filtered.length) {
                  if (index == filtered.length &&
                      _model.firefliesHasMore &&
                      !_model.firefliesTranscriptsLoading) {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (_model.firefliesTranscriptsLoading ||
                          !_model.firefliesHasMore) return;
                      _model.firefliesTranscriptsLoading = true;
                      setState(() {});
                      final result = await firefliesGetTranscriptsViaCloud(
                        chatId,
                        limit: MeetingTranscriptsPanelModel.firefliesPageSize,
                        skip: _model.firefliesTranscripts.length,
                      );
                      _model.firefliesTranscriptsLoading = false;
                      if (!result.hasError) {
                        for (final t in result.transcripts) {
                          _model.firefliesTranscripts.add(t);
                        }
                        _model.firefliesHasMore = result.transcripts.length >=
                            MeetingTranscriptsPanelModel.firefliesPageSize;
                      }
                      setState(() {});
                    });
                  }
                return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                        ),
                      ),
                    ),
                  );
                }
              final t = filtered[index];
              return Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          size: 20,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 14.0,
                                color: Color(0xFF1A1F36),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (t.date != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                t.date!,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.0,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: _model.firefliesFetchingTranscriptIds.contains(t.id)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF3B82F6)),
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward,
                                size: 20,
                                color: Color(0xFF3B82F6),
                              ),
                        onPressed: _model.firefliesFetchingTranscriptIds.contains(t.id)
                            ? null
                            : () async {
                                setState(() {
                                  _model.firefliesFetchingTranscriptIds.add(t.id);
                                });
                                final result =
                                    await firefliesFetchAndStoreTranscriptViaCloud(
                                        chatId, t.id);
                                if (!context.mounted) return;
                                setState(() {
                                  _model.firefliesFetchingTranscriptIds.remove(t.id);
                                });
                                if (result['success'] == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Transcript summary and action items saved to Fireflies transcripts.',
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result['error']?.toString() ??
                                            'Failed to fetch transcript.',
                                      ),
                                    ),
                                  );
                                }
                                },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

