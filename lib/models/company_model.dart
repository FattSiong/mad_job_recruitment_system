class CompanyModel {
  final String? companyID;
  final String name;
  final String description;
  final String registrationNumber;
  final String? verificationDocumentURL;
  final bool isVerified;
  final String verificationStatus;
  final double? latitude;  // 👉 New
  final double? longitude; // 👉 New

  CompanyModel({
    this.companyID,
    required this.name,
    required this.description,
    required this.registrationNumber,
    this.verificationDocumentURL,
    this.isVerified = false,
    this.verificationStatus = 'pending',
    this.latitude,  // 👉 New
    this.longitude, // 👉 New
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      companyID: json['companyID'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      registrationNumber: json['registrationNumber'] as String,
      verificationDocumentURL: json['verificationDocumentURL'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      verificationStatus: (json['verificationStatus'] ?? json['verificationstatus']) as String? ?? 'pending',
      // 👉 New: Safely parse numbers to double
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'registrationNumber': registrationNumber,
      'verificationDocumentURL': verificationDocumentURL,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'latitude': latitude,  // 👉 New
      'longitude': longitude, // 👉 New
    };
  }
}