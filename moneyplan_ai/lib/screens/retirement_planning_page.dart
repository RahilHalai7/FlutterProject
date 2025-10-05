import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../services/retirement_service.dart';

class RetirementPlanningPage extends StatefulWidget {
  const RetirementPlanningPage({super.key});

  @override
  State<RetirementPlanningPage> createState() => _RetirementPlanningPageState();
}

class _RetirementPlanningPageState extends State<RetirementPlanningPage> {
  final RetirementService _service = RetirementService();

  RetirementProfile? _profile;
  RetirementProjections? _projections;
  List<RetirementRecommendation> _recs = [];
  bool _loading = true;
  bool _error = false;

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
      final p = await _service.fetchProfile();
      final pr = await _service.fetchProjections();
      final recs = await _service.fetchRecommendations();
      setState(() {
        _profile = p;
        _projections = pr;
        _recs = recs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retirement Planning')),
      body: _loading
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
                          _buildRecommendations(),
                        ],
                      ),
                    );
                  },
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
    final p = _profile!;
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
    final pr = _projections!;
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
    final pr = _projections!;
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

  Widget _buildRecommendations() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recommendations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._recs.map((r) => _recTile(r)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _recTile(RetirementRecommendation r) {
    final riskColor = {
      'low': Colors.green,
      'moderate': Colors.orange,
      'high': Colors.red,
    }[r.risk] ?? Colors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${r.category} • Expected: ${r.expectedReturn}')
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(r.risk, style: TextStyle(color: riskColor)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () async {
              final ok = await _service.planWithStrategy(r);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(ok ? 'Strategy Saved' : 'Action Failed'),
                  content: Text(ok
                      ? 'Added ${r.title} to your retirement strategy.'
                      : 'Could not update strategy. Please try again.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                  ],
                ),
              );
            },
            child: const Text('Plan with this'),
          )
        ],
      ),
    );
  }

  String _fmt(double v) {
    // Simple formatter for big numbers
    if (v >= 1e7) return '${(v / 1e7).toStringAsFixed(2)} Cr';
    if (v >= 1e5) return '${(v / 1e5).toStringAsFixed(2)} L';
    return v.toStringAsFixed(0);
  }
}