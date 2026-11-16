import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/education_model.dart';
import '../controllers/profile_controller.dart';
import '../widgets/load_error_view.dart';
import '../widgets/profile/add_education_sheet.dart';
import '../widgets/profile/profile_record_card.dart';
import '../widgets/profile/profile_sheet_helpers.dart';
import '../../../shared_widgets/confirm_dialog.dart';

/// Add, edit and remove the job seeker's education.
/// Changes are saved straight away; callers should reload when this screen closes.
class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final ProfileController _controller = ProfileController();

  List<EducationModel> _items = [];
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

  /// Loads the user's education.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final items = await _controller.fetchEducation();
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
    final education = await showAddEducationSheet(context);
    if (education == null || !mounted) return;

    setState(() => _isSaving = true);
    final ok = await _controller.addEducation(education);
    if (!mounted) return;
    setState(() => _isSaving = false);

    _showSnack(ok ? 'Education added!' : 'Failed to add education.', success: ok);
    if (ok) _load();
  }

  /// Opens the edit sheet for [item] and saves the changes.
  Future<void> _edit(EducationModel item) async {
    final updated = await showAddEducationSheet(context, initial: item);
    if (updated == null || !mounted) return;

    setState(() => _isSaving = true);
    final ok = await _controller.updateEducation(updated);
    if (!mounted) return;
    setState(() => _isSaving = false);

    _showSnack(ok ? 'Education updated!' : 'Failed to update education.', success: ok);
    if (ok) _load();
  }

  /// Deletes [item] after asking.
  Future<void> _delete(EducationModel item) async {
    if (item.educationID == null) return;

    final confirmed = await _confirmDelete('${item.degree} at ${item.institutionName}');
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    final ok = await _controller.deleteEducation(item.educationID!);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (ok) _items = _items.where((e) => e.educationID != item.educationID).toList();
    });

    _showSnack(ok ? 'Education removed.' : 'Failed to remove education.', success: ok);
  }

  /// "Remove education?" dialog. True when confirmed.
  Future<bool> _confirmDelete(String label) {
    return showConfirmDialog(
      context,
      title: 'Remove education?',
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
              label: const Text('Add Education', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
    );
  }

  /// Gradient header with the title and back button.
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
          const Icon(Icons.school_outlined, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Education',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Add your schools, qualifications and achievements.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Your Education (3)" (no count while loading or after an error).
  Widget _buildListTitle() {
    final count = (_isLoading || _loadError != null) ? '' : ' (${_items.length})';
    return Text(
      'Your Education$count',
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
                  'No education added yet. Tap "Add Education" to add one.',
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
        (edu) => ProfileRecordCard(
          icon: Icons.school_outlined,
          iconColor: Colors.orange,
          title: edu.fieldOfStudy != null && edu.fieldOfStudy!.isNotEmpty
              ? '${edu.degree} - ${edu.fieldOfStudy}'
              : edu.degree,
          subtitle: edu.institutionName,
          dateRange: formatProfileDateRange(edu.startDate, edu.endDate, edu.isCurrent),
          description: edu.description,
          onEdit: _isSaving ? null : () => _edit(edu),
          onDelete: _isSaving ? null : () => _delete(edu),
        ),
      ),
      const SizedBox(height: 72), // room for the floating button
    ];
  }
}
