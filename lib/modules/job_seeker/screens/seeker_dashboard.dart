import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_button_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/session_helper.dart';
import '../../../shared_widgets/login_screen.dart';
import '../../../shared_widgets/state_message_card.dart';
import '../../chat/screens/chat_inbox_screen.dart';
import '../../community_hub/screens/community_hub_screen.dart';
import '../controllers/applied_jobs_controller.dart';
import '../controllers/job_list_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/dashboard/home_header.dart';
import '../widgets/dashboard/job_search_sheet.dart';
import '../widgets/job_list_view.dart';
import 'job_map_screen.dart';
import 'job_search_results_screen.dart';
import 'my_jobs_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';

/// The job seeker's main screen: Home (job search), My Jobs, Messages,
/// Community and Profile tabs.
class SeekerDashboard extends StatefulWidget {
  const SeekerDashboard({super.key});

  @override
  State<SeekerDashboard> createState() => _SeekerDashboardState();
}

class _SeekerDashboardState extends State<SeekerDashboard> {
  static const int _homeTab = 0;
  static const int _myJobsTab = 1;
  static const int _profileTab = 4;

  /// "Recommended Jobs" on Home: every active job, newest first.
  final JobListController _homeJobs = JobListController()..load();

  int _currentIndex = _homeTab;
  String? _fullName;
  String? _photoUrl;

  String? get _currentUserId => SessionHelper.currentUserId;

  StreamSubscription<Object>? _authSubscription;

  /// "Hi, Aisyah": the first word of the user's name, or their email name.
  String get _greetingName {
    final name = _fullName?.trim() ?? '';
    if (name.isNotEmpty) return name.split(RegExp(r'\s+')).first;

    final email = SessionHelper.currentEmail ?? '';
    if (email.isEmpty) return 'there';
    return email.split('@').first;
  }

  @override
  void initState() {
    super.initState();
    SessionHelper.consumeManualSignOut(); // fresh login: clear any old flag
    _authSubscription = SessionHelper.onSessionEnded(_handleSignedOut);
    _loadGreeting();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _homeJobs.dispose();
    super.dispose();
  }

  /// The session ended on its own (expired, or signed out on another device):
  /// go back to Login. A normal Logout is handled by the profile screen, which
  /// opens Login itself, so it is ignored here (otherwise Login opens twice).
  void _handleSignedOut(bool wasManual) {
    if (wasManual || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Your session has expired. Please log in again.')),
    );
  }

  /// Name and photo for the greeting (the greeting works without them).
  Future<void> _loadGreeting() async {
    final profile = await ProfileController().fetchGreeting();
    if (!mounted || profile == null) return;
    setState(() {
      _fullName = profile.fullName;
      _photoUrl = profile.photoUrl;
    });
  }

  /// Switches tab. Opening My Jobs reloads its tabs; coming back to Home
  /// picks up a new name or photo from the Profile tab.
  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == _myJobsTab) AppliedJobsController.notifyChanged();
    if (index == _homeTab) _loadGreeting();
  }

  /// Opens the job search; shows the results of what the user searched.
  Future<void> _openSearch() async {
    final filters = await showJobSearchSheet(context);
    if (filters == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobSearchResultsScreen(filters: filters)),
    );
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
  }

  /// Home tab: greeting and search bar, then the recommended jobs.
  Widget _buildHomeTab() {
    return SafeArea(
      child: JobListView(
        controller: _homeJobs,
        header: [
          HomeHeader(
            name: _greetingName,
            photoUrl: _photoUrl,
            onAvatarTap: () => _onTabTapped(_profileTab),
            onSearchTap: _openSearch,
            onScanTap: _openScanner,
            onNotificationsReturned: AppliedJobsController.notifyChanged,
          ),
          const SizedBox(height: 24),
          _buildRecommendedHeader(),
          const SizedBox(height: 12),
        ],
        emptyState: const StateMessageCard(
          boxed: false,
          icon: Icons.work_off_outlined,
          title: 'No jobs yet',
          message: 'New openings will show up here. Pull down to check again.',
        ),
      ),
    );
  }

  /// "Recommended Jobs" title and the Nearby Jobs button.
  Widget _buildRecommendedHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommended Jobs',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              SizedBox(height: 4),
              Text(
                'Fresh openings from active postings.',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JobMapScreen()),
            );
          },
          icon: const Icon(Icons.map, size: 18),
          label: const Text('Nearby Jobs'),
          style: AppButtonStyles.outlined(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  /// Messages tab (the chat list).
  Widget _buildMessagesTab() {
    if (_currentUserId == null) {
      return const Center(child: Text('Not logged in'));
    }

    return const ChatInboxScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          const MyJobsScreen(),
          _buildMessagesTab(),
          _buildCommunityTab(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primarySoft,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'My Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Community tab.
  Widget _buildCommunityTab() {
    if (_currentUserId == null) {
      return const Center(child: Text('Not logged in'));
    }
    return CommunityHubScreen(currentUserID: _currentUserId!);
  }
}
