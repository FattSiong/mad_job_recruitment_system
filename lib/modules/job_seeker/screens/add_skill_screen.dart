import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/skill_model.dart';
import '../controllers/skill_controller.dart';
import '../widgets/load_error_view.dart';
import '../../../shared_widgets/confirm_dialog.dart';
import '../../../shared_widgets/surface_card.dart';

/// Add, update and remove the skills on the job seeker's profile.
/// Changes are saved straight away; callers should reload skills when this screen closes.
class AddSkillScreen extends StatefulWidget {
  const AddSkillScreen({super.key});

  @override
  State<AddSkillScreen> createState() => _AddSkillScreenState();
}

class _AddSkillScreenState extends State<AddSkillScreen> {
  static const List<String> _suggestedSkills = [
    'Communication',
    'Teamwork',
    'Problem Solving',
    'Microsoft Excel',
    'Python',
    'Java',
    'Flutter',
    'SQL',
    'JavaScript',
    'Project Management',
    'Data Analysis',
    'UI/UX Design',
    'Digital Marketing',
    'Customer Service',
  ];

  final SkillController _controller = SkillController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  List<SkillModel> _skills = [];
  String? _selectedProficiency;
  String? _loadError;
  bool _isLoading = true;
  bool _isAdding = false;
  final Set<String> _busySkillIds = {};

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _loadSkills();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _loadSkills() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final skills = await _controller.fetchMySkills();
      if (!mounted) return;
      setState(() {
        _skills = skills;
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

  Future<void> _addSkill() async {
    if (_isAdding) return;
    FocusScope.of(context).unfocus();
    setState(() => _isAdding = true);

    try {
      final skill = await _controller.addSkill(
        _nameController.text,
        proficiency: _selectedProficiency,
      );
      if (!mounted) return;
      setState(() {
        _skills = [..._skills, skill];
        _nameController.clear();
        _selectedProficiency = null;
      });
      _showSnack('${skill.skillName} added to your skills.', success: true);
    } on SkillException catch (e) {
      if (mounted) _showSnack(e.message, success: false);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _changeProficiency(SkillModel skill, String? proficiency) async {
    if (skill.skillID == null || proficiency == skill.proficiency) return;
    setState(() => _busySkillIds.add(skill.skillID!));

    final ok = await _controller.updateProficiency(skill.skillID!, proficiency);
    if (!mounted) return;
    setState(() {
      _busySkillIds.remove(skill.skillID);
      if (ok) {
        _skills = _skills
            .map((s) => s.skillID == skill.skillID
                ? SkillModel(
                    skillID: s.skillID,
                    seekerID: s.seekerID,
                    skillName: s.skillName,
                    proficiency: proficiency,
                    createdAt: s.createdAt,
                  )
                : s)
            .toList();
      }
    });
    if (!ok) _showSnack('Failed to update ${skill.skillName}.', success: false);
  }

  Future<void> _deleteSkill(SkillModel skill) async {
    if (skill.skillID == null) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove skill?',
      message: 'Remove "${skill.skillName}" from your profile?',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busySkillIds.add(skill.skillID!));
    final ok = await _controller.deleteSkill(skill.skillID!);
    if (!mounted) return;
    setState(() {
      _busySkillIds.remove(skill.skillID);
      if (ok) _skills = _skills.where((s) => s.skillID != skill.skillID).toList();
    });
    _showSnack(
      ok ? '${skill.skillName} removed.' : 'Failed to remove ${skill.skillName}.',
      success: ok,
    );
  }

  void _useSuggestion(String name) {
    _nameController.text = name;
    _nameController.selection = TextSelection.collapsed(offset: name.length);
    _nameFocus.requestFocus();
  }

  void _showSnack(String message, {required bool success}) {
    if (success) {
      SnackBarHelper.showSuccess(context, message);
    } else {
      SnackBarHelper.showError(context, message);
    }
  }

  bool _alreadyAdded(String name) {
    final key = name.trim().toLowerCase();
    return _skills.any((s) => s.skillName.toLowerCase() == key);
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadSkills,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildAddCard(),
                const SizedBox(height: 20),
                _buildMySkillsCard(),
              ],
            ),
          ),
        ),
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
          const Icon(Icons.psychology_outlined, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Skills',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Skills help employers find you and improve your Skill Gap Analysis.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard() {
    final canAdd = _nameController.text.trim().isNotEmpty && !_isAdding;
    final suggestions = _suggestedSkills.where((s) => !_alreadyAdded(s)).toList();

    return SurfaceCard(
      children: [
        SectionTitle('Add a Skill', subtitle: 'Type a skill and choose how well you know it.'),
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          maxLength: SkillController.maxNameLength,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (canAdd) _addSkill();
          },
          decoration: InputDecoration(
            hintText: 'e.g. Flutter, Public Speaking',
            prefixIcon: const Icon(Icons.add_task_rounded, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Proficiency (optional)',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SkillModel.proficiencyLevels.map((level) {
            final selected = _selectedProficiency == level;
            return ChoiceChip(
              label: Text(level),
              selected: selected,
              onSelected: (_) => setState(() => _selectedProficiency = selected ? null : level),
              selectedColor: AppColors.primarySoft,
              backgroundColor: AppColors.surfaceAlt,
              side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
              showCheckmark: false,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: canAdd ? _addSkill : null,
            icon: _isAdding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(
              _isAdding ? 'Adding...' : 'Add Skill',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
              disabledForegroundColor: AppColors.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Suggestions',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map((s) => ActionChip(
                      label: Text(s),
                      avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                      onPressed: () => _useSuggestion(s),
                      backgroundColor: AppColors.surfaceAlt,
                      side: const BorderSide(color: AppColors.border),
                      labelStyle: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMySkillsCard() {
    final Widget body;
    if (_isLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    } else if (_loadError != null) {
      body = LoadErrorView(message: _loadError!, onRetry: _loadSkills);
    } else if (_skills.isEmpty) {
      body = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.textMuted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No skills added yet. Add your first skill above.',
                style: TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      );
    } else {
      body = Column(children: _skills.map(_buildSkillTile).toList());
    }

    return SurfaceCard(
      children: [
        SectionTitle(_isLoading || _loadError != null ? 'Your Skills' : 'Your Skills (${_skills.length})', subtitle: 'Tap the level to change it.'),
        body,
      ],
    );
  }

  Widget _buildSkillTile(SkillModel skill) {
    final busy = _busySkillIds.contains(skill.skillID);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              skill.skillName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else ...[
            PopupMenuButton<String>(
              tooltip: 'Change level',
              onSelected: (value) => _changeProficiency(skill, value == 'none' ? null : value),
              itemBuilder: (_) => [
                ...SkillModel.proficiencyLevels.map(
                  (level) => PopupMenuItem(value: level, child: Text(level)),
                ),
                const PopupMenuItem(value: 'none', child: Text('Not specified')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: skill.proficiency != null ? AppColors.primarySoft : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: skill.proficiency != null ? AppColors.primarySoft : AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      skill.proficiency ?? 'Set level',
                      style: TextStyle(
                        color: skill.proficiency != null ? AppColors.primary : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: skill.proficiency != null ? AppColors.primary : AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
              onPressed: () => _deleteSkill(skill),
            ),
          ],
        ],
      ),
    );
  }
}
