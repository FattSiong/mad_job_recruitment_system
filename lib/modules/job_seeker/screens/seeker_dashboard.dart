import 'package:flutter/material.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../models/job_model.dart';
import '../controllers/job_discovery_controller.dart';
import '../widgets/job_card.dart';
import 'job_details_screen.dart';
import 'job_map_screen.dart';

class SeekerDashboard extends StatefulWidget {
  const SeekerDashboard({super.key});

  @override
  State<SeekerDashboard> createState() => _SeekerDashboardState();
}

class _SeekerDashboardState extends State<SeekerDashboard> {
  final TextEditingController _searchController = TextEditingController();
  final JobDiscoveryController _controller = JobDiscoveryController();

  List<JobModel> _jobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    final fetchedJobs = await _controller.fetchActiveJobs();
    setState(() {
      _jobs = fetchedJobs;
      _isLoading = false;
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      _loadJobs();
      return;
    }

    setState(() => _isLoading = true);
    final searchResults = await _controller.searchJobs(query);
    setState(() {
      _jobs = searchResults;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Discovery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Map View',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const JobMapScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notifications',
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(UiConstants.defaultPadding), // 👉 Standardized Padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchBar(
              controller: _searchController,
              hintText: 'Search for jobs, skills...',
              leading: const Icon(Icons.search),
              trailing: [
                IconButton(icon: const Icon(Icons.tune), onPressed: () {})
              ],
              onSubmitted: _performSearch,
            ),
            const SizedBox(height: 24),
            const Text(
              'Recommended for You',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: UiConstants.defaultPadding),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _jobs.isEmpty
                  ? const Center(child: Text('No jobs found. Try another search.'))
                  : ListView.builder(
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
          ],
        ),
      ),
    );
  }
}