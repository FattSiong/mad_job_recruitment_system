import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_picker_helper.dart';
import '../../../../core/utils/file_preview_helper.dart';
import '../../../../shared_widgets/surface_card.dart';
import '../../screens/ai_resume_assistant_screen.dart';
import '../../screens/build_resume_screen.dart';
import '../../../../core/theme/app_button_styles.dart';

/// Resume status, then Build Resume, Upload and AI Resume Assistant.
class ProfileResumeCard extends StatelessWidget {
  final String? resumeURL;
  final bool isUploading;
  final VoidCallback onUpload;

  /// Called when Build Resume or the AI Resume Assistant closes
  /// (Build Resume can set a new profile resume).
  final VoidCallback? onReturn;

  const ProfileResumeCard({
    super.key,
    required this.resumeURL,
    required this.isUploading,
    required this.onUpload,
    this.onReturn,
  });

  /// Opens [screen], then calls [onReturn].
  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    onReturn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final url = resumeURL;
    final hasResume = url != null && url.isNotEmpty;

    return SurfaceCard(
      children: [
        if (hasResume)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.errorRed, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resume Uploaded',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your latest resume is ready to preview.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => FilePreviewHelper.previewNetworkFile(context, url, title: 'My Resume'),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.description_outlined, color: AppColors.textMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No resume uploaded yet. Add a ${FileLimits.resumeTypesLabel} file (max ${FileLimits.resumeMB} MB).',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _button(
          icon: const Icon(Icons.description_outlined),
          label: 'Build Resume',
          onPressed: () => _open(context, const BuildResumeScreen()),
        ),
        const SizedBox(height: 12),
        _button(
          icon: isUploading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload_file_rounded),
          label: hasResume ? 'Upload New Resume' : 'Upload Resume',
          onPressed: isUploading ? null : onUpload,
        ),
        const SizedBox(height: 12),
        _button(
          icon: const Icon(Icons.auto_awesome_rounded),
          label: 'AI Resume Assistant',
          onPressed: () => _open(context, const AiResumeAssistantScreen()),
        ),
      ],
    );
  }

  /// Full-width outlined button.
  Widget _button({required Widget icon, required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
        style: AppButtonStyles.outlined(),
      ),
    );
  }
}
