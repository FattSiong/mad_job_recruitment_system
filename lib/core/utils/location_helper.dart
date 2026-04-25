import 'package:geocoding/geocoding.dart';

class LocationHelper {
  // A simple memory cache to prevent spamming the geocoding API while scrolling
  static final Map<String, String> _locationCache = {};

  static Future<String> getCityFromCoordinates(double? lat, double? lng) async {
    if (lat == null || lng == null) return 'Location unavailable';

    // Create a unique key for these coordinates
    final cacheKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

    // If we already calculated this location during this session, return it instantly!
    if (_locationCache.containsKey(cacheKey)) {
      return _locationCache[cacheKey]!;
    }

    try {
      // Otherwise, ask the map API for the city name
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // 'locality' is usually the city/town (e.g., Kuala Lumpur, Kajang)
        String city = place.locality ?? place.subAdministrativeArea ?? 'Unknown Location';

        // Save it to the cache for next time
        _locationCache[cacheKey] = city;
        return city;
      }
    } catch (e) {
      print('Geocoding error: $e');
    }

    return 'Unknown Location';
  }
}