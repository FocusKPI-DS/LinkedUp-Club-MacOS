import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
class PDFViewWidget extends StatefulWidget {
  const PDFViewWidget({
    super.key,
    required this.url,
  });

  final String? url;

  @override
  State<PDFViewWidget> createState() => _PDFViewWidgetState();
}

class _PDFViewWidgetState extends State<PDFViewWidget> {
  late PDFViewModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PDFViewModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
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
                          child: widget.url != null
                              ? FlutterFlowPdfViewer(
                                  networkPath: widget.url!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  horizontalScroll: false,
                                )
                              : Center(
                                  child: Text(
                                    'No document selected',
                                    style: FlutterFlowTheme.of(context).bodyMedium,
                                  ),
                                ),
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
                  Icons.insert_drive_file_rounded,
                  color: FlutterFlowTheme.of(context).primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document Viewer',
                    style: FlutterFlowTheme.of(context).headlineMedium.override(
                          fontFamily: 'Inter',
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          useGoogleFonts: true,
                        ),
                  ),
                  Text(
                    'PDF Preview',
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
              hoverColor: FlutterFlowTheme.of(context).alternate.withOpacity(0.2),
            ),
          ),
          const SizedBox(width: 16),
          FFButtonWidget(
            onPressed: () async {
              if (widget.url == null || widget.url!.isEmpty) return;

              // Force filename to be something sensible if we can't get it from the URL
              String fileName = widget.url!.split('/').last.split('?').first;
              if (fileName.isEmpty) fileName = 'document.pdf';
              if (!fileName.toLowerCase().endsWith('.pdf')) {
                fileName = '$fileName.pdf';
              }
              // Unescape URL encoded characters in filename if any
              fileName = Uri.decodeComponent(fileName);

              await _downloadFile(widget.url!, fileName);
            },
            text: 'Download PDF',
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
          safeFileName = safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
          safeFileName = safeFileName.split('/').last.split('\\').last;

          // Download the file first
          debugPrint('Downloading from URL: $url');
          final response = await http.get(Uri.parse(url));
          debugPrint('Download response status: ${response.statusCode}');

          if (response.statusCode != 200) {
            throw Exception('Failed to download file: ${response.statusCode}');
          }

          // Use file_picker's saveFile to handle macOS sandboxing properly
          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Save File',
            fileName: safeFileName,
            type: FileType.custom,
            allowedExtensions: ['pdf'],
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
                SnackBar(content: Text('Error saving file: $e'), backgroundColor: Colors.red),
              );
            }
          }
        } catch (e) {
          debugPrint('Error during download: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error downloading file: $e'), backgroundColor: Colors.red),
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
          
          // Ensure filename has .pdf extension
          if (!safeFileName.toLowerCase().endsWith('.pdf')) {
            safeFileName = '$safeFileName.pdf';
          }

          // Download the file first
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception('Failed to download file: ${response.statusCode}');
          }

          // Use FilePicker to save file (this makes it accessible in Files app)
          // On iOS/Android, bytes parameter is required
          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Save File',
            fileName: safeFileName,
            type: FileType.custom,
            allowedExtensions: ['pdf'],
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
              final nameWithoutExtension = fileName.replaceAll('.$extension', '');
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
