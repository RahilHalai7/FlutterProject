class CibilCreditReport {
  final bool success;
  final CibilReportData? data;
  final String? error;
  final int? statusCode;

  CibilCreditReport({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory CibilCreditReport.fromJson(Map<String, dynamic> json) {
    return CibilCreditReport(
      success: json['success'] ?? false,
      data: json['data'] != null ? CibilReportData.fromJson(json['data']) : null,
      error: json['error'],
      statusCode: json['statusCode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data?.toJson(),
      'error': error,
      'statusCode': statusCode,
    };
  }
}

class CibilReportData {
  final String? fullName;
  final String? panNumber;
  final String? dateOfBirth;
  final CibilScore? cibilScore;
  final List<CreditAccount>? creditAccounts;
  final List<CreditInquiry>? creditInquiries;
  final PersonalInfo? personalInfo;
  final String? reportDate;
  final String? reportId;

  CibilReportData({
    this.fullName,
    this.panNumber,
    this.dateOfBirth,
    this.cibilScore,
    this.creditAccounts,
    this.creditInquiries,
    this.personalInfo,
    this.reportDate,
    this.reportId,
  });

  factory CibilReportData.fromJson(Map<String, dynamic> json) {
    return CibilReportData(
      fullName: json['full_name'] ?? json['fullName'],
      panNumber: json['pan_number'] ?? json['panNumber'],
      dateOfBirth: json['date_of_birth'] ?? json['dateOfBirth'],
      cibilScore: json['cibil_score'] != null || json['cibilScore'] != null
          ? CibilScore.fromJson(json['cibil_score'] ?? json['cibilScore'])
          : null,
      creditAccounts: json['credit_accounts'] != null || json['creditAccounts'] != null
          ? (json['credit_accounts'] ?? json['creditAccounts'] as List)
              .map((account) => CreditAccount.fromJson(account))
              .toList()
          : null,
      creditInquiries: json['credit_inquiries'] != null || json['creditInquiries'] != null
          ? (json['credit_inquiries'] ?? json['creditInquiries'] as List)
              .map((inquiry) => CreditInquiry.fromJson(inquiry))
              .toList()
          : null,
      personalInfo: json['personal_info'] != null || json['personalInfo'] != null
          ? PersonalInfo.fromJson(json['personal_info'] ?? json['personalInfo'])
          : null,
      reportDate: json['report_date'] ?? json['reportDate'],
      reportId: json['report_id'] ?? json['reportId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'pan_number': panNumber,
      'date_of_birth': dateOfBirth,
      'cibil_score': cibilScore?.toJson(),
      'credit_accounts': creditAccounts?.map((account) => account.toJson()).toList(),
      'credit_inquiries': creditInquiries?.map((inquiry) => inquiry.toJson()).toList(),
      'personal_info': personalInfo?.toJson(),
      'report_date': reportDate,
      'report_id': reportId,
    };
  }
}

class CibilScore {
  final int? score;
  final String? scoreRange;
  final String? creditRating;
  final DateTime? lastUpdated;
  final List<ScoreFactor>? factors;

  CibilScore({
    this.score,
    this.scoreRange,
    this.creditRating,
    this.lastUpdated,
    this.factors,
  });

  factory CibilScore.fromJson(Map<String, dynamic> json) {
    return CibilScore(
      score: json['score'],
      scoreRange: json['score_range'] ?? json['scoreRange'],
      creditRating: json['credit_rating'] ?? json['creditRating'],
      lastUpdated: json['last_updated'] != null || json['lastUpdated'] != null
          ? DateTime.tryParse(json['last_updated'] ?? json['lastUpdated'])
          : null,
      factors: json['factors'] != null
          ? (json['factors'] as List)
              .map((factor) => ScoreFactor.fromJson(factor))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'score_range': scoreRange,
      'credit_rating': creditRating,
      'last_updated': lastUpdated?.toIso8601String(),
      'factors': factors?.map((factor) => factor.toJson()).toList(),
    };
  }

  String get scoreDescription {
    if (score == null) return 'No Score Available';
    if (score! >= 750) return 'Excellent';
    if (score! >= 700) return 'Good';
    if (score! >= 650) return 'Fair';
    if (score! >= 600) return 'Poor';
    return 'Very Poor';
  }

  String get scoreColor {
    if (score == null) return '#9E9E9E';
    if (score! >= 750) return '#4CAF50';
    if (score! >= 700) return '#8BC34A';
    if (score! >= 650) return '#FF9800';
    if (score! >= 600) return '#FF5722';
    return '#F44336';
  }
}

class ScoreFactor {
  final String? factor;
  final String? impact;
  final String? description;

  ScoreFactor({
    this.factor,
    this.impact,
    this.description,
  });

  factory ScoreFactor.fromJson(Map<String, dynamic> json) {
    return ScoreFactor(
      factor: json['factor'],
      impact: json['impact'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'factor': factor,
      'impact': impact,
      'description': description,
    };
  }
}

class CreditAccount {
  final String? accountType;
  final String? bankName;
  final String? accountNumber;
  final double? currentBalance;
  final double? creditLimit;
  final String? accountStatus;
  final DateTime? openDate;
  final DateTime? lastPaymentDate;
  final int? paymentHistory;

  CreditAccount({
    this.accountType,
    this.bankName,
    this.accountNumber,
    this.currentBalance,
    this.creditLimit,
    this.accountStatus,
    this.openDate,
    this.lastPaymentDate,
    this.paymentHistory,
  });

  factory CreditAccount.fromJson(Map<String, dynamic> json) {
    return CreditAccount(
      accountType: json['account_type'] ?? json['accountType'],
      bankName: json['bank_name'] ?? json['bankName'],
      accountNumber: json['account_number'] ?? json['accountNumber'],
      currentBalance: json['current_balance']?.toDouble() ?? json['currentBalance']?.toDouble(),
      creditLimit: json['credit_limit']?.toDouble() ?? json['creditLimit']?.toDouble(),
      accountStatus: json['account_status'] ?? json['accountStatus'],
      openDate: json['open_date'] != null || json['openDate'] != null
          ? DateTime.tryParse(json['open_date'] ?? json['openDate'])
          : null,
      lastPaymentDate: json['last_payment_date'] != null || json['lastPaymentDate'] != null
          ? DateTime.tryParse(json['last_payment_date'] ?? json['lastPaymentDate'])
          : null,
      paymentHistory: json['payment_history'] ?? json['paymentHistory'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_type': accountType,
      'bank_name': bankName,
      'account_number': accountNumber,
      'current_balance': currentBalance,
      'credit_limit': creditLimit,
      'account_status': accountStatus,
      'open_date': openDate?.toIso8601String(),
      'last_payment_date': lastPaymentDate?.toIso8601String(),
      'payment_history': paymentHistory,
    };
  }
}

class CreditInquiry {
  final String? inquiryType;
  final String? inquirerName;
  final DateTime? inquiryDate;
  final String? purpose;
  final double? amount;

  CreditInquiry({
    this.inquiryType,
    this.inquirerName,
    this.inquiryDate,
    this.purpose,
    this.amount,
  });

  factory CreditInquiry.fromJson(Map<String, dynamic> json) {
    return CreditInquiry(
      inquiryType: json['inquiry_type'] ?? json['inquiryType'],
      inquirerName: json['inquirer_name'] ?? json['inquirerName'],
      inquiryDate: json['inquiry_date'] != null || json['inquiryDate'] != null
          ? DateTime.tryParse(json['inquiry_date'] ?? json['inquiryDate'])
          : null,
      purpose: json['purpose'],
      amount: json['amount']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inquiry_type': inquiryType,
      'inquirer_name': inquirerName,
      'inquiry_date': inquiryDate?.toIso8601String(),
      'purpose': purpose,
      'amount': amount,
    };
  }
}

class PersonalInfo {
  final String? fullName;
  final String? dateOfBirth;
  final String? gender;
  final List<String>? addresses;
  final List<String>? phoneNumbers;
  final String? emailAddress;

  PersonalInfo({
    this.fullName,
    this.dateOfBirth,
    this.gender,
    this.addresses,
    this.phoneNumbers,
    this.emailAddress,
  });

  factory PersonalInfo.fromJson(Map<String, dynamic> json) {
    return PersonalInfo(
      fullName: json['full_name'] ?? json['fullName'],
      dateOfBirth: json['date_of_birth'] ?? json['dateOfBirth'],
      gender: json['gender'],
      addresses: json['addresses'] != null
          ? List<String>.from(json['addresses'])
          : null,
      phoneNumbers: json['phone_numbers'] != null || json['phoneNumbers'] != null
          ? List<String>.from(json['phone_numbers'] ?? json['phoneNumbers'])
          : null,
      emailAddress: json['email_address'] ?? json['emailAddress'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'addresses': addresses,
      'phone_numbers': phoneNumbers,
      'email_address': emailAddress,
    };
  }
}