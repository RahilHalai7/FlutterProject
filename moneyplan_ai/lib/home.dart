import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/live_rates_service.dart';

// Global Floating Live Rates Widget
class FloatingLiveRates extends StatefulWidget {
  const FloatingLiveRates({super.key});

  @override
  State<FloatingLiveRates> createState() => _FloatingLiveRatesState();
}

class _FloatingLiveRatesState extends State<FloatingLiveRates>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      bottom: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, (1 - _slideAnimation.value) * 200),
                child: Opacity(
                  opacity: _slideAnimation.value,
                  child: _isExpanded
                      ? Container(
                          width: 280,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: FutureBuilder<Map<String, dynamic>>(
                            future: LiveRatesService().getLiveRates(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF8B5CF6),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }

                              final rates = snapshot.data ?? {};
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.trending_up,
                                        color: Color(0xFF8B5CF6),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "Live Rates",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildCompactRateItem(
                                    "Gold (10g)",
                                    "₹${_formatPrice(rates['gold']?['price']?.toDouble() ?? 63250.0)}",
                                    rates['gold']?['changePercent']?.toDouble() ?? 0.45,
                                    Colors.amber,
                                    Icons.circle,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCompactRateItem(
                                    "Silver (10g)",
                                    "₹${_formatPrice(rates['silver']?['price']?.toDouble() ?? 785.50)}",
                                    rates['silver']?['changePercent']?.toDouble() ?? -0.32,
                                    Colors.grey.shade300,
                                    Icons.circle,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCompactRateItem(
                                    "Bitcoin (1 BTC)",
                                    "₹${_formatPrice(rates['bitcoin']?['price']?.toDouble() ?? 4125000.0)}",
                                    rates['bitcoin']?['changePercent']?.toDouble() ?? 1.25,
                                    Colors.orange,
                                    Icons.currency_bitcoin,
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _toggleExpanded,
              backgroundColor: Colors.transparent,
              elevation: 0,
              heroTag: "floating_rates",
              child: Icon(
                _isExpanded ? Icons.close : Icons.show_chart,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRateItem(
    String name,
    String price,
    double changePercent,
    Color color,
    IconData icon,
  ) {
    final isPositive = changePercent >= 0;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              color: isPositive ? Colors.green : Colors.red,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              "${changePercent.toStringAsFixed(2)}%",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    if (price >= 10000000) {
      return "${(price / 10000000).toStringAsFixed(2)}Cr";
    } else if (price >= 100000) {
      return "${(price / 100000).toStringAsFixed(2)}L";
    } else if (price >= 1000) {
      return "${(price / 1000).toStringAsFixed(2)}K";
    } else {
      return price.toStringAsFixed(2);
    }
  }
}

// Global Chatbot Widget that can be used across all pages
class GlobalChatbotAssistant extends StatefulWidget {
  const GlobalChatbotAssistant({super.key});

  @override
  State<GlobalChatbotAssistant> createState() => _GlobalChatbotAssistantState();
}

class _GlobalChatbotAssistantState extends State<GlobalChatbotAssistant>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: FloatingActionButton.large(
                onPressed: () => _showChatbotOptions(context),
                backgroundColor: Colors.transparent,
                elevation: 0,
                heroTag: "global_chatbot",
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChatbotOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '🤖 AI Financial Assistant',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildChatbotOption(
                    context,
                    icon: Icons.chat_bubble_rounded,
                    title: 'FinAI Chatbot',
                    subtitle: 'Get personalized financial advice',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/chatbot');
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildChatbotOption(
                    context,
                    icon: Icons.psychology,
                    title: 'Smart Query Assistant',
                    subtitle: 'Ask questions in natural language',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/nlpAssistant');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildChatbotOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, color: color, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool hasUserData = false; // This would come from your data source

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(
        0xFF0A0E27,
      ), // Deep navy background like login
      appBar: AppBar(
        title: const Text(
          "MoneyPlanAI",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white, // White text like login
          ),
        ),
        backgroundColor: Colors.transparent, // Transparent to show gradient
        elevation: 0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // White drawer icon
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    0.1,
                  ), // Glassmorphism effect like login
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                ), // White icons
              ),
              onPressed: () => Navigator.pushNamed(context, '/profile'),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings, color: Colors.white),
              ),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.red),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ),
        ],
      ),
      drawer: _buildSidebar(context),
      body: Container(
        // Same gradient background as login screen
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E27), // Deep navy blue
              Color(0xFF1A1B3A), // Dark navy
              Color(0xFF2E1065), // Deep purple
              Color(0xFF4C1D95), // Rich purple
              Color(0xFF5B21B6), // Vibrant purple
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Welcome Section - updated with glassmorphism effect
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.1,
                    ), // Glassmorphism like login
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF8B5CF6,
                          ).withOpacity(0.2), // Purple accent like login
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.waving_hand,
                          color: Color(0xFF8B5CF6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Welcome back!",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white, // White text like login
                              ),
                            ),
                            Text(
                              user?.displayName ?? "User",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(
                                  0.8,
                                ), // Semi-transparent white
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _buildIncomeCategorizationPanel(),

                const SizedBox(height: 24),

                _buildEnhancedFeatureCard(
                  title: "Credit Score",
                  subtitle: "Check your CIBIL score with Surepass API",
                  icon: Icons.credit_score,
                  color: Colors.green,
                  onTap: () => Navigator.pushNamed(context, '/cibil'),
                ),
                const SizedBox(height: 24),
                _buildEnhancedFeatureCard(
                  title: "Investment Portfolio",
                  subtitle: "Check out the latest trends where you can invest",
                  icon: Icons.trending_up,
                  color: const Color(0xFF8B5CF6), // Purple like login
                  onTap: () => Navigator.pushNamed(context, '/goals'),
                ),
                const SizedBox(height: 24),
                _buildEnhancedFeatureCard(
                  title: "Retirement Planning",
                  subtitle: "Enjoy your retirement with our retirement plans",
                  icon: Icons.elderly,
                  color: Colors.orange,
                  onTap: () => Navigator.pushNamed(context, '/goals'),
                ),
                const SizedBox(height: 24),
                _buildEnhancedFeatureCard(
                  title: "Goal-Based Planning",
                  subtitle: "Plan your income wisely",
                  icon: Icons.flag,
                  color: Colors.red,
                  onTap: () => Navigator.pushNamed(context, '/goals'),
                ),
                const SizedBox(height: 24),
                _buildEnhancedFeatureCard(
                  title: "Loan Eligibility Checker",
                  subtitle: "Check your loan eligibility instantly",
                  icon: Icons.account_balance,
                  color: Colors.teal,
                  onTap: () => Navigator.pushNamed(context, '/loan'),
                ),

                const SizedBox(height: 100), // leave room for chatbot button and floating rates
              ],
            ),

            const GlobalChatbotAssistant(),
            const FloatingLiveRates(),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeCategorizationPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Glassmorphism effect
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF8B5CF6,
                    ).withOpacity(0.2), // Purple accent
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.pie_chart,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Income Overview",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White text
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            child: hasUserData ? _buildIncomeData() : _buildNoDataState(),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeData() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildIncomeCategory("Salary", "₹45,000", Colors.green),
          _buildIncomeCategory("Freelance", "₹8,000", Colors.orange),
          _buildIncomeCategory(
            "Investments",
            "₹3,500",
            const Color(0xFF8B5CF6),
          ),
          _buildIncomeCategory("Others", "₹1,200", Colors.teal),
        ],
      ),
    );
  }

  Widget _buildIncomeCategory(String category, String amount, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), // Subtle glassmorphism
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getCategoryIcon(category), color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            category,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9), // White text
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'salary':
        return Icons.work;
      case 'freelance':
        return Icons.laptop;
      case 'investments':
        return Icons.trending_up;
      case 'others':
        return Icons.more_horiz;
      default:
        return Icons.attach_money;
    }
  }

  Widget _buildNoDataState() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), // Subtle glassmorphism
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_chart_outlined,
            size: 32,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 8),
          Text(
            "No income data available",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8), // White text
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/incomeData'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Add Income Data"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6), // Purple like login
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGridCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Glassmorphism
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White text
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Glassmorphism
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // White text
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(
                            0.8,
                          ), // Semi-transparent white
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveRatesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Glassmorphism
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Live Market Rates",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  "Live",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            child: FutureBuilder<Map<String, dynamic>>(
              future: LiveRatesService().getLiveRates(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  );
                }

                final rates = snapshot.data ?? {};
                return Column(
                  children: [
                    _buildRateCard(
                      "Gold",
                      "\$${rates['gold']?['price']?.toStringAsFixed(2) ?? '2000.50'}",
                      rates['gold']?['change']?.toDouble() ?? 15.30,
                      rates['gold']?['changePercent']?.toDouble() ?? 0.77,
                      Icons.circle,
                      Colors.amber,
                    ),
                    const SizedBox(height: 12),
                    _buildRateCard(
                      "Silver",
                      "\$${rates['silver']?['price']?.toStringAsFixed(2) ?? '25.45'}",
                      rates['silver']?['change']?.toDouble() ?? -0.25,
                      rates['silver']?['changePercent']?.toDouble() ?? -0.97,
                      Icons.circle,
                      Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    _buildRateCard(
                      "Bitcoin",
                      "\$${rates['bitcoin']?['price']?.toStringAsFixed(2) ?? '45250.75'}",
                      rates['bitcoin']?['change']?.toDouble() ?? 1250.50,
                      rates['bitcoin']?['changePercent']?.toDouble() ?? 2.84,
                      Icons.currency_bitcoin,
                      Colors.orange,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateCard(
    String name,
    String price,
    double change,
    double changePercent,
    IconData icon,
    Color color,
  ) {
    final isPositive = change >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${changePercent.toStringAsFixed(2)}%",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              Text(
                "${isPositive ? '+' : ''}${change.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 11,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(
        0xFF1A1B3A,
      ), // Dark background like login gradient
      child: Column(
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF8B5CF6),
                  Color(0xFF3B82F6),
                ], // Same gradient as login buttons
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 50,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'MoneyPlanAI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Your AI Financial Assistant',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Container(
              color: const Color(0xFF1A1B3A), // Dark background
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.score,
                    title: 'Credit Score Prediction',
                    onTap: () => Navigator.pushNamed(context, '/creditScore'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.trending_up,
                    title: 'Investment Portfolio',
                    onTap: () => Navigator.pushNamed(context, '/investment'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.elderly,
                    title: 'Retirement Planning',
                    onTap: () => Navigator.pushNamed(context, '/retirement'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.flag,
                    title: 'Goal-Based Planning',
                    onTap: () => Navigator.pushNamed(context, '/goals'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.account_balance,
                    title: 'Loan Eligibility',
                    onTap: () => Navigator.pushNamed(context, '/loan'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Divider(color: Colors.white.withOpacity(0.3)),
                  ),
                  _buildDrawerItem(
                    icon: Icons.chat,
                    title: 'FinAI Chatbot',
                    onTap: () => Navigator.pushNamed(context, '/chatbot'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.question_answer,
                    title: 'Query Assistant',
                    onTap: () => Navigator.pushNamed(context, '/nlpAssistant'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFF8B5CF6),
        ), // Purple accent like login
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white, // White text
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}