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
import '../../../shared_widgets/confirm_dialog.dart';
import '../../../shared_widgets/gradient_page_header.dart';

/// Add, edit and remove the job seeker's work experience.
/// Changes are saved straight away; callers should reload when this screen closes.
class WorkExperienceScreen extends StatefulWidget {
  const WorkExperienceScreen({super.key});

  @override
  State<WorkExperienceScreen> createState() => _WorkExperienceScreenState();
}

class _WorkExperienceScreenState extends State<WorkExperienceScreen> {
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

  /// Loads the user's work experience.
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

  /// Opens the add sheet and saves the new entry.
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

  /// Opens the edit sheet for [item] and saves the changes.
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

  /// Deletes [item] after asking.
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

  /// "Remove work experience?" dialog. True when confirmed.
  Future<bool> _confirmDelete(String label) {
    return showConfirmDialog(
      context,
      title: 'Remove work experience?',
      message: 'Remove "$label" from your profile?',
      confirmLabel: 'Remove',
    );
  }

  /// Green or red snackbar.
  void _showSnack(String message, {required bool success}) {
    if (success) {
      SnackBarHelper.showSuccess(context, message);
    } else {
      SnackBarHelper.showError(context, message);
    }
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
              color: AppColors.primary,
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Experience', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
    );
  }

  /// Gradient header with the title and back button.
  Widget _buildHeader() => const GradientPageHeader(
        icon: Icons.work_history_outlined,
        title: 'Work Experience',
        subtitle: 'Show employers where you have worked and what you did.',
      );

  /// "Your Experience (2)" (no count while loading or after an error).
  Widget _buildListTitle() {
    final count = (_isLoading || _loadError != null) ? '' : ' (${_items.length})';
    return Text(
      'Your Experience$count',
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
    );
  }

  /// The entries, or a spinner / error / empty message.
  List<Widget> _buildBody() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
              Icon(Icons.inbox_outlined, color: AppColors.textMuted),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No work experience added yet. Tap "Add Experience" to add one.',
                  style: TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic),
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
          iconColor: AppColors.primary,
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
