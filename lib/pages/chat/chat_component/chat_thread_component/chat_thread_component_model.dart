import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/chat/chat_component/chat_thread/chat_thread_widget.dart';
import 'chat_thread_component_widget.dart' show ChatThreadComponentWidget;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '/flutter_flow/upload_data.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Type of a pending attachment (not yet uploaded).
enum AttachmentType { image, video, file }

/// Represents a single pending attachment queued for upload.
class PendingAttachment {
  final SelectedFile file;
  final String fileName;
  final AttachmentType type;

  const PendingAttachment({
    required this.file,
    required this.fileName,
    required this.type,
  });
}

class ChatThreadComponentModel
    extends FlutterFlowModel<ChatThreadComponentWidget> {
  ///  Local state fields for this component.

  String? image;

  String? file;

  bool select = false;

  bool audio = false;

  String? audiopath;

  bool recording = false;

  String? audioMainUrl;

  String? videoUrl;

  SelectedFile? selectedVideoFile;

  MessagesRecord? replyingToMessage;

  MessagesRecord? editingMessage;

  // ScrollController? scrollController; // Removed for ScrollablePositionedList
  ItemScrollController? itemScrollController;
  ItemPositionsListener? itemPositionsListener;

  String? highlightedMessageId;

  bool? isSending = false;

  bool? isSendingImage = false;

  bool isMention = false;

  // Mention overlay state
  bool showMentionOverlay = false;
  String mentionQuery = '';
  List<UsersRecord> filteredMembers = [];

  // Emoji picker state
  bool showEmojiPicker = false;

  // Pending attachments list (not yet uploaded, shown as inline preview above input)
  // Supports multiple mixed-type attachments simultaneously (max 10).
  List<PendingAttachment> pendingAttachments = [];

  static const int maxPendingAttachments = 10;

  /// Add a pending attachment if under the cap. Returns false if at limit.
  bool addPendingAttachment(PendingAttachment att) {
    if (pendingAttachments.length >= maxPendingAttachments) return false;
    pendingAttachments.add(att);
    return true;
  }

  /// Remove a pending attachment by index.
  void removePendingAttachmentAt(int index) {
    if (index >= 0 && index < pendingAttachments.length) {
      pendingAttachments.removeAt(index);
    }
  }

  /// Clear all pending attachments.
  void clearPendingAttachments() {
    pendingAttachments.clear();
  }

  List<DocumentReference> userSend = [];
  void addToUserSend(DocumentReference item) => userSend.add(item);
  void removeFromUserSend(DocumentReference item) => userSend.remove(item);
  void removeAtIndexFromUserSend(int index) => userSend.removeAt(index);
  void insertAtIndexInUserSend(int index, DocumentReference item) =>
      userSend.insert(index, item);
  void updateUserSendAtIndex(int index, Function(DocumentReference) updateFn) =>
      userSend[index] = updateFn(userSend[index]);

  String text = 'Tap the mic to record your voice.';

  List<String> images = [];
  void addToImages(String item) => images.add(item);
  void removeFromImages(String item) => images.remove(item);
  void removeAtIndexFromImages(int index) => images.removeAt(index);
  void insertAtIndexInImages(int index, String item) =>
      images.insert(index, item);
  void updateImagesAtIndex(int index, Function(String) updateFn) =>
      images[index] = updateFn(images[index]);

  ///  State fields for stateful widgets in this component.

  // Models for chatThread dynamic component.
  late FlutterFlowDynamicModels<ChatThreadModel> chatThreadModels;
  // State field(s) for message widget.
  FocusNode? messageFocusNode;
  TextEditingController? messageTextController;
  String? Function(BuildContext, String?)? messageTextControllerValidator;
  // Stores action output result for [Custom Action - checkValidWords] action in IconButton widget.
  bool? isValid;
  // Stores action output result for [Custom Action - uploadAudioToStorage] action in IconButton widget.
  String? netwoekURL;
  // Stores action output result for [Backend Call - Create Document] action in IconButton widget.
  MessagesRecord? newChat;
  bool isDataUploading_uploadData = false;
  List<FFUploadedFile> uploadedLocalFiles_uploadData = [];
  List<String> uploadedFileUrls_uploadData = [];

  bool isDataUploading_uploadDataCamera = false;
  FFUploadedFile uploadedLocalFile_uploadDataCamera =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadDataCamera = '';

  bool isDataUploading_uploadDataFile = false;
  FFUploadedFile uploadedLocalFile_uploadDataFile =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadDataFile = '';

  bool isDataUploading_uploadDataVideo = false;
  FFUploadedFile uploadedLocalFile_uploadDataVideo =
      FFUploadedFile(bytes: Uint8List.fromList([]));
  String uploadedFileUrl_uploadDataVideo = '';

  AudioRecorder? audioRecorder;
  String? stop;
  FFUploadedFile recordedFileBytes =
      FFUploadedFile(bytes: Uint8List.fromList([]));

  @override
  void initState(BuildContext context) {
    chatThreadModels = FlutterFlowDynamicModels(() => ChatThreadModel());
  }

  @override
  void dispose() {
    chatThreadModels.dispose();
    messageFocusNode?.dispose();
    messageTextController?.dispose();
  }
}
