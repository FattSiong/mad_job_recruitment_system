class CompanyModel {
  final String? companyID;
  final String name;
  final String description;
  final String registrationNumber;
  final String? verificationDocumentURL;
  final bool isVerified;
  final String verificationStatus;
  final String? rejectionReason;
  final double? latitude;
  final double? longitude;
  final String currentPlanType;
  final DateTime? subscriptionEndsAt;
  final String? companyLogoURL;


  CompanyModel({
    this.companyID,
    required this.name,
    required this.description,
    required this.registrationNumber,
    this.verificationDocumentURL,
    this.isVerified = false,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.latitude,
    this.longitude,
    this.currentPlanType = 'FREE',
    this.subscriptionEndsAt,
    this.companyLogoURL,
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
      rejectionReason: json['rejectionReason'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      currentPlanType: json['currentPlanType'] as String? ?? 'FREE',
      subscriptionEndsAt: json['subscriptionEndsAt'] != null
          ? DateTime.tryParse(json['subscriptionEndAt'])
          : null,
      companyLogoURL: json['companyLogoURL'] as String?,
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
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'latitude': latitude,
      'longitude': longitude,
      'currentPlanType': currentPlanType,
      'subscriptionEndsAt': subscriptionEndsAt?.toIso8601String(),
      'companyLogoURL': companyLogoURL,
    };
  }
}