import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/utils/data_load_exception.dart';
import '../../../models/nearby_job_model.dart';
import '../../../core/constants/job_filter_options.dart';
import 'location_controller.dart';

/// Why the map couldn't use the phone's location.
enum LocationIssue { serviceOff, denied, blocked, failed }

/// Where the map should start, and why if it isn't the user's location.
class StartLocation {
  final LatLng position;
  final LocationIssue? issue;

  const StartLocation(this.position, [this.issue]);
}

/// State of the "Discover Nearby Jobs" map: filters, results, the selected
/// job, and whether the user has moved away from the searched area.
class JobMapController extends ChangeNotifier {
  final LocationController _locations = LocationController();

  /// Kuala Lumpur city centre, used when the phone's location isn't available.
  static const LatLng fallbackCenter = LatLng(3.140853, 101.693207);

  // ---- Filters --------------------------------------------------------
  String _keyword = '';
  String _jobType = JobFilterOptions.anyJobType;
  String _datePosted = JobFilterOptions.anyDate;
  String _salary = JobFilterOptions.anySalary;
  double _radiusKm = JobFilterOptions.defaultRadiusKm;

  String get keyword => _keyword;
  String get jobType => _jobType;
  String get datePosted => _datePosted;
  String get salary => _salary;
  double get radiusKm => _radiusKm;

  bool get hasActiveFilters =>
      _keyword.trim().isNotEmpty ||
      _jobType != JobFilterOptions.anyJobType ||
      _datePosted != JobFilterOptions.anyDate ||
      _salary != JobFilterOptions.anySalary ||
      _radiusKm != JobFilterOptions.defaultRadiusKm;

  String filterValue(String filterType) => switch (filterType) {
        JobFilterOptions.datePosted => _datePosted,
        JobFilterOptions.jobType => _jobType,
        _ => _salary,
      };

  // ---- Results --------------------------------------------------------
  List<NearbyJob> _jobs = [];
  bool _capped = false;
  bool _isLoading = false;
  bool _isLocating = false;
  bool _hasSearched = false;
  String? _error;
  LatLng? _searchCenter;
  int _selectedIndex = 0;
  bool _areaMoved = false;
  int _searchId = 0;
  bool _disposed = false;

  List<NearbyJob> get jobs => List.unmodifiable(_jobs);
  bool get capped => _capped;
  bool get isLoading => _isLoading;
  bool get isLocating => _isLocating;
  bool get hasSearched => _hasSearched;
  String? get error => _error;
  LatLng? get searchCenter => _searchCenter;
  bool get areaMoved => _areaMoved;
  bool get hasResults => _jobs.isNotEmpty;

  int get selectedIndex => _jobs.isEmpty ? -1 : _selectedIndex.clamp(0, _jobs.length - 1);
  NearbyJob? get selectedJob => _jobs.isEmpty ? null : _jobs[selectedIndex];

  /// Jobs at the same spot as [job] (including it), for "1 of 3 here".
  List<NearbyJob> jobsAtSameSpot(NearbyJob job) =>
      _jobs.where((j) => j.spotKey == job.spotKey).toList();

  /// Jobs grouped by spot, in the order of the list (nearest first).
  Map<String, List<NearbyJob>> get spots {
    final map = <String, List<NearbyJob>>{};
    for (final j in _jobs) {
      map.putIfAbsent(j.spotKey, () => []).add(j);
    }
    return map;
  }

  /// "12 jobs within 10 km"
  String get summary {
    final n = _jobs.length;
    final km = _radiusKm.toInt();
    if (n == 0) return 'No jobs within $km km';
    final count = _capped ? 'Nearest $n' : '$n';
    return '$count job${n == 1 ? '' : 's'} within $km km';
  }

  // ---------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------

