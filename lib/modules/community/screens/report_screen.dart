import 'package:flutter/material.dart';

import '../../../services/community_service.dart';

const Color _reportInk = Color(0xFF172033);
const Color _reportPrimary = Color(0xFF1E4C8F);
const Color _reportMuted = Color(0xFF6B7890);
const Color _reportBorder = Color(0xFFD5E2F3);
const Color _reportBackground = Color(0xFFF4F7FB);
const Color _reportSurface = Color(0xFFF8FBFF);
const Color _reportAlert = Color(0xFFB84444);

class ReportScreen extends StatefulWidget {
  final String targetID;
  final String currentUserID;
  final bool isPost;

  const ReportScreen({
    super.key,
    required this.targetID,
    required this.currentUserID,
    required this.isPost,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final CommunityService _communityService = CommunityService();
  final TextEditingController _detailsController = TextEditingController();

  String _selectedCategory = 'Spam';
  bool _isSubmitting = false;

  final List<String> _categories = const [
    'Spam',
    'Inappropriate Content',
    'Harassment',
    'Other',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      if (widget.isPost) {
        await _communityService.reportPost(
          postID: widget.targetID,
          reporterID: widget.currentUserID,
          category: _selectedCategory,
          details: _detailsController.text.trim(),
        );
      } else {
        await _communityService.reportComment(
          commentID: widget.targetID,
          reporterID: widget.currentUserID,
          category: _selectedCategory,
          details: _detailsController.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildReasonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _reportBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reason for reporting',
            style: TextStyle(
              color: _reportInk,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the option that best describes the issue so it can be reviewed faster.',
            style: TextStyle(
              color: _reportMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _reportSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _reportBorder),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _reportMuted,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(18),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: _reportInk,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _reportBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Additional details',
                style: TextStyle(
                  color: _reportInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(Optional)',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Share any context that could help moderators understand what happened.',
            style: TextStyle(
              color: _reportMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _reportSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _reportBorder),
            ),
            child: TextField(
              controller: _detailsController,
              minLines: 8,
              maxLines: 12,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                color: _reportInk,
                fontSize: 15,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText:
                    'Add any relevant details, examples, or context that would help explain the issue.',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 15,
                  height: 1.5,
                ),
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isPost ? 'Report Post' : 'Report Comment';

    return Scaffold(
      backgroundColor: _reportBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE9F1FB),
              Color(0xFFF4F7FB),
              Color(0xFFF8FAFD),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(18),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF163B65),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: _reportInk,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _reportAlert.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _reportAlert.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.shield_outlined,
                                color: _reportAlert,
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Use reporting for genuine safety or policy concerns. It helps moderators review the right cases more quickly.',
                                style: TextStyle(
                                  color: Color(0xFF8E2C2C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildReasonCard(),
                      const SizedBox(height: 16),
                      _buildDetailsCard(),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: _reportBorder.withValues(alpha: 0.95),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _reportAlert,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _reportAlert.withValues(alpha: 0.55),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.flag_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Submit Report',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
