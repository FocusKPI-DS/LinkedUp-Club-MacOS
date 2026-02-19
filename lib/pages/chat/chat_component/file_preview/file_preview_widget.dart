import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_pdf_viewer.dart';
import '/flutter_flow/upload_data.dart';
import 'file_preview_model.dart';
export 'file_preview_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';

class FilePreviewWidget extends StatefulWidget {
  const FilePreviewWidget({
    Key? key,
    required this.mediaFile,
    required this.fileName,
    required this.onSend,
  }) : super(key: key);

  final SelectedFile mediaFile;
  final String fileName;
  final Future<void> Function(String caption, SelectedFile mediaFile, String fileName) onSend;

  @override
  State<FilePreviewWidget> createState() => _FilePreviewWidgetState();
}

class _FilePreviewWidgetState extends State<FilePreviewWidget> {
  late FilePreviewModel _model;

  final TextEditingController _captionController = TextEditingController();
  bool _isSending = false;

  bool get _isPdf {
    final ext = widget.fileName.contains('.')
        ? widget.fileName.split('.').last.toLowerCase()
        : '';
    return ext == 'pdf';
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FilePreviewModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await widget.onSend(
        _captionController.text.trim(),
        widget.mediaFile,
        widget.fileName,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error sending file: $e');
      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error sending: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _iconForFile(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.fileName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _isPdf ? _buildPdfPreview() : _buildGenericFilePreview(),
              ),
            ),
            _buildCaptionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: FlutterFlowPdfViewer(
          fileBytes: widget.mediaFile.bytes,
          width: double.infinity,
          height: double.infinity,
          horizontalScroll: false,
        ),
      ),
    );
  }

  Widget _buildGenericFilePreview() {
    final size = widget.mediaFile.bytes.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(
              _iconForFile(widget.fileName),
              size: 56,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.fileName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _formatFileSize(size),
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 10),
                  child: Icon(
                    CupertinoIcons.smiley,
                    size: 24,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                Expanded(
                  child: CupertinoTextField(
                    controller: _captionController,
                    placeholder: 'Add a caption...',
                    placeholderStyle: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 8,
                      top: 12,
                      bottom: 12,
                    ),
                    decoration: const BoxDecoration(color: Colors.transparent),
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 6),
                  child: GestureDetector(
                    onTap: _isSending ? null : _handleSend,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.systemBlue,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                              radius: 8,
                            )
                          : const Icon(
                              CupertinoIcons.arrow_up,
                              size: 18,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
