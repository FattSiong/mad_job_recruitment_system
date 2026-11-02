import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared_widgets/hero_icon_button.dart';

class LocationSearchScreen extends StatefulWidget {
  final String initialKeyword;
  final String initialLocation;

  const LocationSearchScreen({
    super.key,
    required this.initialKeyword,
    required this.initialLocation,
  });

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  // Theme Colors matching Seeker Dashboard

  late TextEditingController _keywordController;
  late TextEditingController _locationController;
  bool _isLocating = false;

  final List<String> _popularLocations = [
    'Kuala Lumpur', 'Selangor', 'Johor Bahru', 'Shah Alam', 'Penang',
    'Melaka', 'Petaling Jaya', 'Johor', 'Ipoh', 'Sabah', 'Kedah',
    'Pulau Pinang', 'Kelantan', 'Puchong'
  ];

  final List<String> _states = [
    'Johor', 'Kedah', 'Kelantan', 'Kuala Lumpur', 'Labuan', 'Malacca',
    'Negeri Sembilan', 'Pahang', 'Penang', 'Perak', 'Perlis',
    'Putrajaya', 'Sabah', 'Sarawak', 'Selangor', 'Terengganu'
  ];

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController(text: widget.initialKeyword);
    _locationController = TextEditingController(text: widget.initialLocation);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _selectLocation(String location) {
    Navigator.pop(context, {
      'keyword': _keywordController.text.trim(),
      'location': location,
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String city = place.locality ?? place.subAdministrativeArea ?? 'Unknown Location';

        if (city != 'Unknown Location') {
          _selectLocation(city);
        } else {
          throw Exception('Could not determine city from current location.');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showStyled(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
          icon: Icons.location_off_rounded,
          accentColor: AppColors.coral,
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  InputDecoration _searchInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // Wrap the entire Column in a SingleChildScrollView so everything scrolls together
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    // Hero Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
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
                              HeroIconButton(
                                icon: Icons.arrow_back_rounded,
                                tooltip: 'Back',
                                onTap: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 16, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Location Search',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Find roles nearby',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Search by city, state, or use your current location.',
                            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search Inputs Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _keywordController,
                            textInputAction: TextInputAction.next,
                            decoration: _searchInputDecoration(
                              hint: 'Job title, keywords, or company',
                              icon: Icons.search,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _locationController,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (value) {
                              final trimmed = value.trim();
                              if (trimmed.isEmpty) return;
                              _selectLocation(trimmed);
                            },
                            onChanged: (value) => setState(() {}),
                            decoration: _searchInputDecoration(
                              hint: 'Country, city or state',
                              icon: Icons.location_on_outlined,
                              suffix: _locationController.text.isNotEmpty
                                  ? IconButton(
                                icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                                onPressed: () {
                                  _locationController.clear();
                                  setState(() {});
                                },
                              )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLocating ? null : _getCurrentLocation,
                              icon: _isLocating
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.my_location_rounded),
                              label: Text(_isLocating ? 'Locating...' : 'Use Current Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Suggestions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Popular Locations',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10.0,
                      runSpacing: 10.0,
                      children: _popularLocations.map((location) {
                        return InkWell(
                          onTap: () => _selectLocation(location),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                                location,
                                style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500)
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Location By State',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true, // Important when inside SingleChildScrollView
                      physics: const NeverScrollableScrollPhysics(), // Disables GridView's internal scroll
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _states.length,
                      itemBuilder: (context, index) {
                        final state = _states[index];
                        return InkWell(
                          onTap: () => _selectLocation(state),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.map_outlined, size: 16, color: AppColors.textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state,
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}