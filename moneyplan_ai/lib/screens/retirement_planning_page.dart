import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/retirement_service.dart';
import '../services/retirement_settings_service.dart';
import '../services/profile_service.dart';

class RetirementPlanningPage extends StatefulWidget {
  const RetirementPlanningPage({super.key});

  @override
  State<RetirementPlanningPage> createState() => _RetirementPlanningPageState();
}

class _RetirementPlanningPageState extends State<RetirementPlanningPage> {
  final RetirementService _service = RetirementService();
  final GlobalKey _projectionsSectionKey = GlobalKey();

  UnifiedProfile? _basicProfile;

  RetirementProfile? _profile;
  RetirementProjections? _projections;
  bool _loading = true;
  bool _error = false;
  RetirementAssumptions _assumptions = const RetirementAssumptions();
  RetirementProjections? _customProjections;
  final TextEditingController _monthlyContributionCtrl =
      TextEditingController();
  final TextEditingController _incomeCtrl = TextEditingController();
  final TextEditingController _currentSavingsCtrl = TextEditingController();
  final TextEditingController _monthlyExpensesCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _retirementAgeCtrl = TextEditingController();
  // Removed manual save; assumptions are loaded from DB when available
  // Removed _savingAssumptions state; no manual saving in UI.

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      // Load saved assumptions first
      var a = await RetirementSettingsService.loadAssumptions();
      _monthlyContributionCtrl.text = a.monthlyContribution.toStringAsFixed(0);

      // Prefer Firebase for profile; fallback to backend if needed
      RetirementProfile? p = await _fetchProfileFromFirebase(a);
      p ??= await _tryBackendProfileFallback();
      // Final fallback: neutral defaults
      p ??= _safeProfile();

      // Try to fetch projections from backend, else compute locally
      RetirementProjections? pr;
      try {
        pr = await _service.fetchProjections();
      } catch (_) {
        pr = _calcProjections(p!, a);
      }

      final custom = _calcProjections(p!, a);

      // Sync profile adjustment inputs with loaded values
      _ageCtrl.text = p!.age.toString();
      _incomeCtrl.text = p.income.toStringAsFixed(0);
      _currentSavingsCtrl.text = p.currentSavings.toStringAsFixed(0);
      _monthlyExpensesCtrl.text = p.monthlyExpenses.toStringAsFixed(0);
      _retirementAgeCtrl.text =
          (a.retirementAgeGoalOverride ?? p.retirementAgeGoal).toString();

