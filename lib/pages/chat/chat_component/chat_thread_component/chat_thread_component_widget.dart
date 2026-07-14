import '/backend/backend.dart';
import '/utils/debug_log.dart';
import '/custom_code/actions/ai_translation_service.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/schema/enums/enums.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '../chat_thread/chat_thread_widget.dart';
import '../photo_stack_bubble.dart';
import '../rich_chat_input/rich_chat_input_widget.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'chat_thread_component_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'web_paste_handler_bridge.dart';
import 'desktop_clipboard_paste_helper.dart';
import '/utils/chat_message_font.dart';

export 'chat_thread_component_model.dart';

class ChatThreadComponentWidget extends StatefulWidget {
  const ChatThreadComponentWidget({
    super.key,
    required this.chatReference,
    this.onMessageLongPress,
    this.onTranslateMessage,
    this.onMessageAction,
    this.onMessagesMutated,
    this.onSidebarPreviewUpdate,
    this.activeSelectionId,
    this.isSelectionMode = false,
    this.selectedMessages,
    this.onMessageToggled,
  });

  final ChatsRecord? chatReference;
  final Function(MessagesRecord, Offset?, ChatThreadComponentWidgetState?,
      {bool clearSelection})? onMessageLongPress;
  final Function(MessagesRecord)? onTranslateMessage;
  final Function(String, MessagesRecord)? onMessageAction;
  final VoidCallback? onMessagesMutated;
  final void Function(
    DocumentReference chatRef,
    Map<String, dynamic> patch,
  )? onSidebarPreviewUpdate;
  final ValueNotifier<String?>? activeSelectionId;
  final bool isSelectionMode;
  final Set<MessagesRecord>? selectedMessages;
  final Function(MessagesRecord)? onMessageToggled;

  @override
  State<ChatThreadComponentWidget> createState() =>
      ChatThreadComponentWidgetState();

  static ChatThreadComponentWidgetState? of(BuildContext context) {
    return context.findAncestorStateOfType<ChatThreadComponentWidgetState>();
  }
}

class ChatThreadComponentWidgetState extends State<ChatThreadComponentWidget> {
  late ChatThreadComponentModel _model;

  final ValueNotifier<bool> translateNotifier = ValueNotifier(false);

  // Cache for user display names and photos to avoid "No One" / missing avatar fallback
  final Map<String, String> _userNameCache = {};
  final Map<String, String> _userPhotoCache = {};
  final Set<String> _pendingNameLookups = {};
  final Map<String, DocumentReference> _deferredUserLookups = {};
  Timer? _userLookupDebounce;

  static bool get _staggerDesktopFirestore =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  /// Defer message stream on Windows/Linux to avoid concurrent
  /// Firestore channel traffic (native thread violations → crash).
  bool _messagesStreamReady = true;

  /// Windows/Linux: one-shot fetch instead of live stream (avoids native crash).
  List<MessagesRecord>? _desktopMessages;
  bool _desktopMessagesLoading = false;
  bool _desktopLoadingOlder = false;
  bool _desktopHasMoreOlder = true;
  static const int _desktopPageSize = 40;
  Timer? _desktopMessagesPollTimer;
  VoidCallback? _desktopScrollListener;

  void _ensureUserCached(MessagesRecord message) {
    if (message.senderRef == null) return;
    final refId = message.senderRef!.id;
    if (_userNameCache.containsKey(refId)) return;
    if (_pendingNameLookups.contains(refId)) return;

    if (_staggerDesktopFirestore) {
      _deferredUserLookups[refId] = message.senderRef!;
      _userLookupDebounce?.cancel();
      _userLookupDebounce = Timer(const Duration(milliseconds: 600), () {
        _flushDeferredUserLookups();
      });
      return;
    }

    _pendingNameLookups.add(refId);
    fsGetUserOnce(message.senderRef!).then((userDoc) {
      if (mounted) {
        setState(() {
          _userNameCache[refId] = userDoc.displayName;
          _userPhotoCache[refId] = userDoc.photoUrl;
        });
      }
      _pendingNameLookups.remove(refId);
    }).catchError((_) {
      _pendingNameLookups.remove(refId);
    });
  }

  Future<void> _flushDeferredUserLookups() async {
    final refs = Map<String, DocumentReference>.from(_deferredUserLookups);
    _deferredUserLookups.clear();
    for (final entry in refs.entries) {
      final refId = entry.key;
      final ref = entry.value;
      if (!mounted || _userNameCache.containsKey(refId)) continue;
      if (_pendingNameLookups.contains(refId)) continue;
      _pendingNameLookups.add(refId);
      try {
        final userDoc = await fsGetUserOnce(ref);
        if (mounted) {
          setState(() {
            _userNameCache[refId] = userDoc.displayName;
            _userPhotoCache[refId] = userDoc.photoUrl;
          });
        }
      } catch (_) {}
      _pendingNameLookups.remove(refId);
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  String _resolveUserName(MessagesRecord message) {
    if (message.senderName.isNotEmpty) return message.senderName;
    if (message.senderRef == null) return '';
    final refId = message.senderRef!.id;
    if (_userNameCache.containsKey(refId)) return _userNameCache[refId] ?? '';
    _ensureUserCached(message);
    return '';
  }

  String _resolveUserPhoto(MessagesRecord message) {
    if (message.senderPhoto.isNotEmpty) return message.senderPhoto;
    if (message.senderRef == null) return '';
    final refId = message.senderRef!.id;
    if (_userPhotoCache.containsKey(refId)) return _userPhotoCache[refId] ?? '';
    _ensureUserCached(message);
    return '';
  }

  void safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void clearHighlight() {
    _model.highlightedMessageId = null;
    safeSetState(() {});
  }

  void setHighlightedMessage(String? messageId) {
    _model.highlightedMessageId = messageId;
    safeSetState(() {});
  }

  void scrollToMessage(String messageId) {
    if (widget.chatReference == null) return;

    if (useWindowsFirestoreRest) {
      Future<void> findAndScroll() async {
        List<MessagesRecord> messages;
        if (_desktopMessages != null && _desktopMessages!.isNotEmpty) {
          messages = _desktopMessages!;
        } else {
          messages = await fsQueryChatMessages(widget.chatReference!.reference);
        }
        for (int i = 0; i < messages.length; i++) {
          if (messages[i].reference.id == messageId) {
            _model.itemScrollController?.scrollTo(
              index: i,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            setHighlightedMessage(messageId);
            Future.delayed(const Duration(seconds: 2), () {
              setHighlightedMessage(null);
            });
            break;
          }
        }
      }
      findAndScroll();
      return;
    }

    // Query messages to find the index of the target message
    final messagesRef = widget.chatReference?.reference
        .collection('messages')
        .orderBy('created_at', descending: true);
    if (messagesRef == null) return;

    messagesRef.get().then((snapshot) {
      final docs = snapshot.docs;
      for (int i = 0; i < docs.length; i++) {
        if (docs[i].id == messageId) {
          _model.itemScrollController?.scrollTo(
            index: i,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          // Highlight the message briefly
          setHighlightedMessage(messageId);
          Future.delayed(const Duration(seconds: 2), () {
            setHighlightedMessage(null);
          });
          break;
        }
      }
    });
  }

  void triggerTranslate(MessagesRecord message) {
    widget.onTranslateMessage?.call(message);
  }

  // --- @ Mention state ---
  QuillController? _quillController;
  List<UsersRecord> _memberUsers = [];
  bool _mentionActive = false;
  int _mentionStartOffset = -1;
  List<UsersRecord> _filteredMentionUsers = [];
  int _selectedMentionIndex = 0;

  // Track exact mention positions for atomic deletion
  final List<_MentionRange> _mentionRanges = [];

  Function? _unregisterWebPaste;

  // --- Per-chat draft storage ---
  // Static so drafts persist across widget rebuilds when switching chats.
  static final Map<String, Delta> _drafts = {};

  /// Save current QuillController content as a draft for the given chatId.
  void _saveDraft(String chatId) {
    if (_quillController == null) return;
    final delta = _quillController!.document.toDelta();
    final plainText = _quillController!.document.toPlainText().trim();
    if (plainText.isNotEmpty) {
      _drafts[chatId] = delta;
    } else {
      _drafts.remove(chatId);
    }
  }

  /// Restore a previously saved draft for the given chatId into the QuillController.
  void _restoreDraft(String chatId) {
    if (_quillController == null) return;
    final draft = _drafts[chatId];
    if (draft != null) {
      _quillController!.document = Document.fromDelta(draft);
      // Move cursor to end
      final length = _quillController!.document.length;
      _quillController!.updateSelection(
        TextSelection.collapsed(offset: length - 1),
        ChangeSource.local,
      );
    } else {
      _quillController!.document = Document();
    }
  }

  /// Clear draft for a chatId (called after successful send).
  void _clearDraft(String chatId) {
    _drafts.remove(chatId);
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatThreadComponentModel());
    _model.messageTextController ??= TextEditingController();
    _model.messageFocusNode ??= FocusNode();
    _model.itemScrollController = ItemScrollController();
    _model.itemPositionsListener = ItemPositionsListener.create();
    if (_staggerDesktopFirestore) {
      _desktopScrollListener = _onDesktopMessageScroll;
      _model.itemPositionsListener!.itemPositions
          .addListener(_desktopScrollListener!);
    }

    // Create shared QuillController for @ detection
    _quillController = QuillController.basic();
    _quillController!.addListener(_onQuillTextChanged);

    // Register global keyboard handler to intercept Cmd+V BEFORE QuillEditor consumes it
    HardwareKeyboard.instance.addHandler(_globalKeyHandler);

    // Register web paste handler (no-op on native)
    if (kIsWeb) {
      _unregisterWebPaste = registerWebPasteHandler(_handleWebPaste);
    }

    if (_staggerDesktopFirestore) {
      _messagesStreamReady = false;
      _desktopMessages = null;
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() => _messagesStreamReady = true);
          _loadDesktopMessagesInitial();
          _startDesktopMessagesPolling();
        }
      });
      Future.delayed(const Duration(milliseconds: 2000), _loadMembers);
    } else {
      // Load group members
      _loadMembers();
    }

