import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../models/feed_post_model.dart';
import '../../../shared_widgets/full_screen_image_viewer.dart';

/// The post's attachment: a photo (tap to zoom) or a file card (tap to open).
class PostMediaView extends StatelessWidget {
  final FeedPostModel post;

  const PostMediaView({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    if (!post.hasMedia) return const SizedBox.shrink();
    final url = post.mediaURL!;
    // Unique per open, so the same post in two lists never clashes.
    final heroTag = 'community-media-${post.postID}-${identityHashCode(this)}';

    if (post.isImage) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(imageUrl: url, heroTag: heroTag),
          ),
        ),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, minHeight: 160),
              child: CachedNetworkImage(
                imageUrl: url,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 1080,
                placeholder: (_, __) => Container(
                  height: 200,
                  color: AppColors.primarySoft,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) => _fileCard(context, url),
              ),
            ),
        ),
      );
    }
    return _fileCard(context, url);
  }

  /// Card for a PDF attachment; tapping it opens the file.
  Widget _fileCard(BuildContext context, String url) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => FilePreviewHelper.previewNetworkFile(context, url, title: 'Attachment'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  post.isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                  color: post.isPdf ? AppColors.danger : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.mediaFileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.isPdf ? 'PDF · Tap to open' : 'Tap to open',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
