import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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

  // 👉 Added controller for custom salary input matching Seeker Dashboard
  final TextEditingController _salaryInputController = TextEditingController();

  bool _isMapLoaded = false;
  GoogleMapController? _mapController;

  LatLng _mapCenter = const LatLng(3.140853, 101.693207);

  // Filter States
  String _selectedJobType = 'All';
  String _selectedDatePosted = 'All time';
  String _selectedSalary = 'Any';
  double _currentRadiusKm = 25.0;

  Set<Marker> _jobMarkers = {};
  Set<Circle> _circles = {};
  bool _isLoading = false;
  JobModel? _selectedJob;

  @override
  void dispose() {
    _keywordController.dispose();
    _salaryInputController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _mapCenter = LatLng(position.latitude, position.longitude);
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(_mapCenter));
        }
      });
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
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
          fillColor: const Color(0xFF0A66C2).withValues(alpha: 0.1),
          strokeColor: const Color(0xFF0A66C2),
          strokeWidth: 2,
        )
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
      }
    } catch (e) {
      debugPrint("Error searching jobs: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showFilterOptions(String filterType) {
    List<String> options = [];
    String currentValue = '';

    // Standard options setup remains the same
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // 👉 Move the temp variable declaration here so it's only scoped to this builder
        double tempRadius = _currentRadiusKm;

        return StatefulBuilder(
          builder: (context, setModalState) {
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

                      // 👉 Radius Slider uses tempRadius
                      if (filterType == 'Radius') ...[
                        const Text('Discovery nearby job', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text('Set search radius up to ${tempRadius.toInt()}km', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                        const SizedBox(height: 28),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: const Color(0xFF0A66C2),
                            inactiveTrackColor: Colors.grey.shade300,
                            thumbColor: const Color(0xFF0A66C2),
                            overlayColor: const Color(0xFF0A66C2).withValues(alpha: 0.12),
                            valueIndicatorColor: const Color(0xFF0A66C2),
                            valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                            trackHeight: 8,
                            thumbShape: const CustomSliderThumb(icon: Icons.directions_car),
                          ),
                          child: Slider(
                            value: tempRadius,
                            min: 5.0,
                            max: 100.0,
                            divisions: 19,
                            label: '${tempRadius.toInt()} km',
                            onChanged: (double value) {
                              setModalState(() {
                                tempRadius = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => _currentRadiusKm = 25.0);
                                  Navigator.pop(context);
                                },
                                child: const Text('Reset', style: TextStyle(color: Colors.black87)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() => _currentRadiusKm = tempRadius);
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A66C2)),
                                child: const Text('Apply', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        )
                      ]
                      // 👉 Salary Filter uses RadioGroup (No tempRadius needed)
                      else if (filterType == 'Salary') ...[
                        // Custom Input Logic...
                        const Text('Or Select Predefined Range', style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        RadioGroup<String>(
                          groupValue: currentValue,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedSalary = value);
                              Navigator.pop(context);
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
                      // 👉 Other filters use RadioGroup (No tempRadius needed)
                      else ...[
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
                        ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
                _getUserLocation();
              },
              icon: const Icon(Icons.cloud_download),
              label: const Text('Load Google Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A66C2),
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
              child: Icon(Icons.location_on, size: 40, color: AppColors.errorRed),
            ),
          ),

          // 👉 Top Controls Panel
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👉 Search Box and Radius Filter joined in ONE container
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))
                      ]
                  ),
                  child: Row(
                    children: [
                      // Text Field (Left Side)
                      Expanded(
                        child: TextField(
                          controller: _keywordController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: 'Job title, keywords...',
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),

                      // Subtle Divider between input and radius button
                      Container(width: 1, height: 30, color: Colors.grey.shade300),

                      // Radius Button (Right Side with Black Icon)
                      InkWell(
                        onTap: () => _showFilterOptions('Radius'),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions_car, color: Colors.black87),
                              const SizedBox(width: 6),
                              Text(
                                '${_currentRadiusKm.toInt()} km',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.tune, size: 20),
                          onPressed: () {
                            setState(() {
                              _currentRadiusKm = 25.0;
                              _selectedJobType = 'All';
                              _selectedDatePosted = 'All time';
                              _selectedSalary = 'Any';
                              _keywordController.clear();
                              _salaryInputController.clear();
                            });
                          },
                        ),
                      ),
                      _buildFilterChip('Date posted', _selectedDatePosted, 'All time'),
                      _buildFilterChip('Job type', _selectedJobType, 'All'),
                      _buildFilterChip('Salary', _selectedSalary, 'Any'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Positioned(
              top: 140,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A66C2))),
                        SizedBox(width: 12),
                        Text('Searching...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
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
                          child: const Icon(Icons.business, color: Color(0xFF0A66C2)),
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
                                style: const TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold),
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

          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getUserLocation,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),

          Positioned(
            bottom: 24,
            left: 40,
            right: 40,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _searchNearbyJobs,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Search Jobs Here',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomSliderThumb extends SliderComponentShape {
  final IconData icon;

  const CustomSliderThumb({required this.icon});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(36, 36);
  }

  @override
  void paint(
      PaintingContext context,
      Offset center, {
        required Animation<double> activationAnimation,
        required Animation<double> enableAnimation,
        required bool isDiscrete,
        required TextPainter labelPainter,
        required RenderBox parentBox,
        required SliderThemeData sliderTheme,
        required TextDirection textDirection,
        required double value,
        required double textScaleFactor,
        required Size sizeWithOverflow,
      }) {
    final Canvas canvas = context.canvas;

    final Paint paintCircle = Paint()
      ..color = sliderTheme.thumbColor ?? const Color(0xFF0A66C2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18, paintCircle);

    final TextPainter textPainter = TextPainter(textDirection: textDirection);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 22.0,
        fontFamily: icon.fontFamily,
        color: Colors.white,
        package: icon.fontPackage,
      ),
    );
    textPainter.layout();

    final Offset textOffset = Offset(
      center.dx - (textPainter.width / 2),
      center.dy - (textPainter.height / 2),
    );

    textPainter.paint(canvas, textOffset);
  }
}