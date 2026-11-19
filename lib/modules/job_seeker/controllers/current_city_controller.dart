import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/utils/data_load_exception.dart';

/// Finds the city the phone is in, for the "Use my current location"
/// button of the job search.
class CurrentCityController {
  CurrentCityController._();

  static const String _fallbackMessage =
      'Could not get your location. Please try again or type a city.';

  /// The city (or area / state) of the phone's location.
  /// Throws a [DataLoadException] with a message to show when it can't.
  static Future<String> findCity() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw DataLoadException('Location services are turned off.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw DataLoadException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw DataLoadException('Location permission is blocked. Allow it in the phone settings.');
    }

    try {
      // Give up after 10 s indoors / with weak GPS instead of spinning forever.
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) throw DataLoadException(_fallbackMessage);

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      final place = placemarks.isEmpty ? null : placemarks.first;
      // Android often gives "" (not null) for a missing part, so skip empty ones.
      final city = [place?.locality, place?.subAdministrativeArea, place?.administrativeArea]
          .map((part) => part?.trim() ?? '')
          .firstWhere((part) => part.isNotEmpty, orElse: () => '');
      if (city.isEmpty) {
        throw DataLoadException('Could not find the city for your location. Please type it instead.');
      }
      return city;
    } on DataLoadException {
      rethrow;
    } catch (_) {
      throw DataLoadException(_fallbackMessage);
    }
  }
}
