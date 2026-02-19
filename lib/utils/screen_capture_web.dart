import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

/// Web-only screen capture utilities using browser getDisplayMedia API.
class ScreenCaptureWeb {
  static html.MediaStream? _activeStream;
  static html.MediaRecorder? _activeRecorder;
  static List<html.Blob>? _recordedChunks;
  static Completer<Uint8List?>? _recordingCompleter;

  /// Whether a screen recording is currently in progress.
  static bool get isRecording => _activeRecorder != null;

  /// Call navigator.mediaDevices.getDisplayMedia() via JS interop
  /// since dart:html MediaDevices doesn't expose it.
  static Future<html.MediaStream> _getDisplayMedia(Map<String, dynamic> constraints) async {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw Exception('MediaDevices API not available');
    }
    final jsConstraints = js_util.jsify(constraints);
    final jsPromise = js_util.callMethod(mediaDevices, 'getDisplayMedia', [jsConstraints]);
    final result = await js_util.promiseToFuture(jsPromise);
    return result as html.MediaStream;
  }

  /// Capture a single screenshot of the user's screen/window/tab.
  /// Returns PNG bytes or null if user cancelled.
  static Future<Uint8List?> captureScreenshot() async {
    try {
      // Prompt user to share a screen/window/tab
      final stream = await _getDisplayMedia({'video': true});

      // Grab the video track
      final videoTrack = stream.getVideoTracks().first;
      final settings = videoTrack.getSettings();
      final width = (settings['width'] as num?)?.toInt() ?? 1920;
      final height = (settings['height'] as num?)?.toInt() ?? 1080;

      // Create a <video> element to capture a frame
      final video = html.VideoElement()
        ..srcObject = stream
        ..autoplay = true
        ..muted = true
        ..width = width
        ..height = height;

      // Wait for video to be ready
      await video.onLoadedMetadata.first;
      // Small delay to ensure first frame is rendered
      await Future.delayed(const Duration(milliseconds: 300));

      // Draw current frame onto a canvas
      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;
      ctx.drawImage(video, 0, 0);

      // Stop all tracks to release the screen share
      for (final track in stream.getTracks()) {
        track.stop();
      }

      // Convert canvas to PNG blob
      final blob = await canvas.toBlob('image/png');
      if (blob == null) return null;

      // Read blob as bytes
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoadEnd.first;
      final result = reader.result;
      if (result is ByteBuffer) {
        return result.asUint8List();
      }
      return null;
    } catch (e) {
      print('Screenshot capture error: $e');
      return null; // User cancelled or error
    }
  }

  /// Start recording the screen. Returns true if recording started.
  static Future<bool> startScreenRecording() async {
    if (_activeRecorder != null) return false; // Already recording

    try {
      // Prompt user to share a screen/window/tab
      final stream = await _getDisplayMedia({
        'video': true,
        'audio': false,
      });

      _activeStream = stream;
      _recordedChunks = [];
      _recordingCompleter = Completer<Uint8List?>();

      // Create MediaRecorder
      final recorder = html.MediaRecorder(stream, {
        'mimeType': 'video/webm;codecs=vp9',
      });
      _activeRecorder = recorder;

      // Collect data chunks
      recorder.addEventListener('dataavailable', (event) {
        final blobEvent = event as html.BlobEvent;
        if (blobEvent.data != null && blobEvent.data!.size > 0) {
          _recordedChunks!.add(blobEvent.data!);
        }
      });

      // Handle stop
      recorder.addEventListener('stop', (event) async {
        if (_recordedChunks == null || _recordedChunks!.isEmpty) {
          _recordingCompleter?.complete(null);
          _cleanup();
          return;
        }

        // Combine all chunks into a single blob
        final blob = html.Blob(_recordedChunks!, 'video/webm');
        
        // Read blob as bytes
        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
        await reader.onLoadEnd.first;
        final result = reader.result;

        if (result is ByteBuffer) {
          _recordingCompleter?.complete(result.asUint8List());
        } else {
          _recordingCompleter?.complete(null);
        }
        _cleanup();
      });

      // Handle user stopping the share via browser UI
      stream.getTracks().forEach((track) {
        track.addEventListener('ended', (_) {
          if (_activeRecorder != null && _activeRecorder!.state == 'recording') {
            _activeRecorder!.stop();
          }
        });
      });

      // Start recording
      recorder.start(1000); // Collect data every 1 second
      return true;
    } catch (e) {
      print('Screen recording start error: $e');
      _cleanup();
      return false;
    }
  }

  /// Stop the current screen recording. Returns WebM video bytes or null.
  static Future<Uint8List?> stopScreenRecording() async {
    if (_activeRecorder == null) return null;

    try {
      if (_activeRecorder!.state == 'recording') {
        _activeRecorder!.stop();
      }

      // Stop the screen share stream
      _activeStream?.getTracks().forEach((track) => track.stop());

      // Wait for the recording data
      return await _recordingCompleter?.future;
    } catch (e) {
      print('Screen recording stop error: $e');
      _cleanup();
      return null;
    }
  }

  static void _cleanup() {
    _activeRecorder = null;
    _activeStream = null;
    _recordedChunks = null;
    _recordingCompleter = null;
  }
}