      setState(() {
        _profile = p;
        _projections = pr;
        _assumptions = a;
        _customProjections = custom;
        _loading = false;
        _error = false;
      });
    } catch (e) {
      // If something truly unexpected occurs, avoid crashing UI
      setState(() {
        _loading = false;
        _error = false; // keep UI rendering with any partial data
      });
    }
  }

  Future<RetirementProfile?> _fetchProfileFromFirebase(
    RetirementAssumptions a,
  ) async {
    try {
      final basic = await ProfileService.fetchBasicProfile();
      if (basic == null) return null;
      // Cache for displaying additional profile details on the page
      _basicProfile = basic;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      // Optional fields from user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final userData = userDoc.data() ?? {};
      final currentSavings = _toDouble(userData['currentSavings']) ?? 0.0;
      // Prefer explicit monthlyExpenses if stored on profile, otherwise compute from transactions
      final monthlyExpensesFromProfile = _toDouble(userData['monthlyExpenses']);
      final monthlyExpenses =
          monthlyExpensesFromProfile ?? await _sumCurrentMonthExpenses(uid);
      // Prefer a user-specific retirementAgeGoal if present, otherwise use assumptions override then default
      final retirementAgeFromProfile = userData['retirementAgeGoal'] is int
          ? (userData['retirementAgeGoal'] as int)
          : int.tryParse(userData['retirementAgeGoal']?.toString() ?? '');
      final retirementAgeGoal =
          retirementAgeFromProfile ?? a.retirementAgeGoalOverride ?? 60;

      // Convert monthly income (stored in profile) to annual for display/estimations
      final annualIncome = (basic.income.isFinite ? basic.income : 0.0) * 12;
      return RetirementProfile(
        age: basic.age,
        retirementAgeGoal: retirementAgeGoal,
        income: annualIncome,
        monthlyExpenses: monthlyExpenses,
        currentSavings: currentSavings,
        riskLevel: basic.riskLevel ?? 'moderate',
      );
    } catch (_) {
      return null;
    }
  }

  Future<RetirementProfile?> _tryBackendProfileFallback() async {
    try {
      return await _service.fetchProfile();
    } catch (_) {
      return null; // No hard-coded defaults
    }
  }

  Future<double> _sumCurrentMonthExpenses(String uid) async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final nextMonth = DateTime(now.year, now.month + 1, 1);

      final q = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('type', isEqualTo: 'expense')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(nextMonth))
          .get();

      double sum = 0.0;
      for (final doc in q.docs) {
        sum += _toDouble(doc.data()['amount']) ?? 0.0;
      }
      return sum;
    } catch (_) {
      return 0.0;
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text(
          'Retirement Planning',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            label: const Text(
              'Back',
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E27),
              Color(0xFF1A1B3A),
              Color(0xFF2E1065),
              Color(0xFF4C1D95),
              Color(0xFF5B21B6),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: _loading
            ? _buildLoading()
            : _error
            ? _buildError()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 16),
                        _buildInputsCard(),
                        const SizedBox(height: 16),
                        // Removed local adjustment and assumption controls per request
                        _buildServerModelInfo(),
                        const SizedBox(height: 16),
                        isWide
                            ? Container(
                                key: _projectionsSectionKey,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildProjectionChartCard(),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 16),
                                          _buildCustomProjectionStatsCard(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                key: _projectionsSectionKey,
                                child: Column(
                                  children: [
                                    _buildProjectionChartCard(),
                                    const SizedBox(height: 16),
                                    _buildCustomProjectionStatsCard(),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 16),
                        // Recommendations removed per request
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 120,
              width: double.infinity,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 240,
              width: double.infinity,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 200,
              width: double.infinity,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Failed to load data'),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final p = _safeProfile();
    final bp = _basicProfile;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            if (bp != null && bp.name.isNotEmpty) _kv('Name', bp.name),
            _kv('Age', '${p.age}'),
            _kv('Income', '₹${_fmt(p.income)} /yr'),
            _kv('Monthly Expenses', '₹${_fmt(p.monthlyExpenses)}'),
            _kv('Current Savings', '₹${_fmt(p.currentSavings)}'),
            _kv('Retirement Age Goal', '${p.retirementAgeGoal}'),
            _kv('Risk', p.riskLevel),
            if (bp?.employmentType != null && bp!.employmentType!.isNotEmpty)
              _kv('Employment Type', bp.employmentType!),
            if (bp != null && bp.email.isNotEmpty) _kv('Email', bp.email),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildProjectionChartCard() {
    final pr = _getActiveProjections();
    final required = pr.estimatedCorpusRequired;
    final projected = pr.projectedSavingsAtCurrentRate;
    final sections = [
      PieChartSectionData(
        value: projected,
        title: 'Projected',
        color: Colors.blue,
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        value: required,
        title: 'Required',
        color: Colors.orange,
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Projection Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (context, t, child) {
                // Scale values for animation
                final animatedSections = sections
                    .map((s) => s.copyWith(value: s.value * t))
                    .toList();
                return SizedBox(
                  height: 240,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: animatedSections,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _legendDot(Colors.blue, 'Projected Corpus'),
                const SizedBox(width: 16),
                _legendDot(Colors.orange, 'Required Corpus'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectionStatsCard() {
    final pr = _getActiveProjections();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Server Projections',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _kv('Years to retirement', '${pr.yearsToRetirement}'),
            const SizedBox(height: 8),
            _kv(
              'Estimated Required Corpus',
              '₹${_fmt(pr.estimatedCorpusRequired)}',
            ),
            const SizedBox(height: 8),
            _kv(
              'Projected Corpus',
              '₹${_fmt(pr.projectedSavingsAtCurrentRate)}',
            ),
            const SizedBox(height: 8),
            _kv(
              pr.shortfallOrSurplus >= 0 ? 'Surplus' : 'Shortfall',
              '₹${_fmt(pr.shortfallOrSurplus.abs())}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color c, String t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(t),
      ],
    );
  }

  Widget _buildAssumptionsCard() {
    final a = _assumptions;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assumptions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _assumptionSlider(
                  label: 'Expected Return (%)',
                  value: a.expectedReturnPct,
                  min: 2,
                  max: 20,
                  onChanged: (v) =>
                      _updateAssumptions(a.copyWith(expectedReturnPct: v)),
                ),
                _assumptionSlider(
                  label: 'Inflation (%)',
                  value: a.inflationPct,
                  min: 0,
                  max: 10,
                  onChanged: (v) =>
                      _updateAssumptions(a.copyWith(inflationPct: v)),
                ),
                _assumptionSlider(
                  label: 'Salary Growth (%)',
                  value: a.salaryGrowthPct,
                  min: 0,
                  max: 15,
                  onChanged: (v) =>
                      _updateAssumptions(a.copyWith(salaryGrowthPct: v)),
                ),
                _assumptionSlider(
                  label: 'Retirement Duration (years)',
                  value: a.retirementDurationYears.toDouble(),
                  min: 10,
                  max: 40,
                  onChanged: (v) => _updateAssumptions(
                    a.copyWith(retirementDurationYears: v.round()),
                  ),
                ),
                _assumptionSlider(
                  label: 'Retirement Age',
                  value:
                      (a.retirementAgeGoalOverride ??
                              _profile?.retirementAgeGoal ??
                              60)
                          .toDouble(),
                  min: 45,
                  max: 70,
                  onChanged: (v) => _updateAssumptions(
                    a.copyWith(retirementAgeGoalOverride: v.round()),
                  ),
                ),
                _assumptionTextField(
                  label: 'Monthly Contribution (₹)',
                  controller: _monthlyContributionCtrl,
                  onSubmitted: (txt) {
                    final parsed =
                        double.tryParse(txt) ?? a.monthlyContribution;
                    _monthlyContributionCtrl.text = parsed.toStringAsFixed(0);
                    _updateAssumptions(a.copyWith(monthlyContribution: parsed));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Removed manual save button to rely on DB-loaded assumptions
            // Row(
            //   children: [
            //     ElevatedButton(
            //       onPressed: _savingAssumptions ? null : _saveAssumptions,
            //       child: _savingAssumptions
            //           ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            //           : const Text('Save Assumptions'),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  // Helpers re-added
  Widget _assumptionSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey)),
              Text(value.toStringAsFixed(1)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _assumptionTextField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onSubmitted,
  }) {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g., 10000',
            ),
            onSubmitted: onSubmitted,
          ),
        ],
      ),
    );
  }

  RetirementProjections _getActiveProjections() {
    // Prefer custom projections computed via Calculate; fall back to server; otherwise zeros.
    if (_customProjections != null) return _customProjections!;
    if (_projections != null) return _projections!;
    return RetirementProjections(
      yearsToRetirement: 0,
      estimatedCorpusRequired: 0,
      projectedSavingsAtCurrentRate: 0,
      shortfallOrSurplus: 0,
      modelSource: 'none',
    );
  }

  Widget _buildServerModelInfo() {
    final source = _projections?.modelSource ?? 'server';
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.auto_graph),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Projections powered by Retirement Calculator (${source})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateAssumptions(RetirementAssumptions a) {
    setState(() {
      _assumptions = a;
      _customProjections = _calcProjections(_safeProfile(), _assumptions);
    });
  }

  // Removed manual save of assumptions; values are loaded from Firestore when available.

  RetirementProjections _calcProjections(
    RetirementProfile p,
    RetirementAssumptions a,
  ) {
    final int goalAge = a.retirementAgeGoalOverride ?? p.retirementAgeGoal;
    final int yearsToRetirement = (goalAge - p.age).clamp(0, 100);
    final double r = (a.expectedReturnPct - a.inflationPct) / 100.0;
    final double g = a.salaryGrowthPct / 100.0;

    // Expense at retirement (inflation-adjusted)
    final double annualExpenseAtRetirement =
        p.monthlyExpenses *
        12 *
        math.pow(1 + a.inflationPct / 100.0, yearsToRetirement).toDouble();

    // Required corpus as PV of an annuity over retirementDurationYears at real return r
    final int m = a.retirementDurationYears;
    double requiredCorpus;
    if (r <= 0.000001) {
      requiredCorpus = annualExpenseAtRetirement * m;
    } else {
      requiredCorpus =
          annualExpenseAtRetirement * (1 - math.pow(1 + r, -m)) / r;
    }

    // Projected savings
    final double currentFV =
        p.currentSavings * math.pow(1 + r, yearsToRetirement).toDouble();
    final double C = a.monthlyContribution * 12;
    double contribFV;
    if ((r - g).abs() < 1e-9) {
      contribFV =
          C *
          yearsToRetirement *
          math.pow(1 + r, yearsToRetirement - 1).toDouble();
    } else {
      contribFV =
          C *
          (math.pow(1 + r, yearsToRetirement) -
              math.pow(1 + g, yearsToRetirement)) /
          (r - g);
    }
    final double projectedCorpus = currentFV + contribFV;

    final double surplus = projectedCorpus - requiredCorpus;

    return RetirementProjections(
      yearsToRetirement: yearsToRetirement,
      estimatedCorpusRequired: requiredCorpus,
      projectedSavingsAtCurrentRate: projectedCorpus,
      shortfallOrSurplus: surplus,
    );
  }

  String _fmt(double v) {
    // Simple formatter for big numbers
    if (v >= 1e7) return '${(v / 1e7).toStringAsFixed(2)} Cr';
    if (v >= 1e5) return '${(v / 1e5).toStringAsFixed(2)} L';
    return v.toStringAsFixed(0);
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurpleAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  RetirementProfile _safeProfile() {
    // Avoid hard-coded sample values; use minimal neutral defaults
    return _profile ??
        RetirementProfile(
          age: 0,
          retirementAgeGoal: 60,
          income: 0,
          monthlyExpenses: 0,
          currentSavings: 0,
          riskLevel: 'moderate',
        );
  }

  void _updateProfile({
    double? income,
    double? currentSavings,
    double? monthlyExpenses,
    int? age,
    int? retirementAgeGoal,
    String? riskLevel,
  }) {
    final p = _safeProfile();
    final updated = RetirementProfile(
      age: age ?? p.age,
      retirementAgeGoal: retirementAgeGoal ?? p.retirementAgeGoal,
      income: income ?? p.income,
      monthlyExpenses: monthlyExpenses ?? p.monthlyExpenses,
      currentSavings: currentSavings ?? p.currentSavings,
      riskLevel: riskLevel ?? p.riskLevel,
    );
    setState(() {
      _profile = updated;
      _customProjections = _calcProjections(updated, _assumptions);
    });
  }

  Widget _buildProfileAdjustmentsCard() {
    final p = _safeProfile();
    // Initialize controllers if empty
    if (_incomeCtrl.text.isEmpty) {
      _incomeCtrl.text = p.income.toStringAsFixed(0);
    }
    if (_currentSavingsCtrl.text.isEmpty) {
      _currentSavingsCtrl.text = p.currentSavings.toStringAsFixed(0);
    }
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adjust Profile',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _incomeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Income (₹/yr)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      final parsed = double.tryParse(
                        v.replaceAll(',', '').trim(),
                      );
                      if (parsed != null) {
                        _updateProfile(income: parsed);
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _currentSavingsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Current Savings (₹)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      final parsed = double.tryParse(
                        v.replaceAll(',', '').trim(),
                      );
                      if (parsed != null) {
                        _updateProfile(currentSavings: parsed);
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final inc = double.tryParse(
                      _incomeCtrl.text.replaceAll(',', '').trim(),
                    );
                    final sav = double.tryParse(
                      _currentSavingsCtrl.text.replaceAll(',', '').trim(),
                    );
                    _updateProfile(
                      income: inc ?? _safeProfile().income,
                      currentSavings: sav ?? _safeProfile().currentSavings,
                    );
                  },
                  child: const Text('Apply changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputsCard() {
    final p = _safeProfile();
    final a = _assumptions;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Planning Inputs', Icons.tune),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      suffixText: 'yrs',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cake),
                    ),
                    onSubmitted: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed != null) _updateProfile(age: parsed);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _retirementAgeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Retirement Age Goal',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag),
                      suffixText: 'yrs',
                    ),
                    onSubmitted: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed != null) {
                        // use assumptions override to drive projections
                        _updateAssumptions(
                          a.copyWith(retirementAgeGoalOverride: parsed),
                        );
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _incomeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Income (₹/yr)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    onSubmitted: (v) {
                      final parsed = double.tryParse(
                        v.replaceAll(',', '').trim(),
                      );
                      if (parsed != null) _updateProfile(income: parsed);
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _monthlyExpensesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Expenses (₹/mo)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money_off),
                    ),
                    onSubmitted: (v) {
                      final parsed = double.tryParse(
                        v.replaceAll(',', '').trim(),
                      );
                      if (parsed != null)
                        _updateProfile(monthlyExpenses: parsed);
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _currentSavingsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Current Savings (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.savings),
                    ),
                    onSubmitted: (v) {
                      final parsed = double.tryParse(
                        v.replaceAll(',', '').trim(),
                      );
                      if (parsed != null)
                        _updateProfile(currentSavings: parsed);
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _monthlyContributionCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Contribution (₹/mo)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.trending_up),
                    ),
                    onSubmitted: (v) {
                      final parsed = double.tryParse(
                        v.replaceAll(',', '').trim(),
                      );
                      if (parsed != null) {
                        _updateAssumptions(
                          a.copyWith(monthlyContribution: parsed),
                        );
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: p.riskLevel.isNotEmpty ? p.riskLevel : 'moderate',
                    items: const [
                      DropdownMenuItem(
                        value: 'conservative',
                        child: Text('Conservative'),
                      ),
                      DropdownMenuItem(
                        value: 'moderate',
                        child: Text('Moderate'),
                      ),
                      DropdownMenuItem(
                        value: 'aggressive',
                        child: Text('Aggressive'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Risk Level',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shield),
                    ),
                    onChanged: (v) {
                      if (v != null) _updateProfile(riskLevel: v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _sectionHeader('Assumptions', Icons.assessment),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _assumptionSlider(
                  label: 'Expected Return (%)',
                  value: a.expectedReturnPct,
                  min: 2,
                  max: 20,
                  onChanged: (v) =>
                      _updateAssumptions(a.copyWith(expectedReturnPct: v)),
                ),
                _assumptionSlider(
                  label: 'Inflation (%)',
                  value: a.inflationPct,
                  min: 0,
                  max: 10,
                  onChanged: (v) =>
                      _updateAssumptions(a.copyWith(inflationPct: v)),
                ),
                _assumptionSlider(
                  label: 'Salary Growth (%)',
                  value: a.salaryGrowthPct,
                  min: 0,
                  max: 15,
                  onChanged: (v) =>
                      _updateAssumptions(a.copyWith(salaryGrowthPct: v)),
                ),
                _assumptionSlider(
                  label: 'Retirement Duration (years)',
                  value: a.retirementDurationYears.toDouble(),
                  min: 10,
                  max: 40,
                  onChanged: (v) => _updateAssumptions(
                    a.copyWith(retirementDurationYears: v.round()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: edit fields and press Enter or adjust sliders to update projections.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calculate),
                  label: const Text('Calculate'),
                  onPressed: _calculateAndShow,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _seeProjections() {
    // Recompute custom projections with current values to ensure fresh view
    setState(() {
      _customProjections = _calcProjections(_safeProfile(), _assumptions);
    });
    // Smooth scroll to projections section
    final ctx = _projectionsSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _calculateAndShow() {
    final current = _safeProfile();
    // Parse profile fields
    final age = int.tryParse(_ageCtrl.text.trim());
    final retirementAge = int.tryParse(_retirementAgeCtrl.text.trim());
    final income = double.tryParse(_incomeCtrl.text.replaceAll(',', '').trim());
    final expenses = double.tryParse(
      _monthlyExpensesCtrl.text.replaceAll(',', '').trim(),
    );
    final savings = double.tryParse(
      _currentSavingsCtrl.text.replaceAll(',', '').trim(),
    );
    final contribution = double.tryParse(
      _monthlyContributionCtrl.text.replaceAll(',', '').trim(),
    );

    // Build updated profile and assumptions
    final updatedProfile = RetirementProfile(
      age: age ?? current.age,
      retirementAgeGoal: retirementAge ?? current.retirementAgeGoal,
      income: income ?? current.income,
      monthlyExpenses: expenses ?? current.monthlyExpenses,
      currentSavings: savings ?? current.currentSavings,
      riskLevel: current.riskLevel,
    );

    final updatedAssumptions = _assumptions.copyWith(
      monthlyContribution: contribution ?? _assumptions.monthlyContribution,
      retirementAgeGoalOverride:
          retirementAge ?? _assumptions.retirementAgeGoalOverride,
    );

    final computed = _calcProjections(updatedProfile, updatedAssumptions);

    setState(() {
      _profile = updatedProfile;
      _assumptions = updatedAssumptions;
      _customProjections = computed;
    });

    // Optional: simple feedback
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Calculated projections')));

    // Scroll to projections
    final ctx = _projectionsSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildCustomProjectionStatsCard() {
    final pr =
        _customProjections ?? _calcProjections(_safeProfile(), _assumptions);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom Projections (from inputs)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _kv('Years to retirement', '${pr.yearsToRetirement}'),
            const SizedBox(height: 8),
            _kv(
              'Estimated Required Corpus',
              '₹${_fmt(pr.estimatedCorpusRequired)}',
            ),
            const SizedBox(height: 8),
            _kv(
              'Projected Corpus',
              '₹${_fmt(pr.projectedSavingsAtCurrentRate)}',
            ),
            const SizedBox(height: 8),
            _kv(
              pr.shortfallOrSurplus >= 0 ? 'Surplus' : 'Shortfall',
              '₹${_fmt(pr.shortfallOrSurplus.abs())}',
            ),
          ],
        ),
      ),
    );
  }
}
