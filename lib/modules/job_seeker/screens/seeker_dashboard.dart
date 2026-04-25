import 'package:flutter/material.dart';
import 'package:mad_job_recruitment_system/modules/job_seeker/screens/qr_scanner_screen.dart';
import '../../../core/screens/temp_main_screen.dart';
import '../../../models/job_model.dart';
import '../../../services/auth_service.dart';
import '../controllers/job_discovery_controller.dart';
import '../widgets/job_card.dart';
import 'job_details_screen.dart';
import 'job_map_screen.dart';
import 'location_search_screen.dart';

class SeekerDashboard extends StatefulWidget {
  const SeekerDashboard({super.key});

  @override
  State<SeekerDashboard> createState() => _SeekerDashboardState();
}

class _SeekerDashboardState extends State<SeekerDashboard> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _salaryInputController = TextEditingController();
  final JobDiscoveryController _controller = JobDiscoveryController();

  List<JobModel> _jobs = [];
  bool _isLoading = true;

  // Filter States
  String _selectedJobType = 'All';
  String _selectedDatePosted = 'All time';
  String _selectedSalary = 'Any';

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _locationController.dispose();
    _salaryInputController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    final fetchedJobs = await _controller.fetchActiveJobs();
    if (mounted) {
      setState(() {
        _jobs = fetchedJobs;
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch() async {
    FocusScope.of(context).unfocus(); // Close keyboard

    setState(() => _isLoading = true);

    final searchResults = await _controller.searchJobs(
      query: _keywordController.text.trim(),
      location: _locationController.text.trim(),
      jobType: _selectedJobType,
      datePosted: _selectedDatePosted,
      salary: _selectedSalary,
    );

    if (mounted) {
      setState(() {
        _jobs = searchResults;
        _isLoading = false;
      });
    }
  }

  // Bottom Sheet for filtering options
  // Bottom Sheet for filtering options
  void _showFilterOptions(String filterType) {
    List<String> options = [];
    String currentValue = '';

    if (filterType == 'Date posted') {
      options = ['All time', 'Last 24 hours', 'Last 3 days', 'Last 7 days', 'Last 14 days'];
      currentValue = _selectedDatePosted;
    } else if (filterType == 'Job type') {
      options = ['All', 'Full-time', 'Part-time'];
      currentValue = _selectedJobType;
    } else if (filterType == 'Salary') {
      options = ['Any', 'RM1000', 'RM2000', 'RM3000', 'RM4000', 'RM5000'];
      currentValue = _selectedSalary;

      String currentVal = _selectedSalary.replaceAll(RegExp(r'[^0-9]'), '');
      _salaryInputController.text = currentVal;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter by $filterType', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (filterType == 'Salary') ...[
                    const Text('Enter Custom Minimum Salary', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _salaryInputController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 3500',
                          prefixIcon: Padding(
                            padding: EdgeInsets.all(14.0),
                            child: Text('RM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16)),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _salaryInputController.clear();
                              setState(() => _selectedSalary = 'Any');
                              Navigator.pop(context);
                              _performSearch();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Clear', style: TextStyle(color: Colors.black87)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              String typed = _salaryInputController.text.trim();
                              setState(() {
                                _selectedSalary = typed.isNotEmpty ? 'RM $typed' : 'Any';
                              });
                              Navigator.pop(context);
                              _performSearch();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A66C2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Or Select Predefined Range', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),

                    // 👉 UPDATED: Use RadioGroup to resolve deprecation
                    RadioGroup<String>(
                      groupValue: currentValue,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSalary = value;
                          });
                          Navigator.pop(context);
                          _performSearch();
                        }
                      },
                      child: Column(
                        children: options.map((option) => RadioListTile<String>(
                          title: Text(option),
                          value: option,
                          activeColor: const Color(0xFF0A66C2),
                          contentPadding: EdgeInsets.zero,
                        )).toList(),
                      ),
                    ),
                  ]
                  else ...[
                    // 👉 UPDATED: Use RadioGroup to resolve deprecation
                    RadioGroup<String>(
                      groupValue: currentValue,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            if (filterType == 'Date posted') {
                              _selectedDatePosted = value;
                            } else if (filterType == 'Job type') {
                              _selectedJobType = value;
                            }
                          });
                          Navigator.pop(context);
                          _performSearch();
                        }
                      },
                      child: Column(
                        children: options.map((option) => RadioListTile<String>(
                          title: Text(option),
                          value: option,
                          activeColor: const Color(0xFF0A66C2),
                          contentPadding: EdgeInsets.zero,
                        )).toList(),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLocationSearch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSearchScreen(
          initialKeyword: _keywordController.text,
          initialLocation: _locationController.text,
        ),
      ),
    );

    if (result != null && result is Map<String, String>) {
      setState(() {
        _keywordController.text = result['keyword'] ?? '';
        _locationController.text = result['location'] ?? '';
      });
      _performSearch();
    }
  }

  Widget _buildFilterChip(String label, String value, String defaultValue) {
    final isActive = value != defaultValue;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(isActive ? value : label),
        selected: isActive,
        onSelected: (_) => _showFilterOptions(label),
        selectedColor: const Color(0xFF0A66C2).withValues(alpha: 0.1),
        labelStyle: TextStyle(
          color: isActive ? const Color(0xFF0A66C2) : Colors.black87,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isActive ? const Color(0xFF0A66C2) : Colors.grey.shade300),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Find Jobs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined, color: Colors.black87),
            tooltip: 'Map View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const JobMapScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const TempMainScreen()),
                      (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stacked Search Bar Container
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))
                ]
            ),
            child: Column(
              children: [
                // Keyword Search
                TextField(
                  controller: _keywordController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _performSearch(),
                  decoration: const InputDecoration(
                    hintText: 'Job title, keywords, or company',
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                // Location Search
                TextField(
                  controller: _locationController,
                  readOnly: true,
                  onTap: _openLocationSearch,
                  decoration: InputDecoration(
                    hintText: 'City, state, or postcode',
                    prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                    suffixIcon: _locationController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                      onPressed: () {
                        _locationController.clear();
                        _performSearch();
                      },
                    )
                        : IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF0A66C2)),
                      onPressed: _openLocationSearch,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),

          // 2. Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () {
                    // Reset filters
                    setState(() {
                      _selectedJobType = 'All';
                      _selectedDatePosted = 'All time';
                      _selectedSalary = 'Any';
                      _keywordController.clear();
                      _locationController.clear();
                    });
                    _performSearch();
                  },
                ),
                _buildFilterChip('Date posted', _selectedDatePosted, 'All time'),
                _buildFilterChip('Job type', _selectedJobType, 'All'),
                _buildFilterChip('Salary', _selectedSalary, 'Any'),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // 3. Results Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _keywordController.text.isEmpty && _locationController.text.isEmpty && _selectedJobType == 'All' && _selectedDatePosted == 'All time' && _selectedSalary == 'Any'
                      ? 'Jobs for you'
                      : '${_jobs.length} jobs found',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // 4. Job List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A66C2)))
                : _jobs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No jobs match your search criteria.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _performSearch,
              child: ListView.builder(
                itemCount: _jobs.length,
                itemBuilder: (context, index) {
                  final job = _jobs[index];
                  return JobCard(
                    job: job,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => JobDetailsScreen(job: job)),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QRScannerScreen()),
          );
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Test Scanner'),
        backgroundColor: Colors.blue, // Or your AppColors.primaryBlue
      ),
    );
  }
}