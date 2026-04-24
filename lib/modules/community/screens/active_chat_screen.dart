import 'package:flutter/material.dart';
import '../../../services/community_service.dart';
import '../../../models/message_model.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

// --- NEW IMPORTS FOR AUDIO RECORDING ---
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:audioplayers/audioplayers.dart';

class ActiveChatScreen extends StatefulWidget {
  final String roomID;
  final String currentUserID;
  final String otherUserName;
  final String otherUserID;

  const ActiveChatScreen({
    Key? key,
    required this.roomID,
    required this.currentUserID,
    required this.otherUserName,
    required this.otherUserID,
  }) : super(key: key);

  @override
  State<ActiveChatScreen> createState() => _ActiveChatScreenState();
}

class _ActiveChatScreenState extends State<ActiveChatScreen> {
  final CommunityService _communityService = CommunityService();
  final TextEditingController _messageController = TextEditingController();

  bool _isUploading = false;

  // --- AUDIO RECORDING STATE ---
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _communityService.markMessagesAsRead(widget.roomID, widget.otherUserID);
    _audioRecorder = AudioRecorder(); // Initialize the recorder
  }

  @override
  void dispose() {
    _messageController.dispose();
    _audioRecorder.dispose(); // Always clean up the recorder
    super.dispose();
  }

  // --- AUDIO RECORDING LOGIC ---
  Future<void> _startRecording() async {
    try {
      // Check microphone permissions
      if (await _audioRecorder.hasPermission()) {
        // Find a temporary directory to save the audio file before uploading
        final Directory tempDir = await getTemporaryDirectory();
        final String filePath = '${tempDir.path}/audio_msg_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Start recording
        await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: filePath
        );

        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start recording: $e')));
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    try {
      // Stop the recorder and get the file path
      final String? path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        setState(() => _isUploading = true);

        File audioFile = File(path);

        // Upload the audio file to Supabase using your existing attachment function
        String? fileUrl = await _communityService.uploadChatAttachment(audioFile, widget.roomID);

        if (fileUrl != null) {
          final newMessage = MessageModel(
            messageID: '',
            roomID: widget.roomID,
            senderID: widget.currentUserID,
            content: 'Voice Message', // The text displayed if audio isn't supported
            isRead: false,
            sentAt: DateTime.now(),
            mediaType: 'audio',
            mediaURL: fileUrl, // Save the Supabase Storage URL
          );

          await _communityService.sendMessage(newMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send recording: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
  // -----------------------------

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
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending file: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final newMessage = MessageModel(
      messageID: '',
      roomID: widget.roomID,
      senderID: widget.currentUserID,
      content: _messageController.text.trim(),
      isRead: false,
      sentAt: DateTime.now(),
      mediaType: 'text',
    );

    _messageController.clear();
    await _communityService.sendMessage(newMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName, style: const TextStyle(fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => SharedAttachmentsSheet(roomID: widget.roomID),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _communityService.getMessagesStream(widget.roomID),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Say hi!", style: TextStyle(color: Colors.grey)));
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  reverse: true, // Typically chats scroll from bottom up, make sure your query orders descending!
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderID == widget.currentUserID;

                    return MessageBubble(
                      message: msg,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: _isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: _isUploading ? null : _pickAndSendFile,
                  ),

                  // Text Field Area (Changes to 'Recording...' when holding mic)
                  Expanded(
                    child: _isRecording
                        ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.mic, color: Colors.red),
                          SizedBox(width: 8),
                          Text("Recording audio...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                        : TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),

                  // --- UPDATED: Hold to Record Button ---
                  GestureDetector(
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopAndSendRecording(),
                    // Cancel if they drag their finger away while holding
                    onLongPressCancel: () async {
                      if (_isRecording) {
                        await _audioRecorder.stop();
                        setState(() => _isRecording = false);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        color: _isRecording ? Colors.red : Colors.grey,
                        size: _isRecording ? 28 : 24, // Slightly grows when pressed
                      ),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ------------------------------------------------------------------------
// The Smart Message Bubble Widget (Now Stateful for Audio Playback!)
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
  // Audio Player State
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();

    // If this message is an audio file, set up the listeners
    if (widget.message.mediaType == 'audio' && widget.message.mediaURL != null) {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      _audioPlayer.onDurationChanged.listen((newDuration) {
        if (mounted) {
          setState(() {
            _duration = newDuration;
          });
        }
      });

      _audioPlayer.onPositionChanged.listen((newPosition) {
        if (mounted) {
          setState(() {
            _position = newPosition;
          });
        }
      });

      // Reset when audio finishes
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Always clean up to prevent memory leaks!
    super.dispose();
  }

  // Helper to format the audio duration (e.g., 0:05)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    DateTime sentTime;
    try {
      if (widget.message.sentAt is String) {
        sentTime = DateTime.parse(widget.message.sentAt.toString()).toLocal();
      } else {
        sentTime = (widget.message.sentAt as DateTime).toLocal();
      }
    } catch (e) {
      sentTime = DateTime.now();
    }

    final String timeString = TimeOfDay.fromDateTime(sentTime).format(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: widget.isMe ? const Color(0xFF1865F2) : Colors.grey[100],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: widget.isMe ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight: widget.isMe ? const Radius.circular(4) : const Radius.circular(16),
              ),
              border: widget.isMe ? null : Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. IMAGE
                if (widget.message.mediaType == 'image' && widget.message.mediaURL != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.message.mediaURL!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                    ),
                  ),
                  const SizedBox(height: 4),
                ]

                // 2. DOCUMENT/FILE
                else if (widget.message.mediaType == 'file' && widget.message.mediaURL != null) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: widget.isMe ? Colors.white24 : Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.picture_as_pdf, color: widget.isMe ? Colors.white : Colors.redAccent),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.message.content,
                          style: TextStyle(
                            color: widget.isMe ? Colors.white : Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ]

                // 3. AUDIO RECORDING (Now Functional!)
                else if (widget.message.mediaType == 'audio' && widget.message.mediaURL != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Play/Pause Button
                        GestureDetector(
                          onTap: () async {
                            if (_isPlaying) {
                              await _audioPlayer.pause();
                            } else {
                              await _audioPlayer.play(UrlSource(widget.message.mediaURL!));
                            }
                          },
                          child: Icon(
                            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                            color: widget.isMe ? Colors.white : const Color(0xFF1865F2),
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Progress Slider
                        SizedBox(
                          width: 100, // Fixed width for the slider inside the bubble
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: widget.isMe ? Colors.white : const Color(0xFF1865F2),
                              inactiveTrackColor: widget.isMe ? Colors.white38 : Colors.grey[300],
                              thumbColor: widget.isMe ? Colors.white : const Color(0xFF1865F2),
                            ),
                            child: Slider(
                              min: 0,
                              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                              value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                              onChanged: (value) async {
                                final position = Duration(seconds: value.toInt());
                                await _audioPlayer.seek(position);
                              },
                            ),
                          ),
                        ),

                        // Duration Text
                        Text(
                          _position.inSeconds > 0 ? _formatDuration(_position) : _formatDuration(_duration),
                          style: TextStyle(color: widget.isMe ? Colors.white : Colors.black87, fontSize: 12),
                        ),
                      ],
                    )
                  ]

                  // 4. STANDARD TEXT
                  else ...[
                      Text(
                        widget.message.content,
                        style: TextStyle(
                          color: widget.isMe ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ],
              ],
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
              if (widget.isMe) ...[
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: 4, width: 40,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Shared Media & Files',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _communityService.getSharedAttachments(roomID),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text("No files shared yet.", style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                final attachments = snapshot.data!;

                return ListView.separated(
                  itemCount: attachments.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final item = attachments[index];
                    final String mediaType = item['mediaType'] ?? 'file';
                    final String fileName = item['content'] ?? 'Unknown File';
                    final String fileUrl = item['mediaURL'] ?? '';

                    final DateTime date = DateTime.parse(item['sentAt']).toLocal();
                    final String dateString = "${date.day}/${date.month}/${date.year}";

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: mediaType == 'image'
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(fileUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.broken_image)),
                        )
                            : const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                      ),
                      title: Text(
                        fileName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Shared on $dateString',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.download_rounded, color: Colors.blueAccent),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Opening file...')),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}