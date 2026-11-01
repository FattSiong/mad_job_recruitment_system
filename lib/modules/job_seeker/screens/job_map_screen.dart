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
  static const Color _surfaceAlt = AppColors.surfaceAlt;
  static const Color _border = AppColors.border;

  final LocationController _locationController = LocationController();
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _salaryInputController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng _mapCenter = const LatLng(3.140853, 101.693207);

  String _selectedJobType = 'All';
  String _selectedDatePosted = 'All time';
  String _selectedSalary = 'Any';
  double _currentRadiusKm = 25.0;

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
    _salaryInputController.dispose();
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

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _textPrimary,
      backgroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      side: const BorderSide(color: _border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
      _currentRadiusKm = 25.0;
      _selectedJobType = 'All';
      _selectedDatePosted = 'All time';
      _selectedSalary = 'Any';
      _keywordController.clear();
      _salaryInputController.clear();
    });
  }

  void _showFilterOptions(String filterType) {
    List<String> options = [];
    String currentValue = '';

    if (filterType == 'Date posted') {
      options = [
        'All time',
        'Last 24 hours',
        'Last 3 days',
        'Last 7 days',
        'Last 14 days',
      ];
      currentValue = _selectedDatePosted;
    } else if (filterType == 'Job type') {
      options = ['All', 'Full-time', 'Part-time'];
      currentValue = _selectedJobType;
    } else if (filterType == 'Salary') {
      options = ['Any', 'RM1000', 'RM2000', 'RM3000', 'RM4000', 'RM5000'];
      currentValue = _selectedSalary;
      _salaryInputController.text =
          _selectedSalary.replaceAll(RegExp(r'[^0-9]'), '');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        double tempRadius = _currentRadiusKm;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      filterType == 'Radius'
                          ? 'Search Radius'
                          : 'Filter by $filterType',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      filterType == 'Radius'
                          ? 'Choose how far from the map center you want to search.'
                          : 'Refine nearby jobs with cleaner filters.',
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (filterType == 'Radius') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${tempRadius.toInt()} km',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Current search radius',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: _primary,
                                inactiveTrackColor: Colors.grey.shade300,
                                thumbColor: _primary,
                                overlayColor: _primary.withValues(alpha: 0.12),
                                valueIndicatorColor: _primary,
                                valueIndicatorTextStyle:
                                const TextStyle(color: Colors.white),
                                trackHeight: 8,
                                thumbShape: const CustomSliderThumb(
                                  icon: Icons.directions_car,
                                ),
                              ),
                              child: Slider(
                                value: tempRadius,
                                min: 5.0,
                                max: 100.0,
                                divisions: 19,
                                label: '${tempRadius.toInt()} km',
                                onChanged: (value) {
                                  setModalState(() {
                                    tempRadius = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() => _currentRadiusKm = 25.0);
                                Navigator.pop(context);
                              },
                              style: _secondaryButtonStyle(),
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() => _currentRadiusKm = tempRadius);
                                Navigator.pop(context);
                              },
                              style: _primaryButtonStyle(),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ] else if (filterType == 'Salary') ...[
                      TextField(
                        controller: _salaryInputController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'e.g. 3500',
                          prefixIcon: const Padding(
                            padding: EdgeInsetsDirectional.only(start: 16, end: 8),
                            child: Align(
                              widthFactor: 1,
                              heightFactor: 1,
                              child: Text(
                                'RM',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: _surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: _primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _salaryInputController.clear();
                                setState(() => _selectedSalary = 'Any');
                                Navigator.pop(context);
                              },
                              style: _secondaryButtonStyle(),
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final typed = _salaryInputController.text.trim();
                                setState(() {
                                  _selectedSalary =
                                  typed.isNotEmpty ? 'RM $typed' : 'Any';
                                });
                                Navigator.pop(context);
                              },
                              style: _primaryButtonStyle(),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Or Select Predefined Range',
                        style: TextStyle(
                          fontSize: 14,
                          color: _textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                          children: options.map((option) {
                            return RadioListTile<String>(
                              title: Text(option),
                              value: option,
                              activeColor: _primary,
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ),
                    ] else ...[
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
                          children: options.map((option) {
                            return RadioListTile<String>(
                              title: Text(option),
                              value: option,
                              activeColor: _primary,
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
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
        selectedColor: _primarySoft,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: isActive ? _primary : _textPrimary,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isActive ? const Color(0xFFB8D1EE) : _border,
          ),
        ),
        side: BorderSide(
          color: isActive ? const Color(0xFFB8D1EE) : _border,
        ),
      ),
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
                        onTap: () => _showFilterOptions('Radius'),
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
                                color: Color(0xFF1E8F8B),
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
      ..color = sliderTheme.thumbColor ?? AppColors.primary
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