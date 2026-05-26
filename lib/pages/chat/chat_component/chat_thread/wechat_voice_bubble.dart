import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:assets_audio_player/assets_audio_player.dart';
import '/app_state.dart';

/// A compact voice message widget matching Lona's blue-white UI theme.
///
/// No extra background — renders wave bars + duration text inline.
/// Width scales with audio duration. Tap to play/pause.
class WeChatVoiceBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final int? durationSeconds;

  const WeChatVoiceBubble({
    super.key,
    required this.audioUrl,
    this.isMe = true,
    this.durationSeconds,
  });

  @override
  State<WeChatVoiceBubble> createState() => _WeChatVoiceBubbleState();
}

class _WeChatVoiceBubbleState extends State<WeChatVoiceBubble>
    with TickerProviderStateMixin {
  late final AssetsAudioPlayer _player;
  bool _isPlaying = false;
  Duration _totalDuration = Duration.zero;
  late AnimationController _waveCtrl;
  bool _isWebmOnNative = false; // True if .webm on iOS/macOS (unsupported)

  /// Check if the audio URL is a .webm file that can't be played on native iOS/macOS
  bool get _isUnsupportedFormat {
    if (kIsWeb) return false; // Web can play .webm natively
    final url = widget.audioUrl.toLowerCase();
    return url.contains('.webm') && (Platform.isIOS || Platform.isMacOS);
  }

  @override
  void initState() {
    super.initState();
    _isWebmOnNative = _isUnsupportedFormat;

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _player = AssetsAudioPlayer.newPlayer();

    _player.isPlaying.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
      if (playing) {
        _waveCtrl.repeat();
      } else {
        _waveCtrl.stop();
        _waveCtrl.reset();
      }
    });

    _player.current.listen((c) {
      if (c != null && mounted) {
        setState(() => _totalDuration = c.audio.duration);
      }
    });

    // Eagerly open audio (without autoStart) to get the duration
    // Skip .webm files on iOS/macOS — AVPlayer can't decode them and will hang
    if (widget.audioUrl.isNotEmpty && !_isWebmOnNative) {
      _player.open(
        Audio.network(widget.audioUrl),
        autoStart: false,
        showNotification: false,
      ).catchError((e) {
        debugPrint('⚠️ VoiceBubble: failed to load audio: $e');
      });
    }
  }

  @override
  void didUpdateWidget(WeChatVoiceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the audioUrl changed (e.g. Cloud Function transcoded .webm → .m4a),
    // re-check format and try to load the new URL
    if (oldWidget.audioUrl != widget.audioUrl) {
      final wasUnsupported = _isWebmOnNative;
      _isWebmOnNative = _isUnsupportedFormat;
      
      if (wasUnsupported && !_isWebmOnNative && widget.audioUrl.isNotEmpty) {
        // URL changed from .webm to .m4a — now safe to load
        _player.open(
          Audio.network(widget.audioUrl),
          autoStart: false,
          showNotification: false,
        ).catchError((e) {
          debugPrint('⚠️ VoiceBubble: failed to load transcoded audio: $e');
        });
      }
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    // Don't try to play unsupported formats — will hang AVPlayer
    if (_isWebmOnNative) {
      debugPrint('⚠️ VoiceBubble: cannot play .webm on iOS/macOS, waiting for transcoding...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Converting voice format, please try again in a moment...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    try {
      await _player.playOrPause();
    } catch (e) {
      debugPrint('⚠️ VoiceBubble play error: $e');
    }
  }

  String _fmtDuration() {
    final s = widget.durationSeconds ??
        (_totalDuration.inSeconds > 0 ? _totalDuration.inSeconds : 0);
    if (s <= 0) return '0\'\'';
    if (s < 60) return '$s\'\'';
    return '${s ~/ 60}\'${(s % 60).toString().padLeft(2, '0')}\'\'';
  }

  double _calcWidth() {
    final s = widget.durationSeconds ??
        (_totalDuration.inSeconds > 0 ? _totalDuration.inSeconds : 1);
    return (60.0 + s.clamp(0, 60) * 2.0).clamp(60.0, 180.0);
  }

  double _wave(double p, double off) {
    final v = (p + off) % 1.0;
    return v < 0.5 ? v * 2 : 2 - v * 2;
  }

  Widget _bar(Color c, double h) => Container(
        width: 2.5,
        height: h,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(1.25),
        ),
      );

  Widget _waveIcon(Color c) {
    final p = _waveCtrl.value;
    final h1 = _isPlaying ? 3.0 + 9.0 * _wave(p, 0.0) : 5.0;
    final h2 = _isPlaying ? 3.0 + 9.0 * _wave(p, 0.3) : 9.0;
    final h3 = _isPlaying ? 3.0 + 9.0 * _wave(p, 0.6) : 13.0;
    return SizedBox(
      width: 16,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(c, h1),
          const SizedBox(width: 2),
          _bar(c, h2),
          const SizedBox(width: 2),
          _bar(c, h3),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = FFAppState().chatFontSize;

    // Lona theme: both sent & received bubbles have white background
    const lonaBlue = Color(0xFF007AFF);
    const textColor = Color(0xFF333333);

    final durationText = Text(
      _fmtDuration(),
      style: TextStyle(
        fontFamily: 'SF Pro Text',
        fontSize: fontSize - 1,
        color: textColor,
      ),
    );

    final wave = widget.isMe
        ? _waveIcon(lonaBlue)
        : Transform.flip(flipX: true, child: _waveIcon(lonaBlue));

    // Use InkWell instead of GestureDetector for better tap handling
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _togglePlay,
        borderRadius: BorderRadius.circular(8),
        splashColor: lonaBlue.withOpacity(0.1),
        highlightColor: lonaBlue.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: widget.isMe
                ? [durationText, const SizedBox(width: 6), wave]
                : [wave, const SizedBox(width: 6), durationText],
          ),
        ),
      ),
    );
  }
}
