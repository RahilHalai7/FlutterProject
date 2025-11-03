import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'profile_service.dart';

class RetirementProfile {
  final int age;
  final int retirementAgeGoal;
  final double income;
  final double monthlyExpenses;
  final double currentSavings;
  final String riskLevel;

  RetirementProfile({
    required this.age,
    required this.retirementAgeGoal,
    required this.income,
    required this.monthlyExpenses,
    required this.currentSavings,
    required this.riskLevel,
  });

  factory RetirementProfile.fromJson(Map<String, dynamic> j) =>
      RetirementProfile(
        age: (j['age'] ?? 19) as int,
        retirementAgeGoal: (j['retirement_age_goal'] ?? 60) as int,
        income: (j['income'] ?? 0).toDouble(),
        monthlyExpenses: (j['monthly_expenses'] ?? 0).toDouble(),
        currentSavings: (j['current_savings'] ?? 0).toDouble(),
        riskLevel: (j['risk_level'] ?? 'moderate') as String,
      );
}

class RetirementProjections {
  final int yearsToRetirement;
  final double estimatedCorpusRequired;
  final double projectedSavingsAtCurrentRate;
  final double shortfallOrSurplus;

  RetirementProjections({
    required this.yearsToRetirement,
    required this.estimatedCorpusRequired,
    required this.projectedSavingsAtCurrentRate,
    required this.shortfallOrSurplus,
  });

  factory RetirementProjections.fromJson(Map<String, dynamic> j) =>
      RetirementProjections(
        yearsToRetirement: (j['years_to_retirement'] ?? 0) as int,
        estimatedCorpusRequired: (j['estimated_corpus_required'] ?? 0)
            .toDouble(),
        projectedSavingsAtCurrentRate:
            (j['projected_savings_at_current_rate'] ?? 0).toDouble(),
        shortfallOrSurplus: (j['shortfall_or_surplus'] ?? 0).toDouble(),
      );
}

class RetirementRecommendation {
  final String title;
  final String expectedReturn;
  final String category;
  final String risk;

  RetirementRecommendation({
    required this.title,
    required this.expectedReturn,
    required this.category,
    required this.risk,
  });

  factory RetirementRecommendation.fromJson(Map<String, dynamic> j) =>
      RetirementRecommendation(
        title: j['title'] ?? '',
        expectedReturn: j['expected_return'] ?? '',
        category: j['category'] ?? '',
        risk: j['risk'] ?? 'moderate',
      );
}

class RetirementService {
  final String baseUrl;
  RetirementService({String? baseUrl})
    : baseUrl =
          baseUrl ??
          (kIsWeb ? 'http://localhost:5001' : 'http://10.0.2.2:5001');

  Future<RetirementProfile> fetchProfile() async {
    // Fetch backend profile
    final res = await http.get(Uri.parse('$baseUrl/user/retirement-profile'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load retirement profile');
    }
    var backend = RetirementProfile.fromJson(jsonDecode(res.body));

    // Overlay with Firestore basic profile values where available
    try {
      final up = await ProfileService.fetchBasicProfile();
      if (up != null) {
        backend = RetirementProfile(
          age: up.age != 0 ? up.age : backend.age,
          retirementAgeGoal: backend.retirementAgeGoal,
          income: up.income != 0.0 ? up.income : backend.income,
          monthlyExpenses: backend.monthlyExpenses,
          currentSavings: backend.currentSavings,
          riskLevel: up.riskLevel ?? backend.riskLevel,
        );
      }
    } catch (_) {
      // ignore overlay errors, keep backend values
    }

    return backend;
  }

  Future<RetirementProjections> fetchProjections() async {
    final res = await http.get(Uri.parse('$baseUrl/retirement/projections'));
    if (res.statusCode == 200) {
      return RetirementProjections.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load retirement projections');
  }

  Future<List<RetirementRecommendation>> fetchRecommendations() async {
    final res = await http.get(
      Uri.parse('$baseUrl/retirement/recommendations'),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      return data.map((e) => RetirementRecommendation.fromJson(e)).toList();
    }
    throw Exception('Failed to load retirement recommendations');
  }

  Future<bool> planWithStrategy(
    RetirementRecommendation r, {
    double allocationPercent = 10.0,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/retirement/strategy'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'plan': {'title': r.title, 'category': r.category, 'risk': r.risk},
        'allocation_percent': allocationPercent,
      }),
    );
    return res.statusCode == 200;
  }
}