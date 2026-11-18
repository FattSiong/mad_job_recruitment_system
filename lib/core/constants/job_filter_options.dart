/// Filter values shared by the dashboard search and the map search.
class JobFilterOptions {
  JobFilterOptions._();

  static const String datePosted = 'Date posted';
  static const String jobType = 'Job type';
  static const String salary = 'Salary';
  static const String workplaceType = 'Workplace type';
  static const String distance = 'Distance';

  static const String anyDate = 'All time';
  static const String anyJobType = 'All';
  static const String anySalary = 'Any';
  static const String anyWorkplace = 'Any';
  static const double defaultRadiusKm = 10.0;

  /// Steps for "Search 20 km" when the Nearby Jobs map finds nothing.
  static const List<double> radiusOptions = [5, 10, 20, 50, 100];

  /// Location text that means "around the phone" on the Nearby Jobs map.
  static const String currentLocation = 'Current location';

  static const List<String> datePostedOptions = [
    anyDate,
    'Last 24 hours',
    'Last 3 days',
    'Last 7 days',
    'Last 14 days',
  ];
  static const List<String> jobTypeOptions = [anyJobType, 'Full-time', 'Part-time'];
  static const List<String> salaryOptions = [
    anySalary,
    'RM1000',
    'RM2000',
    'RM3000',
    'RM4000',
    'RM5000',
  ];
  static const List<String> workplaceTypeOptions = [anyWorkplace, 'On-site', 'Remote', 'Hybrid'];

  /// Quick picks under the location box of the job search.
  static const List<String> popularLocations = [
    'Kuala Lumpur',
    'Selangor',
    'Petaling Jaya',
    'Shah Alam',
    'Penang',
    'Johor Bahru',
    'Melaka',
    'Ipoh',
  ];
}
