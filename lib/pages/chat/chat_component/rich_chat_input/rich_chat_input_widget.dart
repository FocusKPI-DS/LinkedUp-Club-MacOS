import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'web_blob_helper.dart';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/utils/quill_delta_to_markdown.dart';
import '/app_state.dart';
import 'ime_composing_handler.dart';
import 'package:record/record.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class RichChatInputWidget extends StatefulWidget {
  final Function(String) onSend;
  final void Function(String markdown, DateTime scheduledAt)? onScheduleMessage;
  final Future<void> Function(String? filePath, Duration length, {Uint8List? audioBytes})? onVoiceSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onEmoji;
  final VoidCallback? onMention;
  final VoidCallback? onScreenshot;
  final VoidCallback? onScreenRecord;
  final VoidCallback? onPhotoLibrary;
  final VoidCallback? onCamera;
  final bool isScreenRecording;
  final bool hasAttachments;
  final String? initialText;
  final String placeholder;
  final FocusNode? focusNode;
  final QuillController? controller;
  final bool isMentionActive;
  final VoidCallback? onMentionConfirm;
  final bool isUploading;

  const RichChatInputWidget({
    super.key,
    required this.onSend,
    this.onScheduleMessage,
    this.onVoiceSend,
    this.onAttachment,
    this.onEmoji,
    this.onMention,
    this.onScreenshot,
    this.onScreenRecord,
    this.onPhotoLibrary,
    this.onCamera,
    this.isScreenRecording = false,
    this.hasAttachments = false,
    this.initialText,
    this.placeholder = 'Message...',
    this.focusNode,
    this.controller,
    this.isMentionActive = false,
    this.onMentionConfirm,
    this.isUploading = false,
  });

  @override
  State<RichChatInputWidget> createState() => _RichChatInputWidgetState();
}

class SendMessageIntent extends Intent {
  const SendMessageIntent();
}

class _RichChatInputWidgetState extends State<RichChatInputWidget> {
  late QuillController _controller;
  late FocusNode _focusNode;
  bool _isComposing = false;
  bool _showToolbar = false;
  bool _showScheduleOverlay = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  final GlobalKey _plusButtonKey = GlobalKey();
  final IMEComposingHandler _imeHandler = IMEComposingHandler();

  // Voice Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  RecorderController? _waveController;  // null on web (package uses Platform internally)
  bool _isRecording = false;
  bool _hasRecorded = false;
  String? _recordedFilePath;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // Web-specific voice recording state
  Uint8List? _recordedBytes;

