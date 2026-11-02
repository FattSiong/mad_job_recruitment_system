import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/file_preview_helper.dart';
import '../../../core/utils/storage_url_helper.dart';
import '../../../models/company_model.dart';

class CompanyVerificationScreen extends StatefulWidget {
  const CompanyVerificationScreen({super.key});

  @override
  State<CompanyVerificationScreen> createState() =>
      _CompanyVerificationScreenState();
}

class _CompanyVerificationScreenState extends State<CompanyVerificationScreen> {
  String _selectedStatus = 'pending';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;

  static const Color _bgColor = Color(0xFFF4F7FB);
  static const Color _heroStart = Color(0xFF12343B);
  static const Color _heroEnd = Color(0xFF2A6B66);
  static const Color _selectedBg = Color(0xFFD9ECE8);
  static const Color _primaryGreen = Color(0xFF1D6F6A);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textSecondary = Color(0xFF687588);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _normalizeStatus(Map<String, dynamic> row) {
    final raw = (row['verificationStatus'] ?? row['verificationstatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (raw == 'approved' || raw == 'verified') return 'verified';
    if (raw == 'rejected') return 'rejected';
    if (raw == 'pending') return 'pending';
    if (row['isVerified'] == true) return 'verified';
    return 'pending';
  }

  static CompanyModel _parseCompanySafely(Map<String, dynamic> rawData) {
    return CompanyModel.fromJson({
      'companyID': rawData['companyID']?.toString(),
      'name': rawData['name']?.toString() ?? 'Unnamed Company',
      'description': rawData['description']?.toString() ?? '',
      'registrationNumber': rawData['registrationNumber']?.toString() ?? 'N/A',
      'verificationDocumentURL':
          rawData['verificationDocumentURL']?.toString(),
      'isVerified': rawData['isVerified'] == true,
      'verificationStatus': _normalizeStatus(rawData),
      'rejectionReason': rawData['rejectionReason']?.toString(),
      'latitude': rawData['latitude'],
      'longitude': rawData['longitude'],
      'companyAddress': rawData['companyAddress']?.toString(),
      'currentPlanType': rawData['currentPlanType']?.toString() ?? 'FREE',
      'subscriptionEndsAt': rawData['subscriptionEndsAt']?.toString(),
      'companyLogoURL': rawData['companyLogoURL']?.toString(),
    });
  }

  Future<bool> _verifyCompany(String companyID, String companyName) async {
    try {
      final Map<String, dynamic> payload = {
        'verificationStatus': 'verified',
        'isVerified': true,
        'rejectionReason': null,
        'verifiedAt': DateTime.now().toUtc().toIso8601String(),
      };

      final adminUid = supabase.auth.currentUser?.id;
      if (adminUid != null) {
        final adminRow = await supabase
            .from('Admin')
            .select('adminID')
            .eq('adminID', adminUid)
            .maybeSingle();
        if (adminRow != null) {
          payload['verifiedByAdminID'] = adminUid;
        }
      }

      await supabase
          .from('Company')
          .update(payload)
          .eq('companyID', companyID);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$companyName verified successfully!'),
            backgroundColor: _primaryGreen,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error verifying company: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not verify company: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _showRejectDialog(String companyID, String companyName) async {
    final TextEditingController reasonController = TextEditingController();
    String? errorText;

    final bool? didReject = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'Reject $companyName',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Provide a clear rejection reason so the employer knows what to fix.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Uploaded SSM certificate does not match registration number.',
                      errorText: errorText,
                      filled: true,
                      fillColor: _bgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: _textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            setDialogState(() {
                              errorText = 'Please enter a rejection reason.';
                            });
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            await supabase
                                .from('Company')
                                .update({
                                  'verificationStatus': 'rejected',
                                  'isVerified': false,
                                  'rejectionReason': reason,
                                })
                                .eq('companyID', companyID);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = 'Failed to reject: $e';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC24E4E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(isSubmitting ? 'Rejecting...' : 'Reject'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();

    if (didReject == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$companyName marked as rejected.'),
          backgroundColor: const Color(0xFFC24E4E),
        ),
      );
      return true;
    }
    return false;
  }

  void _openVerificationDocument(CompanyModel company) {
    final docUrl = company.verificationDocumentURL?.trim() ?? '';
    if (docUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No verification document was uploaded for this company.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdminVerificationDocViewerScreen(
          companyName: company.name,
          documentUrl: docUrl,
        ),
      ),
    );
  }

  void _openCompanyDetails(
    CompanyModel company,
    Map<String, dynamic> rawData,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdminCompanyDetailScreen(
          initialCompany: company,
          initialRawData: rawData,
          onVerify: _verifyCompany,
          onReject: _showRejectDialog,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase.from('Company').stream(primaryKey: ['companyID']),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _heroStart),
            );
          }

          final all = snapshot.data!;
          final query = _searchQuery.trim().toLowerCase();
          final filtered = all.where((d) {
            if (_normalizeStatus(d) != _selectedStatus) return false;
            if (query.isEmpty) return true;
            final name = (d['name'] ?? '').toString().toLowerCase();
            final reg =
                (d['registrationNumber'] ?? '').toString().toLowerCase();
            final addr = (d['companyAddress'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                reg.contains(query) ||
                addr.contains(query);
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_heroStart, _heroEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderChip(
                        Icons.business_center_rounded,
                        'Business Verification',
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Review business access',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Inspect full company details and SSM documents before approving.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search company name, SSM number, or location...',
                      hintStyle: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _primaryGreen,
                      ),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: _textSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: _primaryGreen,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildPill('Pending', 'pending', all),
                      const SizedBox(width: 10),
                      _buildPill('Verified', 'verified', all),
                      const SizedBox(width: 10),
                      _buildPill('Rejected', 'rejected', all),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: filtered.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 44),
                            child: Text(
                              'No matching companies found',
                              style: TextStyle(color: _textSecondary),
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final rawData = filtered[i];
                            final company = _parseCompanySafely(rawData);
                            final reason =
                                rawData['rejectionReason']?.toString().trim();

                            return _buildCompanyCard(
                              company,
                              rawData,
                              (reason == null || reason.isEmpty)
                                  ? 'No reason provided.'
                                  : reason,
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
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

  Widget _buildPill(
    String label,
    String status,
    List<Map<String, dynamic>> all,
  ) {
    final bool isSel = _selectedStatus == status;
    final int count = all.where((d) => _normalizeStatus(d) == status).length;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? _selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSel
                ? _primaryGreen.withValues(alpha: 0.28)
                : Colors.grey.shade200,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSel ? _heroStart : _textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard(
    CompanyModel company,
    Map<String, dynamic> rawData,
    String reason,
  ) {
    final bool hasDoc =
        (company.verificationDocumentURL ?? '').trim().isNotEmpty;
    final String desc = company.description.trim();
    final String address = (company.companyAddress ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openCompanyDetails(company, rawData),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CompanyLogoAvatar(
                      logoUrl: company.companyLogoURL,
                      companyName: company.name,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SSM Reg: ${company.registrationNumber}',
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: company.verificationStatus),
                  ],
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: _primaryGreen,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF4F5D70),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openCompanyDetails(company, rawData),
                        icon: const Icon(Icons.info_outline_rounded, size: 17),
                        label: const Text('Full Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _heroStart,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasDoc
                            ? () => _openVerificationDocument(company)
                            : null,
                        icon: Icon(
                          hasDoc
                              ? Icons.description_outlined
                              : Icons.file_present_outlined,
                          size: 17,
                        ),
                        label: Text(hasDoc ? 'View Document' : 'No Document'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryGreen,
                          side: BorderSide(
                            color: hasDoc
                                ? _primaryGreen.withValues(alpha: 0.45)
                                : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedStatus == 'pending' &&
                    company.companyID != null &&
                    company.companyID!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _verifyCompany(company.companyID!, company.name),
                          icon: const Icon(
                            Icons.verified_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Verify',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(
                            company.companyID!,
                            company.name,
                          ),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFFC24E4E),
                          ),
                          label: const Text(
                            'Reject',
                            style: TextStyle(
                              color: Color(0xFFC24E4E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFC24E4E)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_selectedStatus == 'rejected') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE9E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Rejection Reason: $reason',
                      style: const TextStyle(
                        color: Color(0xFFC24E4E),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Complete Admin Company Details & Verification Review Screen
// ============================================================================

class _AdminCompanyDetailScreen extends StatefulWidget {
  final CompanyModel initialCompany;
  final Map<String, dynamic> initialRawData;
  final Future<bool> Function(String companyID, String companyName) onVerify;
  final Future<bool> Function(String companyID, String companyName) onReject;

  const _AdminCompanyDetailScreen({
    required this.initialCompany,
    required this.initialRawData,
    required this.onVerify,
    required this.onReject,
  });

  @override
  State<_AdminCompanyDetailScreen> createState() =>
      _AdminCompanyDetailScreenState();
}

class _AdminCompanyDetailScreenState extends State<_AdminCompanyDetailScreen> {
  static const Color _bgColor = Color(0xFFF4F7FB);
  static const Color _heroStart = Color(0xFF12343B);
  static const Color _heroEnd = Color(0xFF2A6B66);
  static const Color _primaryGreen = Color(0xFF1D6F6A);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textSecondary = Color(0xFF687588);

  final SupabaseClient _supabase = Supabase.instance.client;

  late CompanyModel _company;
  late Map<String, dynamic> _rawData;
  List<Map<String, dynamic>> _members = [];
  int _jobCount = 0;
  bool _isLoadingExtras = true;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _company = widget.initialCompany;
    _rawData = Map<String, dynamic>.from(widget.initialRawData);
    _loadCompanyContext();
  }

  Future<void> _loadCompanyContext() async {
    final companyId = _company.companyID;
    if (companyId == null || companyId.isEmpty) {
      setState(() => _isLoadingExtras = false);
      return;
    }

    setState(() => _isLoadingExtras = true);
    try {
      final results = await Future.wait([
        _supabase
            .from('Company')
            .select()
            .eq('companyID', companyId)
            .maybeSingle(),
        _supabase
            .from('CompanyMember')
            .select(
              'companyRole, status, joinedAt, employerID, Employer(fullName, email, profilePictureURL)',
            )
            .eq('companyID', companyId)
            .order('companyRole', ascending: false),
        _supabase
            .from('Job')
            .select('jobID')
            .eq('companyID', companyId)
            .neq('status', 'deleted'),
      ]);

      final freshCompanyRow = results[0] as Map<String, dynamic>?;
      final memberRows = List<Map<String, dynamic>>.from(results[1] as List);
      final jobRows = results[2] as List;

      if (!mounted) return;
      setState(() {
        if (freshCompanyRow != null) {
          _rawData = freshCompanyRow;
          _company = _CompanyVerificationScreenState._parseCompanySafely(
            freshCompanyRow,
          );
        }
        _members = memberRows;
        _jobCount = jobRows.length;
        _isLoadingExtras = false;
      });
    } catch (e) {
      debugPrint('Failed loading company admin details: $e');
      if (mounted) {
        setState(() => _isLoadingExtras = false);
      }
    }
  }

  Future<void> _openInGoogleMaps() async {
    final lat = _company.latitude;
    final lng = _company.longitude;
    if (lat == null || lng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    }
  }

  void _openDocumentPreview() {
    final docUrl = (_company.verificationDocumentURL ?? '').trim();
    if (docUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdminVerificationDocViewerScreen(
          companyName: _company.name,
          documentUrl: docUrl,
        ),
      ),
    );
  }

  String _extractFileName(String url) {
    try {
      final parsed = StorageUrlHelper.parse(url);
      if (parsed != null && parsed.path.isNotEmpty) {
        return parsed.path.split('/').last;
      }
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        return Uri.decodeComponent(uri.pathSegments.last);
      }
    } catch (_) {}
    return 'Verification Document';
  }

  String _detectDocTypeLabel(String url) {
    final lower = url.split('?').first.toLowerCase();
    if (lower.endsWith('.pdf')) return 'PDF Document';
    if (lower.endsWith('.png')) return 'PNG Image';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'JPG Image';
    return 'Uploaded Document';
  }

  String? _formatTimestamp(dynamic value) {
    if (value == null) return null;
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return null;
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  Future<void> _handleVerifyAction() async {
    final id = _company.companyID;
    if (id == null || id.isEmpty || _isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    final ok = await widget.onVerify(id, _company.name);
    if (!mounted) return;
    setState(() => _isProcessingAction = false);
    if (ok) {
      await _loadCompanyContext();
    }
  }

  Future<void> _handleRejectAction() async {
    final id = _company.companyID;
    if (id == null || id.isEmpty || _isProcessingAction) return;
    setState(() => _isProcessingAction = true);
    final ok = await widget.onReject(id, _company.name);
    if (!mounted) return;
    setState(() => _isProcessingAction = false);
    if (ok) {
      await _loadCompanyContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = _company.verificationStatus.toLowerCase();
    final String docUrl = (_company.verificationDocumentURL ?? '').trim();
    final bool hasDoc = docUrl.isNotEmpty;
    final String? verifiedAtText = _formatTimestamp(_rawData['verifiedAt']);
    final String rejectionReason = (_company.rejectionReason ?? '').trim();
    final String planType = _company.currentPlanType.trim().toUpperCase();
    final String? subEndsText = _company.subscriptionEndsAt != null
        ? DateFormat('dd MMM yyyy').format(_company.subscriptionEndsAt!.toLocal())
        : null;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _heroStart),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Company Review',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh details',
            icon: const Icon(Icons.refresh_rounded, color: _heroStart),
            onPressed: _loadCompanyContext,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCompanyContext,
        color: _primaryGreen,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            // 1. Hero Company Summary Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_heroStart, _heroEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CompanyLogoAvatar(
                        logoUrl: _company.companyLogoURL,
                        companyName: _company.name,
                        size: 62,
                        lightBorder: true,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _company.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SSM Registration: ${_company.registrationNumber}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusBadge(status: status),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.workspace_premium_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _company.isSubscriptionExpired
                                  ? 'Plan: $planType (Expired)'
                                  : 'Plan: $planType',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$_jobCount Active/Posted Job(s)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE9E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFC24E4E).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.report_problem_rounded,
                      color: Color(0xFFC24E4E),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rejection Reason',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFFC24E4E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rejectionReason,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: Color(0xFF8C2D2D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 2. Verification Document Card
            _buildSectionCard(
              icon: Icons.verified_user_outlined,
              title: 'Verification Document',
              subtitle:
                  'Official SSM / business registration file submitted by the employer.',
              child: hasDoc
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _bgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD9ECE8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  docUrl.toLowerCase().contains('.pdf')
                                      ? Icons.picture_as_pdf_rounded
                                      : Icons.image_outlined,
                                  color: _heroStart,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _extractFileName(docUrl),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _detectDocTypeLabel(docUrl),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                onPressed: _openDocumentPreview,
                                icon: const Icon(
                                  Icons.visibility_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Preview in App',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryGreen,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    FilePreviewHelper.previewNetworkFile(
                                      context,
                                      docUrl,
                                    ),
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 17,
                                ),
                                label: const Text('External'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _heroStart,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'No verification document URL is attached to this company record.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // 3. Complete Company Information Card
            _buildSectionCard(
              icon: Icons.business_rounded,
              title: 'Company Profile & Registration',
              subtitle: 'Complete business details submitted during registration.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Company Name', _company.name),
                  const Divider(height: 22),
                  _buildDetailRow(
                    'SSM / Registration Number',
                    _company.registrationNumber,
                  ),
                  const Divider(height: 22),
                  _buildDetailRow(
                    'Subscription Tier',
                    subEndsText != null
                        ? '$planType (Ends $subEndsText)'
                        : planType,
                  ),
                  if (verifiedAtText != null) ...[
                    const Divider(height: 22),
                    _buildDetailRow('Verified At', verifiedAtText),
                  ],
                  if ((_company.companyID ?? '').isNotEmpty) ...[
                    const Divider(height: 22),
                    _buildDetailRow('Company ID', _company.companyID!),
                  ],
                  const Divider(height: 22),
                  const Text(
                    'Company Description',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _company.description.trim().isEmpty
                        ? 'No company description provided.'
                        : _company.description.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Headquarters Location Card
            _buildSectionCard(
              icon: Icons.location_on_outlined,
              title: 'Headquarters Location',
              subtitle: 'Registered office address and map coordinates.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'Street Address',
                    (_company.companyAddress ?? '').trim().isEmpty
                        ? 'Not specified'
                        : _company.companyAddress!.trim(),
                  ),
                  if (_company.latitude != null &&
                      _company.longitude != null) ...[
                    const Divider(height: 22),
                    _buildDetailRow(
                      'GPS Coordinates',
                      '${_company.latitude!.toStringAsFixed(6)}, ${_company.longitude!.toStringAsFixed(6)}',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openInGoogleMaps,
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Open Pin in Google Maps'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryGreen,
                          side: BorderSide(
                            color: _primaryGreen.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 5. Registered Employer / Team Members Card
            _buildSectionCard(
              icon: Icons.people_outline_rounded,
              title: 'Registered Employer & Team',
              subtitle: 'Employer accounts linked to this company workspace.',
              child: _isLoadingExtras
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(color: _primaryGreen),
                      ),
                    )
                  : _members.isEmpty
                      ? const Text(
                          'No employer members found for this company.',
                          style: TextStyle(color: _textSecondary, fontSize: 13.5),
                        )
                      : Column(
                          children: _members.map((m) {
                            final emp =
                                (m['Employer'] as Map<String, dynamic>?) ?? {};
                            final fullName =
                                (emp['fullName'] ?? 'Employer').toString();
                            final email = (emp['email'] ?? 'No email').toString();
                            final role = (m['companyRole'] ?? 'member')
                                .toString()
                                .toUpperCase();
                            final memberStatus =
                                (m['status'] ?? 'active').toString();
                            final joinedText = _formatTimestamp(m['joinedAt']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _bgColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFFD9ECE8),
                                    child: Text(
                                      fullName.isNotEmpty
                                          ? fullName[0].toUpperCase()
                                          : 'E',
                                      style: const TextStyle(
                                        color: _heroStart,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: _textSecondary,
                                          ),
                                        ),
                                        if (joinedText != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Joined: $joinedText · Status: $memberStatus',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: _textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: role == 'OWNER'
                                          ? const Color(0xFFD9ECE8)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      role,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: _heroStart,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
            ),

            const SizedBox(height: 18),

            // 6. Admin Decision Section
            _buildSectionCard(
              icon: Icons.gavel_rounded,
              title: 'Verification Decision',
              subtitle: status == 'pending'
                  ? 'Approve or reject this company after checking the SSM document.'
                  : 'You can update this company’s verification status if needed.',
              child: Row(
                children: [
                  if (status != 'verified')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isProcessingAction ? null : _handleVerifyAction,
                        icon: const Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          status == 'rejected'
                              ? 'Approve Company'
                              : 'Verify Company',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  if (status == 'pending') const SizedBox(width: 12),
                  if (status != 'rejected')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isProcessingAction ? null : _handleRejectAction,
                        icon: const Icon(
                          Icons.cancel_outlined,
                          size: 18,
                          color: Color(0xFFC24E4E),
                        ),
                        label: Text(
                          status == 'verified'
                              ? 'Revoke & Reject'
                              : 'Reject Company',
                          style: const TextStyle(
                            color: Color(0xFFC24E4E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFC24E4E)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9ECE8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _heroStart, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// In-App Verification Document Viewer (Supports PDF & JPG/PNG + Private/Public)
// ============================================================================

class _AdminVerificationDocViewerScreen extends StatefulWidget {
  final String companyName;
  final String documentUrl;

  const _AdminVerificationDocViewerScreen({
    required this.companyName,
    required this.documentUrl,
  });

  @override
  State<_AdminVerificationDocViewerScreen> createState() =>
      _AdminVerificationDocViewerScreenState();
}

class _AdminVerificationDocViewerScreenState
    extends State<_AdminVerificationDocViewerScreen> {
  static const Color _bgColor = Color(0xFFF4F7FB);
  static const Color _heroStart = Color(0xFF12343B);
  static const Color _primaryGreen = Color(0xFF1D6F6A);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textSecondary = Color(0xFF687588);

  Uint8List? _bytes;
  File? _tempFile;
  bool _isPdf = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  bool _looksLikePdf(Uint8List bytes, String url) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return true; // %PDF magic bytes
    }
    return url.split('?').first.toLowerCase().endsWith('.pdf');
  }

  String _inferExtension(bool isPdf, String url) {
    if (isPdf) return 'pdf';
    final clean = url.split('?').first.toLowerCase();
    if (clean.endsWith('.png')) return 'png';
    if (clean.endsWith('.jpeg')) return 'jpeg';
    return 'jpg';
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _bytes = null;
      _tempFile = null;
    });

    try {
      String resolvedUrl = await StorageUrlHelper.resolve(widget.documentUrl);
      http.Response response = await http.get(Uri.parse(resolvedUrl));

      // Fallback: if verification_documents bucket is private in Supabase,
      // generate a short-lived signed URL automatically.
      if (response.statusCode != 200) {
        final parsed = StorageUrlHelper.parse(widget.documentUrl);
        if (parsed != null) {
          final signedUrl = await Supabase.instance.client.storage
              .from(parsed.bucket)
              .createSignedUrl(parsed.path, 600);
          resolvedUrl = signedUrl;
          response = await http.get(Uri.parse(resolvedUrl));
        }
      }

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception(
          'Document could not be downloaded (HTTP ${response.statusCode}).',
        );
      }

      final bytes = response.bodyBytes;
      final isPdf = _looksLikePdf(bytes, resolvedUrl);
      final ext = _inferExtension(isPdf, resolvedUrl);
      final safeName = widget.companyName
          .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/verification_${safeName}_doc.$ext');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _tempFile = file;
        _isPdf = isPdf;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed loading verification document: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            'Unable to load the verification document in-app. You can try again or open it in an external browser.';
      });
    }
  }

  Future<void> _shareDocument() async {
    final file = _tempFile;
    if (file == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: '${widget.companyName} - Verification Document',
      ),
    );
  }

  Future<void> _openExternally() async {
    final file = _tempFile;
    if (file != null) {
      final result = await OpenFilex.open(file.path);
      if (result.type == ResultType.done) return;
    }
    if (mounted) {
      await FilePreviewHelper.previewNetworkFile(context, widget.documentUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = !_isLoading && _bytes != null;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _heroStart),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.companyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            Text(
              ready
                  ? (_isPdf
                      ? 'SSM / Verification PDF'
                      : 'SSM / Verification Image (pinch to zoom)')
                  : 'Verification Document',
              style: const TextStyle(fontSize: 12, color: _textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Share or save',
            onPressed: ready ? _shareDocument : null,
            icon: Icon(
              Icons.ios_share_rounded,
              color: ready ? _heroStart : Colors.grey.shade400,
            ),
          ),
          IconButton(
            tooltip: 'Open externally',
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new_rounded, color: _heroStart),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _primaryGreen),
                    SizedBox(height: 14),
                    Text(
                      'Loading verification document...',
                      style: TextStyle(color: _textSecondary),
                    ),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            size: 46,
                            color: Color(0xFFC24E4E),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _loadDocument,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Retry',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryGreen,
                                  elevation: 0,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    FilePreviewHelper.previewNetworkFile(
                                      context,
                                      widget.documentUrl,
                                    ),
                                icon: const Icon(Icons.open_in_browser_rounded),
                                label: const Text('Open in Browser'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : _isPdf
                    ? SfPdfViewer.memory(
                        _bytes!,
                        canShowScrollHead: true,
                        pageSpacing: 6,
                      )
                    : InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5.0,
                        child: Center(
                          child: Image.memory(
                            _bytes!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Could not decode image format. Tap the top-right button to open externally.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
      ),
    );
  }
}

// ============================================================================
// Shared UI Helpers
// ============================================================================

class _CompanyLogoAvatar extends StatelessWidget {
  final String? logoUrl;
  final String companyName;
  final double size;
  final bool lightBorder;

  const _CompanyLogoAvatar({
    required this.logoUrl,
    required this.companyName,
    this.size = 48,
    this.lightBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = (logoUrl ?? '').trim();
    final initial =
        companyName.trim().isNotEmpty ? companyName.trim()[0].toUpperCase() : 'C';

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFD9ECE8),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: lightBorder
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              )
            : null,
      ),
      child: cleanUrl.isNotEmpty
          ? Image.network(
              cleanUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallback(initial),
            )
          : _buildFallback(initial),
    );
  }

  Widget _buildFallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF12343B),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    late final Color fg;
    late final Color bg;
    late final IconData icon;
    late final String label;

    switch (normalized) {
      case 'verified':
      case 'approved':
        fg = const Color(0xFF1D6F6A);
        bg = const Color(0xFFD9ECE8);
        icon = Icons.verified_rounded;
        label = 'Verified';
        break;
      case 'rejected':
        fg = const Color(0xFFC24E4E);
        bg = const Color(0xFFFCE9E9);
        icon = Icons.cancel_outlined;
        label = 'Rejected';
        break;
      default:
        fg = const Color(0xFFB7791F);
        bg = const Color(0xFFFEF3DC);
        icon = Icons.schedule_rounded;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
