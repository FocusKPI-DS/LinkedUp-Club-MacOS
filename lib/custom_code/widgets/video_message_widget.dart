import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'dart:io';

class VideoMessageWidget extends StatefulWidget {
  const VideoMessageWidget({
    Key? key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.width = 250.0,
    this.height = 200.0,
    this.isOwnMessage = false,
  }) : super(key: key);

  final String videoUrl;
  final String? thumbnailUrl;
  final double width;
  final double height;
  final bool isOwnMessage;

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      print('🎥 Initializing video with URL: ${widget.videoUrl}');

      // Check if it's a local file or network URL
      if (widget.videoUrl.startsWith('file://') ||
          widget.videoUrl.startsWith('/')) {
        // Local file
        final filePath = widget.videoUrl.replaceFirst('file://', '');
        print('📁 Using local file: $filePath');

        final file = File(filePath);
        if (await file.exists()) {
          _videoPlayerController = VideoPlayerController.file(file);
        } else {
          print('❌ File does not exist: $filePath');
          setState(() {
            _isInitialized = true;
          });
          return;
        }
      } else {
        // Network URL
        print('🌐 Using network URL: ${widget.videoUrl}');
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
      }

      await _videoPlayerController!.initialize();
      print('✅ Video initialized successfully');

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showOptions: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: FlutterFlowTheme.of(context).primary,
          handleColor: FlutterFlowTheme.of(context).primary,
          backgroundColor: FlutterFlowTheme.of(context).secondaryText,
          bufferedColor: FlutterFlowTheme.of(context).secondaryText,
        ),
        placeholder: widget.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  child: Icon(
                    Icons.play_circle_outline,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    size: 50,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  child: Icon(
                    Icons.play_circle_outline,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    size: 50,
                  ),
                ),
              )
            : Container(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                child: Icon(
                  Icons.play_circle_outline,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 50,
                ),
              ),
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('❌ Error initializing video: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: FlutterFlowTheme.of(context).primary,
          ),
        ),
      );
    }

    // Check if video controller is null (failed to initialize)
    if (_videoPlayerController == null || _chewieController == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off,
                color: FlutterFlowTheme.of(context).secondaryText,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'Video Preview',
                style: FlutterFlowTheme.of(context).bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0.0, 2.0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
