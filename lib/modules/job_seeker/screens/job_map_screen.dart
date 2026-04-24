import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../models/job_model.dart';
import '../controllers/location_controller.dart';
import 'job_details_screen.dart';

class JobMapScreen extends StatefulWidget {
  const JobMapScreen({super.key});

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  final LocationController _locationController = LocationController();
  final TextEditingController _keywordController = TextEditingController();

  bool _isMapLoaded = false;
  GoogleMapController? _mapController;
  LatLng _mapCenter = const LatLng(3.140853, 101.693207);
  double _searchRadiusMeters = 5000;

  Set<Marker> _jobMarkers = {};
  Set<Circle> _circles = {};
  bool _isLoading = false;
  JobModel? _selectedJob;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _searchNearbyJobs() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _selectedJob = null;
      _circles = {
        Circle(
          circleId: const CircleId('search_radius'),
          center: _mapCenter,
          radius: _searchRadiusMeters,
          // 👉 Standardized to use your primary brand color instead of red
          fillColor: AppColors.primaryBlue.withOpacity(0.1),
          strokeColor: AppColors.primaryBlue,
          strokeWidth: 2,
        )
      };
    });

    final jobs = await _locationController.getNearbyJobs(
      _mapCenter.latitude,
      _mapCenter.longitude,
      _searchRadiusMeters,
      query: _keywordController.text.trim(),
    );

    final Set<Marker> newMarkers = jobs.map((job) {
      return Marker(
        markerId: MarkerId(job.jobID!),
        position: LatLng(job.latitude!, job.longitude!),
        consumeTapEvents: true,
        onTap: () {
          setState(() {
            _selectedJob = job;
          });
        },
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    }).toSet();

    if (mounted) {
      setState(() {
        _jobMarkers = newMarkers;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${jobs.length} jobs in this area.'),
          backgroundColor: AppColors.primaryBlue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Nearby Jobs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: !_isMapLoaded
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: UiConstants.defaultPadding),
            const Text('Map loading is paused to save API quota.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _isMapLoaded = true);
                _searchNearbyJobs();
              },
              icon: const Icon(Icons.cloud_download),
              label: const Text('Load Google Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _mapCenter,
              zoom: 12.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) {
              _mapCenter = position.target;
              if (_selectedJob != null) {
                setState(() => _selectedJob = null);
              }
            },
            onTap: (position) {
              if (_selectedJob != null) {
                setState(() => _selectedJob = null);
              }
            },
            markers: _jobMarkers,
            circles: _circles,
            myLocationEnabled: true,
          ),

          // Center Pin
          const Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(bottom: 36.0),
              child: Icon(Icons.location_on, size: 40, color: AppColors.errorRed),
            ),
          ),

          // Top Control Panel
          Positioned(
            top: UiConstants.defaultPadding,
            left: UiConstants.defaultPadding,
            right: UiConstants.defaultPadding,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiConstants.cornerRadius)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _keywordController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Flutter, QA, Manager...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(UiConstants.cornerRadius)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                        ),
                      ),
                      onSubmitted: (_) => _searchNearbyJobs(),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Text('Radius:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Slider(
                            value: _searchRadiusMeters,
                            min: 1000,
                            max: 20000,
                            divisions: 19,
                            activeColor: AppColors.primaryBlue,
                            inactiveColor: AppColors.primaryBlue.withOpacity(0.2),
                            label: '${(_searchRadiusMeters / 1000).round()} km',
                            onChanged: (value) {
                              setState(() {
                                _searchRadiusMeters = value;
                              });
                            },
                          ),
                        ),
                        Text('${(_searchRadiusMeters / 1000).toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _searchNearbyJobs,
                        icon: const Icon(Icons.manage_search),
                        label: const Text('Search This Area', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiConstants.cornerRadius)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_isLoading)
            const Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
                        SizedBox(width: 12),
                        Text('Searching...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Floating Job Details Card
          if (_selectedJob != null)
            Positioned(
              bottom: 30,
              left: UiConstants.defaultPadding,
              right: UiConstants.defaultPadding,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => JobDetailsScreen(job: _selectedJob!)),
                  );
                },
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiConstants.cornerRadius)),
                  child: Padding(
                    padding: const EdgeInsets.all(UiConstants.defaultPadding),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                          ),
                          child: const Icon(Icons.business, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(width: UiConstants.defaultPadding),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedJob!.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedJob!.companyName ?? 'Unknown Company',
                                style: TextStyle(color: Colors.grey.shade700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedJob!.salaryRange,
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}