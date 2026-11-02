import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../models/message_model.dart';
import '../chat_formatters.dart';
import 'full_screen_image_viewer.dart';

/// Photos and files shared in a chat.
Future<void> showSharedAttachmentsSheet(
  BuildContext context, {
  required Future<List<MessageModel>> Function() load,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _SharedAttachmentsSheet(load: load),
  );
}

class _SharedAttachmentsSheet extends StatefulWidget {
  final Future<List<MessageModel>> Function() load;

  const _SharedAttachmentsSheet({required this.load});

  @override
  State<_SharedAttachmentsSheet> createState() => _SharedAttachmentsSheetState();
}

class _SharedAttachmentsSheetState extends State<_SharedAttachmentsSheet> {
  late final Future<List<MessageModel>> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Shared photos & files',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<List<MessageModel>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'No photos or files shared yet.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }

                  final images = items.where((m) => m.mediaType == 'image').toList();
                  final files = items.where((m) => m.mediaType != 'image').toList();

                  return ListView(
                    children: [
                      if (images.isNotEmpty) ...[
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          children: images.map((m) {
                            final tag = 'shared_${m.messageID}';
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FullScreenImageViewer(imageUrl: m.mediaURL!, heroTag: tag),
                                ),
                              ),
                              child: Hero(
                                tag: tag,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: CachedNetworkImage(
                                    imageUrl: m.mediaURL!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 300,
                                    errorWidget: (_, __, ___) => Container(
                                      color: AppColors.surfaceAlt,
                                      child: const Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ...files.map(
                        (m) => Card(
                          elevation: 0,
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary),
                            title: Text(m.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(ChatFormatters.listTime(m.sentAt)),
                            onTap: () => FilePreviewHelper.previewNetworkFile(context, m.mediaURL!),
                          ),
                        ),
                      ),
                    ],
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
