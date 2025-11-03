import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RetirementAssumptions {
  final double expectedReturnPct; // e.g., 10%
  final double inflationPct; // e.g., 6%
  final double monthlyContribution; // INR
  final double salaryGrowthPct; // annual growth of contribution/income
  final int retirementDurationYears; // years in retirement (coverage)
  final int? retirementAgeGoalOverride; // optional override

  const RetirementAssumptions({
    this.expectedReturnPct = 10.0,
    this.inflationPct = 6.0,
    this.monthlyContribution = 10000.0,
    this.salaryGrowthPct = 5.0,
    this.retirementDurationYears = 25,
    this.retirementAgeGoalOverride,
  });

  RetirementAssumptions copyWith({
    double? expectedReturnPct,
    double? inflationPct,
    double? monthlyContribution,
    double? salaryGrowthPct,
    int? retirementDurationYears,
    int? retirementAgeGoalOverride,
  }) {
    return RetirementAssumptions(
      expectedReturnPct: expectedReturnPct ?? this.expectedReturnPct,
      inflationPct: inflationPct ?? this.inflationPct,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      salaryGrowthPct: salaryGrowthPct ?? this.salaryGrowthPct,
      retirementDurationYears:
          retirementDurationYears ?? this.retirementDurationYears,
      retirementAgeGoalOverride:
          retirementAgeGoalOverride ?? this.retirementAgeGoalOverride,
    );
  }

  Map<String, dynamic> toMap() => {
        'expectedReturnPct': expectedReturnPct,
        'inflationPct': inflationPct,
        'monthlyContribution': monthlyContribution,
        'salaryGrowthPct': salaryGrowthPct,
        'retirementDurationYears': retirementDurationYears,
        if (retirementAgeGoalOverride != null)
          'retirementAgeGoalOverride': retirementAgeGoalOverride,
      };

  static RetirementAssumptions fromMap(Map<String, dynamic>? m) {
    if (m == null) return const RetirementAssumptions();
    return RetirementAssumptions(
      expectedReturnPct: (m['expectedReturnPct'] ?? 10.0).toDouble(),
      inflationPct: (m['inflationPct'] ?? 6.0).toDouble(),
      monthlyContribution: (m['monthlyContribution'] ?? 10000.0).toDouble(),
      salaryGrowthPct: (m['salaryGrowthPct'] ?? 5.0).toDouble(),
      retirementDurationYears: (m['retirementDurationYears'] ?? 25) as int,
      retirementAgeGoalOverride: m['retirementAgeGoalOverride'] as int?,
    );
  }
}

class RetirementSettingsService {
  static Future<RetirementAssumptions> loadAssumptions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const RetirementAssumptions();
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('retirement')
        .get();
    final data = doc.data();
    return RetirementAssumptions.fromMap(data);
  }

  static Future<void> saveAssumptions(RetirementAssumptions a) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('retirement')
        .set({...a.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
  }
}