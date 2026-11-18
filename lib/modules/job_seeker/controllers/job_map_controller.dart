import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/utils/data_load_exception.dart';
import '../../../models/job_model.dart';
import '../../../models/nearby_job_model.dart';
import '../../../core/constants/job_filter_options.dart';
import 'job_discovery_controller.dart';
import 'location_controller.dart';
import '../../../core/utils/safe_notifier.dart';

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
class JobMapController extends ChangeNotifier with SafeNotifier {
  final LocationController _locations = LocationController();

  /// Kuala Lumpur city centre, used when the phone's location isn't available.
  static const LatLng fallbackCenter = LatLng(3.140853, 101.693207);

  // ---- Search ---------------------------------------------------------
  /// Keyword, filters and radius. [JobSearchFilters.location] is what the
  /// search is around: [JobFilterOptions.currentLocation] (the phone), a
  /// place name, or empty (wherever the user moved the map).
  JobSearchFilters _filters = const JobSearchFilters(
    location: JobFilterOptions.currentLocation,
    radiusKm: JobFilterOptions.defaultRadiusKm,
  );

  JobSearchFilters get filters => _filters;
  double get radiusKm => _filters.radiusKm ?? JobFilterOptions.defaultRadiusKm;

  /// "Near you", "Cyberjaya" or "This map area".
  String get areaLabel {
    final location = _filters.location.trim();
    if (location == JobFilterOptions.currentLocation) return 'Near you';
    return location.isEmpty ? 'This map area' : location;
  }

  /// True when the keyword or a filter narrows the search.
  bool get hasActiveFilters => _filters.query.trim().isNotEmpty || _filters.filterCount > 0;

  // ---- Results --------------------------------------------------------
  // Set once per search (and when a pin is opened), so building the map
  // and the list doesn't regroup or copy the jobs every frame.
  List<NearbyJob> _jobs = const [];
  Map<String, List<NearbyJob>> _spots = const {};
  List<NearbyJob> _listed = const [];
  bool _capped = false;
  bool _isLoading = false;
  bool _isLocating = false;
  bool _hasSearched = false;
  String? _error;
  LatLng? _searchCenter;
  String? _openSpot;
  bool _areaMoved = false;
  int _searchId = 0;

  List<NearbyJob> get jobs => _jobs;
  bool get capped => _capped;
  bool get isLoading => _isLoading;
  bool get isLocating => _isLocating;
  bool get hasSearched => _hasSearched;
  String? get error => _error;
  LatLng? get searchCenter => _searchCenter;
  bool get areaMoved => _areaMoved;
  bool get hasResults => _jobs.isNotEmpty;

  /// The pin whose jobs the list shows (after tapping it), or null for all jobs.
  String? get openedSpot => _openSpot;

  /// The jobs in the list: those at [openedSpot], or all of them.
  List<NearbyJob> get listedJobs => _listed;

  /// Jobs at the same spot as [job] (including it), for "3 here".
  List<NearbyJob> jobsAtSameSpot(NearbyJob job) => _spots[job.spotKey] ?? const [];

  /// Jobs grouped by spot (one pin each), nearest first.
  Map<String, List<NearbyJob>> get spots => _spots;

  /// Stores a new result and groups it by spot.
  void _setJobs(List<NearbyJob> jobs) {
    final grouped = <String, List<NearbyJob>>{};
    for (final j in jobs) {
      grouped.putIfAbsent(j.spotKey, () => []).add(j);
    }
    _jobs = List.unmodifiable(jobs);
    _spots = Map.unmodifiable(grouped.map((key, list) => MapEntry(key, List<NearbyJob>.unmodifiable(list))));
    _listed = _jobs;
    _openSpot = null;
  }

  /// "12 jobs within 10 km"
  String get summary {
    final n = _jobs.length;
    final km = radiusKm.toInt();
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
    notifySafely();
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
      notifySafely();
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
    notifySafely();

    try {
      final result = await _locations.getNearbyJobs(
        center.latitude,
        center.longitude,
        radiusKm * 1000,
        query: _filters.query,
        jobType: _filters.jobType,
        salary: _filters.salary,
        datePosted: _filters.datePosted,
        workplaceType: _filters.workplaceType,
      );
      if (id != _searchId) return; // a newer search started
      _setJobs(result.jobs);
      _capped = result.capped;
    } catch (e) {
      if (id != _searchId) return;
      _setJobs(const []);
      _capped = false;
      _error = e is DataLoadException ? e.message : 'Unable to load nearby jobs. Please try again.';
    } finally {
      if (id == _searchId) {
        _isLoading = false;
        _hasSearched = true;
        notifySafely();
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
    final moved = movedKm > (radiusKm * 0.2).clamp(0.5, 10.0);
    if (moved != _areaMoved) {
      _areaMoved = moved;
      notifySafely();
    }
  }

  // ---------------------------------------------------------------------
  // Opening a job
  // ---------------------------------------------------------------------

  /// Full jobs already loaded (the search leaves out descriptions).
  final Map<String, JobModel> _fullJobs = {};
  String? _openingJobID;

  /// The job being loaded to open its details (its card shows a spinner).
  String? get openingJobID => _openingJobID;

  /// The whole job for its details screen (loaded once, then remembered).
  /// Throws a [DataLoadException] when it can't be loaded.
  Future<JobModel> loadFullJob(NearbyJob item) async {
    final id = item.job.jobID;
    if (id == null) return item.job;
    final cached = _fullJobs[id];
    if (cached != null) return cached;

    _openingJobID = id;
    notifySafely();
    try {
      return _fullJobs[id] = await _locations.fetchJob(id);
    } finally {
      _openingJobID = null;
      notifySafely();
    }
  }

  /// A pin was tapped: list only its jobs (and highlight it).
  void openSpot(String spotKey) {
    final jobsHere = _spots[spotKey];
    if (_openSpot == spotKey || jobsHere == null) return;
    _openSpot = spotKey;
    _listed = jobsHere;
    notifySafely();
  }

  /// "Show all": list every job again.
  void showAllJobs() {
    if (_openSpot == null) return;
    _openSpot = null;
    _listed = _jobs;
    notifySafely();
  }

  // ---------------------------------------------------------------------
  // Filters (the screen runs a new search after each change)
  // ---------------------------------------------------------------------

  /// Sets the keyword, filters, radius and area for the next search.
  void setFilters(JobSearchFilters filters) {
    _filters = filters.copyWith(
      radiusKm: (filters.radiusKm ?? JobFilterOptions.defaultRadiusKm).clamp(5.0, 100.0),
    );
    notifySafely();
  }

  /// The next bigger radius choice, or null at the biggest.
  double? get nextRadiusKm {
    for (final km in JobFilterOptions.radiusOptions) {
      if (km > radiusKm) return km;
    }
    return null;
  }

  /// Switches to [nextRadiusKm]. Returns false if already at the biggest.
  bool widenRadius() {
    final next = nextRadiusKm;
    if (next == null) return false;
    setFilters(_filters.copyWith(radiusKm: next));
    return true;
  }

  /// Clears the keyword and filters (keeps the area and radius).
  void clearFilters() {
    setFilters(JobSearchFilters(location: _filters.location, radiusKm: _filters.radiusKm));
  }
}
