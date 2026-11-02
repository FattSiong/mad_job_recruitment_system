import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../models/message_model.dart';
import '../chat_formatters.dart';
import '../../../shared_widgets/full_screen_image_viewer.dart';
import '../../../shared_widgets/storage_image.dart';
import 'voice_message_player.dart';

/// One chat message: text, photo, file, voice note or "deleted".
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool isPending;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.isPending = false,
    this.onLongPress,
  });

  bool get _hasMedia => (message.mediaURL ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isImage = !message.isDeleted && message.mediaType == 'image' && _hasMedia;

    final background = message.isDeleted
        ? AppColors.border
        : (isMine ? AppColors.primary : AppColors.surface);

    // Mine on the right, theirs on the left, whatever the parent does.
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              child: Container(
                padding: isImage
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMine ? 20 : 6),
                    bottomRight: Radius.circular(isMine ? 6 : 20),
                  ),
                  border: (isMine || message.isDeleted)
                      ? null
                      : Border.all(color: AppColors.borderSoft),
                ),
                child: _buildBody(context),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ChatFormatters.bubbleTime(message.sentAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              if (isMine && !message.isDeleted) ...[
                const SizedBox(width: 4),
                Icon(
                  isPending ? Icons.schedule_rounded : Icons.done_all_rounded,
                  size: 15,
                  color: isPending
                      ? AppColors.textMuted
                      : (message.isRead ? AppColors.statusScheduled : AppColors.textMuted),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final textColor = message.isDeleted
        ? AppColors.textMuted
        : (isMine ? Colors.white : AppColors.textDark);

    if (message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            'This message was deleted',
            style: TextStyle(color: textColor, fontStyle: FontStyle.italic),
          ),
        ],
      );
    }

    if (_hasMedia && message.mediaType == 'image') {
      final url = message.mediaURL!;
      final tag = 'chat_${message.messageID}';
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: url, heroTag: tag)),
        ),
        child: Hero(
          tag: tag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: StorageImage(
              url: url, // private chat file: shown through a signed link
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              memCacheWidth: 660,
              placeholder: (_) => Container(
                width: 220,
                height: 220,
                color: AppColors.surfaceAlt,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_) => Container(
                width: 220,
                height: 220,
                color: AppColors.surfaceAlt,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      );
    }

    if (_hasMedia && message.mediaType == 'audio') {
      return VoiceMessagePlayer(
        messageID: message.messageID,
        url: message.mediaURL!,
        isMine: isMine,
        knownLength: VoiceMessagePlayer.lengthFromContent(message.content),
      );
    }

    if (_hasMedia && message.mediaType == 'file') {
      return InkWell(
        onTap: () => FilePreviewHelper.previewNetworkFile(context, message.mediaURL!),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isMine ? Colors.white.withValues(alpha: 0.18) : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.insert_drive_file_rounded,
                color: isMine ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: textColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (message.mediaType == 'call_log') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.call_rounded, size: 18, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.content,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      );
    }

    // Plain Text (not SelectableText) so long-press still opens the menu.
    return Text(
      message.content,
      style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
    );
  }
}

/// "Today" / "Yesterday" / date label between days.
class ChatDaySeparator extends StatelessWidget {
  final DateTime date;

  const ChatDaySeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            ChatFormatters.daySeparator(date),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
