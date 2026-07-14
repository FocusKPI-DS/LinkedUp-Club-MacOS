import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '/custom_code/actions/web_download_helper.dart';

class FlutterFlowExpandedImageView extends StatefulWidget {
  const FlutterFlowExpandedImageView({
    super.key,
    required this.image,
    this.allowRotation = false,
    this.useHeroAnimation = true,
    this.tag,
    this.imageUrl,
    this.showDownload = true, // Default to true for backward compatibility
    this.imageUrls,
    this.initialIndex = 0,
  });

  final Widget image;
  final bool allowRotation;
  final bool useHeroAnimation;
  final Object? tag;
  final String? imageUrl;
  final bool showDownload; // Control whether to show download button

  /// Optional full gallery (e.g. photo stack). When 2+ URLs are provided,
  /// left/right arrows navigate between them.
  final List<String>? imageUrls;
  final int initialIndex;

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Opens the image viewer.
  ///
  /// On desktop: a restored (floating) window-sized dialog — not a maximized/
  /// full-route takeover. On mobile/web: a fade full-screen route.
  static Future<void> show(
    BuildContext context, {
    required Widget image,
    bool allowRotation = false,
    bool useHeroAnimation = true,
    Object? tag,
    String? imageUrl,
    bool showDownload = true,
    List<String>? imageUrls,
    int initialIndex = 0,
  }) {
    final viewer = FlutterFlowExpandedImageView(
      image: image,
      allowRotation: allowRotation,
      // Hero into a dialog is unreliable on desktop; keep for fullscreen only.
      useHeroAnimation: useHeroAnimation && !_isDesktop,
      tag: tag,
      imageUrl: imageUrl,
      showDownload: showDownload,
      imageUrls: imageUrls,
      initialIndex: initialIndex,
    );

    if (_isDesktop) {
      final media = MediaQuery.sizeOf(context);
      final width = (media.width * 0.72).clamp(640.0, 1100.0);
      final height = (media.height * 0.78).clamp(480.0, 840.0);
      return showDialog<void>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.55),
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: SizedBox(
              width: width,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: viewer,
                ),
              ),
            ),
          );
        },
      );
    }

    return Navigator.push<void>(
      context,
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => viewer,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FlutterFlowExpandedImageView> createState() =>
      _FlutterFlowExpandedImageViewState();
}

