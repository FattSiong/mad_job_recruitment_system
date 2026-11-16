/// Filter values shared by the dashboard search and the map search.
class JobFilterOptions {
  JobFilterOptions._();

  static const String datePosted = 'Date posted';
  static const String jobType = 'Job type';
  static const String salary = 'Salary';

  static const String anyDate = 'All time';
  static const String anyJobType = 'All';
  static const String anySalary = 'Any';
  static const double defaultRadiusKm = 10.0;

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
}
