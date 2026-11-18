import 'package:flutter/material.dart';

import '../../../../core/constants/job_filter_options.dart';
import '../../../../core/theme/app_button_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_input_decoration.dart';
import '../../../../core/utils/data_load_exception.dart';
import '../../../../shared_widgets/button_spinner.dart';
import '../../controllers/current_city_controller.dart';
import '../../controllers/job_discovery_controller.dart';

/// Full-screen sheet for a job search: job title / keyword, location
/// (typed, a quick pick, or the phone's location) and the job type, salary,
/// workplace type and date posted filters.
/// Returns the search, or null if it was closed without searching.
Future<JobSearchFilters?> showJobSearchSheet(
  BuildContext context, {
  JobSearchFilters initial = const JobSearchFilters(),
}) {
  return showModalBottomSheet<JobSearchFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _JobSearchSheet(initial: initial),
  );
}

class _JobSearchSheet extends StatefulWidget {
  final JobSearchFilters initial;

  const _JobSearchSheet({required this.initial});

  @override
  State<_JobSearchSheet> createState() => _JobSearchSheetState();
}

class _JobSearchSheetState extends State<_JobSearchSheet> {
  late final TextEditingController _keyword = TextEditingController(text: widget.initial.query);
  late final TextEditingController _location = TextEditingController(text: widget.initial.location);

  late String _jobType = widget.initial.jobType ?? JobFilterOptions.anyJobType;
  late String _salary = widget.initial.salary ?? JobFilterOptions.anySalary;
  late String _workplaceType = widget.initial.workplaceType ?? JobFilterOptions.anyWorkplace;
  late String _datePosted = widget.initial.datePosted ?? JobFilterOptions.anyDate;

  /// The filter section that is open (one at a time), or null.
  String? _openFilter;
  bool _isLocating = false;
  String? _locationError;

  JobSearchFilters get _current => JobSearchFilters(
        query: _keyword.text.trim(),
        location: _location.text.trim(),
        jobType: _jobType,
        salary: _salary,
        workplaceType: _workplaceType,
        datePosted: _datePosted,
      );

  @override
  void dispose() {
    _keyword.dispose();
    _location.dispose();
    super.dispose();
  }

  /// Empties both boxes and sets every filter back to "any".
  void _clearAll() {
    setState(() {
      _keyword.clear();
      _location.clear();
      _jobType = JobFilterOptions.anyJobType;
      _salary = JobFilterOptions.anySalary;
      _workplaceType = JobFilterOptions.anyWorkplace;
      _datePosted = JobFilterOptions.anyDate;
      _locationError = null;
    });
  }

  void _setLocation(String value) {
    setState(() {
      _location.text = value;
      _locationError = null;
    });
  }

