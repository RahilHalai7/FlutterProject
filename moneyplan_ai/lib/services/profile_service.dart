import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnifiedProfile {
  final String name;
  final int age;
  final String email;
  final double income;
  final String?
  employmentType; // e.g., Government, Private, Student, Retired, Other
  final String? riskLevel; // normalized: low|medium|high

  const UnifiedProfile({
    required this.name,
    required this.age,
    required this.email,
    required this.income,
    this.employmentType,
    this.riskLevel,
  });
}

class ProfileService {
  static Future<UnifiedProfile?> fetchBasicProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    // Force server read to avoid stale cached values after profile updates
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;

    // Handle inconsistent field naming between signup and profile page
    final name = (data['Name'] ?? data['name'] ?? '').toString();
    final rawAge = data.containsKey('age') ? data['age'] : data['Age'];
    final age = (rawAge ?? 0) is int
        ? (rawAge as int)
        : int.tryParse((rawAge)?.toString() ?? '') ?? 0;
    final email = (data['email'] ?? '').toString();
    final rawIncome = data.containsKey('income')
        ? data['income']
        : data['Income'];
    final income = (rawIncome ?? 0) is num
        ? (rawIncome as num).toDouble()
        : double.tryParse((rawIncome)?.toString() ?? '') ?? 0.0;
    final employmentType = (data['employmentType'] ?? '').toString();

    // Normalize risk appetite to expected lowercase variants
    final riskAppetiteRaw = (data['riskAppetite'] ?? '').toString();
    final riskLevel = _normalizeRisk(riskAppetiteRaw);

    return UnifiedProfile(
      name: name,
      age: age,
      email: email,
      income: income,
      employmentType: employmentType.isEmpty ? null : employmentType,
      riskLevel: riskLevel,
    );
  }

  static String? _normalizeRisk(String v) {
    if (v.isEmpty) return null;
    switch (v.toLowerCase()) {
      case 'high':
        return 'high';
      case 'medium':
        return 'moderate'; // project uses 'moderate' in some places
      case 'low':
        return 'low';
      default:
        return v.toLowerCase();
    }
  }
}