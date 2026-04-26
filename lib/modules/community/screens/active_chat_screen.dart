import 'package:flutter/material.dart';
import '../../../services/community_service.dart';
import '../../../models/message_model.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math';

import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

// Required for Supabase queries and HTTP requests to OneSignal
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../services/call_service.dart';
import 'standard_call_screen.dart';

class ActiveChatScreen extends StatefulWidget {
  final String roomID;
  final String currentUserID;
  final String otherUserName;
  final String otherUserID;
  final String? otherUserProfilePictureUrl;

  const ActiveChatScreen({
    Key? key,
    required this.roomID,
    required this.currentUserID,
    required this.otherUserName,
    required this.otherUserID,
    this.otherUserProfilePictureUrl,
  }) : super(key: key);

  @override
  State<ActiveChatScreen> createState() => _ActiveChatScreenState();
}

class _ActiveChatScreenState extends State<ActiveChatScreen> {
  final CommunityService _communityService = CommunityService();
  final TextEditingController _messageController = TextEditingController();

  bool _isUploading = false;
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _hasMessageText = false;
  DateTime? _recordingStartedAt;
  bool _isFinishingRecording = false;
  String? _pendingRecordingMessageId;
  String? _otherUserProfilePictureUrl;

  @override
  void initState() {
    super.initState();
    _communityService.markMessagesAsRead(widget.roomID, widget.otherUserID);
    _audioRecorder = AudioRecorder();
    _messageController.addListener(_handleComposerChanged);
    _otherUserProfilePictureUrl = widget.otherUserProfilePictureUrl?.trim();
    _loadOtherUserProfilePicture();
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleComposerChanged);
    _messageController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasMessageText && mounted) {
      setState(() => _hasMessageText = hasText);
    }
  }

  String _createClientMessageId() {
    final random = Random.secure();
    String hex(int length) =>
        List.generate(length, (_) => random.nextInt(16).toRadixString(16))
            .join();

    return '${hex(8)}-${hex(4)}-4${hex(3)}-${['8', '9', 'a', 'b'][random.nextInt(4)]}${hex(3)}-${hex(12)}';
  }

  Future<void> _loadOtherUserProfilePicture() async {
    if ((_otherUserProfilePictureUrl ?? '').isNotEmpty) {
      return;
    }

    final profilePictureUrl =
        await _communityService.getUserProfilePictureUrl(widget.otherUserID);

    if (!mounted || profilePictureUrl == null || profilePictureUrl.isEmpty) {
      return;
    }

    setState(() {
      _otherUserProfilePictureUrl = profilePictureUrl;
    });
  }

  // ------------------------------------------------------------------------
  // The Push Notification Trigger Engine
  // ------------------------------------------------------------------------
  Future<void> _sendPushNotification(
    String content, {
    bool isCall = false,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      debugPrint('--- Push debug start ---');
      debugPrint('Push type: ${isCall ? 'call' : 'message'}');
      debugPrint('Receiver userID: ${widget.otherUserID}');

      const String oneSignalAppId = '16f92d86-ad69-4841-8a4f-b6c0cbb8f9f6';
      const String oneSignalRestApiKey = 'os_v2_app_c34s3bvnnfeedcspw3amxohz62pdusnidibetufmo2b5zeh25cmys643hvxviodmkoa3i4rljlt67paibzgnuq57gdipg4eztmebpqq';

      final requestBody = {
        'app_id': oneSignalAppId,
        'target_channel': 'push',
        'include_aliases': {
          'external_id': [widget.otherUserID],
        },
        'headings': {'en': isCall ? 'Incoming Call' : 'New Message'},
        'contents': {'en': content},
        'data': {
          'type': isCall ? 'call' : 'chat',
          'roomID': widget.roomID,
          ...?additionalData,
        },
        'android_channel_id': isCall
            ? '3e4bd85b-81e9-4907-b42b-34dea3a5de8f'
            : 'a0d1ce94-07ac-4bbf-95ab-dc7482dce5ee',
        'ttl': isCall ? 60 : 2419200,
        if (isCall && additionalData?['callID'] != null) 'collapse_id': 'call_${additionalData?['callID']}',
        'priority': 10,
        'ios_sound': 'default',
        'android_sound': 'default',
        'android_visibility': 1,
      };

      debugPrint('OneSignal request body: \n' + jsonEncode(requestBody));

      final response = await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $oneSignalRestApiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        debugPrint('OneSignal push failed. Check the channel exists in OneSignal Dashboard and is set to High/Urgent.');
      }

      debugPrint('OneSignal response status: \n${response.statusCode}');
      debugPrint('OneSignal response body: \n${response.body}');
      debugPrint('--- Push debug end ---');
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String filePath = '${tempDir.path}/audio_msg_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: filePath
        );

        setState(() {
          _isRecording = true;
          _recordingStartedAt = DateTime.now();
          _pendingRecordingMessageId = _createClientMessageId();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start: $e')));
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (_isFinishingRecording || !_isRecording) {
      return;
    }

    _isFinishingRecording = true;

    try {
      final String? path = await _audioRecorder.stop();
      final startedAt = _recordingStartedAt;
      final pendingMessageId =
          _pendingRecordingMessageId ?? _createClientMessageId();
      final recordingSeconds = startedAt == null
          ? 1
          : ((DateTime.now().difference(startedAt).inMilliseconds ~/ 1000)
                  .clamp(1, 3600));

      setState(() {
        _isRecording = false;
        _recordingStartedAt = null;
      });

      if (path != null) {
        setState(() => _isUploading = true);

        File audioFile = File(path);
        String? fileUrl = await _communityService.uploadChatAttachment(audioFile, widget.roomID);

        if (fileUrl != null) {
          final newMessage = MessageModel(
            messageID: pendingMessageId,
            roomID: widget.roomID,
            senderID: widget.currentUserID,
            content: 'Voice Message (${recordingSeconds}s)',
            isRead: false,
            sentAt: DateTime.now(),
            mediaType: 'audio',
            mediaURL: fileUrl,
          );

          await _communityService.sendMessage(newMessage);

          // Trigger Audio Push Notification
          _sendPushNotification('🎤 Voice Message');
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _pendingRecordingMessageId = null;
        });
      } else {
        _pendingRecordingMessageId = null;
      }
      _isFinishingRecording = false;
    }
  }

  Future<void> _cancelRecording() async {
    if (_isFinishingRecording || !_isRecording) {
      return;
    }

    _isFinishingRecording = true;

    try {
      await _audioRecorder.stop();
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingStartedAt = null;
          _pendingRecordingMessageId = null;
        });
      }
      _isFinishingRecording = false;
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png', 'jpeg'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isUploading = true);

        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        String ext = result.files.single.extension?.toLowerCase() ?? '';

        String mediaType = ['jpg', 'png', 'jpeg'].contains(ext) ? 'image' : 'file';
        String? fileUrl = await _communityService.uploadChatAttachment(file, widget.roomID);

        if (fileUrl != null) {
          final newMessage = MessageModel(
            messageID: '',
            roomID: widget.roomID,
            senderID: widget.currentUserID,
            content: fileName,
            isRead: false,
            sentAt: DateTime.now(),
            mediaType: mediaType,
            mediaURL: fileUrl,
          );

          await _communityService.sendMessage(newMessage);

          // Trigger File/Image Push Notification
          _sendPushNotification(mediaType == 'image' ? '📷 Photo' : '📎 Attachment: $fileName');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final textContent = _messageController.text.trim();

    final newMessage = MessageModel(
      messageID: '',
      roomID: widget.roomID,
      senderID: widget.currentUserID,
      content: textContent,
      isRead: false,
      sentAt: DateTime.now(),
      mediaType: 'text',
    );

    _messageController.clear();
    await _communityService.sendMessage(newMessage);

    // Trigger Text Push Notification
    _sendPushNotification(textContent);
  }

  Future<void> _startStandardCall() async {
    try {
      final callData = await CallService().initiateCall(
          widget.currentUserID,
          widget.otherUserID
      );

      String callerName = 'Incoming Caller';
      try {
        final me = await Supabase.instance.client
            .from('User')
            .select('username')
            .eq('userID', widget.currentUserID)
            .maybeSingle();
        if (me != null && me['username'] != null) {
          callerName = me['username'].toString();
        }
      } catch (_) {
        // Fallback name is fine for notifications.
      }

      // Trigger Call Push Notification
      _sendPushNotification(
        '📞 Incoming Voice Call...',
        isCall: true,
        additionalData: {
          'callID': callData.callID,
          'roomCode': callData.roomCode,
          'callerID': widget.currentUserID,
          'callerName': callerName,
        },
      );

      if (context.mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StandardCallScreen(
              callID: callData.callID,
              roomCode: callData.roomCode,
              otherUserName: widget.otherUserName,
              chatRoomID: widget.roomID,
              currentUserID: widget.currentUserID,
              isCaller: true,
            ),
          ),
        );

        if (result == 'recall') {
          _startStandardCall();
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String get _conversationLabel {
    final trimmedName = widget.otherUserName.trim();
    if (trimmedName.isEmpty) {
      return 'Community chat';
    }

    final firstName = trimmedName.split(RegExp(r'\s+')).first;
    return '$firstName is in this conversation';
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E4F1)),
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor ?? const Color(0xFF163B65)),
        tooltip: 'Chat action',
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFB),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  size: 34,
                  color: Color(0xFF163B65),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Start the conversation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2433),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Send a quick hello to ${widget.otherUserName} and your messages will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF687588),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MessageModel> _dedupeMessages(List<MessageModel> messages) {
    final seenMessageIds = <String>{};
    final seenMediaEntries = <String>{};
    final seenFallbackEntries = <String>{};
    final uniqueMessages = <MessageModel>[];

    for (final message in messages) {
      final messageId = message.messageID.trim();
      final mediaType = message.mediaType?.trim() ?? '';
      final mediaUrl = message.mediaURL?.trim() ?? '';

      if (messageId.isNotEmpty && !seenMessageIds.add(messageId)) {
        continue;
      }

      if (mediaUrl.isNotEmpty) {
        final mediaKey = '$mediaType|$mediaUrl';
        if (!seenMediaEntries.add(mediaKey)) {
          continue;
        }
      }

      final fallbackKey =
          '${message.roomID}|${message.senderID}|${message.sentAt.toIso8601String()}|${message.content}|$mediaType|$mediaUrl';
      if (!seenFallbackEntries.add(fallbackKey)) {
        continue;
      }

      uniqueMessages.add(message);
    }

    return uniqueMessages;
  }

  Widget _buildMessages() {
    return StreamBuilder<List<MessageModel>>(
      stream: _communityService.getMessagesStream(widget.roomID),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Unable to load messages right now.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF687588),
                  height: 1.5,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final messages = _dedupeMessages(snapshot.data!).reversed.toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
          reverse: true,
          physics: const BouncingScrollPhysics(),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg.senderID == widget.currentUserID;

            return MessageBubble(
              key: ValueKey(msg.messageID),
              message: msg,
              isMe: isMe,
            );
          },
        );
      },
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(Icons.graphic_eq_rounded, color: Color(0xFFC24E4E)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Recording audio... release to send',
              style: TextStyle(
                color: Color(0xFFC24E4E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFB),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.add_rounded,
                            color: Color(0xFF163B65),
                          ),
                    onPressed: _isUploading ? null : _pickAndSendFile,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _isRecording
                      ? _buildRecordingIndicator()
                      : TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Message',
                            hintStyle: const TextStyle(color: Color(0xFF9AA5B5)),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF4F7FB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                color: Color(0xFF163B65),
                                width: 1.2,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopAndSendRecording(),
                  onLongPressCancel: _cancelRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? const Color(0xFFFDECEC)
                          : const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isRecording
                          ? const Color(0xFFC24E4E)
                          : const Color(0xFF687588),
                      size: _isRecording ? 26 : 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _hasMessageText
                        ? AppColors.primaryBlue
                        : const Color(0xFFD7E3F3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarLetter = widget.otherUserName.trim().isEmpty
        ? 'U'
        : widget.otherUserName.trim().substring(0, 1).toUpperCase();
    final hasProfilePicture =
        (_otherUserProfilePictureUrl ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDCEBFB),
                borderRadius: BorderRadius.circular(16),
                image: hasProfilePicture
                    ? DecorationImage(
                        image: NetworkImage(_otherUserProfilePictureUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: hasProfilePicture
                  ? null
                  : Text(
                      avatarLetter,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF163B65),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2433),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _conversationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF687588),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _buildActionButton(
            icon: Icons.call_rounded,
            iconColor: AppColors.successGreen,
            onPressed: _startStandardCall,
          ),
          _buildActionButton(
            icon: Icons.dashboard_customize_rounded,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => SharedAttachmentsSheet(roomID: widget.roomID),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEAF2FC),
                    Color(0xFFF8FAFD),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: _buildMessages(),
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------
// Global Tracker to prevent multiple audios from playing at once
// ------------------------------------------------------------------------
final ValueNotifier<String?> currentlyPlayingVoiceMessageId = ValueNotifier<String?>(null);

// ------------------------------------------------------------------------
// The Smart Message Bubble Widget (Now with Soft Delete!)
// ------------------------------------------------------------------------
class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final CommunityService _communityService = CommunityService();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  Color get _primaryBubbleColor => const Color(0xFF163B65);
  Color get _incomingBubbleColor => Colors.white;
  Color get _incomingBorderColor => const Color(0xFFD9E4F1);
  Color get _deletedBubbleColor => const Color(0xFFE9EDF3);

  @override
  void initState() {
    super.initState();

    currentlyPlayingVoiceMessageId.addListener(_stopIfAnotherPlays);
    _bindAudioStateListeners();
    _configureAudioMessage();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.message.messageID != widget.message.messageID ||
        oldWidget.message.mediaURL != widget.message.mediaURL ||
        oldWidget.message.mediaType != widget.message.mediaType) {
      _configureAudioMessage();
    }
  }

  void _bindAudioStateListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });

    _audioPlayer.onPlayerComplete.listen((event) async {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }

      if (currentlyPlayingVoiceMessageId.value == widget.message.messageID) {
        currentlyPlayingVoiceMessageId.value = null;
      }
      await _audioPlayer.stop();
    });
  }

  Future<void> _configureAudioMessage() async {
    await _audioPlayer.stop();

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _duration = Duration.zero;
        _position = Duration.zero;
      });
    } else {
      _isPlaying = false;
      _duration = Duration.zero;
      _position = Duration.zero;
    }

    if (widget.message.isDeleted ||
        widget.message.mediaType != 'audio' ||
        widget.message.mediaURL == null) {
      return;
    }

    await _audioPlayer.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: [AVAudioSessionOptions.defaultToSpeaker],
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );

    await _audioPlayer.setSource(UrlSource(widget.message.mediaURL!));
  }

  void _stopIfAnotherPlays() async {
    if (currentlyPlayingVoiceMessageId.value != widget.message.messageID && _isPlaying) {
      await _audioPlayer.pause();
    }
  }

  @override
  void dispose() {
    currentlyPlayingVoiceMessageId.removeListener(_stopIfAnotherPlays);
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Duration? _contentAudioDuration() {
    final match = RegExp(r'\((\d+)s\)').firstMatch(widget.message.content);
    if (match == null) {
      return null;
    }

    final seconds = int.tryParse(match.group(1) ?? '');
    if (seconds == null || seconds <= 0) {
      return null;
    }

    return Duration(seconds: seconds);
  }

  Duration _resolvedAudioDuration() {
    final contentDuration = _contentAudioDuration();
    if (contentDuration == null) {
      return _duration;
    }

    if (_duration == Duration.zero) {
      return contentDuration;
    }

    return _duration <= contentDuration ? _duration : contentDuration;
  }

  Color _bubbleColor() {
    if (widget.message.isDeleted) {
      return _deletedBubbleColor;
    }

    return widget.isMe ? _primaryBubbleColor : _incomingBubbleColor;
  }

  Color _contentColor() {
    if (widget.message.isDeleted) {
      return const Color(0xFF7C8798);
    }

    return widget.isMe ? Colors.white : const Color(0xFF1B2433);
  }

  Border? _bubbleBorder() {
    if (widget.message.isDeleted || widget.isMe) {
      return null;
    }

    return Border.all(color: _incomingBorderColor);
  }

  List<BoxShadow>? _bubbleShadow() {
    if (widget.message.isDeleted || widget.isMe) {
      return null;
    }

    return const [
      BoxShadow(
        color: Color(0x0D0F172A),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ];
  }

  Widget _buildDeletedMessage() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.block_rounded,
          size: 16,
          color: Color(0xFF7C8798),
        ),
        const SizedBox(width: 6),
        Text(
          'This message was deleted',
          style: TextStyle(
            color: _contentColor(),
            fontStyle: FontStyle.italic,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildImageMessage() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenImageViewer(
              imageUrl: widget.message.mediaURL!,
              heroTag: widget.message.mediaURL!,
            ),
          ),
        );
      },
      child: Hero(
        tag: widget.message.mediaURL!,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            widget.message.mediaURL!,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 220,
              height: 220,
              color: const Color(0xFFE9EDF3),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileMessage() {
    final textColor = _contentColor();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.isMe
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xFFDCEBFB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.insert_drive_file_rounded,
            color: widget.isMe ? Colors.white : const Color(0xFF163B65),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Attachment',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9AA5B5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.message.content,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioMessage() {
    final textColor = _contentColor();
    final resolvedDuration = _resolvedAudioDuration();
    final maxSeconds = resolvedDuration.inSeconds > 0
        ? resolvedDuration.inSeconds.toDouble()
        : 1.0;
    final currentSeconds = _position.inSeconds.toDouble().clamp(0.0, maxSeconds);
    final displayedPosition =
        _position > resolvedDuration ? resolvedDuration : _position;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () async {
            if (_isPlaying) {
              await _audioPlayer.pause();
            } else {
              currentlyPlayingVoiceMessageId.value = widget.message.messageID;

              if (_position == Duration.zero) {
                await _audioPlayer.play(UrlSource(widget.message.mediaURL!));
              } else {
                await _audioPlayer.resume();
              }
            }
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.white.withValues(alpha: 0.18)
                  : const Color(0xFFDCEBFB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: widget.isMe ? Colors.white : const Color(0xFF163B65),
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice message',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor:
                      widget.isMe ? Colors.white : const Color(0xFF163B65),
                  inactiveTrackColor: widget.isMe
                      ? Colors.white.withValues(alpha: 0.35)
                      : const Color(0xFFD9E4F1),
                  thumbColor:
                      widget.isMe ? Colors.white : const Color(0xFF163B65),
                ),
                child: Slider(
                  min: 0,
                  max: maxSeconds,
                  value: currentSeconds,
                  onChanged: (value) async {
                    await _audioPlayer.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _position.inSeconds > 0
              ? _formatDuration(displayedPosition)
              : _formatDuration(resolvedDuration),
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBody() {
    if (widget.message.isDeleted) {
      return _buildDeletedMessage();
    }

    if (widget.message.mediaType == 'image' && widget.message.mediaURL != null) {
      return _buildImageMessage();
    }

    if (widget.message.mediaType == 'file' && widget.message.mediaURL != null) {
      return _buildFileMessage();
    }

    if (widget.message.mediaType == 'audio' && widget.message.mediaURL != null) {
      return _buildAudioMessage();
    }

    return Text(
      widget.message.content,
      style: TextStyle(
        color: _contentColor(),
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This will delete the message for everyone in this chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _communityService.softDeleteMessage(widget.message.messageID);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
              }
            },
            child: const Text('Delete for Everyone', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sentTime = widget.message.sentAt.toLocal();
    final String timeString = TimeOfDay.fromDateTime(sentTime).format(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () {
              if (widget.isMe && !widget.message.isDeleted) {
                _showDeleteDialog();
              }
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: _bubbleColor(),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: widget.isMe
                        ? const Radius.circular(22)
                        : const Radius.circular(8),
                    bottomRight: widget.isMe
                        ? const Radius.circular(8)
                        : const Radius.circular(22),
                  ),
                  border: _bubbleBorder(),
                  boxShadow: _bubbleShadow(),
                ),
                child: _buildMessageBody(),
              ),
            ),
          ),

          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeString,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              if (widget.isMe && !widget.message.isDeleted) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.done_all,
                  size: 15,
                  color: widget.message.isRead ? Colors.blue : Colors.grey[400],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------
// Shared Attachments Bottom Sheet
// ------------------------------------------------------------------------
class SharedAttachmentsSheet extends StatelessWidget {
  final String roomID;
  final CommunityService _communityService = CommunityService();

  SharedAttachmentsSheet({Key? key, required this.roomID}) : super(key: key);

  Future<void> _openAttachment(
    BuildContext context, {
    required String mediaType,
    required String fileUrl,
  }) async {
    if (mediaType == 'image') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImageViewer(
            imageUrl: fileUrl,
            heroTag: 'shared_$fileUrl',
          ),
        ),
      );
      return;
    }

    await FilePreviewHelper.previewNetworkFile(context, fileUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1DAE6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Media & files',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2433),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'View shared photos and open files exchanged in this conversation.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF687588),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _communityService.getSharedAttachments(roomID),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCEBFB),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.folder_off_outlined,
                                size: 34,
                                color: Color(0xFF163B65),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No shared items yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2433),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Attachments you send in this chat will appear here for quick access.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF687588),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final attachments = snapshot.data!
                      .where(
                        (item) =>
                            item['mediaType'] == 'image' ||
                            item['mediaType'] == 'file',
                      )
                      .toList();

                  if (attachments.isEmpty) {
                    return Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCEBFB),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.perm_media_outlined,
                                size: 34,
                                color: Color(0xFF163B65),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No media or files yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2433),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Shared images and documents will appear here for quick viewing.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF687588),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: attachments.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = attachments[index];
                      final String mediaType = item['mediaType'] ?? 'file';
                      final String fileName = item['content'] ?? 'Unknown File';
                      final String fileUrl = item['mediaURL'] ?? '';

                      final DateTime date = DateTime.parse(item['sentAt']).toLocal();
                      final String dateString = "${date.day}/${date.month}/${date.year}";

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => _openAttachment(
                            context,
                            mediaType: mediaType,
                            fileUrl: fileUrl,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCEBFB),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: mediaType == 'image'
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(18),
                                          child: Hero(
                                            tag: 'shared_$fileUrl',
                                            child: Image.network(
                                              fileUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.broken_image_outlined),
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.insert_drive_file_rounded,
                                          color: Color(0xFF163B65),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Color(0xFF1B2433),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Shared on $dateString',
                                        style: const TextStyle(
                                          color: Color(0xFF687588),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F7FB),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      mediaType == 'image'
                                          ? Icons.visibility_rounded
                                          : Icons.download_rounded,
                                      color: const Color(0xFF163B65),
                                    ),
                                    onPressed: () => _openAttachment(
                                      context,
                                      mediaType: mediaType,
                                      fileUrl: fileUrl,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// Full Screen Image Viewer
// ------------------------------------------------------------------------
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImageViewer({
    Key? key,
    required this.imageUrl,
    required this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: heroTag,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}
