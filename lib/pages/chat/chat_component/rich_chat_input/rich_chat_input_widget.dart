import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/utils/quill_delta_to_markdown.dart';
import '/app_state.dart';
import 'ime_composing_handler.dart';

class RichChatInputWidget extends StatefulWidget {
  final Function(String) onSend;
  final void Function(DateTime scheduledAt)? onScheduleMessage;
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

  const RichChatInputWidget({
    super.key,
    required this.onSend,
    this.onScheduleMessage,
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
    if (markdown.trim().isEmpty && !widget.hasAttachments) return;

    print('DEBUG: _handleSend executing - sending message');
    widget.onSend(markdown);

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

  void _showPlusMenu() {
    final RenderBox? button =
        _plusButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
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
                        _buildFormatButton(Icons.format_bold, Attribute.bold),
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

          // Editor with Enter-to-Send shortcut
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 48,
                maxHeight: 200,
              ),
              child: QuillEditor.basic(
                controller: _controller,
                focusNode: _focusNode,
                scrollController: ScrollController(),
                config: QuillEditorConfig(
                  placeholder: widget.placeholder,
                  autoFocus: false,
                  expands: false,
                  padding: EdgeInsets.zero,
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
                        if (widget.isMentionActive) return null;
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

                // Schedule message (clock) Button
                Tooltip(
                  message: 'Schedule message',
                  child: InkWell(
                    onTap: () {
                      if (widget.onScheduleMessage != null) {
                        setState(() =>
                            _showScheduleOverlay = !_showScheduleOverlay);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.schedule_rounded,
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

                const Spacer(),

                // Send Button — animated color transition
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: (_isComposing || widget.hasAttachments)
                        ? CupertinoColors.systemBlue
                        : FlutterFlowTheme.of(context)
                            .alternate
                            .withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: (_isComposing || widget.hasAttachments)
                          ? _handleSend
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
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
                            _scheduledDate != null &&
                                    _scheduledTime != null
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
                                    final at = DateTime(
                                      _scheduledDate!.year,
                                      _scheduledDate!.month,
                                      _scheduledDate!.day,
                                      _scheduledTime!.hour,
                                      _scheduledTime!.minute,
                                    );
                                    widget.onScheduleMessage!(at);
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
}
