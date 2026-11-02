import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/nearby_job_model.dart';
import '../controllers/job_map_controller.dart';
import '../controllers/location_controller.dart';
import '../widgets/job_filters.dart';
import '../widgets/map/nearby_job_card.dart';
import 'job_details_screen.dart';

/// "Discover Nearby Jobs": jobs around a point on the map, with a swipeable
/// list of the results (nearest first) that follows the pins.
class JobMapScreen extends StatefulWidget {
  const JobMapScreen({super.key});

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  // Space taken by the search bar + filters at the top, and the job list at the bottom.
  static const double _topOverlay = 136;
  static const double _listHeight = 136;

  final JobMapController _controller = JobMapController();
  final TextEditingController _keywordController = TextEditingController();
  final PageController _pageController = PageController(viewportFraction: 0.88);

  GoogleMapController? _map;
  LatLng _cameraTarget = JobMapController.fallbackCenter;

  /// True while the app (not the user) is moving the camera.
  bool _programmaticMove = false;

  @override
  void initState() {
    super.initState();
    _keywordController.addListener(() => setState(() {}));
    _start();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Start-up: find the user, then search straight away
  // ---------------------------------------------------------------------

  Future<void> _start() async {
    final start = await _controller.findStartLocation();
    if (!mounted) return;
    _showLocationIssue(start.issue);
    _cameraTarget = start.position;
    await _searchAt(start.position);
  }

  void _showLocationIssue(LocationIssue? issue) {
    if (issue == null) return;
    String message;
    String? label;
    Future<bool> Function()? action;
    switch (issue) {
      case LocationIssue.serviceOff:
        message = 'Location is turned off. Showing Kuala Lumpur instead.';
        label = 'Turn On';
        action = Geolocator.openLocationSettings;
      case LocationIssue.blocked:
        message = 'Location permission is blocked. Allow it in Settings to see jobs near you.';
        label = 'Settings';
        action = Geolocator.openAppSettings;
      case LocationIssue.denied:
        message = 'Showing Kuala Lumpur. Move the map or search a place to look elsewhere.';
      case LocationIssue.failed:
        message = 'Couldn\'t find your location. Showing Kuala Lumpur instead.';
    }
    final onAction = action;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: (label != null && onAction != null)
            ? SnackBarAction(label: label, onPressed: () => onAction())
            : null,
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    final start = await _controller.findStartLocation();
    if (!mounted) return;
    _showLocationIssue(start.issue);
    if (start.issue == null) await _searchAt(start.position);
  }

  // ---------------------------------------------------------------------
  // Searching
  // ---------------------------------------------------------------------

  Future<void> _searchAt(LatLng center) async {
    FocusScope.of(context).unfocus();
    _controller.setKeyword(_keywordController.text);
    _fitToArea(center); // zoom so the whole search circle is visible
    await _controller.search(center);
    if (!mounted) return;
    // The job list changes the map's bottom padding; re-fit once it's on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.searchCenter == center) _fitToArea(center);
    });
    if (_controller.error != null) {
      SnackBarHelper.showStyled(
        context,
        message: _controller.error!,
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
        duration: const Duration(seconds: 3),
      );
    }
    if (_pageController.hasClients && _controller.hasResults) {
      _pageController.jumpToPage(0);
    }
  }

  /// Search again around the same point (after a filter or radius change).
  Future<void> _searchAgain() => _searchAt(_controller.searchCenter ?? _cameraTarget);

  Future<void> _widenRadius() async {
    if (_controller.widenRadius()) await _searchAgain();
  }

  Future<void> _clearFilters() async {
    _keywordController.clear();
    _controller.clearFilters();
    await _searchAgain();
  }

  Future<void> _pickFilter(String filterType) async {
    final value = await showJobFilterSheet(
      context,
      filterType: filterType,
      currentValue: _controller.filterValue(filterType),
    );
    if (value == null || !mounted || value == _controller.filterValue(filterType)) return;
    _controller.setFilter(filterType, value);
    await _searchAgain();
  }

  Future<void> _pickRadius() async {
    final km = await showRadiusFilterSheet(context, currentKm: _controller.radiusKm);
    if (km == null || !mounted || km == _controller.radiusKm) return;
    _controller.setRadius(km);
    await _searchAgain();
  }

  Future<void> _searchPlace() async {
    final input = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Search a place'),
        content: TextField(
          controller: input,
          autofocus: true,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
          decoration: InputDecoration(
            hintText: 'e.g. Cyberjaya, Penang, Bangsar',
            prefixIcon: const Icon(Icons.place_outlined, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, input.text),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (query == null || query.trim().isEmpty || !mounted) return;

    final place = await _controller.findPlace(query);
    if (!mounted) return;
    if (place == null) {
      SnackBarHelper.showStyled(
        context,
        message: 'Couldn\'t find "${query.trim()}". Try a town or area name.',
        icon: Icons.location_off_outlined,
        accentColor: AppColors.warning,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    _cameraTarget = place;
    await _searchAt(place);
  }

  // ---------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------

  Future<void> _animate(CameraUpdate update) async {
    final map = _map;
    if (map == null) return;
    _programmaticMove = true;
    try {
      await map.animateCamera(update);
    } catch (_) {
      _programmaticMove = false;
    }
  }

  void _fitToArea(LatLng center) {
    final box = LocationController.boundingBox(
      center.latitude,
      center.longitude,
      _controller.radiusKm * 1000,
    );
    _animate(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(box.minLat, box.minLng),
        northeast: LatLng(box.maxLat, box.maxLng),
      ),
      24,
    ));
  }

  void _onCameraIdle() {
    if (_programmaticMove) {
      _programmaticMove = false;
      return;
    }
    _controller.cameraSettled(_cameraTarget);
  }

  /// A job card was swiped into view: highlight its pin and centre on it.
  void _onPageChanged(int index) {
    _controller.select(index);
    final item = index < _controller.jobs.length ? _controller.jobs[index] : null;
    if (item != null) _animate(CameraUpdate.newLatLng(LatLng(item.latitude, item.longitude)));
  }

  /// A pin was tapped: show its (first) job in the list.
  void _onSpotTapped(String spotKey) {
    final index = _controller.indexOfSpot(spotKey);
    if (index < 0) return;
    final current = _pageController.hasClients ? _pageController.page?.round() : null;
    if (current != null && current != index) {
      _pageController.jumpToPage(index); // _onPageChanged selects it and moves the map
    } else {
      _onPageChanged(index);
    }
  }

  void _openJob(NearbyJob item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailsScreen(job: item.job)),
    );
  }

  // ---------------------------------------------------------------------
  // Map layers
  // ---------------------------------------------------------------------

  Set<Marker> _markers() {
    final selectedKey = _controller.selectedJob?.spotKey;
    return _controller.spots.entries.map((entry) {
      final first = entry.value.first;
      final count = entry.value.length;
      final isSelected = entry.key == selectedKey;
      return Marker(
        markerId: MarkerId(entry.key),
        position: LatLng(first.latitude, first.longitude),
        zIndex: isSelected ? 2.0 : (count > 1 ? 1.0 : 0.0),
        consumeTapEvents: true, // the app moves the map itself
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected
              ? BitmapDescriptor.hueOrange
              : count > 1
                  ? BitmapDescriptor.hueViolet
                  : BitmapDescriptor.hueAzure,
        ),
        onTap: () => _onSpotTapped(entry.key),
      );
    }).toSet();
  }

  Set<Circle> _circles() {
    final center = _controller.searchCenter;
    if (center == null) return {};
    return {
      Circle(
        circleId: const CircleId('search_radius'),
        center: center,
        radius: _controller.radiusKm * 1000,
        fillColor: AppColors.primary.withValues(alpha: 0.08),
        strokeColor: AppColors.primary.withValues(alpha: 0.7),
        strokeWidth: 2,
      ),
    };
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Discover Nearby Jobs',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final showList = _controller.hasResults && !_controller.isLoading;
          final bottomInset = showList ? _listHeight + 16 : 0.0;
          final showCenterPin = _controller.areaMoved || !_controller.hasSearched;

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: JobMapController.fallbackCenter,
                  zoom: 11,
                ),
                padding: EdgeInsets.only(top: _topOverlay, bottom: bottomInset),
                onMapCreated: (map) {
                  _map = map;
                  final center = _controller.searchCenter;
                  if (center != null) _fitToArea(center);
                },
                onCameraMove: (position) => _cameraTarget = position.target,
                onCameraIdle: _onCameraIdle,
                markers: _markers(),
                circles: _circles(),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),

              // Pin marking the centre of the next search (the map's padded centre).
              if (showCenterPin)
                Positioned(
                  top: _topOverlay,
                  bottom: bottomInset,
                  left: 0,
                  right: 0,
                  child: const IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 36),
                        child: Icon(Icons.location_on, size: 40, color: AppColors.coral),
                      ),
                    ),
                  ),
                ),

              Positioned(top: 12, left: 16, right: 16, child: _buildSearchPanel()),

              Positioned(
                top: _topOverlay - 8,
                left: 16,
                right: 16,
                child: Center(child: _buildStatusPill()),
              ),

              Positioned(
                right: 16,
                bottom: bottomInset + 16,
                child: FloatingActionButton.small(
                  heroTag: 'job-map-my-location',
                  tooltip: 'My location',
                  elevation: 3,
                  backgroundColor: AppColors.surface,
                  onPressed: _controller.isLocating ? null : _goToMyLocation,
                  child: _controller.isLocating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.my_location_rounded, color: AppColors.primary),
                ),
              ),

              if (showList)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  height: _listHeight,
                  child: _buildJobList(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchPanel() {
    final c = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchAt(_cameraTarget),
                  decoration: InputDecoration(
                    hintText: 'Job title, company, keyword…',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    suffixIcon: _keywordController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                            onPressed: () {
                              _keywordController.clear();
                              _searchAgain();
                            },
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Search a place',
                onPressed: _searchPlace,
                icon: const Icon(Icons.place_outlined, color: AppColors.primary),
              ),
              Container(width: 1, height: 30, color: AppColors.border),
              InkWell(
                onTap: _pickRadius,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.radar_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${c.radiusKm.toInt()} km',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              JobFilterChip(
                label: JobFilterOptions.datePosted,
                value: c.datePosted,
                defaultValue: JobFilterOptions.anyDate,
                onTap: () => _pickFilter(JobFilterOptions.datePosted),
              ),
              JobFilterChip(
                label: JobFilterOptions.jobType,
                value: c.jobType,
                defaultValue: JobFilterOptions.anyJobType,
                onTap: () => _pickFilter(JobFilterOptions.jobType),
              ),
              JobFilterChip(
                label: JobFilterOptions.salary,
                value: c.salary,
                defaultValue: JobFilterOptions.anySalary,
                onTap: () => _pickFilter(JobFilterOptions.salary),
              ),
              if (c.hasActiveFilters)
                ActionChip(
                  avatar: const Icon(Icons.filter_alt_off_outlined, size: 18, color: AppColors.danger),
                  label: const Text('Clear'),
                  onPressed: _clearFilters,
                  backgroundColor: AppColors.surface,
                  labelStyle: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Top-centre pill: searching… / "Search this area" / result count.
  Widget _buildStatusPill() {
    final c = _controller;

    if (c.isLocating || c.isLoading) {
      return _pill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(
              c.isLocating ? 'Finding your location…' : 'Searching…',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ],
        ),
      );
    }

    if (c.areaMoved || (!c.hasSearched && !c.isLocating)) {
      return Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _searchAt(_cameraTarget),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Search this area', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    if (!c.hasSearched || c.error != null) return const SizedBox.shrink();

    if (!c.hasResults) {
      final canWiden = c.radiusKm < 100;
      return _pill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Text(c.summary, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
            if (canWiden) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _widenRadius,
                child: Text(
                  'Search ${(c.radiusKm * 2).clamp(5, 100).toInt()} km',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ] else if (c.hasActiveFilters) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _clearFilters,
                child: const Text(
                  'Clear filters',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return _pill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.work_outline_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(c.summary, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
          if (c.capped)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Tooltip(
                message: 'There are more jobs in this area. Zoom in, use a smaller radius or add filters.',
                child: Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildJobList() {
    final jobs = _controller.jobs;
    return PageView.builder(
      controller: _pageController,
      itemCount: jobs.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final item = jobs[index];
        final sameSpot = _controller.jobsAtSameSpot(item);
        final label = sameSpot.length > 1
            ? '${sameSpot.indexOf(item) + 1} of ${sameSpot.length} jobs at this location'
            : null;
        return NearbyJobCard(
          item: item,
          selected: index == _controller.selectedIndex,
          sameSpotLabel: label,
          onTap: () => _openJob(item),
        );
      },
    );
  }
}
