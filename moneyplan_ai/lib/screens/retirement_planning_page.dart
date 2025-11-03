import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../services/retirement_service.dart';
import '../services/retirement_settings_service.dart';

class RetirementPlanningPage extends StatefulWidget {
  const RetirementPlanningPage({super.key});

  @override
  State<RetirementPlanningPage> createState() => _RetirementPlanningPageState();
}

class _RetirementPlanningPageState extends State<RetirementPlanningPage> {
  final RetirementService _service = RetirementService();

  RetirementProfile? _profile;
  RetirementProjections? _projections;
  bool _loading = true;
  bool _error = false;
  RetirementAssumptions _assumptions = const RetirementAssumptions();
  RetirementProjections? _customProjections;
  final TextEditingController _monthlyContributionCtrl = TextEditingController();
  final TextEditingController _incomeCtrl = TextEditingController();
  final TextEditingController _currentSavingsCtrl = TextEditingController();
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

      // Try to fetch profile from backend, fallback to defaults
      RetirementProfile? p;
      try {
        p = await _service.fetchProfile();
      } catch (_) {
        // Minimal sensible defaults if backend is unavailable
        p = RetirementProfile(
          age: 30,
          retirementAgeGoal: 60,
          income: 800000,
          monthlyExpenses: 40000,
          currentSavings: 300000,
          riskLevel: 'moderate',
        );
      }
 

      // Try to fetch projections from backend, else compute locally
      RetirementProjections? pr;
      try {
        pr = await _service.fetchProjections();
      } catch (_) {
        pr = _calcProjections(p!, a);
      }

      final custom = _calcProjections(p!, a);

