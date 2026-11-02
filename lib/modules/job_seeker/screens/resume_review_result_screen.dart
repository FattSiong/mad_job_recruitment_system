import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/resume_review_model.dart';
import '../widgets/resume_review/resume_review_widgets.dart';
import 'build_resume_screen.dart';

/// AI Resume Assistant: the feedback report for one review.
class ResumeReviewResultScreen extends StatefulWidget {
  final ResumeReviewModel review;

  const ResumeReviewResultScreen({super.key, required this.review});

  @override
  State<ResumeReviewResultScreen> createState() => _ResumeReviewResultScreenState();
}

class _ResumeReviewResultScreenState extends State<ResumeReviewResultScreen> {
  /// null = all priorities
  String? _priorityFilter;

  ResumeReviewModel get _review => widget.review;

  List<ResumeImprovement> get _visibleImprovements => _priorityFilter == null
      ? _review.improvements
      : _review.improvements.where((i) => i.priority == _priorityFilter).toList();

  void _openBuilder() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BuildResumeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildScoreCard(),
              const SizedBox(height: 20),
              _buildCategoriesCard(),
              if (_review.strengths.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildStrengthsCard(),
              ],
              if (_review.improvements.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildImprovementsCard(),
              ],
              if (_review.missingSections.isNotEmpty || _review.keywordSuggestions.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildAddCard(),
              ],
              if (_review.formattingNotes.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildFormattingCard(),
              ],
              const SizedBox(height: 16),
              const Text(
                'AI feedback can be wrong. Only add skills, numbers and achievements that are true for you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ---------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resume Feedback',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_review.resumeName.isEmpty ? _review.source.label : _review.resumeName}'
                  ' · ${DateFormat('d MMM yyyy, h:mm a').format(_review.createdAt)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _title(String title, [String? subtitle]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    final color = resumeScoreColor(_review.overallScore);
    final role = _review.targetJobRole != null
        ? 'For: ${_review.targetJobRole}'
        : _review.detectedRole.isNotEmpty
            ? 'Looks aimed at: ${_review.detectedRole}'
            : null;

    return _card(
      children: [
        Row(
          children: [
            ResumeScoreRing(score: _review.overallScore),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _review.scoreLabel,
                      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _review.verdict.isNotEmpty ? _review.verdict : 'Resume score',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  if (role != null) ...[
                    const SizedBox(height: 6),
                    Text(role, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (_review.summary.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(_review.summary, style: const TextStyle(color: AppColors.textDark, height: 1.5)),
        ],
        if (_review.improvements.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('${_review.improvements.length}', 'suggestions'),
              const SizedBox(width: 10),
              _stat('${_review.highPriorityCount}', 'high priority'),
              const SizedBox(width: 10),
              _stat('${_review.strengths.length}', 'strengths'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      );

  Widget _buildCategoriesCard() {
    return _card(
      children: [
        _title('Score Breakdown', 'How your resume does in each area.'),
        ..._review.categories.map((c) => ReviewCategoryBar(category: c)),
      ],
    );
  }

  Widget _buildStrengthsCard() {
    return _card(
      children: [
        _title('What You\'re Doing Well'),
        ..._review.strengths.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(s, style: const TextStyle(color: AppColors.textDark, height: 1.4))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImprovementsCard() {
    final visible = _visibleImprovements;
    Widget chip(String? value, String label) {
      final count = value == null
          ? _review.improvements.length
          : _review.improvements.where((i) => i.priority == value).length;
      final selected = _priorityFilter == value;
      return ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => setState(() => _priorityFilter = value),
        selectedColor: AppColors.primarySoft,
        backgroundColor: AppColors.surfaceAlt,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textDark,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );
    }

    return _card(
      children: [
        _title('How to Improve', 'Start with the high priority items.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(null, 'All'),
            chip('high', 'High'),
            chip('medium', 'Medium'),
            chip('low', 'Low'),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Nothing in this group.', style: TextStyle(color: AppColors.textMuted)),
          )
        else
          ...visible.map((i) => ResumeImprovementCard(item: i)),
      ],
    );
  }

  Widget _buildAddCard() {
    Widget chips(List<String> items, IconData icon) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((s) => Chip(
                    avatar: Icon(icon, size: 16, color: AppColors.primary),
                    label: Text(s),
                    backgroundColor: AppColors.surfaceAlt,
                    side: const BorderSide(color: AppColors.border),
                    labelStyle: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ))
              .toList(),
        );

    return _card(
      children: [
        _title('Consider Adding'),
        if (_review.missingSections.isNotEmpty) ...[
          const Text('Missing sections',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 10),
          chips(_review.missingSections, Icons.add_rounded),
          const SizedBox(height: 18),
        ],
        if (_review.keywordSuggestions.isNotEmpty) ...[
          const Text('Keywords employers look for',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(
            _review.jobSampleSize > 0
                ? 'Based on ${_review.jobSampleSize} matching job posting${_review.jobSampleSize == 1 ? '' : 's'} in the app. Add only the ones you really have.'
                : 'Add only the ones you really have.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          chips(_review.keywordSuggestions, Icons.key_rounded),
        ],
      ],
    );
  }

  Widget _buildFormattingCard() {
    return _card(
      children: [
        _title('Layout & ATS', 'ATS = the software many companies use to scan resumes.'),
        ..._review.formattingNotes.map(
          (n) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_align_left_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(n, style: const TextStyle(color: AppColors.textDark, height: 1.4))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final isBuilder = _review.source == ResumeReviewSource.builder;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openBuilder,
            icon: Icon(isBuilder ? Icons.edit_note_rounded : Icons.auto_fix_high_rounded),
            label: Text(isBuilder ? 'Edit Resume' : 'Improve in Resume Builder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ),
    );
  }
}
