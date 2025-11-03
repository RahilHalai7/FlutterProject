import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class UserProfile {
  final String name;
  final int age;
  final String job;
  final int income;
  final String riskLevel;

  UserProfile({
    required this.name,
    required this.age,
    required this.job,
    required this.income,
    required this.riskLevel,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'] ?? '',
    age: j['age'] ?? 19,
    job: j['job'] ?? '',
    income: j['income'] ?? 0,
    riskLevel: j['risk_level'] ?? 'moderate',
  );
}

class Opportunity {
  final String title;
  final String expectedReturn;
  final String risk;
  final String category;

  Opportunity({
    required this.title,
    required this.expectedReturn,
    required this.risk,
    required this.category,
  });

  factory Opportunity.fromJson(Map<String, dynamic> j) => Opportunity(
    title: j['title'] ?? '',
    expectedReturn: j['expected_return'] ?? '',
    risk: j['risk'] ?? 'moderate',
    category: j['category'] ?? '',
  );
}

class PortfolioItem {
  final String title;
  final String category;
  double allocationPercent;

  PortfolioItem({
    required this.title,
    required this.category,
    required this.allocationPercent,
  });
}

class PortfolioService {
  static String get baseUrl {
    // FastAPI server runs on 5001; adjust for mobile if needed.
    return kIsWeb ? 'http://localhost:5001' : 'http://10.0.2.2:5001';
  }

  static Future<UserProfile> fetchUserProfile() async {
    final res = await http.get(Uri.parse('$baseUrl/user/profile'));
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return UserProfile.fromJson(j);
  }

  static Future<List<Opportunity>> fetchOpportunities() async {
    final res = await http.get(Uri.parse('$baseUrl/market/opportunities'));
    final arr = jsonDecode(res.body) as List<dynamic>;
    return arr
        .map((e) => Opportunity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> updatePortfolio({
    required String action,
    required Opportunity item,
    double allocationPercent = 10.0,
  }) async {
    final payload = {
      'action': action,
      'item': {'title': item.title, 'category': item.category},
      'allocation_percent': allocationPercent,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/portfolio/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