    // Restore draft for the initial chat
    final initialChatId = widget.chatReference?.reference.id;
    if (initialChatId != null) {
      _restoreDraft(initialChatId);
    }
  }

  @override
  void didUpdateWidget(covariant ChatThreadComponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload members when chat changes
    if (widget.chatReference?.reference != oldWidget.chatReference?.reference) {
      // Save draft for the OLD chat before switching
      final oldChatId = oldWidget.chatReference?.reference.id;
      if (oldChatId != null) {
        _saveDraft(oldChatId);
      }

      _memberUsers.clear();
      _pendingMentions.clear();
      _mentionRanges.clear();
      _filteredMentionUsers.clear();
      _mentionActive = false;
      if (_staggerDesktopFirestore) {
        Future.delayed(const Duration(milliseconds: 1500), _loadMembers);
      } else {
        _loadMembers();
      }

      // Restore draft for the NEW chat
      final newChatId = widget.chatReference?.reference.id;
      if (newChatId != null) {
        _restoreDraft(newChatId);
      }

      if (_staggerDesktopFirestore) {
        _messagesStreamReady = false;
        _desktopMessages = null;
        _desktopHasMoreOlder = true;
        _desktopLoadingOlder = false;
        _desktopMessagesPollTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() => _messagesStreamReady = true);
            _loadDesktopMessagesInitial();
            _startDesktopMessagesPolling();
          }
        });
      }
    }
  }

  void _resetDesktopPaginationState() {
    _desktopHasMoreOlder = true;
    _desktopLoadingOlder = false;
  }

  void _onDesktopMessageScroll() {
    if (!_staggerDesktopFirestore ||
        _desktopLoadingOlder ||
        !_desktopHasMoreOlder ||
        _desktopMessages == null ||
        _desktopMessages!.isEmpty) {
      return;
    }

    final positions = _model.itemPositionsListener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return;

    final maxVisibleIndex =
        positions.map((position) => position.index).reduce((a, b) => a > b ? a : b);
    final total = _desktopMessages!.length;
    if (maxVisibleIndex >= total - 2) {
      unawaited(_loadOlderDesktopMessages());
    }
  }

  Future<void> _loadDesktopMessagesInitial() async {
    if (!_staggerDesktopFirestore || widget.chatReference == null) return;
    if (_desktopMessagesLoading) return;
    _desktopMessagesLoading = true;
    _resetDesktopPaginationState();
    try {
      final messages = await fsQueryChatMessages(
        widget.chatReference!.reference,
        limit: _desktopPageSize,
      );
      if (mounted) {
        setState(() {
          _desktopMessages = messages;
          _desktopHasMoreOlder = messages.length >= _desktopPageSize;
        });
      }
    } catch (e) {
      debugLog('❌ [desktop-messages] fetch failed: $e');
    } finally {
      _desktopMessagesLoading = false;
    }
  }

  Future<void> _loadOlderDesktopMessages() async {
    if (!_staggerDesktopFirestore ||
        widget.chatReference == null ||
        _desktopLoadingOlder ||
        !_desktopHasMoreOlder) {
      return;
    }
    final current = _desktopMessages;
    if (current == null || current.isEmpty) return;

    final oldest = current.last;
    if (oldest.createdAt == null) {
      _desktopHasMoreOlder = false;
      return;
    }

    _desktopLoadingOlder = true;
    safeSetState(() {});
    try {
      final older = await fsQueryChatMessages(
        widget.chatReference!.reference,
        limit: _desktopPageSize,
        startAfter: oldest,
      );
      if (!mounted) return;

      if (older.isEmpty) {
        setState(() => _desktopHasMoreOlder = false);
        return;
      }

      final existingIds = current.map((m) => m.reference.id).toSet();
      final toAdd =
          older.where((m) => !existingIds.contains(m.reference.id)).toList();
      setState(() {
        _desktopMessages!.addAll(toAdd);
        _desktopHasMoreOlder = older.length >= _desktopPageSize;
      });
    } catch (e) {
      debugLog('❌ [desktop-messages] load older failed: $e');
    } finally {
      _desktopLoadingOlder = false;
      if (mounted) safeSetState(() {});
    }
  }

  Future<void> _syncDesktopMessages() async {
    if (!_staggerDesktopFirestore || widget.chatReference == null) return;

    try {
      final recent = await fsQueryChatMessages(
        widget.chatReference!.reference,
        limit: _desktopPageSize,
      );
      if (!mounted) return;

      if (_desktopMessages == null) {
        setState(() {
          _desktopMessages = recent;
          _desktopHasMoreOlder = recent.length >= _desktopPageSize;
        });
        return;
      }

      final recentIds = recent.map((m) => m.reference.id).toSet();
      final oldestRecentTime =
          recent.isNotEmpty ? recent.last.createdAt : null;

      final merged = <MessagesRecord>[...recent];

      for (final message in _desktopMessages!) {
        if (recentIds.contains(message.reference.id)) continue;
        if (oldestRecentTime != null &&
            message.createdAt != null &&
            !message.createdAt!.isBefore(oldestRecentTime)) {
          // Removed on server (unsend) within the recent window.
          continue;
        }
        merged.add(message);
      }

      merged.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      setState(() => _desktopMessages = merged);
    } catch (e) {
      debugLog('❌ [desktop-messages] sync failed: $e');
    }
  }

  void _afterMessagesMutated() {
    if (_staggerDesktopFirestore) {
      unawaited(_syncDesktopMessages());
    }
    widget.onMessagesMutated?.call();
  }

  void _notifySidebarPreview(Map<String, dynamic> patch) {
    final chatRef = widget.chatReference?.reference;
    if (chatRef == null) return;
    widget.onSidebarPreviewUpdate?.call(chatRef, patch);
  }

  Future<void> _pollDesktopMessagesTail() async {
    await _syncDesktopMessages();
  }

  void _startDesktopMessagesPolling() {
    _desktopMessagesPollTimer?.cancel();
    _desktopMessagesPollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _pollDesktopMessagesTail(),
    );
  }

  void _refreshDesktopMessages() {
    if (_staggerDesktopFirestore) {
      unawaited(_syncDesktopMessages());
    }
  }

  /// Global keyboard handler for Backspace/Delete atomic mention deletion.
  bool _globalKeyHandler(KeyEvent event) {
    if (kIsWeb) return false;

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.backspace ||
         event.logicalKey == LogicalKeyboardKey.delete)) {
      if (_tryAtomicMentionDelete()) {
        return true;
      }
    }

    return false;
  }

  /// Tries to paste an image or file from the clipboard into pending attachments.
  /// Returns true when clipboard content was handled as an attachment.
  Future<bool> _tryPasteImageFromClipboard() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isMacOS) {
        return await _tryPasteImageFromClipboardMacOS();
      }
      if (Platform.isWindows || Platform.isLinux) {
        return await _tryPasteImageFromClipboardDesktop();
      }
    } catch (e) {
      debugLog('📋 [paste] Error: $e');
    }
    return false;
  }

  Future<bool> _tryPasteImageFromClipboardMacOS() async {
    final filePaths = await _pasteboardChannel.invokeMethod<List>('getFileURLs');
    if (filePaths != null && filePaths.isNotEmpty) {
      for (final pathObj in filePaths) {
        final path = pathObj as String;
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = path.split('/').last;
          _addPasteAttachment(
            bytes: Uint8List.fromList(bytes),
            fileName: fileName,
            filePath: path,
          );
          debugLog('📋 [paste] Added file from clipboard: $fileName (${bytes.length} bytes)');
        }
      }
      safeSetState(() {});
      return true;
    }

    final rawImage =
        await _pasteboardChannel.invokeMethod<dynamic>('getImageData');
    final imageData = rawImage is Uint8List
        ? rawImage
        : (rawImage is List
            ? Uint8List.fromList(rawImage.cast<int>())
            : null);
    if (imageData != null && imageData.isNotEmpty) {
      final fileName =
          'paste_${DateTime.now().millisecondsSinceEpoch}.png';
      _addPasteAttachment(bytes: imageData, fileName: fileName);
      debugLog('📋 [paste] Added image from clipboard: $fileName (${imageData.length} bytes)');
      safeSetState(() {});
      return true;
    }

    return false;
  }

  Future<bool> _tryPasteImageFromClipboardDesktop() async {
    final items = await DesktopClipboardPasteHelper.readAll();
    if (items.isEmpty) return false;

    for (final item in items) {
      _addPasteAttachment(
        bytes: item.bytes,
        fileName: item.fileName,
        filePath: item.filePath,
      );
      debugLog('📋 [paste] Added from clipboard: ${item.fileName} (${item.bytes.length} bytes)');
    }
    safeSetState(() {});
    return true;
  }

  @override
  void dispose() {
    _userLookupDebounce?.cancel();
    _desktopMessagesPollTimer?.cancel();
    if (_desktopScrollListener != null) {
      _model.itemPositionsListener?.itemPositions
          .removeListener(_desktopScrollListener!);
    }
    HardwareKeyboard.instance.removeHandler(_globalKeyHandler);
    _unregisterWebPaste?.call();
    _quillController?.removeListener(_onQuillTextChanged);
    _quillController?.dispose();
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (widget.chatReference == null) return;
    final members = widget.chatReference!.members;
    final users = <UsersRecord>[];
    for (final ref in members) {
      if (ref == currentUserReference) continue;
      try {
        final user = await fsGetUserOnce(ref);
        users.add(user);
      } catch (_) {}
    }
    if (mounted) {
      debugLog('📋 [_loadMembers] Loaded ${users.length} members for chat ${widget.chatReference!.reference.id}, total members in doc: ${members.length}');
      setState(() => _memberUsers = users);
    }
  }

  void _onQuillTextChanged() {
    if (_quillController == null) return;
    final doc = _quillController!.document;
    final selection = _quillController!.selection;
    if (selection.baseOffset != selection.extentOffset) return;

    final cursorPos = selection.baseOffset;
    final text = doc.toPlainText();
    if (cursorPos <= 0 || cursorPos > text.length) {
            setState(() { _mentionActive = false; _filteredMentionUsers = []; });
      return;
    }

    // Find the last '@' before cursor
    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex == -1) {
            setState(() { _mentionActive = false; _filteredMentionUsers = []; });
      return;
    }

    // Extract query after '@'
    final query = textBeforeCursor.substring(atIndex + 1);
    // If query contains space after a completed mention, dismiss
    if (query.contains('\n')) {
            setState(() { _mentionActive = false; _filteredMentionUsers = []; });
      return;
    }

    _mentionStartOffset = atIndex;
    final filtered = _memberUsers.where((u) {
      final name = u.displayName.toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      if (_mentionActive) {
        setState(() {
          _mentionActive = false;
          _filteredMentionUsers = [];
        });
      }
      return;
    }

    setState(() {
      _mentionActive = true;
      _filteredMentionUsers = filtered;
      _selectedMentionIndex = 0;
    });
  }


  void _selectMention(UsersRecord user) {
          setState(() { _mentionActive = false; _filteredMentionUsers = []; });
    if (_quillController == null || _mentionStartOffset < 0) return;

    final cursorPos = _quillController!.selection.baseOffset;
    final deleteLength = cursorPos - _mentionStartOffset;

    // Replace "@query" with the display text "@Name "
    final displayText = '@${user.displayName} ';
    // The mention itself is "@Name" (without trailing space)
    final mentionText = '@${user.displayName}';
    
    _quillController!.replaceText(
      _mentionStartOffset,
      deleteLength,
      displayText,
      TextSelection.collapsed(offset: _mentionStartOffset + displayText.length),
    );

    // Track this mention: store uid + name + offset + length
    _pendingMentions.add(_MentionEntry(
      uid: user.reference.id,
      displayName: user.displayName,
    ));
    
    // Record the mention range for atomic deletion (without trailing space)
    // Adjust existing ranges first
    for (final m in _mentionRanges) {
      if (m.offset >= _mentionStartOffset) {
        m.offset += displayText.length - deleteLength;
      }
    }
    _mentionRanges.add(_MentionRange(
      offset: _mentionStartOffset,
      length: mentionText.length,
      uid: user.reference.id,
      displayName: user.displayName,
    ));

    _mentionStartOffset = -1;
  }

  // Track pending mentions for the current message being composed
  final List<_MentionEntry> _pendingMentions = [];

  String _injectMentionMarkup(String plainText) {
    // Replace each @DisplayName with <@uid|DisplayName>
    var result = plainText;
    // Process longest names first to avoid partial matches
    final sorted = List<_MentionEntry>.from(_pendingMentions)
      ..sort((a, b) => b.displayName.length.compareTo(a.displayName.length));
    
    // Track which mentions have been injected to avoid duplicates
    final injected = <String>{};
    for (final m in sorted) {
      final key = '${m.uid}_${m.displayName}';
      if (injected.contains(key)) continue;
      
      // Use replaceFirst to handle each mention occurrence
      final replaced = result.replaceFirst(
        '@${m.displayName}',
        '<@${m.uid}|${m.displayName}>',
      );
      if (replaced != result) {
        result = replaced;
        injected.add(key);
      }
    }
    return result;
  }

  /// Check if cursor is at a mention boundary and handle atomic deletion.
  /// Called from the keyboard handler when backspace/delete is pressed.
  /// Returns true if a mention was atomically deleted (caller should skip default behavior).
  bool _tryAtomicMentionDelete() {
    if (_quillController == null || _mentionRanges.isEmpty) return false;
    final sel = _quillController!.selection;
    
    // If there's a range selection that overlaps a mention, let QuillEditor handle it normally
    // We only intercept single-cursor backspace
    if (sel.baseOffset != sel.extentOffset) return false;
    
    final cursorPos = sel.baseOffset;
    
    // Find a mention where cursor is at its end (just pressed backspace after mention)
    // or within the mention text
    for (int i = 0; i < _mentionRanges.length; i++) {
      final m = _mentionRanges[i];
      final mentionEnd = m.offset + m.length;
      // Cursor is right after mention end or inside the mention
      if (cursorPos > m.offset && cursorPos <= mentionEnd) {
        // Delete the entire mention
        _quillController!.replaceText(
          m.offset,
          m.length,
          '',
          TextSelection.collapsed(offset: m.offset),
        );
        // Remove this mention range and shift others
        _mentionRanges.removeAt(i);
        for (final other in _mentionRanges) {
          if (other.offset > m.offset) {
            other.offset -= m.length;
          }
        }
        // Also remove from _pendingMentions
        _pendingMentions.removeWhere((p) => p.uid == m.uid && p.displayName == m.displayName);
        return true;
      }
    }
    return false;
  }

  Future<void> _handleSendMessage(String content) async {
    if (widget.chatReference == null) return;

    // CRITICAL: Capture the target chat reference NOW, before any async work.
    // This prevents messages being sent to the wrong chat if the user switches
    // groups during file upload (which can take up to 60 seconds).
    final targetChatRef = widget.chatReference!.reference;
    final targetChatId = targetChatRef.id;

    final hasText = content.trim().isNotEmpty;
    final hasAttachments = _model.pendingAttachments.isNotEmpty;
    debugLog('📤 [send] _handleSendMessage called: hasText=$hasText, hasAttachments=$hasAttachments, content="${content.length > 50 ? content.substring(0, 50) : content}", targetChat=$targetChatId');
    if (!hasText && !hasAttachments) return;

    // Handle edit mode: update existing message instead of creating new
    if (_model.editingMessage != null) {
      final editMsg = _model.editingMessage!;
      String processedContent = hasText ? _injectMentionMarkup(content) : '';
      
      // Fallback: if _pendingMentions was empty (e.g. mention tracking drifted),
      // re-parse the ORIGINAL message's mentions and re-inject any that still
      // appear as @DisplayName in the edited content.
      if (_pendingMentions.isEmpty && editMsg.content.contains('<@')) {
        final origMentionPattern = RegExp(r'<@([^|]+)\|([^>]+)>');
        final origMatches = origMentionPattern.allMatches(editMsg.content);
        for (final m in origMatches) {
          final uid = m.group(1)!;
          final displayName = m.group(2)!;
          processedContent = processedContent.replaceFirst(
            '@$displayName',
            '<@$uid|$displayName>',
          );
        }
      }
      
      _pendingMentions.clear();
      _mentionRanges.clear();
      try {
        await fsPatchDocument(editMsg.reference, {
          'content': processedContent,
          'is_edited': true,
          'edited_at': getCurrentTimestamp,
        });
        debugLog('✏️ [edit] Message updated: ${editMsg.reference.id}');
      } catch (e) {
        debugLog('❌ [edit] Error updating message: $e');
      }
      _model.editingMessage = null;
      safeSetState(() {});
      _afterMessagesMutated();
      return;
    }

    // Inject mention markup before sending
    var processedContent = hasText ? _injectMentionMarkup(content) : '';
    _pendingMentions.clear();
    _mentionRanges.clear();

    // Apply outgoing translation if enabled
    if (hasText && FFAppState().aiTranslationEnabled) {
      try {
        processedContent = await translateOutgoingMessage(processedContent);
      } catch (e) {
        debugLog('⚠️ [send] Outgoing translation failed (sending original): $e');
      }
    }

    _model.isSending = true;
    safeSetState(() {});

    try {
      // 1. Upload and send pending attachments
      if (hasAttachments) {
        final attachments = List<PendingAttachment>.from(_model.pendingAttachments);
        _model.clearPendingAttachments();
        safeSetState(() {});

        for (final att in attachments) {
          try {
            // Safety check: abort if user has switched to a different chat
            if (widget.chatReference?.reference.id != targetChatId) {
              debugLog('⚠️ [send] Chat switched during upload — aborting send to $targetChatId');
              return;
            }

            debugLog('⬆️ [upload] Starting upload: ${att.fileName} (${att.file.bytes.length} bytes)');
            final downloadUrl = await uploadData(att.file.storagePath, att.file.bytes)
                .timeout(const Duration(seconds: 60));
            debugLog('⬆️ [upload] Upload complete: $downloadUrl');
            if (downloadUrl == null) {
              debugLog('❌ Failed to upload file: ${att.fileName}');
              continue;
            }

            // Safety check again after upload completes
            if (widget.chatReference?.reference.id != targetChatId) {
              debugLog('⚠️ [send] Chat switched after upload — aborting send to $targetChatId');
              return;
            }

            MessageType msgType;
            Map<String, dynamic> messageData;

            switch (att.type) {
              case AttachmentType.image:
                msgType = MessageType.image;
                messageData = createMessagesRecordData(
                  senderRef: currentUserReference,
                  content: '',
                  createdAt: getCurrentTimestamp,
                  messageType: msgType,
                  image: downloadUrl,
                );
                break;
              case AttachmentType.video:
                msgType = MessageType.video;
                messageData = createMessagesRecordData(
                  senderRef: currentUserReference,
                  content: '',
                  createdAt: getCurrentTimestamp,
                  messageType: msgType,
                  video: downloadUrl,
                );
                break;
              case AttachmentType.file:
                msgType = MessageType.file;
                messageData = createMessagesRecordData(
                  senderRef: currentUserReference,
                  content: '',
                  createdAt: getCurrentTimestamp,
                  messageType: msgType,
                  attachmentUrl: downloadUrl,
                );
                // Store filename separately so the file card picks it up via _getResolvedFileName()
                messageData['file_name'] = att.fileName;
                break;
            }

            // Use captured targetChatRef, not widget.chatReference
            await fsCreateMessage(targetChatRef, messageData);

            await fsPatchDocument(targetChatRef, {
              'last_message': '📎 ${att.fileName}',
              'last_message_at': getCurrentTimestamp,
              'last_message_sent': currentUserReference,
              'last_message_type': msgType.serialize(),
              'last_message_seen': [currentUserReference],
            });
            _notifySidebarPreview({
              'last_message': '📎 ${att.fileName}',
              'last_message_at': getCurrentTimestamp,
              'last_message_sent': currentUserReference,
              'last_message_type': msgType.serialize(),
              'last_message_seen': [currentUserReference],
            });
          } catch (uploadError) {
            debugLog('❌ Error uploading ${att.fileName}: $uploadError');
          }
        }
      }

      // 2. Send text message (if any)
      if (hasText) {
        // Safety check before sending text
        if (widget.chatReference?.reference.id != targetChatId) {
          debugLog('⚠️ [send] Chat switched before text send — aborting send to $targetChatId');
          return;
        }

         final messageData = createMessagesRecordData(
          senderRef: currentUserReference,
          content: processedContent,
          createdAt: getCurrentTimestamp,
          messageType: MessageType.text,
          replyTo: _model.replyingToMessage?.reference.id,
          replyToContent: _model.replyingToMessage?.content,
          replyToSender: _model.replyingToMessage != null
              ? (_resolveUserName(_model.replyingToMessage!))
              : null,
        );

        // Use captured targetChatRef, not widget.chatReference
        await fsCreateMessage(targetChatRef, messageData);

        // Update chat's last_message fields for preview
        final previewContent = processedContent.replaceAllMapped(
          RegExp(r'<@[^|]+\|([^>]+)>'),
          (m) => '@${m.group(1)}',
        );
        final previewPatch = {
          'last_message': previewContent.length > 100 ? previewContent.substring(0, 100) : previewContent,
          'last_message_at': getCurrentTimestamp,
          'last_message_sent': currentUserReference,
          'last_message_type': MessageType.text.serialize(),
          'last_message_seen': [currentUserReference],
        };
        await fsPatchDocument(targetChatRef, previewPatch);
        _notifySidebarPreview(previewPatch);
      }

      _model.messageTextController?.clear();
      _model.replyingToMessage = null;
      // Clear draft for this chat since message was sent
      _clearDraft(targetChatId);
      // Re-request focus so the keyboard stays up AND focus is properly bound
      // (fixes iOS issue where keyboard stays but focus node desyncs)
      if (!kIsWeb && Platform.isIOS) {
        _model.messageFocusNode?.requestFocus();
      }
    } catch (e) {
      debugLog('Error sending message: $e');
    } finally {
      _model.isSending = false;
      safeSetState(() {});
      _afterMessagesMutated();
    }
  }

  Future<void> _handleScheduleMessage(
      String content, DateTime scheduledAt) async {
    if (widget.chatReference == null) return;
    content = content.trim();
    if (content.isEmpty && _model.pendingAttachments.isEmpty) return;

    _model.isSending = true;
    safeSetState(() {});

    try {
      final messageData = createMessagesRecordData(
        senderRef: currentUserReference,
        content: content,
        createdAt: getCurrentTimestamp,
        messageType: MessageType.text,
      );

      await fsCreateScheduledMessage({
        'chat_ref': widget.chatReference!.reference,
        'scheduled_send_at': Timestamp.fromDate(scheduledAt),
        'status': 'pending',
        'message_data': messageData,
        'created_at': getCurrentTimestamp,
      });

      _model.messageTextController?.clear();
      _model.replyingToMessage = null;
      _model.clearPendingAttachments();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message scheduled for ${DateFormat('MMM d, h:mm a').format(scheduledAt)}',
          ),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );
    } catch (e) {
      debugLog('Error scheduling message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to schedule message'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      _model.isSending = false;
      safeSetState(() {});
    }
  }

  Future<void> _handleSendVoiceMessage(String? audioPath, Duration duration, {Uint8List? audioBytes}) async {
    if (widget.chatReference == null) return;

    final targetChatRef = widget.chatReference!.reference;
    final targetChatId = targetChatRef.id;

    debugLog('🎙️ [send] _handleSendVoice called: path=$audioPath, duration=${duration.inSeconds}s, targetChat=$targetChatId, webBytes=${audioBytes?.length ?? 0}');

    _model.isSending = true;
    safeSetState(() {});

    try {
      Uint8List bytes;
      String fileName;

      if (kIsWeb && audioBytes != null) {
        // Web: use in-memory bytes directly
        bytes = audioBytes;
        fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.webm';
      } else if (audioPath != null) {
        // Native: read from file
        final file = File(audioPath);
        if (!await file.exists()) {
          throw Exception('Audio file not found at $audioPath');
        }
        bytes = await file.readAsBytes();
        fileName = audioPath.split('/').last;
      } else {
        throw Exception('No audio data available');
      }

      final storagePath = 'users/$currentUserUid/uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      debugLog('⬆️ [upload] Uploading voice message to $storagePath');
      final downloadUrl = await uploadData(storagePath, Uint8List.fromList(bytes));
      if (downloadUrl == null) {
        throw Exception('Failed to upload voice message.');
      }

      final messageData = createMessagesRecordData(
        senderRef: currentUserReference,
        content: '',
        createdAt: getCurrentTimestamp,
        messageType: MessageType.voice,
        audioPath: downloadUrl,
        audio: downloadUrl,
      );

      await fsCreateMessage(targetChatRef, messageData);

      final lastMessageText = '[语音] ${duration.inSeconds}"';
      
      final voicePreviewPatch = {
        'last_message': lastMessageText,
        'last_message_at': getCurrentTimestamp,
        'last_message_sent': currentUserReference,
        'last_message_type': MessageType.voice.serialize(),
        'last_message_seen': [currentUserReference],
      };
      await fsPatchDocument(targetChatRef, voicePreviewPatch);
      _notifySidebarPreview(voicePreviewPatch);

      debugLog('✅ [send] Voice message sent successfully');

      // Update unread counts (best-effort, don't fail the send if permissions are restricted)
      if (!useWindowsFirestoreRest) {
        try {
          final chatDoc = await targetChatRef.get();
          if (chatDoc.exists) {
            final chatRecord = ChatsRecord.fromSnapshot(chatDoc);
            final unreadCountQuery =
                await targetChatRef.collection('unread_counts').get();
            for (final userRef in chatRecord.members) {
              if (userRef != currentUserReference) {
                final docs =
                    unreadCountQuery.docs.where((d) => d.id == userRef.id);
                final doc = docs.isNotEmpty ? docs.first : null;
                if (doc != null) {
                  await doc.reference.update({'count': FieldValue.increment(1)});
                } else {
                  await targetChatRef
                      .collection('unread_counts')
                      .doc(userRef.id)
                      .set({'count': 1});
                }
              }
            }
          }
        } catch (unreadError) {
          debugLog(
              '⚠️ [send] Could not update unread counts (non-fatal): $unreadError');
        }
      }
    } catch (e, stackTrace) {
      debugLog('❌ [send] Error sending voice message: $e');
      debugLog('❌ [send] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送语音失败: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } finally {
      _model.isSending = false;
      safeSetState(() {});
      _afterMessagesMutated();
    }
  }

  /// Checks pasteboard for image data or file URLs and adds as pending attachments.
  /// macOS uses a native MethodChannel; Windows/Linux use [super_clipboard].
  static const _pasteboardChannel = MethodChannel('com.focuskpi.linkedup/pasteboard');

  void _addPasteAttachment({
    required Uint8List bytes,
    required String fileName,
    String? filePath,
  }) {
    final ext = fileName.split('.').last.toLowerCase();
    final type = (ext == 'mp4' || ext == 'mov' || ext == 'avi' || ext == 'mkv')
        ? AttachmentType.video
        : (ext == 'png' ||
                ext == 'jpg' ||
                ext == 'jpeg' ||
                ext == 'gif' ||
                ext == 'webp' ||
                ext == 'heic' ||
                ext == 'bmp' ||
                ext == 'tiff')
            ? AttachmentType.image
            : AttachmentType.file;

    final storagePath =
        'users/$currentUserUid/uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    _model.addPendingAttachment(PendingAttachment(
      file: SelectedFile(
        storagePath: storagePath,
        filePath: filePath,
        bytes: bytes,
      ),
      fileName: fileName,
      type: type,
    ));
  }

  /// Handles paste events from the web browser.
  void _handleWebPaste(List<WebPastedFile> files) {
    for (final file in files) {
      final ext = file.fileName.split('.').last.toLowerCase();
      final type = (ext == 'mp4' || ext == 'mov' || ext == 'avi' || ext == 'mkv')
          ? AttachmentType.video
          : (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'gif' || ext == 'webp' || ext == 'heic' || file.mimeType.startsWith('image/'))
              ? AttachmentType.image
              : AttachmentType.file;

      final fileName = file.fileName.isEmpty ? 'paste_${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'png' : ext}' : file.fileName;
      final storagePath = 'users/$currentUserUid/uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      _model.addPendingAttachment(PendingAttachment(
        file: SelectedFile(
          storagePath: storagePath,
          bytes: file.bytes,
        ),
        fileName: fileName,
        type: type,
      ));
      debugLog('📋 [web-paste] Added: $fileName (${file.bytes.length} bytes)');
    }
    safeSetState(() {});
  }

  bool _isDragging = false;

  /// Handles files dropped from Finder / Desktop onto the chat area.
  /// Uses XFile.readAsBytes() for cross-platform compatibility (works on web too).
  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    for (final item in details.files) {
      try {
        // Use XFile API (readAsBytes) instead of dart:io File for web compatibility
        final bytes = await item.readAsBytes();
        final fileName = item.name.isNotEmpty ? item.name : item.path.split('/').last;
        final ext = fileName.split('.').last.toLowerCase();
        final type = (ext == 'mp4' || ext == 'mov' || ext == 'avi' || ext == 'mkv')
            ? AttachmentType.video
            : (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'gif' || ext == 'webp' || ext == 'heic')
                ? AttachmentType.image
                : AttachmentType.file;

        final storagePath = 'users/$currentUserUid/uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        _model.addPendingAttachment(PendingAttachment(
          file: SelectedFile(
            storagePath: storagePath,
            filePath: kIsWeb ? null : item.path,
            bytes: Uint8List.fromList(bytes),
          ),
          fileName: fileName,
          type: type,
        ));
        debugLog('📂 [drop] Added file: $fileName (${bytes.length} bytes)');
      } catch (e) {
        debugLog('📂 [drop] Error processing dropped file: $e');
      }
    }
    safeSetState(() {});
  }

  /// Image URLs on a message (`images` preferred, else single `image`).
  List<String> _photoUrlsForMessage(MessagesRecord message) {
    if (message.images.isNotEmpty) {
      return message.images.where((u) => u.trim().isNotEmpty).toList();
    }
    if (message.image.trim().isNotEmpty) {
      return [message.image];
    }
    return const [];
  }

  bool _isPhotoOnlyMessage(MessagesRecord message) {
    if (message.isSystemMessage) return false;
    final urls = _photoUrlsForMessage(message);
    if (urls.isEmpty) return false;
    // Treat as photo message when typed as image, or content is empty with media.
    if (message.messageType == MessageType.image) return true;
    final content = message.content.trim();
    return content.isEmpty;
  }

  bool _samePhotoBurst(MessagesRecord a, MessagesRecord b) {
    if (a.senderRef == null || b.senderRef == null) return false;
    if (a.senderRef != b.senderRef) return false;
    if (!_isPhotoOnlyMessage(a) || !_isPhotoOnlyMessage(b)) return false;
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null || bTime == null) return false;
    // iMessage-style: photos sent within a short window.
    return aTime.difference(bTime).abs() <= const Duration(seconds: 60);
  }

  /// messages are newest-first (index 0 = newest). Returns display rows that
  /// collapse consecutive photo bursts into a single stack item.
  List<_ThreadDisplayItem> _buildThreadDisplayItems(
    List<MessagesRecord> messages,
  ) {
    final items = <_ThreadDisplayItem>[];
    var i = 0;
    while (i < messages.length) {
      final message = messages[i];
      final urls = _photoUrlsForMessage(message);

      if (!_isPhotoOnlyMessage(message)) {
        items.add(_ThreadDisplayItem.single(message));
        i++;
        continue;
      }

      // Gather consecutive photo burst toward older messages (higher indices).
      final group = <MessagesRecord>[message];
      var j = i + 1;
      while (j < messages.length && _samePhotoBurst(group.last, messages[j])) {
        group.add(messages[j]);
        j++;
      }

      // Collect URLs oldest → newest for natural swipe order.
      final allUrls = <String>[];
      for (final m in group.reversed) {
        allUrls.addAll(_photoUrlsForMessage(m));
      }

      if (allUrls.length <= 1) {
        items.add(_ThreadDisplayItem.single(message));
      } else {
        items.add(_ThreadDisplayItem.photoStack(
          messages: group,
          imageUrls: allUrls,
        ));
      }
      i = j;
    }
    return items;
  }

  void _scrollToMessageById(String messageId, List<MessagesRecord> messages) {
    final items = _buildThreadDisplayItems(messages);
    for (int i = 0; i < items.length; i++) {
      if (items[i].containsMessageId(messageId)) {
        _model.itemScrollController?.scrollTo(
          index: i,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        return;
      }
    }
  }

  Widget _buildMessageScrollList(List<MessagesRecord> messages) {
    if (messages.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }

    final displayItems = _buildThreadDisplayItems(messages);

    return ScrollablePositionedList.builder(
      itemCount: displayItems.length,
      itemScrollController: _model.itemScrollController,
      itemPositionsListener: _model.itemPositionsListener,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final item = displayItems[index];

        bool showTimestamp = false;
        bool isConsecutive = false;
        bool isFollowedByConsecutive = false;

        final message = item.primaryMessage;

        // Compare against neighboring *display* rows for spacing/timestamps.
        if (index == displayItems.length - 1) {
          showTimestamp = true;
        } else {
          final previousMessage = displayItems[index + 1].primaryMessage;
          if (message.createdAt != null && previousMessage.createdAt != null) {
            final difference =
                message.createdAt!.difference(previousMessage.createdAt!);
            if (difference.inMinutes.abs() >= 5) {
              showTimestamp = true;
            }
          }
          if (!showTimestamp &&
              !message.isSystemMessage &&
              !previousMessage.isSystemMessage &&
              message.senderRef != null &&
              previousMessage.senderRef != null) {
            isConsecutive = message.senderRef == previousMessage.senderRef;
          }
        }

        if (index > 0) {
          final nextMessage = displayItems[index - 1].primaryMessage;
          var showTimestampBeforeNext = false;
          if (message.createdAt != null && nextMessage.createdAt != null) {
            final difference =
                nextMessage.createdAt!.difference(message.createdAt!);
            if (difference.inMinutes.abs() >= 5) {
              showTimestampBeforeNext = true;
            }
          }
          if (!showTimestampBeforeNext &&
              !message.isSystemMessage &&
              !nextMessage.isSystemMessage &&
              message.senderRef != null &&
              nextMessage.senderRef != null) {
            isFollowedByConsecutive =
                message.senderRef == nextMessage.senderRef;
          }
        }

        if (item.isPhotoStack) {
          final isMine =
              message.senderRef?.path == currentUserReference?.path;
          final stackName = _resolveUserName(message);
          return PhotoStackBubble(
            key: ValueKey(
              'photo_stack_${item.messages.map((m) => m.reference.id).join('_')}',
            ),
            imageUrls: item.imageUrls,
            isMine: isMine,
            messageId: message.reference.id,
            senderName: stackName,
            isGroup: widget.chatReference?.isGroup ?? false,
            isConsecutive: isConsecutive,
            isFollowedByConsecutive: isFollowedByConsecutive,
          );
        }

        if (message.senderRef != null &&
            _resolveUserName(message).isEmpty) {
          _ensureUserCached(message);
        }

        final resolvedName = _resolveUserName(message);

        try {
          return ChatThreadWidget(
            key: ValueKey('msg_${message.reference.id}'),
            message: message,
            senderImage: _resolveUserPhoto(message),
            name: resolvedName,
            chatRef: widget.chatReference!.reference,
            userRef: message.senderRef ?? currentUserReference,
            action: () async {},
            onMessageLongPress: widget.onMessageLongPress,
            onMessageAction: widget.onMessageAction,
            onMessagesMutated: _afterMessagesMutated,
            activeSelectionId: widget.activeSelectionId,
            isSelectionMode: widget.isSelectionMode,
            selectedMessages: widget.selectedMessages,
            onMessageToggled: widget.onMessageToggled,
            isGroup: widget.chatReference?.isGroup ?? false,
            isConsecutive: isConsecutive,
            isFollowedByConsecutive: isFollowedByConsecutive,
            showTimestamp: showTimestamp,
            onReplyToMessage: (msg) {
              setState(() {
                _model.replyingToMessage = msg;
              });
              _model.messageFocusNode?.requestFocus();
            },
            onEditMessage: (msg) {
              setState(() {
                _model.editingMessage = msg;
                _model.replyingToMessage = null;
              });
              if (_quillController != null) {
                _quillController!.clear();
                final content = msg.content;
                _pendingMentions.clear();
                _mentionRanges.clear();
                if (content.isNotEmpty) {
                  final mentionPattern = RegExp(r'<@([^|]+)\|([^>]+)>');
                  final matches = mentionPattern.allMatches(content).toList();
                  final display = content.replaceAllMapped(
                    mentionPattern,
                    (m) => '@${m.group(2)}',
                  );
                  for (final match in matches) {
                    final uid = match.group(1)!;
                    final displayName = match.group(2)!;
                    _pendingMentions.add(_MentionEntry(
                      uid: uid,
                      displayName: displayName,
                    ));
                    final displayUpToThisPoint = content
                        .substring(0, match.start)
                        .replaceAllMapped(
                          mentionPattern,
                          (m) => '@${m.group(2)}',
                        );
                    final searchFrom = displayUpToThisPoint.length;
                    final atName = '@$displayName';
                    final mentionOffset = display.indexOf(atName, searchFrom);
                    if (mentionOffset >= 0) {
                      _mentionRanges.add(_MentionRange(
                        uid: uid,
                        displayName: displayName,
                        offset: mentionOffset,
                        length: atName.length,
                      ));
                    }
                  }
                  _quillController!.document.insert(0, display);
                  _quillController!.moveCursorToEnd();
                }
              }
              _model.messageFocusNode?.requestFocus();
            },
            onScrollToMessage: (messageId) {
              _scrollToMessageById(messageId, messages);
            },
          );
        } catch (e) {
          debugLog(
              '❌ [itemBuilder] Error rendering message ${message.reference.id}: $e');
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildDesktopMessageList() {
    if (_desktopMessages == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        _buildMessageScrollList(_desktopMessages!),
        if (_desktopLoadingOlder)
          const Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chatReference == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final threadBody = Stack(
        children: [
    GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Column(
        children: [
          // Message List
          Expanded(
            child: !_messagesStreamReady
                ? const Center(child: CircularProgressIndicator())
                : _staggerDesktopFirestore
                    ? _buildDesktopMessageList()
                    : StreamBuilder<List<MessagesRecord>>(
              stream: queryMessagesRecord(
                parent: widget.chatReference!.reference,
                queryBuilder: (messagesRecord) =>
                    messagesRecord.orderBy('created_at', descending: true),
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugLog('❌ [StreamBuilder] Error: ${snapshot.error}');
                  return Center(
                    child: Text(
                      'Error loading messages',
                      style: TextStyle(color: FlutterFlowTheme.of(context).error),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                return _buildMessageScrollList(messages);
              },
            ),
          ),

          // Attachment Previews
          if (_model.pendingAttachments.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _model.pendingAttachments.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final att = _model.pendingAttachments[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 64,
                          height: 64,
                          color: Colors.grey[200],
                          child: att.type == AttachmentType.image
                              ? Image.memory(
                                  att.file.bytes,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image, color: Colors.grey),
                                )
                              : att.type == AttachmentType.video
                                  ? const Icon(Icons.videocam, color: Colors.blue, size: 28)
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.insert_drive_file, color: Colors.grey, size: 24),
                                        const SizedBox(height: 2),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Text(
                                            att.fileName,
                                            style: const TextStyle(fontSize: 8, color: Colors.grey),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            _model.removePendingAttachmentAt(index);
                            safeSetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // Editing indicator bar
          if (_model.editingMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                border: Border(
                  top: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(CupertinoIcons.pencil, size: 16, color: const Color(0xFFFF9500)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Editing message',
                          style: TextStyle(
                            fontFamily: chatMessageFontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF9500),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _model.editingMessage!.content.isNotEmpty
                              ? _model.editingMessage!.content.replaceAllMapped(
                                  RegExp(r'<@[^|]+\|([^>]+)>'),
                                  (m) => '@${m.group(1)}',
                                )
                              : '📎 Attachment',
                          style: TextStyle(
                            fontFamily: chatMessageFontFamily,
                            fontSize: 12,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _model.editingMessage = null;
                        _quillController?.clear();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Reply preview bar
          if (_model.replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                border: Border(
                  top: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _resolveUserName(_model.replyingToMessage!),
                          style: TextStyle(
                            fontFamily: chatMessageFontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _model.replyingToMessage!.content.isNotEmpty
                              ? _model.replyingToMessage!.content
                              : (_model.replyingToMessage!.image.isNotEmpty
                                  ? '📷 Photo'
                                  : (_model.replyingToMessage!.video.isNotEmpty
                                      ? '🎥 Video'
                                      : '📎 File')),
                          style: TextStyle(
                            fontFamily: chatMessageFontFamily,
                            fontSize: 12,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _model.replyingToMessage = null;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Wrap mention list + input in Focus to intercept arrow/enter keys
          Focus(
            skipTraversal: true,
            onKeyEvent: (node, event) {
              if (!_mentionActive || _filteredMentionUsers.isEmpty) {
                return KeyEventResult.ignored;
              }
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.arrowDown) {
                setState(() {
                  _selectedMentionIndex = (_selectedMentionIndex + 1) % _filteredMentionUsers.length;
                });
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowUp) {
                setState(() {
                  _selectedMentionIndex = (_selectedMentionIndex - 1 + _filteredMentionUsers.length) % _filteredMentionUsers.length;
                });
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
                if (_selectedMentionIndex >= 0 && _selectedMentionIndex < _filteredMentionUsers.length) {
                  _selectMention(_filteredMentionUsers[_selectedMentionIndex]);
                }
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.escape) {
                setState(() {
                  _mentionActive = false;
                  _filteredMentionUsers = [];
                  _selectedMentionIndex = 0;
                });
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

          // Mention list (inline, above input)
          if (_mentionActive && _filteredMentionUsers.isNotEmpty)
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                border: Border(
                  top: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 0.5,
                  ),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(vertical: 4),
                itemCount: _filteredMentionUsers.length,
                itemBuilder: (_, i) {
                  final user = _filteredMentionUsers[i];
                  final isSelected = i == _selectedMentionIndex;
                  return InkWell(
                    onTap: () => _selectMention(user),
                    child: Container(
                      color: isSelected
                          ? FlutterFlowTheme.of(context).primaryBackground
                          : Colors.transparent,
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: user.photoUrl.isNotEmpty
                                ? NetworkImage(user.photoUrl) as ImageProvider
                                : null,
                            backgroundColor: Color(0xFFE5E7EB),
                            child: user.photoUrl.isEmpty
                                ? Icon(Icons.person, size: 14, color: Color(0xFF9CA3AF))
                                : null,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              user.displayName,
                              style: TextStyle(
                                fontFamily: chatMessageFontFamily,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Rich Input Area — always visible; message list loads independently
          RichChatInputWidget(
            onTryPasteImage: !kIsWeb &&
                    (Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS)
                ? _tryPasteImageFromClipboard
                : null,
            onSend: _handleSendMessage,
            onVoiceSend: _handleSendVoiceMessage,
            onScheduleMessage: _handleScheduleMessage,
            focusNode: _model.messageFocusNode,
            controller: _quillController,
            placeholder: 'Message...',
            isUploading: _model.isSending ?? false,
            hasAttachments: _model.pendingAttachments.isNotEmpty,
            isMentionActive: _mentionActive,
            onMentionConfirm: () {
              if (_selectedMentionIndex >= 0 && _selectedMentionIndex < _filteredMentionUsers.length) {
                _selectMention(_filteredMentionUsers[_selectedMentionIndex]);
              }
            },
            onMention: () {
              if (_quillController != null) {
                final pos = _quillController!.selection.baseOffset;
                _quillController!.replaceText(pos, 0, '@', TextSelection.collapsed(offset: pos + 1));
              }
            },
            onAttachment: () async {
              debugLog('📎 [onAttachment] File picker opening...');
              try {
                final selectedFiles = await selectFiles(
                  multiFile: false,
                );
                debugLog('📎 [onAttachment] File picker returned: ${selectedFiles?.length ?? 0} files');
                if (selectedFiles != null && selectedFiles.isNotEmpty) {
                  final file = selectedFiles.first;
                  // Use the original file path (filePath) to get the real filename,
                  // not storagePath which is a timestamp-based Firebase path
                  final fileName = (file.filePath != null && file.filePath!.isNotEmpty)
                      ? file.filePath!.split('/').last
                      : file.storagePath.split('/').last;
                  debugLog('📎 [onAttachment] File: $fileName, bytes: ${file.bytes.length}');
                  // Determine type from file extension
                  final ext = fileName.split('.').last.toLowerCase();
                  final type = (ext == 'mp4' || ext == 'mov' || ext == 'avi')
                      ? AttachmentType.video
                      : (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'gif' || ext == 'webp' || ext == 'heic')
                          ? AttachmentType.image
                          : AttachmentType.file;
                  _model.addPendingAttachment(PendingAttachment(
                    file: file,
                    fileName: fileName,
                    type: type,
                  ));
                  debugLog('📎 [onAttachment] Added to pendingAttachments, count: ${_model.pendingAttachments.length}');
                  safeSetState(() {});
                }
              } catch (e) {
                debugLog('❌ [onAttachment] Error: $e');
              }
            },
            onPhotoLibrary: () async {
              debugLog('📸 [onPhotoLibrary] Opening photo library...');
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  final fileName = picked.name.isNotEmpty ? picked.name : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  final ext = fileName.split('.').last.toLowerCase();
                  final type = (ext == 'mp4' || ext == 'mov')
                      ? AttachmentType.video
                      : AttachmentType.image;
                  final storagePath = 'users/$currentUserUid/uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName';
                  _model.addPendingAttachment(PendingAttachment(
                    file: SelectedFile(
                      storagePath: storagePath,
                      bytes: Uint8List.fromList(bytes),
                    ),
                    fileName: fileName,
                    type: type,
                  ));
                  debugLog('📸 [onPhotoLibrary] Added: $fileName (${bytes.length} bytes)');
                  safeSetState(() {});
                }
              } catch (e) {
                debugLog('❌ [onPhotoLibrary] Error: $e');
              }
            },
            onEmoji: () {
              _showInputEmojiPicker();
            },
            onCamera: () {
              // Camera logic
            },
          ),
              ],
            ),
          ),
        ],
      ),
    ),
          // Drag-and-drop overlay
          if (_isDragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withOpacity(0.5),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_upload_outlined, size: 48, color: const Color(0xFF007AFF)),
                        const SizedBox(height: 8),
                        Text(
                          'Drop files here',
                          style: TextStyle(
                            fontFamily: chatMessageFontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ], // Stack children
      ); // Stack

    if (_staggerDesktopFirestore) {
      return threadBody;
    }
    return DropTarget(
      onDragDone: _handleDroppedFiles,
      onDragEntered: (_) => safeSetState(() => _isDragging = true),
      onDragExited: (_) => safeSetState(() => _isDragging = false),
      child: threadBody,
    );
  }

  void _showInputEmojiPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 360,
              height: 340,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.06),
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    // Compact header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Text(
                            'Emoji',
                            style: TextStyle(
                              fontFamily: chatMessageFontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color:
                                  isDark ? Colors.white24 : Colors.black.withOpacity(0.15),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                    ),
                    // Emoji Picker
                    Expanded(
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          final controller = _quillController;
                          if (controller != null) {
                            final index = controller.selection.baseOffset;
                            final insertAt = index >= 0
                                ? index
                                : controller.document.length - 1;
                            controller.document.insert(insertAt, emoji.emoji);
                            controller.updateSelection(
                              TextSelection.collapsed(
                                  offset: insertAt + emoji.emoji.length),
                              ChangeSource.local,
                            );
                          }
                        },
                        config: Config(
                          height: 260,
                          checkPlatformCompatibility: true,
                          emojiViewConfig: EmojiViewConfig(
                            columns: 8,
                            emojiSizeMax: 24,
                            verticalSpacing: 0,
                            horizontalSpacing: 0,
                            gridPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            recentsLimit: 24,
                            replaceEmojiOnLimitExceed: true,
                            noRecents: Text(
                              'No Recents',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            loadingIndicator: const Center(
                              child: CupertinoActivityIndicator(radius: 10),
                            ),
                            buttonMode: ButtonMode.CUPERTINO,
                            backgroundColor: isDark
                                ? const Color(0xFF1C1C1E)
                                : Colors.white,
                          ),
                          skinToneConfig: SkinToneConfig(
                            enabled: true,
                            dialogBackgroundColor:
                                isDark ? const Color(0xFF2C2C2E) : Colors.white,
                            indicatorColor: Colors.grey,
                          ),
                          categoryViewConfig: CategoryViewConfig(
                            initCategory: Category.RECENT,
                            backgroundColor: isDark
                                ? const Color(0xFF1C1C1E)
                                : Colors.white,
                            indicatorColor:
                                FlutterFlowTheme.of(context).primary,
                            iconColor:
                                isDark ? Colors.white38 : Colors.black38,
                            iconColorSelected:
                                FlutterFlowTheme.of(context).primary,
                            tabBarHeight: 36,
                            categoryIcons: const CategoryIcons(
                              recentIcon: CupertinoIcons.clock,
                              smileyIcon: CupertinoIcons.smiley,
                              animalIcon: CupertinoIcons.tortoise,
                              foodIcon: CupertinoIcons.cart,
                              activityIcon: CupertinoIcons.sportscourt,
                              travelIcon: CupertinoIcons.car,
                              objectIcon: CupertinoIcons.lightbulb,
                              symbolIcon: CupertinoIcons.heart,
                              flagIcon: CupertinoIcons.flag,
                            ),
                          ),
                          bottomActionBarConfig: const BottomActionBarConfig(
                            enabled: false,
                          ),
                          searchViewConfig: SearchViewConfig(
                            backgroundColor: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFF2F2F7),
                            buttonIconColor:
                                isDark ? Colors.white54 : Colors.black54,
                            hintText: 'Search emoji...',
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
      ),
    );
  }
}

class _ThreadDisplayItem {
  const _ThreadDisplayItem._({
    required this.messages,
    required this.imageUrls,
    required this.isPhotoStack,
  });

  factory _ThreadDisplayItem.single(MessagesRecord message) {
    return _ThreadDisplayItem._(
      messages: [message],
      imageUrls: const [],
      isPhotoStack: false,
    );
  }

  factory _ThreadDisplayItem.photoStack({
    required List<MessagesRecord> messages,
    required List<String> imageUrls,
  }) {
    return _ThreadDisplayItem._(
      messages: messages,
      imageUrls: imageUrls,
      isPhotoStack: true,
    );
  }

  final List<MessagesRecord> messages;
  final List<String> imageUrls;
  final bool isPhotoStack;

  /// Newest message in the group (primary for alignment / timestamps).
  MessagesRecord get primaryMessage => messages.first;

  bool containsMessageId(String messageId) {
    return messages.any((m) => m.reference.id == messageId);
  }
}

class _MentionEntry {
  final String uid;
  final String displayName;
  const _MentionEntry({required this.uid, required this.displayName});
}

class _MentionRange {
  int offset;
  final int length;
  final String uid;
  final String displayName;
  _MentionRange({required this.offset, required this.length, required this.uid, required this.displayName});
}
