import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/work_experience_model.dart';
import '../controllers/profile_controller.dart';
import '../widgets/load_error_view.dart';
import '../widgets/profile/add_experience_sheet.dart';
import '../widgets/profile/profile_record_card.dart';
import '../widgets/profile/profile_sheet_helpers.dart';

/// Add, edit and remove the job seeker's work experience.
/// Changes are saved straight away; callers should reload when this screen closes.
class WorkExperienceScreen extends StatefulWidget {
  const WorkExperienceScreen({super.key});

  @override
  State<WorkExperienceScreen> createState() => _WorkExperienceScreenState();
}

class _WorkExperienceScreenState extends State<WorkExperienceScreen> {
  static const Color _primary = AppColors.primary;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;

  final ProfileController _controller = ProfileController();

  List<WorkExperienceModel> _items = [];
  String? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final items = await _controller.fetchWorkExperiences();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } on DataLoadException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _add() async {
    final experience = await showAddExperienceSheet(context);
    if (experience == null || !mounted) return;

    setState(() => _isSaving = true);
    final ok = await _controller.addWorkExperience(experience);
    if (!mounted) return;
    setState(() => _isSaving = false);

    _showSnack(ok ? 'Work experience added!' : 'Failed to add work experience.', success: ok);
    if (ok) _load();
  }

  Future<void> _edit(WorkExperienceModel item) async {
    final updated = await showAddExperienceSheet(context, initial: item);
    if (updated == null || !mounted) return;

    setState(() => _isSaving = true);
    final ok = await _controller.updateWorkExperience(updated);
    if (!mounted) return;
    setState(() => _isSaving = false);

    _showSnack(ok ? 'Work experience updated!' : 'Failed to update work experience.', success: ok);
    if (ok) _load();
  }

  Future<void> _delete(WorkExperienceModel item) async {
    if (item.experienceID == null) return;

    final confirmed = await _confirmDelete('${item.jobTitle} at ${item.companyName}');
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    final ok = await _controller.deleteWorkExperience(item.experienceID!);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (ok) _items = _items.where((e) => e.experienceID != item.experienceID).toList();
    });

    _showSnack(ok ? 'Work experience removed.' : 'Failed to remove work experience.', success: ok);
  }

  Future<bool?> _confirmDelete(String label) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Remove work experience?'),
        content: Text('Remove "$label" from your profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {required bool success}) {
    SnackBarHelper.showStyled(
      context,
      message: message,
      icon: success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
      accentColor: success ? AppColors.successGreen : AppColors.errorRed,
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: _primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildListTitle(),
                  const SizedBox(height: 14),
                  ..._buildBody(),
                ],
              ),
            ),
            if (_isSaving)
              const Positioned.fill(
                child: ColoredBox(
                  color: AppColors.overlay,
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: (_isLoading || _loadError != null)
          ? null
          : FloatingActionButton.extended(
              onPressed: _isSaving ? null : _add,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Experience', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.work_history_outlined, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Work Experience',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Show employers where you have worked and what you did.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTitle() {
    final count = (_isLoading || _loadError != null) ? '' : ' (${_items.length})';
    return Text(
      'Your Experience$count',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary),
    );
  }

  List<Widget> _buildBody() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(color: _primary)),
        ),
      ];
    }
    if (_loadError != null) {
      return [LoadErrorView(message: _loadError!, onRetry: _load)];
    }
    if (_items.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            children: [
              Icon(Icons.inbox_outlined, color: _textMuted),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No work experience added yet. Tap "Add Experience" to add one.',
                  style: TextStyle(color: _textMuted, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      ..._items.map(
        (exp) => ProfileRecordCard(
          icon: Icons.work_outline_rounded,
          iconColor: _primary,
          title: exp.jobTitle,
          subtitle: exp.companyName,
          dateRange: formatProfileDateRange(exp.startDate, exp.endDate, exp.isCurrent),
          description: exp.description,
          onEdit: _isSaving ? null : () => _edit(exp),
          onDelete: _isSaving ? null : () => _delete(exp),
        ),
      ),
      const SizedBox(height: 72), // room for the floating button
    ];
  }
}
