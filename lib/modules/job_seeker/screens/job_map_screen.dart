import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/job_filter_options.dart';
import '../../../core/theme/app_button_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/nearby_job_model.dart';
import '../../../shared_widgets/button_spinner.dart';
import '../../../shared_widgets/state_message_card.dart';
import '../controllers/job_map_controller.dart';
import '../controllers/location_controller.dart';
import '../widgets/dashboard/job_search_sheet.dart';
import '../widgets/load_error_view.dart';
import '../widgets/map/nearby_job_card.dart';
import 'job_details_screen.dart';

/// Nearby Jobs: a full-screen map of jobs around a point, with a search
/// pill on top (opens the same search as Home, plus distance) and a
/// drag-up list of the results, nearest first. Tapping a pin lists only the
/// jobs at that pin, with "Show all" to go back to every job.
class JobMapScreen extends StatefulWidget {
  const JobMapScreen({super.key});

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  static const double _barHeight = 56; // back button and search pill
  static const double _peekHeight = 84; // list header when the list is closed
  static const double _halfSize = 0.42; // list half open (how it starts)

  final JobMapController _controller = JobMapController();
  final DraggableScrollableController _sheet = DraggableScrollableController();

  /// Scrolls the job list (given by the drag-up sheet).
  ScrollController? _listScroll;
  GoogleMapController? _map;
  LatLng _cameraTarget = JobMapController.fallbackCenter;

  /// True while the app (not the user) is moving the camera.
  bool _programmaticMove = false;

  // Built once per change instead of every frame (the map rebuilds while
  // the list is dragged, the camera moves or the status changes).
  Set<Marker> _markerCache = const {};
  Map<String, List<NearbyJob>>? _markerSpots;
  String? _markerOpenSpot;
  Widget? _sheetContent;
  ScrollController? _sheetScroll;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sheet.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Start-up and location
  // ---------------------------------------------------------------------

  /// Searches around the phone, or Kuala Lumpur when its location isn't available.
  Future<void> _start() async {
    final start = await _controller.findStartLocation();
    if (!mounted) return;
    _showLocationIssue(start.issue, showingFallback: true);
    // The user already searched while the phone was being located: keep it.
    if (_controller.searchCenter != null) return;
    _cameraTarget = start.position;
    await _searchAt(
      start.position,
      location: start.issue == null ? JobFilterOptions.currentLocation : 'Kuala Lumpur',
    );
  }

  /// Searches around the phone's location. False if it isn't available
  /// (the reason is shown).
  Future<bool> _searchNearMe() async {
    final start = await _controller.findStartLocation();
    if (!mounted) return false;
    _showLocationIssue(start.issue);
    if (start.issue != null) return false;
    _cameraTarget = start.position;
    await _searchAt(start.position, location: JobFilterOptions.currentLocation);
    return true;
  }

