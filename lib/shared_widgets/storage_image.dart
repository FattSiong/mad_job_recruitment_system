import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/utils/storage_url_helper.dart';

/// Network image that also works for files in PRIVATE storage buckets
/// (e.g. chat photos): the stored link is swapped for a signed link first.
/// Public links are shown directly. The picture is cached under a stable key,
/// so it is downloaded once even though signed links change.
class StorageImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final int? memCacheWidth;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? error;

  const StorageImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.memCacheWidth,
    this.placeholder,
    this.error,
  });

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  late Future<String> _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = StorageUrlHelper.resolveCached(widget.url);
  }

  @override
  void didUpdateWidget(StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolved = StorageUrlHelper.resolveCached(widget.url);
    }
  }

  Widget _placeholder(BuildContext context) =>
      widget.placeholder?.call(context) ?? SizedBox(width: widget.width, height: widget.height);

  Widget _error(BuildContext context) =>
      widget.error?.call(context) ??
      SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolved,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) return _placeholder(context);
        return CachedNetworkImage(
          imageUrl: url,
          cacheKey: StorageUrlHelper.cacheKey(widget.url),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          memCacheWidth: widget.memCacheWidth,
          placeholder: (context, _) => _placeholder(context),
          errorWidget: (context, _, __) => _error(context),
        );
      },
    );
  }
}
