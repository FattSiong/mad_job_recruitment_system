import 'package:flutter/material.dart';
import '../../../services/community_service.dart';

class ReportScreen extends StatefulWidget {
  final String targetID; // Can be a postID or commentID
  final String currentUserID;
  final bool isPost; // True if reporting a post, false if reporting a comment

  const ReportScreen({
    Key? key,
    required this.targetID,
    required this.currentUserID,
    required this.isPost,
  }) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final CommunityService _communityService = CommunityService();
  final TextEditingController _detailsController = TextEditingController();

  String _selectedCategory = 'Spam';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Spam',
    'Inappropriate Content',
    'Harassment',
    'Other'
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

      if (mounted) {
        Navigator.pop(context); // Go back to the previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isPost ? 'Report Post' : 'Report Comment',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Icon & Subtitle ---
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 36),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Help us keep the community safe",
                      style: TextStyle(color: Colors.grey[600], fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- Reason Dropdown ---
              const Text(
                'Reason for reporting',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 15)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Details Text Field ---
              Row(
                children: [
                  const Text(
                    'Additional Details ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Text(
                    '(Optional)',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _detailsController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'Please provide any additional context to help us understand the issue...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Submit Button ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Text(
                    'Submit Report',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8), // Extra padding at the bottom
            ],
          ),
        ),
      ),
    );
  }
}