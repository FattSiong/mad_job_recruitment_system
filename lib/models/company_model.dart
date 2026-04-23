class CompanyModel {
  final String? companyID;
  final String name;
  final String description;
  final String registrationNumber;
  final String? verificationDocumentURL;
  final bool isVerified;
  final String verificationStatus;
  final double? latitude;
  final double? longitude;
  final String currentPlanType;
  final DateTime? subscriptionEndAt;

  CompanyModel({
    this.companyID,
    required this.name,
    required this.description,
    required this.registrationNumber,
    this.verificationDocumentURL,
    this.isVerified = false,
    this.verificationStatus = 'pending',
    this.latitude,
    this.longitude,
    this.currentPlanType = 'FREE',
    this.subscriptionEndAt,
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
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      currentPlanType: json['currentPlanType'] as String? ?? 'FREE',
      subscriptionEndAt: json['subscriptionEndAt'] != null
          ? DateTime.tryParse(json['subscriptionEndAt'])
          : null,
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
      'latitude': latitude,
      'longitude': longitude,
      'currentPlanType': currentPlanType,
      'subscriptionEndAt': subscriptionEndAt?.toIso8601String(),
    };
  }
}