import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:ff_commons/flutter_flow/upload_data_class.dart';
import 'package:permission_handler/permission_handler.dart';
import '/auth/firebase_auth/auth_util.dart';

class MacOSCameraCaptureWidget extends StatefulWidget {
  final bool isVideo;
  final Function(SelectedFile) onCapture;

  const MacOSCameraCaptureWidget({
    super.key,
    required this.isVideo,
    required this.onCapture,
  });

  @override
  State<MacOSCameraCaptureWidget> createState() =>
      _MacOSCameraCaptureWidgetState();
}

class _MacOSCameraCaptureWidgetState extends State<MacOSCameraCaptureWidget> {
  final GlobalKey cameraKey = GlobalKey(debugLabel: 'cameraKey');
  CameraMacOSController? macosController;
  bool isInitialized = false;
  bool isRecording = false;
  bool _isVideoMode = false; // Track current mode (photo/video)
  bool _showCamera = false; // Start with camera hidden until permission granted
  int _cameraKeyValue = 0; // Unique key value to force camera recreation
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _isVideoMode = widget.isVideo;
    // Request permission and initialize camera
    _requestPermissionAndInitialize();
  }

  /// Dedicated channel — does NOT conflict with permission_handler plugin.
  static const _cameraChannel =
      MethodChannel('com.focuskpi.linkedup/camera_permission');

  Future<void> _requestPermissionAndInitialize() async {
    debugPrint('🔐 [CameraWidget] Starting camera permission flow...');

    try {
      // ── Step 1: Check current macOS authorization status ──
      // AVAuthorizationStatus: 0=notDetermined, 1=restricted, 2=denied, 3=authorized
      final int status = await _cameraChannel.invokeMethod('checkStatus');
      debugPrint('📷 [CameraWidget] Current AVAuthorizationStatus = $status');

      if (status == 3) {
        // Already authorized → show camera immediately
        debugPrint('✅ [CameraWidget] Already authorized, opening camera');
        _enableCamera();
        return;
      }

      // ── Step 2: ALWAYS call requestAccess ──
      // If status == 0 (notDetermined) → macOS will show the system dialog
      //   ("Lona would like to access the camera")
      // If status == 2 (denied) → returns false immediately (no dialog)
      debugPrint('⏳ [CameraWidget] Calling AVCaptureDevice.requestAccess...');
      final result = await _cameraChannel.invokeMethod('requestAccess');
      debugPrint('📷 [CameraWidget] requestAccess result: $result');

      bool granted = false;
      int newStatus = status;
      if (result is Map) {
        granted = result['granted'] == true;
        newStatus = result['status'] ?? status;
      }

      if (granted) {
        debugPrint('✅ [CameraWidget] Camera access GRANTED by user!');
        _enableCamera();
        return;
      }

      // ── Step 3: Permission denied — guide user to System Settings ──
      debugPrint(
          '❌ [CameraWidget] Camera denied (status=$newStatus). Showing settings dialog...');
      if (mounted) {
        await _showOpenSettingsDialog();
      }
    } catch (e) {
      debugPrint('❌ [CameraWidget] Method channel error: $e');
      debugPrint('   This usually means the native channel is not set up.');
      debugPrint('   Falling back to permission_handler...');

      // Fallback: use permission_handler package
      try {
        final permStatus = await Permission.camera.request();
        if (permStatus.isGranted && mounted) {
          _enableCamera();
        } else if (mounted) {
          await _showOpenSettingsDialog();
        }
      } catch (fallbackError) {
        debugPrint('❌ [CameraWidget] Fallback also failed: $fallbackError');
        if (mounted) {
          _safePopNavigation();
        }
      }
    }
  }

  void _enableCamera() {
    if (!mounted) return;
    // Small delay then enable the camera view
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _showCamera = true;
          _cameraKeyValue = DateTime.now().millisecondsSinceEpoch;
        });
      }
    });
  }

  /// Shows a native-feeling dialog like Slack/WhatsApp when camera is denied.
  /// Gives the user a button to open System Settings > Privacy > Camera directly.
  Future<void> _showOpenSettingsDialog() async {
    if (!mounted) return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.videocam_off, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('Camera Access Required'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Camera access has been denied. To use the camera, you need to enable it in System Settings.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'Steps:\n'
              '1. Click "Open Settings" below\n'
              '2. Find this app in the Camera list\n'
              '3. Toggle the switch ON\n'
              '4. Come back and try again',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      // Open macOS System Settings > Privacy > Camera via dedicated channel
      try {
        await _cameraChannel.invokeMethod('openSettings');
        debugPrint('✅ Opened System Settings for camera');
      } catch (e) {
        debugPrint('⚠️ Failed to open settings via channel: $e');
        // Fallback: try openAppSettings from permission_handler
        try {
          await openAppSettings();
        } catch (_) {}
      }
    }

    // Pop the camera page since permission is not available right now
    _safePopNavigation();
  }

  void _safePopNavigation() {
    if (mounted) {
      try {
        Navigator.of(context).pop();
      } catch (e) {
        debugPrint('⚠️ Could not pop navigation: $e');
      }
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing MacOSCameraCaptureWidget...');

    // Hide camera immediately and change key to force disposal
    _showCamera = false;
    _cameraKeyValue++;

    // Stop recording timer
    _recordingTimer?.cancel();
    _recordingTimer = null;

    // Stop recording if in progress (synchronous cleanup)
    if (isRecording && macosController != null) {
      try {
        // Try to stop recording, but don't await in dispose
        macosController!.stopRecording().catchError((e) {
          debugPrint('Error stopping recording in dispose: $e');
          return null; // Return null on error
        });
      } catch (e) {
        debugPrint('Error stopping recording in dispose: $e');
      }
    }

    // Clear controller reference
    macosController = null;
    isInitialized = false;
    isRecording = false;

    // Force release camera at native level (fire and forget)
    try {
      const platform = MethodChannel('com.focuskpi.linkedup/camera_cleanup');
      platform.invokeMethod('release').catchError((e) {
        debugPrint('⚠️ Could not call native camera release in dispose: $e');
      });
    } catch (e) {
      debugPrint('⚠️ Error setting up native camera release in dispose: $e');
    }

    debugPrint(
        '✅ MacOSCameraCaptureWidget disposed - camera should be released');
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _startRecordingTimer() {
    _recordingDuration = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (mounted) {
      setState(() {
        _recordingDuration = Duration.zero;
      });
    }
  }

  Future<void> _cleanupCamera() async {
    debugPrint('🧹 Starting NUCLEAR camera cleanup...');

    // Stop recording timer first
    _recordingTimer?.cancel();
    _recordingTimer = null;

    // Stop recording if in progress
    if (isRecording && macosController != null) {
      try {
        debugPrint('🛑 Stopping video recording...');
        await macosController!.stopRecording();
        if (mounted) {
          setState(() {
            isRecording = false;
            _recordingDuration = Duration.zero;
          });
        }
      } catch (e) {
        debugPrint('❌ Error stopping recording during cleanup: $e');
      }
    }

    // Clear controller reference first
    macosController = null;
    isInitialized = false;

    // Hide camera view IMMEDIATELY and change key to force complete widget recreation/disposal
    if (mounted) {
      setState(() {
        _showCamera = false;
        _cameraKeyValue =
            DateTime.now().millisecondsSinceEpoch; // Completely new key
      });
    }

    // Wait longer for the camera view to be completely removed
    await Future.delayed(const Duration(milliseconds: 500));

    // Force release camera at native level via method channel
    try {
      const platform = MethodChannel('com.focuskpi.linkedup/camera_cleanup');
      await platform.invokeMethod('release');
      debugPrint('✅ Native camera release called');
    } catch (e) {
      debugPrint('⚠️ Could not call native camera release: $e');
    }

    // NUCLEAR: Try to reset permission state (this will request again next time)
    // Note: We can't actually revoke permission, but requesting again might help reset state
    try {
      // Just log that we're done - permission will be requested fresh next time
      debugPrint('🔄 Permission will be requested fresh on next camera open');
    } catch (e) {
      debugPrint('⚠️ Error in permission reset: $e');
    }

    debugPrint('✅ NUCLEAR camera cleanup complete');
  }

  void _switchMode() {
    if (isRecording) return; // Don't allow switching while recording

    setState(() {
      _isVideoMode = !_isVideoMode;
      isInitialized = false;
      macosController = null;
    });

    // Reinitialize camera with new mode
    // The CameraMacOSView will rebuild with the new mode
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Cleanup camera before allowing pop
        await _cleanupCamera();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              // Cleanup camera before closing
              await _cleanupCamera();
              // Wait a bit more to ensure native camera is fully released
              await Future.delayed(const Duration(milliseconds: 200));
              // Navigate back (dispose will be called automatically)
              if (mounted && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            _isVideoMode ? 'Record Video' : 'Take Photo',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Stack(
          children: [
            // Camera preview - only show if _showCamera is true and permission granted
            if (_showCamera)
              Center(
                child: CameraMacOSView(
                  key: ValueKey(
                      'camera_${_isVideoMode}_$_cameraKeyValue'), // EXTREMELY unique key forces complete recreation
                  fit: BoxFit.contain,
                  cameraMode: _isVideoMode
                      ? CameraMacOSMode.video
                      : CameraMacOSMode.photo,
                  onCameraInizialized: (CameraMacOSController controller) {
                    if (mounted && _showCamera) {
                      setState(() {
                        macosController = controller;
                        isInitialized = true;
                      });
                    }
                  },
                ),
              )
            else
              // Show loading while requesting permission
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            // Recording timer (shown only when recording)
            if (isRecording)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.8),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_recordingDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Controls overlay
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode toggle button (WhatsApp style)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Photo mode button
                      GestureDetector(
                        onTap: _isVideoMode ? _switchMode : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: !_isVideoMode
                                ? Colors.white.withOpacity(0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_camera,
                                color: !_isVideoMode
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.6),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Photo',
                                style: TextStyle(
                                  color: !_isVideoMode
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: !_isVideoMode
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Video mode button
                      GestureDetector(
                        onTap: !_isVideoMode ? _switchMode : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _isVideoMode
                                ? Colors.white.withOpacity(0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.videocam,
                                color: _isVideoMode
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.6),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Video',
                                style: TextStyle(
                                  color: _isVideoMode
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: _isVideoMode
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Capture button
                  if (_isVideoMode) ...[
                    // Record/Stop button for video
                    GestureDetector(
                      onTap: isInitialized ? _handleVideoCapture : null,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRecording ? Colors.red : Colors.white,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: isRecording
                              ? const Icon(Icons.stop,
                                  color: Colors.white, size: 30)
                              : const Icon(Icons.fiber_manual_record,
                                  color: Colors.red, size: 30),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Capture button for photo
                    GestureDetector(
                      onTap: isInitialized ? _handlePhotoCapture : null,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: const Center(
                          child: Icon(Icons.camera_alt,
                              color: Colors.black, size: 30),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Could not show snackbar: $e');
    }
  }

  Future<void> _handlePhotoCapture() async {
    if (macosController == null || !isInitialized) return;

    try {
      final cameraFile = await macosController!.takePicture();
      if (cameraFile != null) {
        Uint8List? bytes;
        String? filePath;

        // CameraMacOSFile has 'url' and 'bytes' properties
        if (cameraFile.bytes != null) {
          // Use bytes directly if available
          bytes = cameraFile.bytes;
        } else if (cameraFile.url != null) {
          // Convert file:// URL to file path and read bytes
          String urlString = cameraFile.url!;
          if (urlString.startsWith('file://')) {
            filePath = urlString.replaceFirst('file://', '');
          } else {
            filePath = urlString;
          }
          final file = File(filePath);
          if (await file.exists()) {
            bytes = await file.readAsBytes();
          }
        }

        if (bytes != null) {
          // Generate storage path with user ID (required by Firebase Storage rules)
          final userId =
              currentUserUid.isNotEmpty ? currentUserUid : 'anonymous';
          final timestamp = DateTime.now().microsecondsSinceEpoch;
          final storagePath = 'users/$userId/uploads/$timestamp.jpg';

          final selectedFile = SelectedFile(
            storagePath: storagePath,
            filePath: filePath,
            bytes: bytes,
          );

          // Call the callback - it will handle navigation
          if (mounted) {
            widget.onCapture(selectedFile);
          }
        } else {
          throw Exception('Failed to get photo data');
        }
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      _showErrorSnackbar('Error capturing photo: $e');
    }
  }

  Future<void> _handleVideoCapture() async {
    if (macosController == null || !isInitialized) return;

    try {
      if (!isRecording) {
        // Start recording
        final recordingStarted = await macosController!.recordVideo();
        if (recordingStarted == true) {
          setState(() {
            isRecording = true;
          });
          _startRecordingTimer(); // Start the timer
        } else {
          throw Exception('Failed to start video recording');
        }
      } else {
        // Stop recording
        _stopRecordingTimer(); // Stop the timer first
        final cameraFile = await macosController!.stopRecording();
        setState(() {
          isRecording = false;
        });

        if (cameraFile != null) {
          Uint8List? bytes;
          String? filePath;

          // CameraMacOSFile has 'url' and 'bytes' properties
          if (cameraFile.bytes != null && cameraFile.bytes!.isNotEmpty) {
            // Use bytes directly if available
            bytes = cameraFile.bytes;
            debugPrint(
                '✅ Using video bytes directly (${bytes?.length ?? 0} bytes)');
          } else if (cameraFile.url != null && cameraFile.url!.isNotEmpty) {
            // Convert file:// URL to file path and read bytes
            String urlString = cameraFile.url!;
            if (urlString.startsWith('file://')) {
              filePath = urlString.replaceFirst('file://', '');
            } else {
              filePath = urlString;
            }

            debugPrint('📁 Video file path: $filePath');
            final file = File(filePath);

            // Wait a bit for the file to be fully written (sometimes AVAssetWriter takes time)
            bool fileExists = await file.exists();
            int retries = 0;
            while (!fileExists && retries < 5) {
              await Future.delayed(const Duration(milliseconds: 200));
              fileExists = await file.exists();
              retries++;
            }

            if (fileExists) {
              try {
                bytes = await file.readAsBytes();
                debugPrint('✅ Read video file (${bytes.length} bytes)');
              } catch (readError) {
                debugPrint('❌ Error reading video file: $readError');
                throw Exception('Failed to read video file: $readError');
              }
            } else {
              debugPrint('❌ Video file does not exist at: $filePath');
              throw Exception(
                  'Video file was not saved. Please try recording again.');
            }
          } else {
            debugPrint('❌ CameraMacOSFile has no bytes or URL');
            throw Exception('No video data available from camera');
          }

          if (bytes != null && bytes.isNotEmpty) {
            // Generate storage path with user ID (required by Firebase Storage rules)
            final userId =
                currentUserUid.isNotEmpty ? currentUserUid : 'anonymous';
            final timestamp = DateTime.now().microsecondsSinceEpoch;
            final storagePath = 'users/$userId/uploads/$timestamp.mp4';

            final selectedFile = SelectedFile(
              storagePath: storagePath,
              filePath: filePath,
              bytes: bytes,
            );

            // Call the callback - it will handle navigation
            if (mounted) {
              widget.onCapture(selectedFile);
            }
          } else {
            throw Exception('Video data is empty');
          }
        } else {
          throw Exception(
              'No video file returned from camera. The recording may have failed.');
        }
      }
    } catch (e) {
      debugPrint('Error capturing video: $e');
      _showErrorSnackbar('Error capturing video: $e');
      if (mounted) {
        setState(() {
          isRecording = false;
        });
        _stopRecordingTimer(); // Stop timer on error
      }
    }
  }
}
