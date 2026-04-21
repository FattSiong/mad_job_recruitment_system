class CompanyMemberModel {
  final String companyID;
  final String employerID;
  final String companyRole;
  final String status;

  CompanyMemberModel({
    required this.companyID,
    required this.employerID,
    this.companyRole = 'owner', // The person who registers the company is the owner
    this.status = 'active',
  });

  // We only need toJson for now since we are just inserting
  Map<String, dynamic> toJson() {
    return {
      'companyID': companyID,
      'employerID': employerID,
      'companyRole': companyRole,
      'status': status,
    };
  }
}