  /// Explains why the phone's location isn't used, with a button to fix it
  /// (turn on location / open settings).
  void _showLocationIssue(LocationIssue? issue, {bool showingFallback = false}) {
    if (issue == null) return;
    final fallback = showingFallback ? ' Showing Kuala Lumpur instead.' : '';
    String message;
    String? label;
    Future<bool> Function()? action;
    switch (issue) {
      case LocationIssue.serviceOff:
        message = 'Location is turned off.$fallback';
        label = 'Turn On';
        action = Geolocator.openLocationSettings;
      case LocationIssue.blocked:
        message = 'Location permission is blocked. Allow it in Settings to see jobs near you.';
        label = 'Settings';
        action = Geolocator.openAppSettings;
      case LocationIssue.denied:
        message = 'Location permission was denied.$fallback';
      case LocationIssue.failed:
        message = 'Couldn\'t find your location.$fallback';
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

  // ---------------------------------------------------------------------
  // Searching
  // ---------------------------------------------------------------------

  /// Searches around [center] ([location] says what it is, see
  /// [JobMapController.filters]) and zooms the map to the search circle.
  Future<void> _searchAt(LatLng center, {required String location}) async {
    _controller.setFilters(_controller.filters.copyWith(location: location));
    _fitToArea(center);
    await _controller.search(center);
    if (mounted) _scrollListToTop();
  }

  /// Searches the same area again (after a filter or radius change).
  Future<void> _searchAgain() =>
      _searchAt(_controller.searchCenter ?? _cameraTarget, location: _controller.filters.location);

  /// Opens the search; searches with what the user chose.
  Future<void> _openSearch() async {
    final previous = _controller.filters;
    final filters = await showJobSearchSheet(context, initial: previous, forMap: true);
    if (filters == null || !mounted) return;
    _controller.setFilters(filters);

    final location = filters.location.trim();
    final sameArea = location.isEmpty ||
        (location == previous.location.trim() && _controller.searchCenter != null);

    if (location == JobFilterOptions.currentLocation && !sameArea) {
      if (!await _searchNearMe()) await _keepArea(previous.location);
      return;
    }
    if (sameArea) {
      await _searchAgain();
      return;
    }

    final place = await _controller.findPlace(location);
    if (!mounted) return;
    if (place == null) {
      SnackBarHelper.showStyled(
        context,
        message: 'Couldn\'t find "$location". Try a town or area name.',
        icon: Icons.location_off_outlined,
        accentColor: AppColors.warning,
        duration: const Duration(seconds: 3),
      );
      await _keepArea(previous.location);
      return;
    }
    _cameraTarget = place;
    await _searchAt(place, location: location);
  }

  /// The new area couldn't be used: search the old area with the new filters.
  Future<void> _keepArea(String location) {
    _controller.setFilters(_controller.filters.copyWith(location: location));
    return _searchAgain();
  }

  /// "Search 20 km" on an empty result.
  Future<void> _widenRadius() async {
    if (_controller.widenRadius()) await _searchAgain();
  }

  /// Clears the keyword and filters and searches again.
  Future<void> _clearFilters() async {
    _controller.clearFilters();
    await _searchAgain();
  }

  // ---------------------------------------------------------------------
  // Camera, pins and the list
  // ---------------------------------------------------------------------

  /// Moves the map camera; marks the move as the app's own, not the user's.
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

  /// Zooms the map so the whole search circle around [center] is visible.
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

  /// The map stopped moving: if the user moved it, offer "Search this area".
  void _onCameraIdle() {
    if (_programmaticMove) {
      _programmaticMove = false;
      return;
    }
    _controller.cameraSettled(_cameraTarget);
  }

  /// A pin was tapped: list only its jobs, centre on it and open the list
  /// if it is closed.
  Future<void> _onSpotTapped(String spotKey) async {
    final jobsHere = _controller.spots[spotKey];
    if (jobsHere == null || jobsHere.isEmpty) return;
    _controller.openSpot(spotKey);
    _scrollListToTop();
    final first = jobsHere.first;
    _animate(CameraUpdate.newLatLng(LatLng(first.latitude, first.longitude)));

    if (_sheet.isAttached && _sheet.size < _halfSize - 0.01) {
      await _sheet.animateTo(
        _halfSize,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// "Show all" (or a tap on the map away from the pins): every job again.
  void _showAllJobs() {
    if (_controller.openedSpot == null) return;
    _controller.showAllJobs();
    _scrollListToTop();
  }

  void _scrollListToTop() {
    final list = _listScroll;
    if (list != null && list.hasClients) list.jumpTo(0);
  }

  /// Opens the job's details.
  /// (The search leaves out descriptions, so the whole job is loaded first.)
  Future<void> _openJob(NearbyJob item) async {
    if (_controller.openingJobID != null) return;
    try {
      final job = await _controller.loadFullJob(item);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job)),
      );
    } on DataLoadException catch (e) {
      if (mounted) SnackBarHelper.showError(context, e.message, duration: const Duration(seconds: 3));
    }
  }

  /// One pin per spot (the number of jobs there when more than one).
  /// Rebuilt only when the results or the opened pin change.
  Set<Marker> _markers() {
    final spots = _controller.spots;
    final selectedKey = _controller.openedSpot;
    if (identical(spots, _markerSpots) && selectedKey == _markerOpenSpot) return _markerCache;
    _markerSpots = spots;
    _markerOpenSpot = selectedKey;
    return _markerCache = spots.entries.map((entry) {
      final first = entry.value.first;
      final count = entry.value.length;
      final isSelected = entry.key == selectedKey;
      return Marker(
        markerId: MarkerId(entry.key),
        position: LatLng(first.latitude, first.longitude),
        zIndexInt: isSelected ? 2 : (count > 1 ? 1 : 0), // selected on top, then groups
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

  /// The search circle drawn on the map.
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
    final safe = MediaQuery.paddingOf(context);
    final barTop = safe.top + 12;
    final mapTop = barTop + _barHeight + 8;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark, // dark status bar icons over the map
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final mapBottom = height * _halfSize;
            final minSize = ((_peekHeight + safe.bottom) / height).clamp(0.08, _halfSize - 0.05);
            final maxSize = (1 - (mapTop + 4) / height).clamp(_halfSize + 0.05, 1.0);

            return ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final c = _controller;
                final showCenterPin = c.areaMoved || !c.hasSearched;
                _sheetContent = null; // something changed: build the list again
                return Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: JobMapController.fallbackCenter,
                        zoom: 11,
                      ),
                      padding: EdgeInsets.only(top: mapTop, bottom: mapBottom),
                      onMapCreated: (map) {
                        _map = map;
                        final center = c.searchCenter;
                        if (center != null) _fitToArea(center);
                      },
                      onCameraMove: (position) => _cameraTarget = position.target,
                      onCameraIdle: _onCameraIdle,
                      onTap: (_) => _showAllJobs(),
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
                        top: mapTop,
                        bottom: mapBottom,
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

                    Positioned(top: barTop, left: 16, right: 16, child: _buildTopBar()),

                    if (c.areaMoved && !c.isLoading)
                      Positioned(
                        top: mapTop + 4,
                        left: 0,
                        right: 0,
                        child: Center(child: _buildSearchAreaButton()),
                      ),

                    Positioned(top: mapTop + 4, right: 16, child: _buildMyLocationButton()),

                    DraggableScrollableSheet(
                      controller: _sheet,
                      initialChildSize: _halfSize,
                      minChildSize: minSize,
                      maxChildSize: maxSize,
                      snap: true,
                      snapSizes: const [_halfSize],
                      builder: (context, scroll) {
                        _listScroll = scroll;
                        // Dragging rebuilds this every frame; reuse the list
                        // until the results change.
                        if (_sheetContent == null || !identical(scroll, _sheetScroll)) {
                          _sheetScroll = scroll;
                          _sheetContent = _buildJobSheet(scroll, safe.bottom);
                        }
                        return _sheetContent!;
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Back button and the search pill (what is searched, where, how far).
  Widget _buildTopBar() {
    final c = _controller;
    final query = c.filters.query.trim();
    final filterCount = c.filters.filterCount;
    final details = [
      c.areaLabel,
      'within ${c.radiusKm.toInt()} km',
      if (filterCount > 0) '$filterCount filter${filterCount == 1 ? '' : 's'}',
    ].join(' · ');

    return Row(
      children: [
        _floating(
          width: _barHeight,
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _floating(
            child: InkWell(
              onTap: _openSearch,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            query.isEmpty ? 'Search nearby jobs' : query,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: query.isEmpty ? AppColors.textMuted : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// White rounded box with a shadow, [_barHeight] tall, floating on the map.
  Widget _floating({required Widget child, double? width}) {
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: AppColors.shadow,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(height: _barHeight, width: width, child: child),
    );
  }

  /// "Search this area" after the user moved the map.
  Widget _buildSearchAreaButton() {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(999),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _searchAt(_cameraTarget, location: ''),
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

  /// Searches around the phone again.
  Widget _buildMyLocationButton() {
    final locating = _controller.isLocating;
    return FloatingActionButton.small(
      heroTag: 'job-map-my-location',
      tooltip: 'My location',
      elevation: 3,
      backgroundColor: AppColors.surface,
      onPressed: locating ? null : _searchNearMe,
      child: locating
          ? const ButtonSpinner(color: AppColors.primary)
          : const Icon(Icons.my_location_rounded, color: AppColors.primary),
    );
  }

  // ---------------------------------------------------------------------
  // Drag-up job list
  // ---------------------------------------------------------------------

  Widget _buildJobSheet(ScrollController scroll, double bottomSafe) {
    final c = _controller;
    final listed = c.listedJobs;
    final pinOpen = c.openedSpot != null;
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: AppColors.shadow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        controller: scroll,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _FixedHeader(height: _peekHeight, child: _buildSheetHeader()),
          ),
          if (c.error != null && !c.isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LoadErrorView(message: c.error!, onRetry: _searchAgain),
              ),
            )
          else if (c.hasSearched && !c.hasResults && !c.isLoading)
            SliverToBoxAdapter(child: _buildNoJobs())
          else if (c.hasResults)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomSafe),
              sliver: SliverFixedExtentList(
                itemExtent: NearbyJobCard.height,
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = listed[index];
                    return NearbyJobCard(
                      item: item,
                      // Already said in the header when one pin is open.
                      jobsHere: pinOpen ? 1 : c.jobsAtSameSpot(item).length,
                      loading: c.openingJobID != null && c.openingJobID == item.job.jobID,
                      onTap: () => _openJob(item),
                    );
                  },
                  childCount: listed.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Drag handle, "12 jobs within 10 km" and the area, or the open pin's
  /// jobs with "Show all".
  Widget _buildSheetHeader() {
    final c = _controller;
    final busy = c.isLocating || c.isLoading;
    final pinJobs = c.openedSpot == null || busy ? null : c.listedJobs;
    final String title;
    String subtitle = c.capped ? '${c.areaLabel} · zoom in or add filters to see more' : c.areaLabel;
    if (pinJobs != null && pinJobs.isNotEmpty) {
      final first = pinJobs.first;
      final place = (first.job.locationName ?? first.job.companyName ?? '').trim();
      title = '${pinJobs.length} job${pinJobs.length == 1 ? '' : 's'} at this pin';
      subtitle = [if (place.isNotEmpty) place, '${first.distanceLabel} away'].join(' · ');
    } else if (c.isLocating) {
      title = 'Finding your location…';
    } else if (c.isLoading) {
      title = 'Searching…';
    } else if (c.error != null) {
      title = 'Couldn\'t load jobs';
    } else if (!c.hasSearched) {
      title = 'Nearby jobs';
    } else {
      title = c.summary;
    }

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (busy) ...[
                  const ButtonSpinner(size: 16, color: AppColors.primary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (pinJobs != null)
                  TextButton.icon(
                    onPressed: _showAllJobs,
                    icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
                    label: Text('Show all ${c.jobs.length}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// No jobs in the area: offer a bigger distance or clearing the filters.
  Widget _buildNoJobs() {
    final c = _controller;
    final next = c.nextRadiusKm;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: StateMessageCard(
        boxed: false,
        icon: Icons.search_off_rounded,
        title: 'No jobs here',
        message: 'Try a bigger distance, another area or fewer filters.',
        action: Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            if (next != null)
              ElevatedButton(
                onPressed: _widenRadius,
                style: AppButtonStyles.filled(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                child: Text('Search ${next.toInt()} km'),
              ),
            if (c.hasActiveFilters)
              OutlinedButton(
                onPressed: _clearFilters,
                style: AppButtonStyles.outlined(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                child: const Text('Clear filters'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the list header ([child]) at the top of the drag-up sheet.
class _FixedHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _FixedHeader({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(_FixedHeader oldDelegate) => true;
}
