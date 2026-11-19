import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/utils/storage_url_helper.dart';
import 'plain_app_bar.dart';

enum DocumentKind { pdf, image, other }

/// Shows a PDF or image inside the app (resumes, answer files, chat files),
/// with Share and "Open in another app".
///
/// Give either [url] (Supabase Storage or any web link; private buckets are
/// signed automatically) or [file] (a local file).
class DocumentViewerScreen extends StatefulWidget {
  final String? url;
  final File? file;
  final String? title;

  const DocumentViewerScreen({super.key, this.url, this.file, this.title})
      : assert(url != null || file != null);

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};

  /// File extension from a URL or path, ignoring "?token=..." etc.
  static String extensionOf(String urlOrPath) {
    final path = Uri.tryParse(urlOrPath)?.path ?? urlOrPath;
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static DocumentKind kindOf(String urlOrPath) {
    final ext = extensionOf(urlOrPath);
    if (ext == 'pdf') return DocumentKind.pdf;
    if (_imageExtensions.contains(ext)) return DocumentKind.image;
    return DocumentKind.other;
  }

  /// "resume.pdf" from ".../1730000000_resume.pdf?token=..."
  static String fileNameOf(String urlOrPath) {
    final path = Uri.tryParse(urlOrPath)?.path ?? urlOrPath;
    final name = Uri.decodeComponent(path.split('/').last);
    return name.replaceFirst(RegExp(r'^\d{10,}_'), ''); // drop the upload timestamp
  }

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  Uint8List? _bytes;
  File? _localFile;
  String? _error;

  String get _source => widget.file?.path ?? widget.url!;
  String get _fileName => DocumentViewerScreen.fileNameOf(_source);
  DocumentKind get _kind => DocumentViewerScreen.kindOf(_source);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _bytes = null;
      _error = null;
    });
    try {
      if (widget.file != null) {
        final bytes = await widget.file!.readAsBytes();
        if (!mounted) return;
        setState(() {
          _bytes = bytes;
          _localFile = widget.file;
        });
        return;
      }

      final resolved = await StorageUrlHelper.resolve(widget.url!);
      final response = await http.get(Uri.parse(resolved)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$_fileName');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (!mounted) return;
      setState(() {
        _bytes = response.bodyBytes;
        _localFile = file;
      });
    } catch (e) {
      debugPrint('Document load failed: $e');
      if (mounted) {
        setState(() => _error = 'Unable to load this document. Please check your connection and try again.');
      }
    }
  }

  Future<void> _share() async {
    final file = _localFile;
    if (file == null) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: _fileName));
  }

  Future<void> _openExternally() async {
    final file = _localFile;
    if (file == null) return;
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && mounted) {
      SnackBarHelper.showStyled(
        context,
        message: result.type == ResultType.noAppToOpen
            ? 'No app on this phone can open this file.'
            : 'Unable to open the file.',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _bytes != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PlainAppBar(
        title: widget.title ?? 'Document',
        subtitle: _fileName,
        actions: [
          IconButton(
            tooltip: 'Share or save',
            onPressed: ready ? _share : null,
            icon: Icon(Icons.ios_share_rounded, color: ready ? AppColors.primary : AppColors.iconDisabled),
          ),
          IconButton(
            tooltip: 'Open in another app',
            onPressed: ready ? _openExternally : null,
            icon: Icon(Icons.open_in_new_rounded, color: ready ? AppColors.primary : AppColors.iconDisabled),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _kind == DocumentKind.image ? Colors.black : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.errorRed),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Loading document…', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    switch (_kind) {
      case DocumentKind.pdf:
        return SfPdfViewer.memory(bytes, canShowScrollHead: true, pageSpacing: 6);
      case DocumentKind.image:
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
        );
      case DocumentKind.other:
        // Word / RTF / text etc. can't be drawn in the app.
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined, size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  _fileName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This file type can\'t be previewed in the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _openExternally,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open in another app'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
