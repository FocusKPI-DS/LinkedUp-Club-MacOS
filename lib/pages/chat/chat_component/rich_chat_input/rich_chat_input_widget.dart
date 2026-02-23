import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/utils/quill_delta_to_markdown.dart';
import 'ime_composing_handler.dart';
import 'package:super_clipboard/super_clipboard.dart';

class RichChatInputWidget extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onEmoji;
  final VoidCallback? onMention;
  final VoidCallback? onScreenshot;
  final VoidCallback? onScreenRecord;
  final VoidCallback? onPhotoLibrary;

  final VoidCallback? onCamera;
  final Function(ClipboardReader)? onPaste; // New callback
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
    this.onAttachment,
    this.onEmoji,
    this.onMention,
    this.onScreenshot,
    this.onScreenRecord,
    this.onPhotoLibrary,
    this.onCamera,
    this.onPaste, // New callback
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

class _RichChatInputWidgetState extends State<RichChatInputWidget> {
  late QuillController _controller;
  late FocusNode _focusNode;
  bool _isComposing = false;
  bool _showToolbar = false;
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

  void _handleSend() {
    // Don't send if IME is actively composing (e.g. selecting pinyin candidate)
    if (_imeHandler.isComposing) {
      print('DEBUG: _handleSend blocked - IME is composing');
      return;
    }

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

    if (widget.controller != null) {
      widget.controller!.clear();
    } else {
      _controller.clear();
    }
  }

  void _handlePaste() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;

    final reader = await clipboard.read();

    if (widget.onPaste != null) {
      widget.onPaste!(reader);
    }
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
        if (Platform.isIOS) ...[
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
          // Non-iOS (existing logic)
          PopupMenuItem(
            value: 'upload',
            onTap: widget.onAttachment,
            child: Row(
              children: [
                Icon(
                    kIsWeb ||
                            (Platform.isMacOS ||
                                Platform.isWindows ||
                                Platform.isLinux)
                        ? Icons.computer
                        : Icons.photo_library,
                    size: 20,
                    color: FlutterFlowTheme.of(context).primaryText),
                const SizedBox(width: 12),
                Text(
                  kIsWeb ||
                          (Platform.isMacOS ||
                              Platform.isWindows ||
                              Platform.isLinux)
                      ? 'Upload from computer'
                      : 'Photo Library',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
              ],
            ),
          ),
        ],
        if (kIsWeb ||
            (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) ...[
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
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      child: Column(
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
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 40,
                maxHeight: 200,
              ),
              child: Focus(
                onKeyEvent: (node, event) {
                  // Handle Cmd+V (Paste) - Intercept completely
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.keyV &&
                      HardwareKeyboard.instance.isMetaPressed) {
                    print('DEBUG: Cmd+V Intercepted');
                    _handlePaste();
                    return KeyEventResult.handled;
                  }

                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    // 1. Shift+Enter: Newline (Standard behavior)
                    if (HardwareKeyboard.instance.isShiftPressed) {
                      return KeyEventResult.ignored;
                    }

                    // 2. Logic: Let the event propagate. If it was an IME commit, the text will change purely.
                    // If it was a standard Enter, a newline will be inserted.
                    // We check the result after a short delay.

                    final preText = _controller.document.toPlainText();
                    final preSelection = _controller.selection;

                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (!mounted) return;

                      final postText = _controller.document.toPlainText();

                      // Case A: Text became longer by 1 char (the newline) at the selection point
                      // Quill adds \n. comparison might be tricky due to Quill's trailing \n.
                      // Let's verify if the stored 'postText' looks like 'preText' with an inserted \n

                      // Simple check: If just a newline was added
                      // We assume "Enter to Send" if the text essentially stayed the same EXCEPT for a new newline

                      bool newlineAdded = false;
                      // Determine if a newline logic was added.
                      // postText length should correspond to preText length + 1 (for \n)
                      if (postText.length == preText.length + 1 &&
                          postText.trim() == preText.trim()) {
                        newlineAdded = true;
                      } else if (postText == preText + '\n') {
                        // Sometimes specific formatting affects length, but basic append check is safe
                        newlineAdded = true;
                      }

                      if (newlineAdded) {
                        // It was a standard "Enter", so we treat it as "Send".

                        // 1. Remove the added newline to clean up
                        // The newline is likely at the old insertion point
                        if (preSelection.isValid && preSelection.isCollapsed) {
                          _controller.replaceText(
                              preSelection.baseOffset, 1, '', null);
                        } else {
                          // Fallback: remove last char if it matches?
                          // Better to just rely on user knowing text was sent.
                          // Actually we MUST remove it or the next message starts with empty line if we don't clear.
                          // But _handleSend usually clears the controller!
                        }

                        // 2. Trigger Send (which clears the text anyway)
                        _handleSend();
                      } else {
                        // Case B: Text changed significantly (IME commit) or stayed same (some other handling)
                        // Do nothing (User is still typing/composing)
                        print(
                            'DEBUG: Enter ignored (Content changed differently - likely IME)');
                      }
                    });

                    // Allow propagation
                    return KeyEventResult.ignored;
                  }
                  return KeyEventResult.ignored;
                },
                child: QuillEditor.basic(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: ScrollController(),
                  config: QuillEditorConfig(
                    placeholder: widget.placeholder,
                    autoFocus: false,
                    expands: false,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // (+) Button
                InkWell(
                  key: _plusButtonKey,
                  onTap: _showPlusMenu,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                    child: Icon(Icons.add,
                        size: 16,
                        color: FlutterFlowTheme.of(context).primaryText),
                  ),
                ),

                const SizedBox(width: 8),

                // (Aa) Button
                IconButton(
                  icon: Icon(Icons.text_format,
                      size: 20,
                      color: _showToolbar
                          ? FlutterFlowTheme.of(context).primary
                          : FlutterFlowTheme.of(context).secondaryText),
                  onPressed: _toggleToolbar,
                  tooltip: 'Formatting',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),

                const SizedBox(width: 4),

                // Emoji Button
                IconButton(
                  icon: Icon(Icons.emoji_emotions_outlined,
                      size: 20,
                      color: FlutterFlowTheme.of(context).secondaryText),
                  onPressed: widget.onEmoji,
                  tooltip: 'Emoji',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),

                const SizedBox(width: 4),

                // @ Button
                IconButton(
                  icon: Icon(Icons.alternate_email,
                      size: 20,
                      color: FlutterFlowTheme.of(context).secondaryText),
                  onPressed: widget.onMention,
                  tooltip: 'Mention',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),

                const Spacer(),

                // Send Button
                InkWell(
                  onTap: (_isComposing || widget.hasAttachments)
                      ? _handleSend
                      : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (_isComposing || widget.hasAttachments)
                          ? const Color(0xFF007A5A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.send,
                      size: 18,
                      color: (_isComposing || widget.hasAttachments)
                          ? Colors.white
                          : FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
