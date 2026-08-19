import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '/custom_code/actions/web_download_helper.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_pdf_viewer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'p_d_f_view_model.dart';
export 'p_d_f_view_model.dart';

/// Create a component a pop up to show the pdf viewer and also allow them to
/// download the pdf
///
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PDFViewWidget extends StatefulWidget {
  const PDFViewWidget({
    super.key,
    required this.url,
    this.fileName,
  });

  final String? url;
  final String? fileName;

  @override
  State<PDFViewWidget> createState() => _PDFViewWidgetState();
}

class _PDFViewWidgetState extends State<PDFViewWidget> {
  late PDFViewModel _model;
  String? _textContent;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PDFViewModel());
    _loadContent();
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  Future<void> _loadContent() async {
    if (widget.url == null || widget.url!.isEmpty) return;

    final type = _getFileType();
    if (type == 'text') {
      try {
        final response = await http.get(Uri.parse(widget.url!));
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _textContent = response.body;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _errorMessage = 'Failed to load text');
        }
      } catch (e) {
        if (mounted) setState(() => _errorMessage = 'Error loading text: $e');
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getFileType() {
    if (widget.url == null) return 'unknown';
    final name = widget.fileName ?? widget.url!;
    final ext = name.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext))
      return 'image';
    if (['txt', 'md', 'json', 'xml', 'csv', 'log', 'dart', 'js', 'html', 'css']
        .contains(ext)) return 'text';
    if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext))
      return 'office';
    if (['pdf'].contains(ext)) return 'pdf';

    return 'unknown';
  }

  String? _tempFilePath;

  /// Downloads a remote file to a temporary directory and returns the local path.
  Future<String?> _downloadToTemp(String url, String fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      // Sanitize filename
      final safeName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final filePath = '${dir.path}/lona_preview_$safeName';
      final file = File(filePath);

      // Skip re-download if already cached
      if (await file.exists() && await file.length() > 0) {
        _tempFilePath = filePath;
        return filePath;
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        _tempFilePath = filePath;
        return filePath;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Download error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    // Clean up temp file
    if (_tempFilePath != null) {
      try {
        File(_tempFilePath!).deleteSync();
      } catch (_) {}
    }
    _model.maybeDispose();
    super.dispose();
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
              color: FlutterFlowTheme.of(context)
                  .secondaryBackground
                  .withOpacity(0.9),
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
                          color: FlutterFlowTheme.of(context)
                              .alternate
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context)
                                .alternate
                                .withOpacity(0.5),
                            width: 1.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.0),
                          child: _buildBody(context),
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

  Widget _buildBody(BuildContext context) {
    if (widget.url == null) {
      return Center(
        child: Text(
          'No document selected',
          style: FlutterFlowTheme.of(context).bodyMedium,
        ),
      );
    }

    final type = _getFileType();

    if (type == 'pdf') {
      // On macOS, iOS, and web, use native WebView for hardware-accelerated PDF
      // rendering with smooth scrolling. Falls back to pdfx on Android.
      if (kIsWeb || (!kIsWeb && (Platform.isMacOS || Platform.isIOS))) {
        return Stack(
          children: [
            const Center(
              child: CircularProgressIndicator(),
            ),
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url!)),
              initialSettings: InAppWebViewSettings(
                isInspectable: kDebugMode,
                transparentBackground: false,
                allowsBackForwardNavigationGestures: false,
                disableHorizontalScroll: false,
                disableVerticalScroll: false,
                supportZoom: true,
                builtInZoomControls: true,
              ),
            ),
          ],
        );
      }
      return FlutterFlowPdfViewer(
        networkPath: widget.url!,
        width: double.infinity,
        height: double.infinity,
        horizontalScroll: false,
      );
    } else if (type == 'image') {
      return Image.network(
        widget.url!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Text('Failed to load image')),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else if (type == 'text') {
      if (_isLoading) return const Center(child: CircularProgressIndicator());
      if (_errorMessage != null) return Center(child: Text(_errorMessage!));
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _textContent ?? '',
          style: GoogleFonts.robotoMono(fontSize: 14),
        ),
      );
    } else if (type == 'office') {
      final encodedUrl = Uri.encodeComponent(widget.url!);
      final googleViewerUrl =
          'https://docs.google.com/gview?embedded=true&url=$encodedUrl';
      final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

      return Stack(
        children: [
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading preview...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(googleViewerUrl)),
            initialSettings: InAppWebViewSettings(
              isInspectable: kDebugMode,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              iframeAllow: "camera; microphone",
              iframeAllowFullscreen: true,
              transparentBackground: true,
              supportZoom: true,
              builtInZoomControls: true,
            ),
            onLoadStop: (controller, url) async {
              // Inject JS to detect Google Docs Viewer errors and show a helpful overlay
              await controller.evaluateJavascript(source: '''
                (function() {
                  var checkCount = 0;
                  var overlayShown = false;
                  function checkForError() {
                    if (overlayShown || checkCount > 60) return;
                    checkCount++;
                    var body = document.body ? document.body.innerText : '';
                    if (body.indexOf('无法预览') !== -1 || 
                        body.indexOf('sorry') !== -1 || 
                        body.indexOf('Unable to') !== -1 ||
                        body.indexOf('problem loading') !== -1 ||
                        body.indexOf('加载此页面时出现问题') !== -1) {
                      overlayShown = true;
                      var overlay = document.createElement('div');
                      overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(255,255,255,0.95);display:flex;align-items:center;justify-content:center;z-index:99999;flex-direction:column;font-family:-apple-system,sans-serif;';
                      overlay.innerHTML = '<div style="text-align:center;padding:24px;">' +
                        '<div style="font-size:48px;margin-bottom:16px;">📄</div>' +
                        '<div style="font-size:16px;font-weight:600;color:#111;margin-bottom:8px;">This page cannot be previewed</div>' +
                        '<div style="font-size:13px;color:#6B7280;line-height:1.5;">Use the <b style=\\'color:#2563EB\\'>Open Full Document</b> button<br>at the bottom right to view the complete file.</div>' +
                        '</div>';
                      document.body.appendChild(overlay);
                    }
                  }
                  setInterval(checkForError, 2000);
                  checkForError();
                })();
              ''');
            },
          ),
          // "Open in App" button floating at bottom-right on desktop
          if (isDesktop)
            Positioned(
              bottom: 12,
              right: 12,
              child: StatefulBuilder(
                builder: (context, setLocalState) {
                  bool isOpening = false;
                  return ElevatedButton.icon(
                    onPressed: () async {
                      setLocalState(() => isOpening = true);
                      try {
                        final path = await _downloadToTemp(
                          widget.url!,
                          widget.fileName ?? 'document.docx',
                        );
                        if (path != null) {
                          await Process.run('open', [path]);
                        }
                      } catch (e) {
                        if (kDebugMode) print('Open file error: $e');
                      }
                      if (context.mounted) setLocalState(() => isOpening = false);
                    },
                    icon: isOpening
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.open_in_new, size: 14),
                    label: Text(
                      isOpening ? 'Opening...' : 'Open Full Document',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                    ),
                  );
                },
              ),
            ),
        ],
      );
    } else {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Preview not available for this file type'),
            SizedBox(height: 8),
            Text('Please download to view'),
          ],
        ),
      );
    }
  }

  Widget _buildHeader(BuildContext context) {
    final fileName = widget.fileName ?? 'Document Viewer';
    final fileType = _getFileType().toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.insert_drive_file_rounded,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .override(
                              fontFamily: 'Inter',
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              useGoogleFonts: true,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$fileType Preview',
                        style: FlutterFlowTheme.of(context).labelSmall.override(
                              fontFamily: 'Inter',
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.5,
                              useGoogleFonts: true,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            onPressed: () async {
              Navigator.pop(context);
            },
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
            onPressed: () async {
              Navigator.pop(context);
            },
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
              hoverColor:
                  FlutterFlowTheme.of(context).alternate.withOpacity(0.2),
            ),
          ),
          const SizedBox(width: 16),
          FFButtonWidget(
            onPressed: () async {
              if (widget.url == null || widget.url!.isEmpty) return;

              // Helper to get filename
              String fileName = widget.fileName ?? 'document';
              if (widget.url!.isNotEmpty && fileName == 'document') {
                fileName = widget.url!.split('/').last.split('?').first;
              }
              // Unescape URL encoded characters in filename if any
              fileName = Uri.decodeComponent(fileName);

              await _downloadFile(widget.url!, fileName);
            },
            text: 'Download',
            icon: const Icon(
              Icons.file_download_outlined,
              size: 20.0,
            ),
            options: FFButtonOptions(
              width: 180.0,
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
              borderSide: const BorderSide(
                color: Colors.transparent,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(14.0),
              hoverElevation: 6.0,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessPopup(String message) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 80,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-remove after 2 seconds with fade out
    Future.delayed(const Duration(seconds: 2), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Future<void> _downloadFile(String url, String fileName) async {
    debugPrint('_downloadFile called with URL: $url, fileName: $fileName');

    try {
      // Handle web platform FIRST
      if (kIsWeb) {
        debugPrint('Platform is Web, starting download...');
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('Failed to download file: ${response.statusCode}');
        }
        await downloadFileOnWeb(url, fileName, response.bodyBytes);
        _showSuccessPopup('Downloaded');
        return;
      }

      // macOS - Handle separately
      if (Platform.isMacOS) {
        debugPrint('Platform is macOS, starting download...');
        try {
          // Sanitize filename
          String safeFileName = fileName;
          safeFileName =
              safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
          safeFileName = safeFileName.split('/').last.split('\\').last;

          // Extract the actual file extension for the save dialog
          final fileExt = safeFileName.contains('.')
              ? safeFileName.split('.').last.toLowerCase()
              : '';

          // Download the file first
          debugPrint('Downloading from URL: $url');
          final response = await http.get(Uri.parse(url));
          debugPrint('Download response status: ${response.statusCode}');

          if (response.statusCode != 200) {
            throw Exception('Failed to download file: ${response.statusCode}');
          }

          // Use file_picker's saveFile to handle macOS sandboxing properly
          // Use the actual file extension, not hardcoded 'pdf'
          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Save File',
            fileName: safeFileName,
            type: fileExt.isNotEmpty ? FileType.custom : FileType.any,
            allowedExtensions: fileExt.isNotEmpty ? [fileExt] : null,
          );

          if (result != null && result.isNotEmpty) {
            try {
              final file = File(result);
              await file.writeAsBytes(response.bodyBytes);
              debugPrint('File saved successfully to: $result');

              // Reveal in Finder
              try {
                await Process.run('open', ['-R', result]);
                _showSuccessPopup('Downloaded');
              } catch (e) {
                debugPrint('Error revealing file in Finder: $e');
                _showSuccessPopup('File saved');
              }
            } catch (e) {
              debugPrint('Error saving file: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error saving file: $e'),
                    backgroundColor: Colors.red),
              );
            }
          }
        } catch (e) {
          debugPrint('Error during download: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error downloading file: $e'),
                backgroundColor: Colors.red),
          );
        }
        return;
      }

      // For mobile platforms (Android/iOS)
      // iOS: Use FilePicker to save to Files app
      if (Platform.isIOS) {
        try {
          // Sanitize filename
          String safeFileName = fileName;
          safeFileName =
              safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
          safeFileName = safeFileName.split('/').last.split('\\').last;

          // Extract the actual file extension for the save dialog
          final fileExt = safeFileName.contains('.')
              ? safeFileName.split('.').last.toLowerCase()
              : '';

          // Download the file first
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception('Failed to download file: ${response.statusCode}');
          }

          // Use FilePicker to save file (this makes it accessible in Files app)
          // On iOS/Android, bytes parameter is required
          // Use the actual file extension, not hardcoded 'pdf'
          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Save File',
            fileName: safeFileName,
            type: fileExt.isNotEmpty ? FileType.custom : FileType.any,
            allowedExtensions: fileExt.isNotEmpty ? [fileExt] : null,
            bytes: response.bodyBytes, // Required on iOS/Android
          );

          if (result != null && result.isNotEmpty) {
            debugPrint('File saved successfully to: $result');
            _showSuccessPopup('Downloaded');
          } else {
            debugPrint('User cancelled file save dialog');
          }
        } catch (e) {
          debugPrint('Error during download: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error downloading file: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // For Android
      if (Platform.isAndroid) {
        // Request storage permission
        try {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
            if (!status.isGranted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Storage permission is required to download files'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }
        } catch (e) {
          // Permission handler not available
          // Continue without permission check
        }

        // Download the file
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          // Get the downloads directory
          Directory? directory;
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }

          if (directory != null) {
            // Create unique filename if file already exists
            String finalFileName = fileName;
            int counter = 1;
            while (await File('${directory.path}/$finalFileName').exists()) {
              final extension = fileName.split('.').last;
              final nameWithoutExtension =
                  fileName.replaceAll('.$extension', '');
              finalFileName = '${nameWithoutExtension}_$counter.$extension';
              counter++;
            }

            final file = File('${directory.path}/$finalFileName');
            await file.writeAsBytes(response.bodyBytes);

            _showSuccessPopup('Downloaded');
          }
        } else {
          throw Exception('Failed to download file: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading file: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