  /// The phone's location: the last known one straight away if there is
  /// one, otherwise a fresh fix (gives up after 8 seconds).
  Future<StartLocation> findStartLocation() async {
    _isLocating = true;
    _notify();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const StartLocation(fallbackCenter, LocationIssue.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const StartLocation(fallbackCenter, LocationIssue.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const StartLocation(fallbackCenter, LocationIssue.blocked);
      }

      final last = await Geolocator.getLastKnownPosition();
      final recent = last != null &&
          DateTime.now().difference(last.timestamp).inMinutes < 30;
      if (recent) return StartLocation(LatLng(last.latitude, last.longitude));

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return StartLocation(LatLng(position.latitude, position.longitude));
    } catch (e) {
      debugPrint('Location failed: $e');
      final last = await Geolocator.getLastKnownPosition().catchError((_) => null);
      if (last != null) return StartLocation(LatLng(last.latitude, last.longitude));
      return const StartLocation(fallbackCenter, LocationIssue.failed);
    } finally {
      _isLocating = false;
      _notify();
    }
  }

  /// A town, area or address typed by the user, e.g. "Cyberjaya".
  /// Returns null if it can't be found.
  Future<LatLng?> findPlace(String query) async {
    final text = query.trim();
    if (text.isEmpty) return null;
    try {
      // Bias towards Malaysia for short names like "Bangsar".
      final withCountry = text.toLowerCase().contains('malaysia') ? text : '$text, Malaysia';
      var results = await locationFromAddress(withCountry);
      if (results.isEmpty) results = await locationFromAddress(text);
      if (results.isEmpty) return null;
      return LatLng(results.first.latitude, results.first.longitude);
    } catch (e) {
      debugPrint('Place search failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Searching
  // ---------------------------------------------------------------------

  /// Searches around [center] with the current filters.
  Future<void> search(LatLng center) async {
    final id = ++_searchId;
    _searchCenter = center;
    _isLoading = true;
    _areaMoved = false;
    _error = null;
    _notify();

    try {
      final result = await _locations.getNearbyJobs(
        center.latitude,
        center.longitude,
        _radiusKm * 1000,
        query: _keyword,
        jobType: _jobType,
        salary: _salary,
        datePosted: _datePosted,
      );
      if (id != _searchId) return; // a newer search started
      _jobs = result.jobs;
      _capped = result.capped;
      _selectedIndex = 0;
    } catch (e) {
      if (id != _searchId) return;
      _jobs = [];
      _capped = false;
      _error = e is DataLoadException ? e.message : 'Unable to load nearby jobs. Please try again.';
    } finally {
      if (id == _searchId) {
        _isLoading = false;
        _hasSearched = true;
        _notify();
      }
    }
  }

  /// Called when the user has dragged the map. Shows "Search this area" when
  /// the map centre is clearly away from the last search.
  void cameraSettled(LatLng center) {
    final last = _searchCenter;
    if (last == null) return;
    final movedKm = LocationController.distanceMeters(
          last.latitude,
          last.longitude,
          center.latitude,
          center.longitude,
        ) /
        1000;
    final moved = movedKm > (_radiusKm * 0.2).clamp(0.5, 10.0);
    if (moved != _areaMoved) {
      _areaMoved = moved;
      _notify();
    }
  }

  void select(int index) {
    if (index < 0 || index >= _jobs.length || index == _selectedIndex) return;
    _selectedIndex = index;
    _notify();
  }

  /// Index of the first job at [spotKey] (for a tapped pin).
  int indexOfSpot(String spotKey) => _jobs.indexWhere((j) => j.spotKey == spotKey);

  // ---------------------------------------------------------------------
  // Filters (the screen runs a new search after each change)
  // ---------------------------------------------------------------------

  void setKeyword(String value) => _keyword = value.trim();

  void setFilter(String filterType, String value) {
    switch (filterType) {
      case JobFilterOptions.datePosted:
        _datePosted = value;
      case JobFilterOptions.jobType:
        _jobType = value;
      default:
        _salary = value;
    }
    _notify();
  }

  void setRadius(double km) {
    _radiusKm = km.clamp(5.0, 100.0);
    _notify();
  }

  /// Doubles the radius (up to 100 km). Returns false if already at the max.
  bool widenRadius() {
    if (_radiusKm >= 100) return false;
    setRadius((_radiusKm * 2).clamp(5.0, 100.0));
    return true;
  }

  void clearFilters() {
    _keyword = '';
    _jobType = JobFilterOptions.anyJobType;
    _datePosted = JobFilterOptions.anyDate;
    _salary = JobFilterOptions.anySalary;
    _radiusKm = JobFilterOptions.defaultRadiusKm;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
