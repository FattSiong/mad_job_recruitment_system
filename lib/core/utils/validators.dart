class Validators {
  static String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  static String? validateSalary(String? value) {
    if (value != null && value.isNotEmpty) {
      if (double.tryParse(value) == null) {
        return 'Please enter a valid number';
      }
    }
    return null;
  }
}