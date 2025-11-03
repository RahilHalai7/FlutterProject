import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnifiedProfile {
  final String name;
  final int age;
  final String email;
  final double income;
  final String? employmentType; // e.g., Government, Private, Student, Retired, Other
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

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;

    // Handle inconsistent field naming between signup and profile page
    final name = (data['Name'] ?? data['name'] ?? '').toString();
    final age = (data['age'] ?? 0) is int
        ? (data['age'] as int)
        : int.tryParse(data['age']?.toString() ?? '') ?? 0;
    final email = (data['email'] ?? '').toString();
    final income = (data['income'] ?? 0) is num
        ? (data['income'] as num).toDouble()
        : double.tryParse(data['income']?.toString() ?? '') ?? 0.0;
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