import 'dart:typed_data';
import 'dart:ui';
import 'package:docx_viewer/docx_viewer.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_widgets.dart';

/// Same-style preview dialog for DOC/DOCX as PDF viewer. Shows file name in header and Download.
/// Loads the file from [url] as bytes so DocxView works reliably on all platforms (macOS, web, etc.).
class DocumentPreviewWidget extends StatefulWidget {
  const DocumentPreviewWidget({
    super.key,
    required this.url,
    this.fileName,
    required this.onDownload,
  });

  final String url;
  final String? fileName;
  final VoidCallback onDownload;

  @override
  State<DocumentPreviewWidget> createState() => _DocumentPreviewWidgetState();
}

class _DocumentPreviewWidgetState extends State<DocumentPreviewWidget> {
  Uint8List? _bytes;
  String? _error;
  bool _loading = true;

  String get _displayFileName {
    if (widget.fileName != null && widget.fileName!.trim().isNotEmpty) {
      return widget.fileName!.trim();
    }
    String name = widget.url.split('/').last.split('?').first;
    name = Uri.decodeComponent(name);
    return name.isEmpty ? 'document' : name;
  }

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _loading = true;
      _error = null;
      _bytes = null;
    });
    try {
      final uri = Uri.parse(widget.url);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timed out'),
      );
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Failed to load document (${response.statusCode})';
        });
        return;
      }
      setState(() {
        _bytes = response.bodyBytes;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: MediaQuery.sizeOf(context).width > 900
                ? 900.0
                : MediaQuery.sizeOf(context).width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 40.0,
                  color: Colors.black.withOpacity(0.4),
                  offset: const Offset(0.0, 20.0),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).alternate.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate.withOpacity(0.5),
                            width: 1.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.0),
                          child: _buildContent(),
                        ),
                      ),
                    ),
                  ),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  FlutterFlowTheme.of(context).primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading document…',
                style: FlutterFlowTheme.of(context).bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: FlutterFlowTheme.of(context).error,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load preview',
                style: FlutterFlowTheme.of(context).bodyLarge.override(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  useGoogleFonts: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                  fontFamily: 'Inter',
                  color: FlutterFlowTheme.of(context).secondaryText,
                  useGoogleFonts: true,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _loadDocument,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_bytes != null && _bytes!.isNotEmpty) {
      return DocxView(
        bytes: _bytes,
        fontSize: 16,
        onError: (e) {
          debugPrint('DocxView error: $e');
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description,
                  color: FlutterFlowTheme.of(context).primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayFileName,
                    style: FlutterFlowTheme.of(context).headlineMedium.override(
                          fontFamily: 'Inter',
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          useGoogleFonts: true,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Document Preview',
                    style: FlutterFlowTheme.of(context).labelSmall.override(
                          fontFamily: 'Inter',
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.5,
                          useGoogleFonts: true,
                        ),
                  ),
                ],
              ),
            ],
          ),
          FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 22.0,
            borderWidth: 1.0,
            buttonSize: 44.0,
            fillColor: FlutterFlowTheme.of(context).alternate.withOpacity(0.3),
            icon: Icon(
              Icons.close_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 22.0,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FFButtonWidget(
            onPressed: () => Navigator.pop(context),
            text: 'Cancel',
            options: FFButtonOptions(
              width: 110.0,
              height: 48.0,
              padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
              color: Colors.transparent,
              textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    useGoogleFonts: true,
                  ),
              elevation: 0.0,
              borderSide: BorderSide(
                color: FlutterFlowTheme.of(context).alternate,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(14.0),
              hoverColor: FlutterFlowTheme.of(context).alternate.withOpacity(0.2),
            ),
          ),
          const SizedBox(width: 16),
          FFButtonWidget(
            onPressed: () {
              Navigator.pop(context);
              widget.onDownload();
            },
            text: 'Download',
            icon: const Icon(Icons.file_download_outlined, size: 20.0),
            options: FFButtonOptions(
              width: 160.0,
              height: 48.0,
              padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
              color: FlutterFlowTheme.of(context).primary,
              textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    useGoogleFonts: true,
                  ),
              elevation: 4.0,
              borderSide: const BorderSide(color: Colors.transparent, width: 1.0),
              borderRadius: BorderRadius.circular(14.0),
              hoverElevation: 6.0,
            ),
          ),
        ],
      ),
    );
  }
}