class _FlutterFlowExpandedImageViewState
    extends State<FlutterFlowExpandedImageView> {
  bool _isDownloading = false;
  late int _currentIndex;
  PageController? _galleryController;

  bool get _isGallery {
    final urls = widget.imageUrls;
    return urls != null && urls.length > 1;
  }

  List<String> get _galleryUrls =>
      (widget.imageUrls ?? const <String>[])
          .where((u) => u.trim().isNotEmpty)
          .toList();

  String? get _activeImageUrl {
    if (_isGallery) {
      final urls = _galleryUrls;
      if (_currentIndex >= 0 && _currentIndex < urls.length) {
        return urls[_currentIndex];
      }
    }
    return widget.imageUrl;
  }

  @override
  void initState() {
    super.initState();
    final urls = _galleryUrls;
    _currentIndex = widget.initialIndex.clamp(
      0,
      urls.isEmpty ? 0 : urls.length - 1,
    );
    if (_isGallery) {
      _galleryController = PageController(initialPage: _currentIndex);
    }
  }

  @override
  void dispose() {
    _galleryController?.dispose();
    super.dispose();
  }

  void _goToRelative(int delta) {
    if (!_isGallery || _galleryController == null) return;
    final next = (_currentIndex + delta).clamp(0, _galleryUrls.length - 1);
    if (next == _currentIndex) return;
    _galleryController!.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _navArrow({
    required IconData icon,
    required VoidCallback? onPressed,
    required Alignment alignment,
  }) {
    if (onPressed == null) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.35)),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }

  // Show green success popup notification
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

    // Remove after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      overlayEntry.remove();
    });
  }

  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        String fileName = segments.last;
        // Remove Firebase storage tokens and parameters
        if (fileName.contains('?')) {
          fileName = fileName.split('?').first;
        }
        // Decode URL encoding
        fileName = Uri.decodeComponent(fileName);
        if (fileName.isNotEmpty) {
          return fileName;
        }
      }
    } catch (e) {
      // Fallback filename
    }
    // Generate filename based on timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'image_$timestamp.jpg';
  }

  Future<void> _downloadImage() async {
    final url = _activeImageUrl;
    if (url == null || url.isEmpty) {
      return;
    }

    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final fileName = _getFileNameFromUrl(url);

      // macOS - Handle separately
      if (Platform.isMacOS) {
        try {
          // Sanitize filename
          String safeFileName = fileName;
          safeFileName =
              safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
          safeFileName = safeFileName.split('/').last.split('\\').last;
          if (!safeFileName.contains('.')) {
            safeFileName = '${safeFileName}.jpg';
          }

          // Download the file first
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception('Download failed: ${response.statusCode}');
          }

          // Use file_picker's saveFile to handle macOS sandboxing properly
          final fileExtension = safeFileName.contains('.')
              ? safeFileName.split('.').last.toLowerCase()
              : 'jpg';

          // Determine file type based on extension
          FileType fileType = FileType.any;
          List<String>? allowedExtensions;

          if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg']
              .contains(fileExtension)) {
            fileType = FileType.custom;
            allowedExtensions = [fileExtension];
          }

          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Image',
            fileName: safeFileName,
            type: fileType,
            allowedExtensions: allowedExtensions,
          );

          if (result != null && result.isNotEmpty) {
            try {
              final file = File(result);
              await file.writeAsBytes(response.bodyBytes);
              // Reveal in Finder
              try {
                await Process.run('open', ['-R', result]);
              } catch (e) {
                // Silent fail
              }
            } catch (e) {
              debugPrint('Error saving file: $e');
            }
          }
        } catch (e) {
          debugPrint('Download failed: $e');
        }
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      // Web platform
      if (kIsWeb) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) {
            throw Exception('Download failed: ${response.statusCode}');
          }

          // Sanitize filename for web
          String safeFileName = fileName;
          safeFileName =
              safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
          safeFileName = safeFileName.split('/').last.split('\\').last;
          if (!safeFileName.contains('.')) {
            final contentType =
                response.headers['content-type'] ?? 'image/jpeg';
            String extension = 'jpg';
            if (contentType.contains('png')) {
              extension = 'png';
            } else if (contentType.contains('gif')) {
              extension = 'gif';
            } else if (contentType.contains('webp')) {
              extension = 'webp';
            }
            safeFileName = '${safeFileName}.$extension';
          }

          await downloadFileOnWeb(url, safeFileName, response.bodyBytes);
        } catch (e) {
          debugPrint('Download failed: $e');
        }
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      // Other platforms (Linux, Windows, Mobile)
      if (Platform.isLinux || Platform.isWindows) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          Directory? directory;
          if (Platform.isLinux) {
            final homeDir = Platform.environment['HOME'];
            if (homeDir != null) {
              directory = Directory('$homeDir/Downloads');
            }
          } else if (Platform.isWindows) {
            final userProfile = Platform.environment['USERPROFILE'];
            if (userProfile != null) {
              directory = Directory('$userProfile/Downloads');
            }
          }

          if (directory != null && await directory.exists()) {
            String safeFileName = fileName;
            safeFileName =
                safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
            safeFileName = safeFileName.split('/').last.split('\\').last;
            if (!safeFileName.contains('.')) {
              safeFileName = '${safeFileName}.jpg';
            }
            final file = File('${directory.path}/$safeFileName');
            await file.writeAsBytes(response.bodyBytes);
          } else {
            debugPrint('Cannot find download directory');
          }
        } else {
          debugPrint('Download failed: ${response.statusCode}');
        }
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      // iOS and Android platforms - use image_gallery_saver_plus
      if (Platform.isIOS || Platform.isAndroid) {
        try {
          debugPrint(
              '=== Starting download for ${Platform.isIOS ? "iOS" : "Android"} ===');
          debugPrint('Image URL: $url');
          debugPrint('File name: $fileName');

          // Request permissions
          PermissionStatus permission;
          if (Platform.isAndroid) {
            // For Android 13+ (API 33+), use photos permission
            final photosStatus = await Permission.photos.status;
            debugPrint('Android photos permission status: $photosStatus');
            if (photosStatus.isDenied) {
              permission = await Permission.photos.request();
              debugPrint('Requested photos permission: $permission');
              if (permission.isDenied || permission.isPermanentlyDenied) {
                setState(() {
                  _isDownloading = false;
                });
                return;
              }
            }
            // Also check storage permission for older Android versions
            final storageStatus = await Permission.storage.status;
            debugPrint('Android storage permission status: $storageStatus');
            if (storageStatus.isDenied) {
              permission = await Permission.storage.request();
              debugPrint('Requested storage permission: $permission');
              if (permission.isDenied || permission.isPermanentlyDenied) {
                setState(() {
                  _isDownloading = false;
                });
                return;
              }
            }
          } else if (Platform.isIOS) {
            // iOS requires photos permission - check current status first
            final photosStatus = await Permission.photos.status;
            debugPrint('iOS photos permission status: $photosStatus');

            if (!photosStatus.isGranted && !photosStatus.isLimited) {
              // Request permission if not granted or limited
              permission = await Permission.photos.request();
              debugPrint('Requested photos permission: $permission');

              if (permission.isDenied || permission.isPermanentlyDenied) {
                setState(() {
                  _isDownloading = false;
                });
                return;
              }
            }
            debugPrint('iOS permission check passed, proceeding with download');
          }

          // Download the image
          debugPrint('Downloading image from URL...');
          final response = await http.get(Uri.parse(url));
          debugPrint('Download response status: ${response.statusCode}');

          if (response.statusCode != 200) {
            throw Exception('Download failed: HTTP ${response.statusCode}');
          }

          debugPrint(
              'Image downloaded successfully, size: ${response.bodyBytes.length} bytes');

          // Get file name
          String safeFileName = fileName;
          safeFileName =
              safeFileName.replaceAll('/', '_').replaceAll('\\', '_');
          safeFileName = safeFileName.split('/').last.split('\\').last;

          // Remove extension if present, we'll let the saver handle it
          if (safeFileName.contains('.')) {
            safeFileName = safeFileName.split('.').first;
          }

          // If no filename, generate one
          if (safeFileName.isEmpty) {
            safeFileName = 'image_${DateTime.now().millisecondsSinceEpoch}';
          }

          debugPrint('Saving image with name: $safeFileName');

          // Save to gallery using image_gallery_saver_plus
          final result = await ImageGallerySaverPlus.saveImage(
            response.bodyBytes,
            quality: 100,
            name: safeFileName,
            isReturnImagePathOfIOS: false,
          );

          debugPrint('Save result: $result');

          if (result['isSuccess'] == true) {
            final filePath = result['filePath'];
            debugPrint('Image saved successfully to: $filePath');
            // Show green success popup
            if (mounted) {
              _showSuccessPopup('Downloaded');
            }
          } else {
            final errorMsg = result['errorMessage'] ?? result.toString();
            debugPrint('Save failed: $errorMsg');
          }
        } catch (e, stackTrace) {
          debugPrint('Download error: $e');
          debugPrint('Stack trace: $stackTrace');
        }
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      debugPrint('Unsupported platform');
    } catch (e) {
      debugPrint('Download failed: $e');
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Widget _buildViewer() {
    if (_isGallery) {
      final urls = _galleryUrls;
      return PhotoViewGallery.builder(
        pageController: _galleryController,
        itemCount: urls.length,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        builder: (context, index) {
          final url = urls[index];
          final useHero = widget.useHeroAnimation &&
              widget.tag != null &&
              index == widget.initialIndex;
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.5,
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes:
                useHero ? PhotoViewHeroAttributes(tag: widget.tag!) : null,
            onScaleEnd: (context, details, value) {
              if (value.scale != null && value.scale! < 0.3) {
                Navigator.pop(context);
              }
            },
          );
        },
      );
    }

    return PhotoView.customChild(
      minScale: 1.0,
      maxScale: 3.0,
      enableRotation: widget.allowRotation,
      heroAttributes: widget.useHeroAnimation && widget.tag != null
          ? PhotoViewHeroAttributes(tag: widget.tag!)
          : null,
      onScaleEnd: (context, details, value) {
        if (value.scale! < 0.3) {
          Navigator.pop(context);
        }
      },
      child: widget.image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPrev = _isGallery && _currentIndex > 0;
    final canNext = _isGallery && _currentIndex < _galleryUrls.length - 1;
    final showDownload = widget.showDownload &&
        (_activeImageUrl != null && _activeImageUrl!.isNotEmpty);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _goToRelative(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _goToRelative(1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _buildViewer()),
              if (_isGallery) ...[
                _navArrow(
                  icon: Icons.chevron_left_rounded,
                  onPressed: canPrev ? () => _goToRelative(-1) : null,
                  alignment: Alignment.centerLeft,
                ),
                _navArrow(
                  icon: Icons.chevron_right_rounded,
                  onPressed: canNext ? () => _goToRelative(1) : null,
                  alignment: Alignment.centerRight,
                ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_galleryUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Positioned(
                top: 8.0,
                left: 8.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    color: Colors.black,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 24,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              if (showDownload)
                Positioned(
                  top: 8.0,
                  right: 8.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      color: Colors.black,
                      onPressed: _isDownloading ? null : _downloadImage,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              Icons.download,
                              size: 24,
                              color: Colors.black,
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
