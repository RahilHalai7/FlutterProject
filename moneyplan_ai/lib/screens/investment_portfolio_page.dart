import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';

import '../services/portfolio_service.dart';

class InvestmentPortfolioPage extends StatefulWidget {
  const InvestmentPortfolioPage({super.key});

  @override
  State<InvestmentPortfolioPage> createState() => _InvestmentPortfolioPageState();
}

class _InvestmentPortfolioPageState extends State<InvestmentPortfolioPage> {
  late Future<UserProfile> _profileFuture;
  late Future<List<Opportunity>> _oppsFuture;

  // simple in-memory chart data
  final Map<String, double> _allocations = {};

  @override
  void initState() {
    super.initState();
    _profileFuture = PortfolioService.fetchUserProfile();
    _oppsFuture = PortfolioService.fetchOpportunities();
  }

  void _addToPortfolio(Opportunity opp, {double allocation = 10.0}) async {
    final resp = await PortfolioService.updatePortfolio(action: 'add', item: opp, allocationPercent: allocation);
    final byCategory = (resp['by_category'] as Map<dynamic, dynamic>?) ?? {};
    setState(() {
      _allocations.clear();
      byCategory.forEach((key, value) {
        _allocations[key.toString()] = (value as num).toDouble();
      });
    });
  }

  Widget _profileCard(UserProfile p) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Age: ${p.age}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 6),
              Text('Job: ${p.job}', style: const TextStyle(fontSize: 16)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Income: ₹${p.income}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Risk Level: ${p.riskLevel}', style: const TextStyle(fontSize: 16)),
            ]),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    if (_allocations.isEmpty) {
      return [
        PieChartSectionData(value: 100, title: 'No Data', color: Colors.grey.shade300, radius: 60),
      ];
    }
    final colors = [Colors.blue, Colors.orange, Colors.red, Colors.green, Colors.purple, Colors.teal];
    int i = 0;
    return _allocations.entries.map((e) {
      final section = PieChartSectionData(
        value: e.value,
        title: '${e.key}\n${e.value.toStringAsFixed(0)}%',
        color: colors[i % colors.length],
        radius: 60,
      );
      i++;
      return section;
    }).toList();
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Widget _opportunityCard(Opportunity opp) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(opp.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${opp.category} • Expected: ${opp.expectedReturn}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _riskColor(opp.risk).withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: _riskColor(opp.risk))),
                  child: Text('Risk: ${opp.risk}', style: TextStyle(color: _riskColor(opp.risk), fontWeight: FontWeight.w600)),
                ),
                ElevatedButton.icon(onPressed: () => _addToPortfolio(opp, allocation: 10.0), icon: const Icon(Icons.add), label: const Text('Add to Portfolio')),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _loadingShimmer({double height = 100}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(height: height, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text(
          'Your Investment Portfolio',
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
        child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Section 1: Profile Snapshot
            FutureBuilder<UserProfile>(
              future: _profileFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return _loadingShimmer(height: 90);
                }
                return _profileCard(snap.data!);
              },
            ),
            const SizedBox(height: 16),

            // Section 2: Portfolio Summary (Pie Chart)
            Card(
              elevation: 2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: isWide ? 240 : 200,
                  child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 40, sections: _buildSections())),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Recommended Opportunities
            const Text('Recommended Opportunities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            FutureBuilder<List<Opportunity>>(
              future: _oppsFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Column(children: [
                    _loadingShimmer(height: 120),
                    const SizedBox(height: 8),
                    _loadingShimmer(height: 120),
                    const SizedBox(height: 8),
                    _loadingShimmer(height: 120),
                  ]);
                }
                final opps = snap.data!;
                if (isWide) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 3),
                    itemCount: opps.length,
                    itemBuilder: (context, i) => _opportunityCard(opps[i]),
                  );
                }
                return Column(children: opps.map(_opportunityCard).toList());
              },
            ),
          ]),
        );
      }),
    ),
  );
}
}