import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // Import to access the API key (geminiApiKey)
import 'package:intl/intl.dart';

class NLPAssistantScreen extends StatefulWidget {
  const NLPAssistantScreen({super.key});

  @override
  State<NLPAssistantScreen> createState() => _NLPAssistantScreenState();
}

class _NLPAssistantScreenState extends State<NLPAssistantScreen> {
  final TextEditingController _queryController = TextEditingController();
  String _response = '';
  bool _isLoading = false;
  bool _isFetchingHabits = false;
  String? _spendingSummaryCache;

  late final GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: geminiApiKey);
    // Optionally prefetch spending summary at startup:
    _prefetchSpendingSummary();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _prefetchSpendingSummary() async {
    setState(() => _isFetchingHabits = true);
    try {
      final s = await _fetchAndSummarizeSpending();
      setState(() => _spendingSummaryCache = s);
    } catch (e) {
      // keep silent; we'll fetch on demand
    } finally {
      setState(() => _isFetchingHabits = false);
    }
  }

  /// Fetches user's spending from Firestore and returns a human-readable summary.
  /// Expected Firestore path: users/{uid}/spending
  /// Each spending document should have at least:
  ///   - amount: number
  ///   - category: string
  ///   - date: Timestamp or ISO string
  Future<String?> _fetchAndSummarizeSpending() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // No authenticated user available
      return null;
    }

    final uid = user.uid;
    final colRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('spending');

    final snapshot = await colRef.get();
    if (snapshot.docs.isEmpty) return null;

    // aggregate by category and by month
    final Map<String, double> byCategory = {};
    final Map<String, double> byMonth = {};
    double total = 0.0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      // safe reads with fallbacks
      dynamic amtRaw = data['amount'];
      double amount;
      if (amtRaw is num) {
        amount = amtRaw.toDouble();
      } else if (amtRaw is String) {
        amount = double.tryParse(amtRaw) ?? 0.0;
      } else {
        amount = 0.0;
      }

      final category = (data['category'] ?? 'Uncategorized').toString();
      DateTime date;
      final rawDate = data['date'];
      if (rawDate is Timestamp) {
        date = rawDate.toDate();
      } else if (rawDate is String) {
        date = DateTime.tryParse(rawDate) ?? DateTime.now();
      } else {
        date = DateTime.now();
      }

      final monthKey = DateFormat('yyyy-MM').format(date);

      byCategory[category] = (byCategory[category] ?? 0.0) + amount;
      byMonth[monthKey] = (byMonth[monthKey] ?? 0.0) + amount;
      total += amount;
    }

    // compute top categories
    final sortedCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(5).toList();

    // monthly average (over months present)
    final monthsCount = byMonth.length;
    final averageMonthly = monthsCount > 0 ? (total / monthsCount) : 0.0;

    // recent 3 months total if available
    final recentMonths = byMonth.keys.toList()..sort(); // ascending yyyy-MM
    final last3 = recentMonths.reversed.take(3).toList();
    double last3Total = 0.0;
    for (final m in last3) {
      last3Total += (byMonth[m] ?? 0.0);
    }

    // Build summary string
    final buffer = StringBuffer();
    buffer.writeln(
      'Spending Summary (based on ${snapshot.docs.length} transactions):',
    );
    buffer.writeln('- Total spent recorded: ₹${total.toStringAsFixed(2)}');
    buffer.writeln(
      '- Months observed: $monthsCount, Average monthly spend: ₹${averageMonthly.toStringAsFixed(2)}',
    );
    if (last3.isNotEmpty) {
      buffer.writeln(
        '- Last ${last3.length} months total (${last3.join(', ')}): ₹${last3Total.toStringAsFixed(2)}',
      );
    }

    buffer.writeln('- Top categories:');
    for (final e in topCategories) {
      final percent = total > 0 ? (e.value / total * 100) : 0.0;
      buffer.writeln(
        '  • ${e.key}: ₹${e.value.toStringAsFixed(2)} (${percent.toStringAsFixed(1)}%)',
      );
    }

    buffer.writeln(
      '- Example monthly breakdown (YYYY-MM: total): ${byMonth.entries.map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}').join('; ')}',
    );

    // Return the summary
    return buffer.toString();
  }

  Future<void> _processQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      // Ensure we have spending summary (use cache if already fetched)
      String? spendingSummary = _spendingSummaryCache;
      if (spendingSummary == null) {
        setState(() => _isFetchingHabits = true);
        try {
          spendingSummary = await _fetchAndSummarizeSpending();
          _spendingSummaryCache = spendingSummary;
        } catch (e) {
          spendingSummary = null; // proceed without it
        } finally {
          setState(() => _isFetchingHabits = false);
        }
      }

      // Prepare the prompt with financial NLP context and user's spending summary
      final promptBuffer = StringBuffer();
      promptBuffer.writeln(
        'You are a financial NLP assistant that specializes in understanding and answering natural language queries about personal finance. Your expertise includes:\n\n1. Analyzing financial statements and metrics\n2. Explaining financial concepts in simple terms\n3. Providing educational information about investing, saving, and budgeting\n4. Helping users understand financial terminology\n5. Offering general financial planning guidance\n\nRespond with clear, structured information that directly addresses the user\'s query. Format your response using markdown for better readability.\n',
      );

      if (spendingSummary != null) {
        promptBuffer.writeln(
          'User spending summary (from their transaction history):\n',
        );
        promptBuffer.writeln('"""\n$spendingSummary\n"""');
        promptBuffer.writeln(
          'When giving recommendations, use the spending summary above. Provide specific, actionable suggestions (e.g., adjust budgets by category, reduce recurring subscriptions, save X% monthly) and mention any assumptions you make.\n',
        );
      } else {
        promptBuffer.writeln(
          'No spending data available or not authenticated. Provide general actionable suggestions and prompt user for permission to connect their transaction data if needed.\n',
        );
      }

      promptBuffer.writeln('User query: $query');

      final content = [Content.text(promptBuffer.toString())];
      final response = await _model.generateContent(content);
      final responseText =
          response.text ?? 'Sorry, I couldn\'t generate a response.';

      setState(() {
        _response = responseText;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildQueryInput() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ask a Financial Question',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: 'E.g., "How can I reduce my monthly spending?"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _processQuery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Submit Query'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    setState(() => _isFetchingHabits = true);
                    final s = await _fetchAndSummarizeSpending();
                    setState(() {
                      _spendingSummaryCache = s;
                      _isFetchingHabits = false;
                    });
                    final snack = s == null
                        ? 'No spending data found / not signed in.'
                        : 'Spending summary refreshed.';
                    if (mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(snack)));
                  },
                  child: const Text('Refresh Spending Data'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isFetchingHabits)
              const Text(
                'Fetching spending data...',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            if (!_isFetchingHabits && _spendingSummaryCache != null)
              Text(
                'Spending data loaded (used in recommendations).',
                style: TextStyle(fontSize: 12, color: Colors.green[700]),
              ),
            if (!_isFetchingHabits && _spendingSummaryCache == null)
              Text(
                'No spending data loaded.',
                style: TextStyle(fontSize: 12, color: Colors.red[700]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialInstructions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology, size: 80, color: Colors.green[200]),
          const SizedBox(height: 20),
          const Text(
            'Ask me anything about finance',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'I can help with budgeting, investments, financial terms, and more! If you sign in and store transactions in Firestore (users/{uid}/spending), I will use your spending data to give personalized advice.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseArea() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber[700]),
                const SizedBox(width: 8),
                const Text(
                  'Response',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 100,
                  maxHeight: double.infinity,
                ),
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: _response,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      h1: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      p: const TextStyle(fontSize: 14),
                      listBullet: TextStyle(color: Colors.green[700]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Query Assistant',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildQueryInput(),
              const SizedBox(height: 20),
              _isLoading
                  ? const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Expanded(
                      child: _response.isEmpty
                          ? _buildInitialInstructions()
                          : _buildResponseArea(),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
