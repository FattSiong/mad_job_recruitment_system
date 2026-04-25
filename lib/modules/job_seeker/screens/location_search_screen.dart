import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme/app_colors.dart';

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

  // Get Current Location directly using Geocoding
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

      // 1. Get Coordinates
      Position position = await Geolocator.getCurrentPosition();

      // 2. Translate to City locally
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Search', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Styled Search Header Segment
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Keyword Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _keywordController,
                    decoration: const InputDecoration(
                      hintText: 'Search Job Title, Company or Skills',
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Location Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _locationController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) => _selectLocation(value.trim()),
                    onChanged: (value) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search a country, city or state',
                      hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                      prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                      suffixIcon: _locationController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                        onPressed: () {
                          _locationController.clear();
                          setState(() {});
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider shadow effect
          Container(height: 1, color: Colors.grey.shade200),

          // Search Suggestions Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Near Me Button
                  OutlinedButton.icon(
                    onPressed: _isLocating ? null : _getCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, color: AppColors.primaryBlue),
                    label: const Text('Near Me', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppColors.primaryBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Popular Location
                  const Text('Popular Locations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: _popularLocations.map((location) {
                      return InkWell(
                        onTap: () => _selectLocation(location),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(location, style: TextStyle(color: Colors.grey.shade800)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // Location By State
                  const Text('Location By State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _states.length,
                    itemBuilder: (context, index) {
                      final state = _states[index]; // Now just a String
                      return InkWell(
                        onTap: () => _selectLocation(state),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft, // Aligns text nicely to the left
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            state,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500, // Slightly bolder for readability
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}