import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/job_model.dart';
import '../controllers/location_controller.dart';
import 'job_details_screen.dart';
import '../widgets/job_filters.dart';

class JobMapScreen extends StatefulWidget {
  const JobMapScreen({super.key});

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  static const Color _primary = AppColors.primary;
  static const Color _primarySoft = AppColors.primarySoft;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;
  static const Color _border = AppColors.border;

  final LocationController _locationController = LocationController();
  final TextEditingController _keywordController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng _mapCenter = const LatLng(3.140853, 101.693207);

  String _selectedJobType = JobFilterOptions.anyJobType;
  String _selectedDatePosted = JobFilterOptions.anyDate;
  String _selectedSalary = JobFilterOptions.anySalary;
  double _currentRadiusKm = JobFilterOptions.defaultRadiusKm;

  Set<Marker> _jobMarkers = {};
  Set<Circle> _circles = {};
  bool _isLoading = false;
  JobModel? _selectedJob;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationProblem(
          'Location is turned off. Showing Kuala Lumpur instead.',
          actionLabel: 'Turn On',
          onAction: Geolocator.openLocationSettings,
        );
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationProblem(
            'Location permission was denied. Showing Kuala Lumpur instead. '
            'You can still move the map to search any area.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationProblem(
          'Location permission is blocked. Allow it in Settings to see jobs near you.',
          actionLabel: 'Settings',
          onAction: Geolocator.openAppSettings,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _mapCenter = LatLng(position.latitude, position.longitude);
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _mapCenter, zoom: 12.5),
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showLocationProblem('Unable to get your current location. Showing Kuala Lumpur instead.');
    }
  }

  void _showLocationProblem(
    String message, {
    String? actionLabel,
    Future<bool> Function()? onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(label: actionLabel, onPressed: () => onAction())
            : null,
      ),
    );
  }

  Future<void> _searchNearbyJobs() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _selectedJob = null;
      _jobMarkers = {};
      _circles = {
        Circle(
          circleId: const CircleId('search_radius'),
          center: _mapCenter,
          radius: _currentRadiusKm * 1000,
          fillColor: _primary.withValues(alpha: 0.10),
          strokeColor: _primary,
          strokeWidth: 2,
        ),
      };
    });

    try {
      final jobs = await _locationController.getNearbyJobs(
        _mapCenter.latitude,
        _mapCenter.longitude,
        _currentRadiusKm * 1000,
        query: _keywordController.text.trim(),
        jobType: _selectedJobType,
        salary: _selectedSalary,
        datePosted: _selectedDatePosted,
      );

      final safeJobs = jobs
          .where((job) => job.jobID != null && job.latitude != null && job.longitude != null)
          .toList();

      final newMarkers = safeJobs.map((job) {
        return Marker(
          markerId: MarkerId(job.jobID!),
          position: LatLng(job.latitude!, job.longitude!),
          consumeTapEvents: true,
          onTap: () {
            setState(() {
              _selectedJob = job;
            });
          },
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
        );
      }).toSet();

      if (!mounted) return;

      setState(() {
        _jobMarkers = newMarkers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error searching jobs: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      SnackBarHelper.showStyled(
        context,
        message: e is DataLoadException
            ? e.message
            : 'Unable to load nearby jobs. Please try again.',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _currentRadiusKm = JobFilterOptions.defaultRadiusKm;
      _selectedJobType = JobFilterOptions.anyJobType;
      _selectedDatePosted = JobFilterOptions.anyDate;
      _selectedSalary = JobFilterOptions.anySalary;
      _keywordController.clear();
    });
  }

  String _currentFilterValue(String filterType) {
    switch (filterType) {
      case JobFilterOptions.datePosted:
        return _selectedDatePosted;
      case JobFilterOptions.jobType:
        return _selectedJobType;
      default:
        return _selectedSalary;
    }
  }

  Future<void> _showFilterOptions(String filterType) async {
    final value = await showJobFilterSheet(
      context,
      filterType: filterType,
      currentValue: _currentFilterValue(filterType),
    );
    if (value == null || !mounted) return;

    setState(() {
      switch (filterType) {
        case JobFilterOptions.datePosted:
          _selectedDatePosted = value;
        case JobFilterOptions.jobType:
          _selectedJobType = value;
        default:
          _selectedSalary = value;
      }
    });
  }

  Future<void> _showRadiusOptions() async {
    final km = await showRadiusFilterSheet(context, currentKm: _currentRadiusKm);
    if (km == null || !mounted) return;
    setState(() => _currentRadiusKm = km);
  }

  Widget _buildFilterChip(String label, String value, String defaultValue) {
    return JobFilterChip(
      label: label,
      value: value,
      defaultValue: defaultValue,
      onTap: () => _showFilterOptions(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Discover Nearby Jobs',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _textPrimary),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _mapCenter,
              zoom: 12.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) {
              _mapCenter = position.target;
              if (_selectedJob != null) setState(() => _selectedJob = null);
            },
            onTap: (_) {
              if (_selectedJob != null) setState(() => _selectedJob = null);
            },
            markers: _jobMarkers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          const Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(bottom: 36.0),
              child: Icon(
                Icons.location_on,
                size: 40,
                color: AppColors.errorRed,
              ),
            ),
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _keywordController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _searchNearbyJobs(),
                          decoration: const InputDecoration(
                            hintText: 'Job title, keywords...',
                            hintStyle: TextStyle(color: _textMuted),
                            prefixIcon: Icon(Icons.search, color: _textMuted),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey.shade300,
                      ),
                      InkWell(
                        onTap: _showRadiusOptions,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(18),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.directions_car,
                                color: _primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_currentRadiusKm.toInt()} km',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.tune,
                            size: 20,
                            color: _primary,
                          ),
                          onPressed: _resetFilters,
                        ),
                      ),
                      _buildFilterChip(
                        'Date posted',
                        _selectedDatePosted,
                        'All time',
                      ),
                      _buildFilterChip(
                        'Job type',
                        _selectedJobType,
                        'All',
                      ),
                      _buildFilterChip(
                        'Salary',
                        _selectedSalary,
                        'Any',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Positioned(
              top: 140,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Searching...',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_selectedJob != null)
            Positioned(
              bottom: 110,
              left: UiConstants.defaultPadding,
              right: UiConstants.defaultPadding,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobDetailsScreen(job: _selectedJob!),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(UiConstants.defaultPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _primarySoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: UiConstants.defaultPadding),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedJob!.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedJob!.companyName ?? 'Unknown Company',
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedJob!.salaryRange,
                              style: const TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              elevation: 4,
              backgroundColor: Colors.white,
              onPressed: _getUserLocation,
              child: const Icon(
                Icons.my_location_rounded,
                color: _primary,
              ),
            ),
          ),

          Positioned(
            bottom: 24,
            left: 40,
            right: 40,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _searchNearbyJobs,
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text(
                'Search Jobs Here',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: _primaryButtonStyle(),
            ),
          ),
        ],
      ),
    );
  }
}
