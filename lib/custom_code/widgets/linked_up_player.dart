// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class LinkedUpPlayer extends StatefulWidget {
  const LinkedUpPlayer({
    super.key,
    this.width,
    this.height,
    required this.audioPath,
    this.isLocal = true, // true = local file, false = Firebase URL
  });

  final double? width;
  final double? height;
  final String audioPath;
  final bool isLocal;

  @override
  State<LinkedUpPlayer> createState() => _LinkedUpPlayerState();
}

class _LinkedUpPlayerState extends State<LinkedUpPlayer> {
  late final PlayerController controller;
  bool isPlaying = false;
  bool isReady = false;
  Duration? totalDuration;
  int currentPosition = 0;

  @override
  void initState() {
    super.initState();
    controller = PlayerController();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      debugPrint('🎧 Initializing player...');

      String finalPath = widget.audioPath;

      if (!widget.isLocal) {
        debugPrint('☁️ audioPath from Firebase: $finalPath');

        // ✅ Check if it's actually a Firebase URL
        if (!finalPath.startsWith('gs://') && !finalPath.startsWith('http')) {
          throw ArgumentError(
              '❌ Expected Firebase URL, got local file path: $finalPath');
        }

        finalPath = await _downloadFromFirebase(finalPath);
        debugPrint('✅ Downloaded file path: $finalPath');
      } else {
        debugPrint('📁 Using local file path directly: $finalPath');
      }

      await controller.preparePlayer(
        path: finalPath,
        shouldExtractWaveform: true,
      );

      totalDuration = Duration(milliseconds: await controller.getDuration());

      controller.onCurrentDurationChanged.listen((ms) {
        if (mounted) setState(() => currentPosition = ms);
      });

      controller.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => isPlaying = state.isPlaying);
      });

      controller.onCompletion.listen((_) async {
        if (!mounted) return;

        await controller.stopPlayer();
        await controller.preparePlayer(
          path: finalPath,
          shouldExtractWaveform: false,
        );
        setState(() {
          isPlaying = false;
          currentPosition = 0;
        });
      });

      setState(() => isReady = true);
    } catch (e) {
      debugPrint('🎧 Player init error: $e');
    }
  }

  Future<String> _downloadFromFirebase(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${ref.name}');
      await ref.writeToFile(file);
      return file.path;
    } catch (e) {
      debugPrint('❌ Firebase download error: $e');
      rethrow;
    }
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: isReady
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () async {
                          if (isPlaying) {
                            await controller.pausePlayer();
                          } else {
                            await controller.startPlayer();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AudioFileWaveforms(
                        playerController: controller,
                        playerWaveStyle: const PlayerWaveStyle(
                          fixedWaveColor: Color(0xFF2563EB),
                          liveWaveColor: Color(0xFF2563EB),
                          showSeekLine: false,
                          scaleFactor: 500,
                          spacing: 6,
                          waveThickness: 2.5,
                        ),
                        size: Size(MediaQuery.of(context).size.width * 0.7, 56),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_formatDuration(Duration(milliseconds: currentPosition))} / ${_formatDuration(totalDuration ?? Duration.zero)}',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Bricolage Grotesque',
                          color: const Color(0xFF2563EB),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB)),
              ),
            ),
    );
  }
}
