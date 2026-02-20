import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import 'media_preview_model.dart';
export 'media_preview_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:ui';

class MediaPreviewWidget extends StatefulWidget {
  const MediaPreviewWidget({
    super.key,
    required this.mediaFile,
    required this.mediaType, // 'image' or 'video'
    required this.onSend,
  });

  final SelectedFile mediaFile;
  final String mediaType;
  final Future<void> Function(String caption, SelectedFile mediaFile) onSend;

  @override
  State<MediaPreviewWidget> createState() => _MediaPreviewWidgetState();
}

class _MediaPreviewWidgetState extends State<MediaPreviewWidget> {
  late MediaPreviewModel _model;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  String? _videoError;

  final TextEditingController _captionController = TextEditingController();
  bool _isSending = false;

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MediaPreviewModel());

    if (widget.mediaType == 'video') {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (kIsWeb) {
        // For web, create a blob URL or use bytes
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.dataFromBytes(
            widget.mediaFile.bytes,
            mimeType: 'video/mp4',
          ),
        );
      } else {
        // On desktop/mobile, video player requires a file path, not bytes
        String? filePath = widget.mediaFile.filePath;
        
        // Handle file:// URLs
        if (filePath != null && filePath.startsWith('file://')) {
          filePath = filePath.replaceFirst('file://', '');
        }
        
        File? videoFile;
        
        // Try to use file path if available and file exists
        if (filePath != null && filePath.isNotEmpty) {
          final file = File(filePath);
          if (await file.exists()) {
            videoFile = file;
            debugPrint('✅ Using video file at: $filePath');
          }
        }
        
        // If no valid file path, write bytes to a temporary file
        final videoBytes = widget.mediaFile.bytes;
        if (videoFile == null && videoBytes.isNotEmpty) {
          debugPrint('📝 Writing video bytes to temporary file...');
          try {
            final tempDir = Directory.systemTemp;
            final tempFile = File('${tempDir.path}/video_${DateTime.now().microsecondsSinceEpoch}.mp4');
            await tempFile.writeAsBytes(videoBytes);
            videoFile = tempFile;
            debugPrint('✅ Video bytes written to: ${tempFile.path}');
          } catch (writeError) {
            debugPrint('❌ Error writing video to temp file: $writeError');
            throw Exception('Failed to prepare video file: $writeError');
          }
        }
        
        if (videoFile != null) {
          _videoPlayerController = VideoPlayerController.file(videoFile);
          await _videoPlayerController!.initialize();
        } else {
          throw Exception('No video file available for playback');
        }
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.lightGreen,
        ),
        placeholder: Container(
          color: Colors.black,
        ),
        autoInitialize: true,
      );

      setState(() {
        _isVideoInitialized = true;
        _videoError = null;
      });
    } catch (e) {
      debugPrint('Error initializing video: $e');
      // Show error state
      setState(() {
        _isVideoInitialized = true;
        _videoError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    _captionController.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
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
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error sending media: $e');
      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error sending: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (_) {
          // Context is no longer valid, ignore
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
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
          icon: const Icon(
            Icons.close,
            color: Colors.white,
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Media preview area
            Expanded(
              child: Center(
                child: widget.mediaType == 'image'
                    ? _buildImagePreview()
                    : _buildVideoPreview(),
              ),
            ),
            // Caption input area - same style as chat input
            Container(
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
                        // Emoji Button
                        GestureDetector(
                          onTap: () {
                            // TODO: Add emoji picker if needed
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              bottom: 10,
                            ),
                            child: Icon(
                              CupertinoIcons.smiley,
                              size: 24,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                        // Text Input
                        Expanded(
                          child: CupertinoTextField(
                            controller: _captionController,
                            placeholder: 'Add a caption...',
                            placeholderStyle: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            padding: const EdgeInsets.only(
                              left: 8,
                              right: 8,
                              top: 12,
                              bottom: 12,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                        // Send Button - same style as chat
                        AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: AnimatedScale(
                            scale: 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: 6,
                                bottom: 6,
                              ),
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
        child: kIsWeb
            ? Image.memory(
                widget.mediaFile.bytes,
                fit: BoxFit.contain,
              )
            : widget.mediaFile.filePath != null
                ? Image.file(
                    File(widget.mediaFile.filePath!),
                    fit: BoxFit.contain,
                  )
                : Image.memory(
                    widget.mediaFile.bytes,
                    fit: BoxFit.contain,
                  ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (!_isVideoInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_videoError != null || _videoPlayerController == null || _chewieController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading video',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (_videoError != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _videoError!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