  /// Fills the location box with the city the phone is in.
  Future<void> _useCurrentLocation() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLocating = true;
      _locationError = null;
    });
    try {
      final city = await CurrentCityController.findCity();
      if (mounted) _setLocation(city);
    } on DataLoadException catch (e) {
      if (mounted) setState(() => _locationError = e.message);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _search() => Navigator.pop(context, _current);

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The Search button stays above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _sectionLabel('What'),
                TextField(
                  controller: _keyword,
                  autofocus: widget.initial.isEmpty,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}), // Clear all on / off
                  onSubmitted: (_) => _search(),
                  decoration: filledInputDecoration(
                    hint: 'Job title, keywords or company',
                    icon: Icons.search_rounded,
                    suffixIcon: _clearButton(_keyword),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionLabel('Where'),
                _buildLocation(),
                const SizedBox(height: 24),
                _sectionLabel('Filters'),
                _filter(
                  title: JobFilterOptions.jobType,
                  icon: Icons.work_outline_rounded,
                  options: JobFilterOptions.jobTypeOptions,
                  value: _jobType,
                  onSelected: (v) => _jobType = v,
                ),
                _filter(
                  title: JobFilterOptions.salary,
                  icon: Icons.payments_outlined,
                  options: JobFilterOptions.salaryOptions,
                  value: _salary,
                  onSelected: (v) => _salary = v,
                  // "RM3000" is a minimum
                  label: (v) => v == JobFilterOptions.anySalary ? v : '$v+',
                ),
                _filter(
                  title: JobFilterOptions.workplaceType,
                  icon: Icons.home_work_outlined,
                  options: JobFilterOptions.workplaceTypeOptions,
                  value: _workplaceType,
                  onSelected: (v) => _workplaceType = v,
                ),
                _filter(
                  title: JobFilterOptions.datePosted,
                  icon: Icons.schedule_rounded,
                  options: JobFilterOptions.datePostedOptions,
                  value: _datePosted,
                  onSelected: (v) => _datePosted = v,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Search'),
                style: AppButtonStyles.filled(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Drag handle, close button, title and "Clear all".
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 4),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
              ),
              const Expanded(
                child: Text(
                  'Search jobs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
              ),
              TextButton(
                onPressed: _current.isEmpty ? null : _clearAll,
                child: const Text('Clear all'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Location box, "Use my current location" and the quick picks.
  Widget _buildLocation() {
    final typed = _location.text.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _location,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() => _locationError = null),
          onSubmitted: (_) => _search(),
          decoration: filledInputDecoration(
            hint: 'City or state',
            icon: Icons.location_on_outlined,
            suffixIcon: _clearButton(_location),
            errorText: _locationError,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _isLocating ? null : _useCurrentLocation,
          icon: _isLocating
              ? const ButtonSpinner(size: 16, color: AppColors.primary)
              : const Icon(Icons.my_location_rounded, size: 18),
          label: Text(_isLocating ? 'Finding your location...' : 'Use my current location'),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final place in JobFilterOptions.popularLocations)
              _OptionChip(
                label: place,
                selected: typed == place.toLowerCase(),
                // Tapping the chosen place again clears it.
                onTap: () => _setLocation(typed == place.toLowerCase() ? '' : place),
              ),
          ],
        ),
      ],
    );
  }

  /// Small grey heading above a group of fields.
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted),
      ),
    );
  }

  /// X in a text box when it has text.
  Widget? _clearButton(TextEditingController controller) {
    if (controller.text.isEmpty) return null;
    return IconButton(
      tooltip: 'Clear',
      onPressed: () => setState(controller.clear),
      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
    );
  }

  /// One filter: a row that opens to show its options as chips.
  Widget _filter({
    required String title,
    required IconData icon,
    required List<String> options,
    required String value,
    required ValueChanged<String> onSelected,
    String Function(String value)? label,
  }) {
    final String Function(String) show = label ?? ((v) => v);
    return _FilterDropdown(
      title: title,
      icon: icon,
      valueLabel: show(value),
      isSet: value != options.first, // the first option is "any"
      isOpen: _openFilter == title,
      onToggle: () => setState(() => _openFilter = _openFilter == title ? null : title),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            _OptionChip(
              label: show(option),
              selected: option == value,
              onTap: () => setState(() => onSelected(option)),
            ),
        ],
      ),
    );
  }
}

/// A filter row (icon, name, chosen value, arrow) that opens to show [child].
class _FilterDropdown extends StatelessWidget {
  final String title;
  final IconData icon;
  final String valueLabel;
  final bool isSet;
  final bool isOpen;
  final VoidCallback onToggle;
  final Widget child;

  const _FilterDropdown({
    required this.title,
    required this.icon,
    required this.valueLabel,
    required this.isSet,
    required this.isOpen,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: radius,
        border: Border.all(color: isOpen ? AppColors.borderActive : AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            valueLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSet ? AppColors.primary : AppColors.textMuted,
                              fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: isOpen
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Align(alignment: Alignment.centerLeft, child: child),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable chip used for the quick locations and the filter options.
class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.primarySoft,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textDark,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(color: selected ? AppColors.borderActive : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}
