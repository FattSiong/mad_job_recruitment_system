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
  final String? companyAddress;
  final String currentPlanType;
  final DateTime? subscriptionEndsAt;
  final String? companyLogoURL;

  bool get isSubscriptionExpired {
    final normalized = currentPlanType.trim().toUpperCase();
    if (normalized == 'FREE' || normalized.isEmpty) return false;
    if (subscriptionEndsAt == null) return false;
    return DateTime.now().isAfter(subscriptionEndsAt!);
  }

  bool get hasActiveSubscription {
    final normalized = currentPlanType.trim().toUpperCase();
    if (normalized == 'FREE' || normalized.isEmpty) return false;
    return !isSubscriptionExpired;
  }

  /// True only when the company has been verified/approved and is not rejected.
  bool get isApprovedForJobPosting {
    final status = verificationStatus.trim().toLowerCase();
    if (status == 'rejected') return false;
    return isVerified || status == 'verified' || status == 'approved';
  }

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
    this.companyAddress,
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
      companyAddress: json['companyAddress'] as String?,
      currentPlanType: json['currentPlanType'] as String? ?? 'FREE',
      subscriptionEndsAt: json['subscriptionEndsAt'] != null
          ? DateTime.tryParse(json['subscriptionEndsAt'])
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
      'companyAddress': companyAddress,
      'currentPlanType': currentPlanType,
      'subscriptionEndsAt': subscriptionEndsAt?.toIso8601String(),
      'companyLogoURL': companyLogoURL,
    };
  }
}
