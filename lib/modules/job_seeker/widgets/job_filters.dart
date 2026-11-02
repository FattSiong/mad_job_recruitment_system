import 'package:flutter/material.dart';

import '../../../core/constants/job_filter_options.dart';
import '../../../core/theme/app_colors.dart';

export '../../../core/constants/job_filter_options.dart';

/// Chip that opens a filter; shows the chosen value when it isn't the default.
class JobFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String defaultValue;
  final VoidCallback onTap;

  const JobFilterChip({
    super.key,
    required this.label,
    required this.value,
    required this.defaultValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != defaultValue;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(isActive ? value : label),
        selected: isActive,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primarySoft,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: isActive ? AppColors.primary : AppColors.textDark,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(color: isActive ? AppColors.borderActive : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

/// Bottom sheet for "Date posted", "Job type" or "Salary".
/// Returns the chosen value (e.g. 'Last 7 days', 'RM 3500', 'Any'),
/// or null if the sheet is closed without choosing.
Future<String?> showJobFilterSheet(
  BuildContext context, {
  required String filterType,
  required String currentValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _JobFilterSheet(filterType: filterType, currentValue: currentValue),
  );
}

/// Bottom sheet with the map search radius slider.
/// Returns the new radius in km, or null if closed without applying.
Future<double?> showRadiusFilterSheet(BuildContext context, {required double currentKm}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _RadiusFilterSheet(initialKm: currentKm),
  );
}

// ---------------------------------------------------------------------------
// Sheet contents
// ---------------------------------------------------------------------------

Widget _sheetFrame(BuildContext context, {required String title, String? subtitle, required List<Widget> children}) {
  return Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 16,
      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

ButtonStyle _applyButtonStyle() => ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

ButtonStyle _clearButtonStyle() => OutlinedButton.styleFrom(
      foregroundColor: AppColors.textDark,
      padding: const EdgeInsets.symmetric(vertical: 14),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

class _JobFilterSheet extends StatefulWidget {
  final String filterType;
  final String currentValue;

  const _JobFilterSheet({required this.filterType, required this.currentValue});

  @override
  State<_JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends State<_JobFilterSheet> {
  late final TextEditingController _salaryController;
  String? _salaryError;

  bool get _isSalary => widget.filterType == JobFilterOptions.salary;

  List<String> get _options {
    switch (widget.filterType) {
      case JobFilterOptions.datePosted:
        return JobFilterOptions.datePostedOptions;
      case JobFilterOptions.jobType:
        return JobFilterOptions.jobTypeOptions;
      default:
        return JobFilterOptions.salaryOptions;
    }
  }

  @override
  void initState() {
    super.initState();
    _salaryController = TextEditingController(
      text: _isSalary ? widget.currentValue.replaceAll(RegExp(r'[^0-9]'), '') : '',
    );
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  void _applyTypedSalary() {
    final typed = _salaryController.text.trim();
    if (typed.isEmpty) {
      Navigator.pop(context, JobFilterOptions.anySalary);
      return;
    }
    final salary = int.tryParse(typed);
    if (salary == null || salary <= 0) {
      setState(() => _salaryError = 'Please enter a valid salary amount.');
      return;
    }
    Navigator.pop(context, 'RM $salary');
  }

  @override
  Widget build(BuildContext context) {
    final optionList = RadioGroup<String>(
      groupValue: widget.currentValue,
      onChanged: (value) {
        if (value != null) Navigator.pop(context, value);
      },
      child: Column(
        children: _options
            .map((option) => RadioListTile<String>(
                  value: option,
                  title: Text(option),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ))
            .toList(),
      ),
    );

    return _sheetFrame(
      context,
      title: 'Filter by ${widget.filterType}',
      children: [
        if (_isSalary) ...[
          const Text(
            'Enter custom minimum salary',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _salaryController,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              if (_salaryError != null) setState(() => _salaryError = null);
            },
            onSubmitted: (_) => _applyTypedSalary(),
            decoration: InputDecoration(
              hintText: 'e.g. 3500',
              errorText: _salaryError,
              prefixIcon: const Padding(
                padding: EdgeInsetsDirectional.only(start: 16, end: 8),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text('RM', style: TextStyle(color: AppColors.textMuted)),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, JobFilterOptions.anySalary),
                  style: _clearButtonStyle(),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyTypedSalary,
                  style: _applyButtonStyle(),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Or select a suggested range',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
        ],
        optionList,
      ],
    );
  }
}

class _RadiusFilterSheet extends StatefulWidget {
  final double initialKm;

  const _RadiusFilterSheet({required this.initialKm});

  @override
  State<_RadiusFilterSheet> createState() => _RadiusFilterSheetState();
}

class _RadiusFilterSheetState extends State<_RadiusFilterSheet> {
  late double _km = widget.initialKm;

  @override
  Widget build(BuildContext context) {
    return _sheetFrame(
      context,
      title: 'Search Radius',
      subtitle: 'Choose how far from the map center you want to search.',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                '${_km.toInt()} km',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Current search radius',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: Colors.grey.shade300,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.12),
                  valueIndicatorColor: AppColors.primary,
                  valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                  trackHeight: 8,
                  thumbShape: const RadiusSliderThumb(icon: Icons.directions_car),
                ),
                child: Slider(
                  value: _km,
                  min: 5.0,
                  max: 100.0,
                  divisions: 19,
                  label: '${_km.toInt()} km',
                  onChanged: (value) => setState(() => _km = value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, JobFilterOptions.defaultRadiusKm),
                style: _clearButtonStyle(),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _km),
                style: _applyButtonStyle(),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Round slider thumb with an icon (car) in the middle.
class RadiusSliderThumb extends SliderComponentShape {
  final IconData icon;

  const RadiusSliderThumb({required this.icon});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(36, 36);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final Paint paintCircle = Paint()
      ..color = sliderTheme.thumbColor ?? AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18, paintCircle);

    final TextPainter textPainter = TextPainter(textDirection: textDirection);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 22.0,
        fontFamily: icon.fontFamily,
        color: Colors.white,
        package: icon.fontPackage,
      ),
    );
    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }
}
