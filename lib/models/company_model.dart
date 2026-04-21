class CompanyModel {
  final String? companyID;
  final String name;
  final String description;
  final String registrationNumber;
  final String? verificationDocumentURL; // 👉 Added this line
  final bool isVerified;
  final String verificationStatus;

  CompanyModel({
    this.companyID,
    required this.name,
    required this.description,
    required this.registrationNumber,
    this.verificationDocumentURL, // 👉 Added this line
    this.isVerified = false,
    this.verificationStatus = 'pending',
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      companyID: json['companyID'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      registrationNumber: json['registrationNumber'] as String,
      verificationDocumentURL: json['verificationDocumentURL'] as String?, // 👉 Added this line
      isVerified: json['isVerified'] as bool? ?? false,
      verificationStatus: json['verificationStatus'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'registrationNumber': registrationNumber,
      'verificationDocumentURL': verificationDocumentURL, // 👉 Added this line
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
    };
  }
}