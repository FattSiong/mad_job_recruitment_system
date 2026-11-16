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
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Photo from library'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: AppColors.primary),
              title: const Text('Document (PDF, Word)'),
              onTap: () => Navigator.pop(sheetContext, 'document'),
            ),
          ],
        ),
      ),
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
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              title: const Text('Try again'),
              onTap: () => Navigator.pop(sheetContext, 'retry'),
            ),
            if (isText)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppColors.primary),
                title: const Text('Copy text'),
                onTap: () => Navigator.pop(sheetContext, 'copy'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
              title: const Text('Don\'t send', style: TextStyle(color: AppColors.errorRed)),
              onTap: () => Navigator.pop(sheetContext, 'discard'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'retry':
        await _retry(message);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.content));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
        }
      case 'discard':
        await _controller.discard(message);
    }
  }

  /// Back pressed: if some messages are still "Not sent", ask before leaving
  /// (they are only kept while the chat is open).
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
    final editController = TextEditingController(text: message.content);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Edit message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, editController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Not disposed here: the dialog's TextField is still on screen while it closes.
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

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (isText)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppColors.primary),
                title: const Text('Copy text'),
                onTap: () => Navigator.pop(sheetContext, 'copy'),
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: const Text('Edit'),
                subtitle: const Text('Possible for 2 minutes after sending'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                title: const Text('Delete for everyone', style: TextStyle(color: AppColors.errorRed)),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;

    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.content));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
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
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          title: Row(
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
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.call_rounded,
                        color: _controller.isBlocked ? AppColors.textMuted : AppColors.teal,
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
              builder: (context, _) {
                final blockedByMe = _controller.blockState == ChatBlockState.blockedByMe;
                return PopupMenuButton<String>(
                  tooltip: 'More',
                  enabled: !_controller.isChangingBlock,
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textDark),
                  onSelected: (_) => _toggleBlock(),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(
                            blockedByMe ? Icons.lock_open_rounded : Icons.block_rounded,
                            color: blockedByMe ? AppColors.primary : AppColors.errorRed,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            blockedByMe ? 'Unblock user' : 'Block user',
                            style: TextStyle(color: blockedByMe ? AppColors.textDark : AppColors.errorRed),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _buildMessages(),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(
                _controller.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              TextButton.icon(
                onPressed: _controller.start,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
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

  /// Replaces the message box while the chat is blocked.
  Widget _buildBlockedBar() {
    final blockedByMe = _controller.blockState == ChatBlockState.blockedByMe;
    final name = widget.otherUser.displayName;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
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
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _controller.isChangingBlock ? null : _toggleBlock,
                  child: _controller.isChangingBlock
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Unblock', style: TextStyle(fontWeight: FontWeight.w700)),
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
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      ),
    );
  }
}