      // Sync profile adjustment inputs with loaded values
      _incomeCtrl.text = p!.income.toStringAsFixed(0);
      _currentSavingsCtrl.text = p.currentSavings.toStringAsFixed(0);

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
                          _buildProfileAdjustmentsCard(),
                          const SizedBox(height: 16),
                          _buildAssumptionsCard(),
                          const SizedBox(height: 16),
                          isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildProjectionChartCard()),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildProjectionStatsCard()),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildProjectionChartCard(),
                                    const SizedBox(height: 16),
                                    _buildProjectionStatsCard(),
                                  ],
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
            child: Container(height: 120, width: double.infinity, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(height: 240, width: double.infinity, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(height: 200, width: double.infinity, color: Colors.white),
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _kv('Age', '${p.age}'),
            _kv('Income', '₹${_fmt(p.income)} /yr'),
            _kv('Monthly Expenses', '₹${_fmt(p.monthlyExpenses)}'),
            _kv('Current Savings', '₹${_fmt(p.currentSavings)}'),
            _kv('Retirement Age Goal', '${p.retirementAgeGoal}'),
            _kv('Risk', p.riskLevel),
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
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      PieChartSectionData(
        value: required,
        title: 'Required',
        color: Colors.orange,
        radius: 60,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Projection Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _legendDot(Color c, String t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t),
      ],
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
            _kv('Years to retirement', '${pr.yearsToRetirement}'),
            const SizedBox(height: 8),
            _kv('Estimated Required Corpus', '₹${_fmt(pr.estimatedCorpusRequired)}'),
            const SizedBox(height: 8),
            _kv('Projected Corpus', '₹${_fmt(pr.projectedSavingsAtCurrentRate)}'),
            const SizedBox(height: 8),
            _kv(pr.shortfallOrSurplus >= 0 ? 'Surplus' : 'Shortfall', '₹${_fmt(pr.shortfallOrSurplus.abs())}'),
          ],
        ),
      ),
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
            const Text('Assumptions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  onChanged: (v) => _updateAssumptions(a.copyWith(expectedReturnPct: v)),
                ),
                _assumptionSlider(
                  label: 'Inflation (%)',
                  value: a.inflationPct,
                  min: 0,
                  max: 10,
                  onChanged: (v) => _updateAssumptions(a.copyWith(inflationPct: v)),
                ),
                _assumptionSlider(
                  label: 'Salary Growth (%)',
                  value: a.salaryGrowthPct,
                  min: 0,
                  max: 15,
                  onChanged: (v) => _updateAssumptions(a.copyWith(salaryGrowthPct: v)),
                ),
                _assumptionSlider(
                  label: 'Retirement Duration (years)',
                  value: a.retirementDurationYears.toDouble(),
                  min: 10,
                  max: 40,
                  onChanged: (v) => _updateAssumptions(a.copyWith(retirementDurationYears: v.round())),
                ),
                _assumptionSlider(
                  label: 'Retirement Age',
                  value: (a.retirementAgeGoalOverride ?? _profile?.retirementAgeGoal ?? 60).toDouble(),
                  min: 45,
                  max: 70,
                  onChanged: (v) => _updateAssumptions(a.copyWith(retirementAgeGoalOverride: v.round())),
                ),
                _assumptionTextField(
                  label: 'Monthly Contribution (₹)',
                  controller: _monthlyContributionCtrl,
                  onSubmitted: (txt) {
                    final parsed = double.tryParse(txt) ?? a.monthlyContribution;
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
    return _customProjections ?? _projections ?? _calcProjections(_safeProfile(), _assumptions);
  }

  void _updateAssumptions(RetirementAssumptions a) {
    setState(() {
      _assumptions = a;
      _customProjections = _calcProjections(_safeProfile(), _assumptions);
    });
  }

  // Removed manual save of assumptions; values are loaded from Firestore when available.

  RetirementProjections _calcProjections(RetirementProfile p, RetirementAssumptions a) {
    final int goalAge = a.retirementAgeGoalOverride ?? p.retirementAgeGoal;
    final int yearsToRetirement = (goalAge - p.age).clamp(0, 100);
    final double r = (a.expectedReturnPct - a.inflationPct) / 100.0;
    final double g = a.salaryGrowthPct / 100.0;

    // Expense at retirement (inflation-adjusted)
    final double annualExpenseAtRetirement = p.monthlyExpenses * 12 * math.pow(1 + a.inflationPct / 100.0, yearsToRetirement).toDouble();

    // Required corpus as PV of an annuity over retirementDurationYears at real return r
    final int m = a.retirementDurationYears;
    double requiredCorpus;
    if (r <= 0.000001) {
      requiredCorpus = annualExpenseAtRetirement * m;
    } else {
      requiredCorpus = annualExpenseAtRetirement * (1 - math.pow(1 + r, -m)) / r;
    }

    // Projected savings
    final double currentFV = p.currentSavings * math.pow(1 + r, yearsToRetirement).toDouble();
    final double C = a.monthlyContribution * 12;
    double contribFV;
    if ((r - g).abs() < 1e-9) {
      contribFV = C * yearsToRetirement * math.pow(1 + r, yearsToRetirement - 1).toDouble();
    } else {
      contribFV = C * (math.pow(1 + r, yearsToRetirement) - math.pow(1 + g, yearsToRetirement)) / (r - g);
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

  RetirementProfile _safeProfile() {
    return _profile ?? RetirementProfile(
      age: 30,
      retirementAgeGoal: 60,
      income: 800000,
      monthlyExpenses: 40000,
      currentSavings: 300000,
      riskLevel: 'moderate',
    );
  }

  void _updateProfile({double? income, double? currentSavings}) {
    final p = _safeProfile();
    final updated = RetirementProfile(
      age: p.age,
      retirementAgeGoal: p.retirementAgeGoal,
      income: income ?? p.income,
      monthlyExpenses: p.monthlyExpenses,
      currentSavings: currentSavings ?? p.currentSavings,
      riskLevel: p.riskLevel,
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
            const Text('Adjust Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      final parsed = double.tryParse(v.replaceAll(',', '').trim());
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
                      final parsed = double.tryParse(v.replaceAll(',', '').trim());
                      if (parsed != null) {
                        _updateProfile(currentSavings: parsed);
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final inc = double.tryParse(_incomeCtrl.text.replaceAll(',', '').trim());
                    final sav = double.tryParse(_currentSavingsCtrl.text.replaceAll(',', '').trim());
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
}