  // Speech to text state (kept for future use)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _sttAvailable = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _imeHandler.init();

    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = QuillController.basic();
      if (widget.initialText != null && widget.initialText!.isNotEmpty) {
        _controller.document =
            Document.fromDelta(Delta()..insert(widget.initialText!));
      }
    }

    _controller.addListener(_onTextChanged);
    _controller.addListener(_onSelectionChanged);

    if (!kIsWeb) {
      _waveController = RecorderController()
        ..androidEncoder = AndroidEncoder.aac
        ..androidOutputFormat = AndroidOutputFormat.mpeg4
        ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
        ..sampleRate = 44100;
    }

    // Don't auto-init speech on macOS — it triggers a TCC privacy crash
    // (SIGABRT) if the user hasn't previously granted speech recognition
    // permission via System Settings.  We defer init to when the user
    // explicitly taps a speech-to-text button.
    if (!kIsWeb && !Platform.isMacOS) {
      _initSpeech();
    }
  }

  void _initSpeech() async {
    try {
      _sttAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('🎤 STT status: $status');
        },
        onError: (errorNotification) {
          debugPrint('🎤 STT Error: $errorNotification');
        },
      );
      debugPrint('🎤 STT initialized: _sttAvailable=$_sttAvailable');
    } catch (e) {
      debugPrint('🎤 STT init failed (non-fatal): $e');
      _sttAvailable = false;
    }
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  void _onTextChanged() {
    final isEmpty = _controller.document.isEmpty();
    if (_isComposing == isEmpty) {
      setState(() {
        _isComposing = !isEmpty;
      });
    }
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ??
          TimeOfDay(hour: now.hour, minute: (now.minute + 1) % 60),
    );
    if (!mounted || time == null) return;
    setState(() {
      _scheduledDate = date;
      _scheduledTime = time;
    });
  }

  String _formatScheduleDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (d.year == tomorrow.year &&
        d.month == tomorrow.month &&
        d.day == tomorrow.day) {
      return 'Tomorrow';
    }
    return '${d.month}/${d.day}/${d.year}';
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _waveController?.dispose();
    _audioRecorder.dispose();
    
    _imeHandler.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.removeListener(_onSelectionChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleSend({bool fromHardwareKeyboard = false}) {
    // Check traditional web IME plugin
    if (_imeHandler.isComposing) {
      print('DEBUG: _handleSend blocked - Web IME is composing');
      return;
    }

    // If not triggered directly from hardware keyboard, no additional IME check needed
    // (native IME state is tracked via the polling timer).

    // Don't send if mention overlay is active (Enter selects mention instead)
    if (widget.isMentionActive) return;

    final isEmpty = _controller.document.isEmpty();
    final delta = _controller.document.toDelta();
    final markdown = isEmpty ? '' : quillDeltaToMarkdownSimplified(delta);

    // Allow sending if there are attachments, even with empty text
    // If we have a recorded voice, send it instead
    if (_hasRecorded && (_recordedFilePath != null || _recordedBytes != null)) {
      _sendVoiceRecording();
      return;
    }

    if (markdown.trim().isEmpty && !widget.hasAttachments) return;

    print('DEBUG: _handleSend executing - sending message');
    widget.onSend(markdown);

    // Clear the input field after sending
    _controller.clear();

    setState(() {
      _showToolbar = false;
      _isComposing = false;
    });
  }

  void _toggleToolbar() {
    setState(() {
      _showToolbar = !_showToolbar;
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording || _hasRecorded) {
      // Already in recording mode — cancel & go back to text input
      _cancelRecording();
    } else {
      // Enter recording-ready mode (show UI, but don't start recording yet)
      setState(() {
        _hasRecorded = false;
        _isRecording = false;
        _recordDuration = 0;
        _recordedFilePath = null;
        // We use _hasRecorded=false + a new flag-like state:
        // We'll show the recording UI by setting a "voice mode" flag
      });
      // Show the recording UI in "ready" state
      setState(() {});
    }
  }

  bool get _isVoiceMode => _isRecording || _hasRecorded || _showVoiceReady;
  bool _showVoiceReady = false;

  void _enterVoiceMode() {
    setState(() {
      _showVoiceReady = true;
    });
  }

  void _exitVoiceMode() {
    _cancelRecording();
    setState(() {
      _showVoiceReady = false;
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        _recordDuration = 0;

        if (kIsWeb) {
          // Web: use start() mode with opus — record_web's startStream only supports pcm16bits.
          // start() uses MediaRecorder API and returns a blob URL on stop().
          _recordedBytes = null;
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.opus, numChannels: 1),
            path: '',  // path is ignored on web
          );
          print('🎙️ [web] Recording started with start() mode');
        } else {
          // Native: record to file
          final directory = await getTemporaryDirectory();
          final fileName = 'voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
          _recordedFilePath = '${directory.path}/$fileName';

          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
            path: _recordedFilePath!,
          );
          _waveController?.record();
        }

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordDuration++;
            });
          }
        });

        setState(() {
          _isRecording = true;
          _hasRecorded = false;
          _showVoiceReady = false;
        });
      } else {
        print('❌ [_startRecording] Microphone permission denied');
      }
    } catch (e, stack) {
      print('❌ Error starting record: $e');
      print('   Stack: $stack');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();

      if (kIsWeb) {
        // Web: stop() returns a blob URL, fetch byte data from it
        final blobUrl = await _audioRecorder.stop();
        print('🎙️ [web-stop] Got blob URL: $blobUrl');
        if (blobUrl != null && blobUrl.isNotEmpty) {
          _recordedBytes = await fetchBlobUrlBytes(blobUrl);
          print('🎙️ [web-stop] Fetched ${_recordedBytes!.length} bytes from blob');
        } else {
          print('❌ [web-stop] No blob URL returned from stop()');
        }
      } else {
        await _audioRecorder.stop();
        await _waveController?.stop();
      }

      if (mounted) {
        setState(() {
          _isRecording = false;
          _hasRecorded = true;
        });
      }
    } catch (e, stack) {
      print('❌ Error stopping record: $e');
      print('   Stack: $stack');
    }
  }

  void _cancelRecording() {
    _recordTimer?.cancel();
    if (_isRecording) {
      _audioRecorder.stop();
      if (!kIsWeb) {
        _waveController?.stop();
      }
    }
    
    // Delete temp file if exists (native only)
    if (!kIsWeb && _recordedFilePath != null) {
      final file = File(_recordedFilePath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }

    setState(() {
      _isRecording = false;
      _hasRecorded = false;
      _recordedFilePath = null;
      _recordedBytes = null;
      _recordDuration = 0;
    });
  }




  void _sendVoiceRecording() async {
    print('🎙️ [_sendVoiceRecording] START: _isRecording=$_isRecording, _hasRecorded=$_hasRecorded, _recordedFilePath=$_recordedFilePath, _recordDuration=$_recordDuration');
    
    if (_isRecording) {
      await _stopRecording();
      print('🎙️ [_sendVoiceRecording] After stop: _isRecording=$_isRecording, _hasRecorded=$_hasRecorded, _recordedFilePath=$_recordedFilePath');
    }
    
    if (_hasRecorded && widget.onVoiceSend != null) {
      if (kIsWeb) {
        // Web: send bytes directly
        if (_recordedBytes != null && _recordedBytes!.isNotEmpty) {
          print('🎙️ [_sendVoiceRecording] Web: sending ${_recordedBytes!.length} bytes');
          await widget.onVoiceSend!(null, Duration(seconds: _recordDuration), audioBytes: _recordedBytes);
        } else {
          print('❌ [_sendVoiceRecording] Web: recorded bytes are empty!');
        }
      } else {
        // Native: send file path
        if (_recordedFilePath != null) {
          final file = File(_recordedFilePath!);
          final exists = await file.exists();
          final size = exists ? await file.length() : 0;
          print('🎙️ [_sendVoiceRecording] File exists=$exists, size=$size bytes');
          
          if (exists && size > 0) {
            await widget.onVoiceSend!(_recordedFilePath!, Duration(seconds: _recordDuration));
          } else {
            print('❌ [_sendVoiceRecording] File is empty or does not exist!');
          }
        }
      }
      _cancelRecording();
      setState(() => _showVoiceReady = false);
    } else {
      print('❌ [_sendVoiceRecording] Cannot send: _hasRecorded=$_hasRecorded, onVoiceSend=${widget.onVoiceSend != null}');
    }
  }

  void _showPlusMenu() {
    final RenderBox? button =
        _plusButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonTopLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonBottomRight = button.localToGlobal(
        button.size.bottomRight(Offset.zero), ancestor: overlay);
    // Anchor popup above the button, left-aligned with the button
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTRB(
        buttonTopLeft.dx,
        buttonTopLeft.dy,
        buttonBottomRight.dx,
        buttonBottomRight.dy,
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: FlutterFlowTheme.of(context).secondaryBackground,
      items: [
        if (!kIsWeb && Platform.isIOS) ...[
          PopupMenuItem(
            value: 'file',
            onTap: widget.onAttachment,
            child: Row(
              children: [
                Icon(Icons.folder_open,
                    size: 20, color: FlutterFlowTheme.of(context).primaryText),
                const SizedBox(width: 12),
                Text(
                  'File',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'photo_library',
            onTap: widget.onPhotoLibrary,
            child: Row(
              children: [
                Icon(Icons.photo_library,
                    size: 20, color: FlutterFlowTheme.of(context).primaryText),
                const SizedBox(width: 12),
                Text(
                  'Photo Library',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'camera',
            onTap: widget.onCamera,
            child: Row(
              children: [
                Icon(Icons.camera_alt,
                    size: 20, color: FlutterFlowTheme.of(context).primaryText),
                const SizedBox(width: 12),
                Text(
                  'Camera',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
              ],
            ),
          ),
        ] else ...[
          // Non-iOS and non-web: Android, macOS, Windows, Linux
          PopupMenuItem(
            value: 'upload',
            onTap: widget.onAttachment,
            child: Row(
              children: [
                Icon(
                    kIsWeb ||
                            (!kIsWeb &&
                                (Platform.isMacOS ||
                                    Platform.isWindows ||
                                    Platform.isLinux))
                        ? Icons.computer
                        : Icons.photo_library,
                    size: 20,
                    color: FlutterFlowTheme.of(context).primaryText),
                const SizedBox(width: 12),
                Text(
                  kIsWeb ||
                          (!kIsWeb &&
                              (Platform.isMacOS ||
                                  Platform.isWindows ||
                                  Platform.isLinux))
                      ? 'Upload from computer'
                      : 'Photo Library',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
              ],
            ),
          ),
        ],
        if (kIsWeb ||
            (!kIsWeb &&
                (Platform.isMacOS ||
                    Platform.isWindows ||
                    Platform.isLinux))) ...[
          PopupMenuItem(
            value: 'screenshot',
            onTap: widget.onScreenshot,
            child: Row(
              children: [
                Icon(Icons.screenshot_monitor,
                    size: 20, color: FlutterFlowTheme.of(context).primaryText),
                const SizedBox(width: 12),
                Text(
                  'Take Screenshot',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'record',
            onTap: widget.onScreenRecord,
            child: Row(
              children: [
                Icon(
                  widget.isScreenRecording ? Icons.stop_circle : Icons.videocam,
                  size: 20,
                  color: widget.isScreenRecording
                      ? Colors.red
                      : FlutterFlowTheme.of(context).primaryText,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isScreenRecording ? 'Stop Recording' : 'Record Screen',
                  style: widget.isScreenRecording
                      ? FlutterFlowTheme.of(context)
                          .bodyMedium
                          .copyWith(color: Colors.red)
                      : FlutterFlowTheme.of(context).bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormatButton(IconData icon, Attribute attribute,
      {bool isLink = false}) {
    final isSelected =
        _controller.getSelectionStyle().attributes.containsKey(attribute.key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: isSelected
              ? FlutterFlowTheme.of(context).primary
              : FlutterFlowTheme.of(context).secondaryText,
        ),
        onPressed: () =>
            isLink ? _onLinkPressed() : _toggleAttribute(attribute),
        tooltip: attribute.key,
        style: IconButton.styleFrom(
          backgroundColor: isSelected
              ? FlutterFlowTheme.of(context).accent1.withOpacity(0.2)
              : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: EdgeInsets.zero,
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  void _toggleAttribute(Attribute attribute) {
    if (attribute.key == 'list') {
      final current = _controller.getSelectionStyle().attributes['list'];
      if (current?.value == attribute.value) {
        _controller.formatSelection(
            const Attribute('list', AttributeScope.block, null));
      } else {
        _controller.formatSelection(attribute);
      }
      return;
    }

    final isToggled =
        _controller.getSelectionStyle().attributes.containsKey(attribute.key);
    if (isToggled) {
      _controller
          .formatSelection(Attribute(attribute.key, attribute.scope, null));
    } else {
      _controller.formatSelection(attribute);
    }
  }

  void _onLinkPressed() async {
    final currentLink =
        _controller.getSelectionStyle().attributes[Attribute.link.key]?.value;

    final textController = TextEditingController(text: currentLink as String?);

    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Link URL',
            style: FlutterFlowTheme.of(context).titleMedium),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: 'https://example.com'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (url != null) {
      if (url.isNotEmpty) {
        _controller
            .formatSelection(Attribute('link', AttributeScope.inline, url));
      } else {
        _controller.formatSelection(
            const Attribute('link', AttributeScope.inline, null));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toolbar (Conditional)
              if (_showToolbar)
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: FlutterFlowTheme.of(context).alternate)),
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          children: [
                            _buildFormatButton(
                                Icons.format_bold, Attribute.bold),
                            _buildFormatButton(
                                Icons.format_italic, Attribute.italic),
                            _buildFormatButton(
                                Icons.format_strikethrough,
                                const Attribute(
                                    'strike', AttributeScope.inline, true)),
                            const VerticalDivider(
                                width: 16, indent: 8, endIndent: 8),
                            _buildFormatButton(
                                Icons.link,
                                const Attribute(
                                    'link', AttributeScope.inline, null),
                                isLink: true),
                            const VerticalDivider(
                                width: 16, indent: 8, endIndent: 8),
                            _buildFormatButton(Icons.format_list_numbered,
                                Attribute.clone(Attribute.list, 'ordered')),
                            _buildFormatButton(Icons.format_list_bulleted,
                                Attribute.clone(Attribute.list, 'bullet')),
                            const VerticalDivider(
                                width: 16, indent: 8, endIndent: 8),
                            _buildFormatButton(
                                Icons.format_quote,
                                const Attribute(
                                    'blockquote', AttributeScope.block, true)),
                            _buildFormatButton(
                                Icons.code,
                                const Attribute(
                                    'code', AttributeScope.inline, true)),
                            _buildFormatButton(
                                Icons.data_object,
                                const Attribute(
                                    'code-block', AttributeScope.block, true)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Editor with Enter-to-Send shortcut / Recording UI
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    maxHeight: 200,
                  ),
                  child: (_isRecording || _hasRecorded || _showVoiceReady)
                      ? _buildRecordingUI()
                      : QuillEditor.basic(
                          controller: _controller,
                          focusNode: _focusNode,
                          scrollController: ScrollController(),
                          config: QuillEditorConfig(
                            placeholder: widget.placeholder,
                            autoFocus: false,
                            expands: false,
                            padding: EdgeInsets.zero,
                            customStyles: DefaultStyles(
                              placeHolder: DefaultTextBlockStyle(
                                TextStyle(
                                  fontSize: FFAppState().chatFontSize,
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText
                                      .withOpacity(0.55),
                                  fontFamily: 'Inter',
                                ),
                                HorizontalSpacing.zero,
                                VerticalSpacing.zero,
                                VerticalSpacing.zero,
                                null,
                              ),
                              paragraph: DefaultTextBlockStyle(
                                TextStyle(
                                  fontSize: FFAppState().chatFontSize,
                                  color: FlutterFlowTheme.of(context).primaryText,
                                  fontFamily: 'Inter',
                                  height: 1.4,
                                ),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        h1: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        h2: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        h3: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        h4: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        h5: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        h6: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        bold: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                        italic: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Inter',
                        ),
                        strikeThrough: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          fontFamily: 'Inter',
                        ),
                        link: TextStyle(
                          color: FlutterFlowTheme.of(context).primary,
                          decoration: TextDecoration.underline,
                          fontFamily: 'Inter',
                        ),
                        leading: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'Inter',
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        lists: DefaultListBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'Inter',
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing(4, 4),
                          VerticalSpacing.zero,
                          null,
                          null,
                        ),
                        indent: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'Inter',
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        align: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'Inter',
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing.zero,
                          VerticalSpacing.zero,
                          null,
                        ),
                        quote: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize,
                            color: FlutterFlowTheme.of(context)
                                .primaryText
                                .withOpacity(0.7),
                            fontFamily: 'Inter',
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing(4, 4),
                          VerticalSpacing.zero,
                          BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryText
                                    .withOpacity(0.4),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        code: DefaultTextBlockStyle(
                          TextStyle(
                            fontSize: FFAppState().chatFontSize - 1,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'SF Mono',
                            height: 1.4,
                          ),
                          HorizontalSpacing.zero,
                          VerticalSpacing(4, 4),
                          VerticalSpacing.zero,
                          BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .alternate
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        inlineCode: InlineCodeStyle(
                          style: TextStyle(
                            fontSize: FFAppState().chatFontSize - 1,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontFamily: 'SF Mono',
                            backgroundColor: FlutterFlowTheme.of(context)
                                .alternate
                                .withOpacity(0.3),
                          ),
                        ),
                      ),
                      customShortcuts: {
                        if (FFAppState().sendMessageShortcut == 0)
                          const SingleActivator(LogicalKeyboardKey.enter):
                              const SendMessageIntent(),
                        if (FFAppState().sendMessageShortcut == 1)
                          const SingleActivator(LogicalKeyboardKey.enter,
                              shift: true): const SendMessageIntent(),
                        if (FFAppState().sendMessageShortcut == 2)
                          const SingleActivator(LogicalKeyboardKey.enter,
                              meta: true): const SendMessageIntent(),
                        const SingleActivator(LogicalKeyboardKey.numpadEnter):
                            const SendMessageIntent(),
                      },
                      customActions: {
                        SendMessageIntent: CallbackAction<SendMessageIntent>(
                          onInvoke: (SendMessageIntent intent) {
                            if (widget.isMentionActive) {
                              widget.onMentionConfirm?.call();
                              return null;
                            }
                            _handleSend(fromHardwareKeyboard: true);
                            return null;
                          },
                        ),
                      },
                    ),
                  ),
                ),
              ),

              // Subtle divider separating editor from action bar
              Divider(
                height: 1,
                thickness: 1,
                color: FlutterFlowTheme.of(context).alternate.withOpacity(0.5),
              ),

              // Bottom Actions Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // (+) Attach Button
                    Tooltip(
                      message: 'Attach',
                      child: InkWell(
                        key: _plusButtonKey,
                        onTap: _showPlusMenu,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .primary
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 22,
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Format (Aa) Button
                    Tooltip(
                      message: 'Formatting',
                      child: InkWell(
                        onTap: _toggleToolbar,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _showToolbar
                                ? FlutterFlowTheme.of(context)
                                    .primary
                                    .withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.text_format_rounded,
                            size: 22,
                            color: _showToolbar
                                ? FlutterFlowTheme.of(context).primary
                                : FlutterFlowTheme.of(context).secondaryText,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 2),

                    // Emoji Button
                    Tooltip(
                      message: 'Emoji',
                      child: InkWell(
                        onTap: widget.onEmoji,
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.emoji_emotions_outlined,
                            size: 22,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 2),

                    // @ Mention Button
                    if (widget.onMention != null)
                      Tooltip(
                        message: 'Mention',
                        child: InkWell(
                          onTap: widget.onMention,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.alternate_email_rounded,
                              size: 21,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(width: 2),

                    // Microphone Button
                    Tooltip(
                      message: _isVoiceMode ? 'Exit Voice Mode' : 'Record Audio',
                      child: InkWell(
                        onTap: _isVoiceMode ? _exitVoiceMode : _enterVoiceMode,
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            _isVoiceMode ? Icons.keyboard : Icons.mic_none_outlined,
                            size: 22,
                            color: _isVoiceMode
                                ? FlutterFlowTheme.of(context).primary
                                : FlutterFlowTheme.of(context).secondaryText,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Slack-style split send button (send | schedule ▾)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: widget.isUploading
                            ? FlutterFlowTheme.of(context)
                                .secondaryText
                                .withOpacity(0.5)
                            : (_isComposing || widget.hasAttachments || _hasRecorded)
                                ? CupertinoColors.systemBlue
                                : FlutterFlowTheme.of(context)
                                    .alternate
                                    .withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Left: immediate send
                          Material(
                            color: Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                            ),
                            child: InkWell(
                              onTap: (!widget.isUploading &&
                                      (_isComposing || widget.hasAttachments || _hasRecorded))
                                  ? _handleSend
                                  : null,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                child: widget.isUploading
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Uploading...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Icon(
                                        Icons.send_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                          // Divider
                          Container(
                            width: 1,
                            height: 18,
                            color: Colors.white.withOpacity(0.35),
                          ),
                          // Right: schedule dropdown arrow
                          if (widget.onScheduleMessage != null)
                            Material(
                              color: Colors.transparent,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(10),
                                bottomRight: Radius.circular(10),
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _showScheduleOverlay =
                                      !_showScheduleOverlay);
                                },
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 5),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Schedule overlay positioned above the input area
          if (_showScheduleOverlay && widget.onScheduleMessage != null)
            Positioned(
              top: -12,
              right: 8,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                color: FlutterFlowTheme.of(context).secondaryBackground,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: const BoxConstraints(minWidth: 200),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 20,
                            color: FlutterFlowTheme.of(context).primaryText,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Send at',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickScheduleDateTime,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Text(
                            _scheduledDate != null && _scheduledTime != null
                                ? '${_formatScheduleDate(_scheduledDate!)} ${_scheduledTime!.format(context)}'
                                : 'Pick date & time',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Inter',
                                  color: _scheduledDate != null &&
                                          _scheduledTime != null
                                      ? FlutterFlowTheme.of(context).primaryText
                                      : FlutterFlowTheme.of(context)
                                          .secondaryText,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showScheduleOverlay = false;
                                _scheduledDate = null;
                                _scheduledTime = null;
                              });
                            },
                            child: Text(
                              'Cancel',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Inter',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                            ),
                          ),
                          FilledButton(
                            onPressed: _scheduledDate != null &&
                                    _scheduledTime != null
                                ? () {
                                    final isEmpty =
                                        _controller.document.isEmpty();
                                    final delta =
                                        _controller.document.toDelta();
                                    final markdown = isEmpty
                                        ? ''
                                        : quillDeltaToMarkdownSimplified(delta);

                                    if (markdown.trim().isEmpty &&
                                        !widget.hasAttachments) {
                                      setState(() {
                                        _showScheduleOverlay = false;
                                        _scheduledDate = null;
                                        _scheduledTime = null;
                                      });
                                      return;
                                    }

                                    final at = DateTime(
                                      _scheduledDate!.year,
                                      _scheduledDate!.month,
                                      _scheduledDate!.day,
                                      _scheduledTime!.hour,
                                      _scheduledTime!.minute,
                                    );
                                    widget.onScheduleMessage!(markdown, at);

                                    // Clear the input field after scheduling
                                    _controller.clear();
                                    setState(() {
                                      _showScheduleOverlay = false;
                                      _scheduledDate = null;
                                      _scheduledTime = null;
                                    });
                                  }
                                : null,
                            child: const Text('Schedule'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingUI() {
    final minutes = (_recordDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordDuration % 60).toString().padLeft(2, '0');

    // Ready state: not recording yet, show "Start Recording" prompt
    if (_showVoiceReady && !_isRecording && !_hasRecorded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.mic_none, color: FlutterFlowTheme.of(context).secondaryText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tap the button to start recording',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Inter',
                  color: FlutterFlowTheme.of(context).secondaryText,
                  fontSize: 14,
                ),
              ),
            ),
            // Start Recording button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _startRecording,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Record',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Active recording or recorded state
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Flashing red dot indicator
          if (_isRecording)
            Animate(
              onPlay: (controller) => controller.repeat(reverse: true),
              effects: const [FadeEffect(duration: Duration(milliseconds: 500), begin: 0.2, end: 1.0)],
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            const Icon(Icons.mic, color: Colors.red, size: 20),
          
          const SizedBox(width: 12),
          
          // Timer
          Text(
            '$minutes:$seconds',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
              fontFamily: 'Inter',
              color: FlutterFlowTheme.of(context).primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Waveform
          Expanded(
            child: kIsWeb
                ? _buildWebWaveformPlaceholder()
                : AudioWaveforms(
                    size: const Size(double.infinity, 30),
                    recorderController: _waveController!,
                    enableGesture: false,
                    waveStyle: WaveStyle(
                      waveColor: FlutterFlowTheme.of(context).primary,
                      extendWaveform: true,
                      showMiddleLine: false,
                    ),
                  ),
          ),

          if (_isRecording) ...[
            // Stop Recording
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              color: Colors.red,
              tooltip: 'Stop Recording',
              onPressed: _stopRecording,
            ),
          ],

          // Send button (shown after recording is stopped)
          if (_hasRecorded) ...[
            IconButton(
              icon: Icon(Icons.send_rounded, color: FlutterFlowTheme.of(context).primary),
              tooltip: 'Send Voice Message',
              onPressed: _sendVoiceRecording,
            ),
          ],
          
          // Delete / Cancel Recording
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
            tooltip: 'Cancel',
            onPressed: _exitVoiceMode,
          ),
        ],
      ),
    );
  }

  /// Web-only: animated bars to simulate waveform visualization
  Widget _buildWebWaveformPlaceholder() {
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(24, (i) {
          // Use a deterministic pseudo-random height that changes each second
          final seed = (_recordDuration * 7 + i * 13) % 100;
          final normalizedHeight = _isRecording
              ? 0.3 + (seed / 100.0) * 0.7 // 30%-100% height when recording
              : 0.15; // minimal height when stopped
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 3,
            height: 30 * normalizedHeight,
            decoration: BoxDecoration(
              color: _isRecording
                  ? FlutterFlowTheme.of(context).primary
                  : FlutterFlowTheme.of(context).secondaryText.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
