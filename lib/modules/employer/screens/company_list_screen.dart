import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';
import 'company_detail_screen.dart';
import 'register_company_screen.dart';

class CompanyListScreen extends StatefulWidget {
  final String userRole;

  const CompanyListScreen({super.key, required this.userRole});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final EmployerService _employerService = EmployerService();

  List<CompanyModel> _companies = [];
  bool _isLoading = true;

  bool get _isAdmin => widget.userRole == 'admin';

  int get _verifiedCount => _companies
      .where(
        (company) =>
            company.isVerified ||
            company.verificationStatus.toLowerCase() == 'verified' ||
            company.verificationStatus.toLowerCase() == 'approved',
      )
      .length;

  int get _pendingCount => _companies
      .where((company) => company.verificationStatus.toLowerCase() == 'pending')
      .length;

  int get _rejectedCount => _companies
      .where((company) => company.verificationStatus.toLowerCase() == 'rejected')
      .length;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _companies = [];
          _isLoading = false;
        });
      }
      return;
    }

    final fetchedCompanies = await _employerService.getCompanies(
      currentUser.id,
      widget.userRole,
    );

    if (!mounted) return;

    setState(() {
      _companies = fetchedCompanies;
      _isLoading = false;
    });
  }

  Future<void> _openCompanyDetails(CompanyModel company) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyDetailScreen(company: company),
      ),
    );

    if (!mounted) return;
    await _loadCompanies();
  }

  Future<void> _openRegisterCompany() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterCompanyScreen()),
    );

    if (!mounted) return;
    await _loadCompanies();
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.toLowerCase();
    late final Color badgeColor;
    late final Color backgroundColor;

    switch (normalized) {
      case 'approved':
      case 'verified':
        badgeColor = const Color(0xFF2D8A5D);
        backgroundColor = const Color(0xFFE5F6ED);
        break;
      case 'rejected':
        badgeColor = const Color(0xFFC24E4E);
        backgroundColor = const Color(0xFFFCE9E9);
        break;
      default:
        badgeColor = const Color(0xFFC28A22);
        backgroundColor = const Color(0xFFFEF3DC);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildPlanBadge(String planType) {
    final normalized = planType.toUpperCase();

    late final Color color;
    late final Color backgroundColor;

    switch (normalized) {
      case 'MONTHLY':
        color = const Color(0xFF1E8F8B);
        backgroundColor = const Color(0xFFE2F6F5);
        break;
      case 'ANNUALLY':
        color = const Color(0xFF6B4FD3);
        backgroundColor = const Color(0xFFEEE8FF);
        break;
      default: // FREE
        color = const Color(0xFF687588);
        backgroundColor = const Color(0xFFEFF3F8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      floatingActionButton: !_isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openRegisterCompany,
              backgroundColor: const Color(0xFF163B65),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Register Company'),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCompanies,
                  child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    children: [
                      _buildTopBar(context),
                      const SizedBox(height: 16),
                      _buildHeaderCard(),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Company Directory',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2433),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Open a company to review its profile, status, and workspace details.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Color(0xFF687588),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: _loadCompanies,
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.refresh_rounded,
                              color: Color(0xFF163B65),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_companies.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    child: _buildEmptyState(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final company = _companies[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _companies.length - 1 ? 0 : 14,
                        ),
                        child: _buildCompanyCard(company),
                      );
                    }, childCount: _companies.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF163B65),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Company Directory',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163B65), Color(0xFF335D8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.apartment_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAdmin ? 'Admin Directory' : 'Employer Companies',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Text(
                'Directory',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            _isAdmin ? 'Review every company in one place' : 'Your companies at a glance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isAdmin
                ? 'Track verification progress, review submissions, and open each company profile quickly.'
                : 'Manage the companies you own or belong to, check their status, and jump into details faster.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeaderChip(
                Icons.business_center_rounded,
                '${_companies.length} total',
              ),
              _buildHeaderChip(
                Icons.verified_rounded,
                '$_verifiedCount verified',
              ),
              _buildHeaderChip(
                Icons.hourglass_top_rounded,
                '$_pendingCount pending',
              ),
              if (_rejectedCount > 0)
                _buildHeaderChip(
                  Icons.report_gmailerrorred_rounded,
                  '$_rejectedCount rejected',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFDCEBFB),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                size: 36,
                color: Color(0xFF163B65),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _isAdmin
                  ? 'No companies in the directory yet'
                  : 'No companies in your workspace yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2433),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isAdmin
                  ? 'Once employers start registering companies, they will appear here for review.'
                  : 'Register your first company or join a team invitation to start building your employer workspace.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF687588),
              ),
            ),
            if (!_isAdmin) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _openRegisterCompany,
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('Register Your First Company'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF163B65),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyCard(CompanyModel company) {
    final isVerified = company.isVerified ||
        company.verificationStatus.toLowerCase() == 'verified' ||
        company.verificationStatus.toLowerCase() == 'approved';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: () => _openCompanyDetails(company),
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCEBFB),
                      borderRadius: BorderRadius.circular(18),
                      image: company.companyLogoURL != null &&
                              company.companyLogoURL!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(company.companyLogoURL!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: company.companyLogoURL == null ||
                            company.companyLogoURL!.isEmpty
                        ? Center(
                            child: Text(
                              company.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF163B65),
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B2433),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'SSM: ${company.registrationNumber}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF687588),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isVerified
                        ? const Color(0xFF163B65)
                        : const Color(0xFF9AA5B5),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusBadge(company.verificationStatus),
                  _buildPlanBadge(company.currentPlanType),
                  if (isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F6ED),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF2D8A5D),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                company.description.trim().isEmpty
                    ? 'No company description has been added yet.'
                    : company.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF4F5C6C),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    isVerified
                        ? Icons.verified_rounded
                        : Icons.pending_outlined,
                    size: 18,
                    color: isVerified
                        ? const Color(0xFF2D8A5D)
                        : const Color(0xFFC28A22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isVerified
                          ? 'Verified and ready for employer actions'
                          : 'Open to view verification details and next steps',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF687588),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
