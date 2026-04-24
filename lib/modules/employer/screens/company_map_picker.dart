import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class CompanyMapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const CompanyMapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<CompanyMapPickerScreen> createState() => _CompanyMapPickerScreenState();
}

class _CompanyMapPickerScreenState extends State<CompanyMapPickerScreen> {
  LatLng? _pickedLocation;
  late GoogleMapController _mapController;
  final _searchController = TextEditingController();

  List<dynamic> _placeList = [];
  Timer? _debounce;

  // 🚨 FYP ALERT: Paste your Google Maps API Key here!
  final String _googleApiKey = 'AIzaSyCjhaAJXXE3F-LL_m4xDgTap1M_42quPKw';

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _pickedLocation = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _getSuggestions(query);
      } else {
        setState(() => _placeList = []);
      }
    });
  }

  // 👉 NEW: Restructured for Places API (New)
  Future<void> _getSuggestions(String input) async {
    const String url = 'https://places.googleapis.com/v1/places:autocomplete';

    // 1. The Body: Sending the input and restricting to Malaysia ('MY')
    final Map<String, dynamic> body = {
      'input': input,
      'includedRegionCodes': ['MY'], // Replaces the old components=country:my
    };

    try {
      // 2. The POST Request: Key and Content-Type must be in the headers
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleApiKey,
        },
        body: json.encode(body),
      );

      final result = json.decode(response.body);

      // 3. Handle the new response structure
      if (response.statusCode == 200 && result['suggestions'] != null) {
        setState(() {
          _placeList = result['suggestions'];
        });
      } else {
        print('Google API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Network Error: $e');
    }
  }

  Future<void> _selectLocation(String address) async {
    _searchController.text = address;
    setState(() => _placeList = []);

    FocusScope.of(context).unfocus();

    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newLatLng = LatLng(loc.latitude, loc.longitude);

        setState(() {
          _pickedLocation = newLatLng;
        });

        _mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newLatLng, zoom: 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find exactly where this is. Try another suggestion.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialPosition = _pickedLocation ?? const LatLng(3.1390, 101.6869);

    return Scaffold(
      appBar: AppBar(title: const Text('Pick Job Location')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPosition,
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (location) {
              setState(() {
                _pickedLocation = location;
                FocusScope.of(context).unfocus();
                _placeList = [];
              });
            },
            markers: _pickedLocation == null
                ? {}
                : {
              Marker(
                markerId: const MarkerId('picked-location'),
                position: _pickedLocation!,
              ),
            },
          ),

          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search for a location...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _placeList = []);
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                if (_placeList.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _placeList.length,
                      itemBuilder: (context, index) {
                        final place = _placeList[index];

                        // 👉 NEW: Parsing the deeply nested JSON structure of the New API
                        final prediction = place['placePrediction'];
                        if (prediction == null) return const SizedBox.shrink();

                        final addressText = prediction['text']['text'] ?? 'Unknown location';

                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.blue),
                          title: Text(addressText),
                          onTap: () {
                            _selectLocation(addressText);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          if (_pickedLocation != null)
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 4,
                ),
                onPressed: () => Navigator.pop(context, _pickedLocation),
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirm Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}