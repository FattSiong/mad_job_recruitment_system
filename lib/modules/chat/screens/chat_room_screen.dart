import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/message_model.dart';
import '../../community/screens/standard_call_screen.dart';
import '../chat_formatters.dart';
import '../controllers/chat_room_controller.dart';
import '../controllers/voice_recorder_controller.dart';
import '../../../shared_widgets/confirm_dialog.dart';
import '../../../shared_widgets/user_avatar.dart';
import '../widgets/chat_composer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/shared_attachments_sheet.dart';
import '../../../shared_widgets/action_sheet.dart';
import '../../../shared_widgets/text_edit_dialog.dart';
import '../../../shared_widgets/button_spinner.dart';
import '../../../core/theme/app_button_styles.dart';
import '../../../shared_widgets/chat_surface.dart';
import '../../../shared_widgets/state_message_card.dart';
import '../../../shared_widgets/plain_app_bar.dart';

/// One conversation.
class ChatRoomScreen extends StatefulWidget {
  final String roomID;
  final ChatParticipant otherUser;

  const ChatRoomScreen({super.key, required this.roomID, required this.otherUser});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  late final ChatRoomController _controller =
      ChatRoomController(roomID: widget.roomID, otherUser: widget.otherUser);
  final VoiceRecorderController _recorder = VoiceRecorderController();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isStartingCall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.start();
    _scrollController.addListener(_onScroll);
  }

  /// Back in the app (maybe with a connection again): resend "Not sent" messages.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.resendFailed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _recorder.dispose();
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Actions (all data work is in the controllers)
  // ---------------------------------------------------------------------

  /// The list is reversed, so the top of the chat is the END of the scroll.
  /// Near it, load older messages (not again after a failure: the user taps retry).
  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400 &&
        _controller.olderError == null) {
      _controller.loadOlder();
    }
  }

  /// Red snackbar (if the screen is still open).
  void _showError(String message) {
    if (!mounted) return;
    SnackBarHelper.showError(context, message);
  }

  /// Sends the typed text. Without a connection it stays in the chat as
  /// "Not sent"; if it is refused (e.g. blocked) the text is put back.
  Future<void> _sendText() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    final error = await _controller.sendText(text);
    if (error != null) {
      if (_textController.text.isEmpty) _textController.text = text; // keep what they typed
      _showError(error);
    }
  }

  /// Photo / camera / document sheet, then sends the chosen file.
  Future<void> _showAttachOptions() async {
    final choice = await showActionSheet<String>(
      context,
      actions: const [
        SheetAction('gallery', 'Photo from library', icon: Icons.photo_library_outlined),
        SheetAction('camera', 'Take a photo', icon: Icons.photo_camera_outlined),
        SheetAction('document', 'Document (PDF, Word)', icon: Icons.description_outlined),
      ],
    );
    if (choice == null || !mounted) return;

    File? file;
    String? fileName;
    try {
      if (choice == 'document') {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'doc', 'docx'],
        );
        final picked = result?.files.single;
        if (picked?.path != null) {
          file = File(picked!.path!);
          fileName = picked.name;
        }
      } else {
        final picked = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 80,
        );
        if (picked != null) {
          file = File(picked.path);
          fileName = picked.name;
        }
      }
    } catch (e) {
      _showError('Unable to open ${choice == 'document' ? 'your files' : 'your photos'}. Please check app permissions.');
      return;
    }

    if (file == null || fileName == null) return;
    final error = await _controller.sendAttachment(file, fileName);
    if (error != null) _showError(error);
  }

  /// Starts a voice note (the mic button is held down).
  Future<void> _startRecording() async {
    final ok = await _recorder.start();
    if (!ok) _showError('Please allow microphone access to send voice messages.');
  }

  /// Mic button released: sends the voice note unless it was too short.
  Future<void> _stopRecording() async {
    final recording = await _recorder.stop();
    if (recording == null) return; // too short or cancelled
    final error = await _controller.sendVoice(recording.file, recording.seconds);
    if (error != null) _showError(error);
  }

  /// "Not sent" message tapped: try to send it again now.
  Future<void> _retry(MessageModel message) async {
    final error = await _controller.retry(message);
    if (error != null) _showError(error);
  }

  /// Long-press menu on a "Not sent" message: retry, copy (text) or discard.
  Future<void> _showUnsentActions(MessageModel message) async {
    final isText = (message.mediaType ?? 'text') == 'text';
    final choice = await showActionSheet<String>(
      context,
      actions: [
        const SheetAction('retry', 'Try again', icon: Icons.refresh_rounded),
        if (isText) const SheetAction('copy', 'Copy text', icon: Icons.copy_rounded),
        const SheetAction('discard', 'Don\'t send', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'retry':
        await _retry(message);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.content));
        if (mounted) {
          SnackBarHelper.showSuccess(context, 'Copied');
        }
      case 'discard':
        await _controller.discard(message);
    }
  }

  /// Back pressed: if some messages are still "Not sent" or still sending
  /// (e.g. a photo uploading), ask before leaving (they are only kept while
  /// the chat is open).
  Future<void> _confirmLeave() async {
    final unsent = _controller.unsentCount;
    if (unsent == 0) {
      Navigator.pop(context);
      return;
    }
    final leave = await showConfirmDialog(
      context,
      title: 'Leave this chat?',
      message: unsent == 1
          ? '1 message hasn\'t been sent yet. It will be discarded if you leave.'
          : '$unsent messages haven\'t been sent yet. They will be discarded if you leave.',
      confirmLabel: 'Leave',
    );
    if (leave && mounted) Navigator.pop(context);
  }

  /// Edit dialog for one of the user's messages (within 2 minutes of sending).
  Future<void> _editMessage(MessageModel message) async {
    final newText = await showTextEditDialog(
      context,
      title: 'Edit message',
      initialText: message.content,
      maxLength: 4000,
      showCounter: false,
    );
    if (newText == null || !mounted) return;
    final error = await _controller.editMessage(message, newText);
    if (error != null) _showError(error);
  }

  /// Long-press menu on a message: copy (text), edit (own text message,
  /// first 2 minutes) and delete (own messages).
  Future<void> _showMessageActions(MessageModel message) async {
    if (message.isDeleted) return;
    if (_controller.isFailed(message)) return _showUnsentActions(message);
    final isText = (message.mediaType ?? 'text') == 'text';
    final canEdit = _controller.canEdit(message);
    final canDelete = _controller.isMine(message) && !_controller.isPending(message);
    if (!isText && !canDelete) return;

    final choice = await showActionSheet<String>(
      context,
      actions: [
        if (isText) const SheetAction('copy', 'Copy text', icon: Icons.copy_rounded),
        if (canEdit)
          const SheetAction(
            'edit',
            'Edit',
            icon: Icons.edit_outlined,
            subtitle: 'Possible for 2 minutes after sending',
          ),
        if (canDelete)
          const SheetAction('delete', 'Delete for everyone', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (!mounted || choice == null) return;

    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.content));
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Copied');
      }
    } else if (choice == 'edit') {
      await _editMessage(message);
    } else if (choice == 'delete') {
      final ok = await _controller.deleteMessage(message);
      if (!ok) _showError('Failed to delete the message. Please try again.');
    }
  }

  /// Blocks or unblocks the other person (blocking asks first).
  Future<void> _toggleBlock() async {
    final name = widget.otherUser.displayName;
    if (_controller.blockState == ChatBlockState.blockedByMe) {
      final error = await _controller.unblock();
      if (!mounted) return;
      if (error != null) {
        _showError(error);
      } else {
        SnackBarHelper.showSuccess(context, '$name is unblocked.');
      }
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Block $name?',
      message: 'Neither of you will be able to send messages or call in this chat. '
          'Old messages stay. You can unblock $name at any time.',
      confirmLabel: 'Block',
    );
    if (!confirmed || !mounted) return;
    if (_recorder.isRecording) await _recorder.cancel();
    final error = await _controller.block();
    if (!mounted) return;
    if (error != null) {
      _showError(error);
    } else {
      FocusScope.of(context).unfocus();
      SnackBarHelper.showSuccess(context, '$name is blocked.');
    }
  }

  /// Starts a voice call and opens the call screen.
  Future<void> _startCall() async {
    if (_isStartingCall || _controller.isBlocked) return;
    setState(() => _isStartingCall = true);
    try {
      final call = await _controller.startCall();
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StandardCallScreen(
            callID: call.callID,
            roomCode: call.roomCode,
            otherUserName: widget.otherUser.displayName,
            otherUserProfilePic: widget.otherUser.photoUrl,
            chatRoomID: widget.roomID,
            currentUserID: _controller.currentUserID,
            isCaller: true,
          ),
        ),
      );
      if (result == 'recall' && mounted) {
        setState(() => _isStartingCall = false);
        await _startCall();
      }
    } catch (e) {
      debugPrint('Start call failed: $e');
      if (e.toString().contains('user_blocked')) {
        await _controller.refreshBlockState(); // blocked meanwhile
        _showError(ChatRoomController.blockedMessage);
      } else {
        _showError('Unable to start the call. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isStartingCall = false);
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // [_confirmLeave] decides (asks if messages are unsent)
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PlainAppBar(
          // Back uses maybePop: PopScope asks about unsent messages.
          titleWidget: Row(
            children: [
              UserAvatar(user: widget.otherUser, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.otherUser.roleLabel,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => IconButton(
                tooltip: _controller.isBlocked ? 'Calls are off in a blocked chat' : 'Voice call',
                onPressed: _isStartingCall || _controller.isBlocked ? null : _startCall,
                icon: _isStartingCall
                    ? const ButtonSpinner(size: 20, color: AppColors.teal)
                    : Icon(
                        Icons.call_rounded,
                        color: _controller.isBlocked ? AppColors.iconDisabled : AppColors.teal,
                      ),
              ),
            ),
            IconButton(
              tooltip: 'Shared photos & files',
              onPressed: () => showSharedAttachmentsSheet(
                context,
                load: _controller.fetchSharedAttachments,
              ),
              icon: const Icon(Icons.perm_media_outlined, color: AppColors.primary),
            ),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _buildMoreMenu(),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ChatSurface(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => _buildMessages(),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([_controller, _recorder]),
              builder: (context, _) => _controller.isBlocked
                  ? _buildBlockedBar()
                  : ChatComposer(
                      textController: _textController,
                      isUploading: _controller.isUploading,
                      isRecording: _recorder.isRecording,
                      recordingElapsed: _recorder.elapsed,
                      onSend: _sendText,
                      onAttach: _showAttachOptions,
                      onRecordStart: _startRecording,
                      onRecordEnd: _stopRecording,
                      onRecordCancel: _recorder.cancel,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The messages (newest at the bottom), or a spinner / error.
  Widget _buildMessages() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final messages = _controller.messages; // newest first
    if (_controller.error != null && messages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: StateMessageCard(
            boxed: false,
            icon: Icons.cloud_off_rounded,
            color: AppColors.danger,
            title: 'Unable to load messages',
            message: _controller.error!,
            action: ElevatedButton.icon(
              onPressed: _controller.start,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: AppButtonStyles.filled(),
            ),
          ),
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(user: widget.otherUser, size: 72),
              const SizedBox(height: 16),
              Text(
                'Say hello to ${widget.otherUser.displayName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your messages will appear here.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    // One extra row at the top while older messages load (or failed to).
    final showOlderRow = _controller.hasOlder || _controller.olderError != null;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 16), // inside the chat panel
      itemCount: messages.length + (showOlderRow ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) return _buildOlderRow();
        final message = messages[index];
        final older = index + 1 < messages.length ? messages[index + 1] : null;
        final showDay = (older == null && !_controller.hasOlder) ||
            (older != null && !ChatFormatters.isSameDay(message.sentAt, older.sentAt));

        return Column(
          key: ValueKey(message.messageID),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDay) ChatDaySeparator(date: message.sentAt),
            MessageBubble(
              message: message,
              isMine: _controller.isMine(message),
              isPending: _controller.isPending(message),
              isFailed: _controller.isFailed(message),
              onRetry: () => _retry(message),
              localFile: _controller.localFileOf(message),
              onLongPress: () => _showMessageActions(message),
            ),
          ],
        );
      },
    );
  }

  /// ⋮ menu with Block / Unblock user.
  Widget _buildMoreMenu() {
    final blockedByMe = _controller.blockState == ChatBlockState.blockedByMe;
    final color = blockedByMe ? AppColors.primary : AppColors.errorRed;
    return PopupMenuButton<String>(
      tooltip: 'More',
      enabled: !_controller.isChangingBlock,
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.primary),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => _toggleBlock(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'block',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(blockedByMe ? Icons.lock_open_rounded : Icons.block_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blockedByMe ? 'Unblock user' : 'Block user',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    blockedByMe ? 'Allow messages and calls again' : 'Stop messages and calls',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Replaces the message box while the chat is blocked.
  Widget _buildBlockedBar() {
    final blockedByMe = _controller.blockState == ChatBlockState.blockedByMe;
    final name = widget.otherUser.displayName;
    // Same floating card as the message box it replaces
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block_rounded, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      blockedByMe
                          ? 'You blocked $name. You can\'t message or call each other.'
                          : 'You can\'t reply to this conversation.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.35),
                    ),
                  ),
                ],
              ),
              if (blockedByMe) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _controller.isChangingBlock ? null : _toggleBlock,
                  icon: _controller.isChangingBlock
                      ? const ButtonSpinner(color: AppColors.primary)
                      : const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: AppButtonStyles.outlined(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Shown above the oldest message: a spinner while loading, or a retry.
  Widget _buildOlderRow() {
    if (_controller.olderError != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _controller.loadOlder,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('${_controller.olderError} Tap to retry'),
        ),
      );
    }
    // Short chats never scroll, so start loading as soon as this row appears.
    if (!_controller.isLoadingOlder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.olderError == null) _controller.loadOlder();
      });
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: ButtonSpinner(size: 22, color: AppColors.primary),
      ),
    );
  }
}
