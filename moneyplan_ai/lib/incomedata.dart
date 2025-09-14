import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IncomeDataPage extends StatefulWidget {
  const IncomeDataPage({super.key});

  @override
  State<IncomeDataPage> createState() => _IncomeDataPageState();
}

class _IncomeDataPageState extends State<IncomeDataPage>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _customCategoryController = TextEditingController();

  late TabController _tabController;

  String _type = 'expense';
  String _category = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Categories for different transaction types
  final Map<String, List<Map<String, dynamic>>> _categories = {
    'expense': [
      {'name': 'Food', 'icon': Icons.restaurant, 'color': Colors.orange},
      {'name': 'Rent', 'icon': Icons.home, 'color': Colors.blue},
      {'name': 'Shopping', 'icon': Icons.shopping_bag, 'color': Colors.pink},
      {
        'name': 'Groceries',
        'icon': Icons.local_grocery_store,
        'color': Colors.green,
      },
      {'name': 'Social Life', 'icon': Icons.people, 'color': Colors.purple},
      {
        'name': 'Transportation',
        'icon': Icons.directions_car,
        'color': Colors.indigo,
      },
      {'name': 'Healthcare', 'icon': Icons.local_hospital, 'color': Colors.red},
      {'name': 'Entertainment', 'icon': Icons.movie, 'color': Colors.cyan},
      {
        'name': 'Utilities',
        'icon': Icons.electrical_services,
        'color': Colors.amber,
      },
      {'name': 'Other', 'icon': Icons.more_horiz, 'color': Colors.grey},
    ],
    'income': [
      {'name': 'Salary', 'icon': Icons.work, 'color': Colors.green},
      {'name': 'Freelance', 'icon': Icons.laptop, 'color': Colors.blue},
      {'name': 'Investment', 'icon': Icons.trending_up, 'color': Colors.purple},
      {'name': 'Business', 'icon': Icons.business, 'color': Colors.orange},
      {'name': 'Bonus', 'icon': Icons.card_giftcard, 'color': Colors.pink},
      {'name': 'Other', 'icon': Icons.more_horiz, 'color': Colors.grey},
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _customCategoryController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addTransaction() async {
    if (_amountController.text.trim().isEmpty) {
      _showSnackBar('Please enter an amount', Colors.red);
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', Colors.red);
      return;
    }

    if (_category == 'Other' && _customCategoryController.text.trim().isEmpty) {
      _showSnackBar('Please specify the category', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final category = _category == 'Other'
          ? _customCategoryController.text.trim()
          : _category;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .add({
            'amount': amount,
            'type': _type,
            'category': category,
            'note': _noteController.text.trim(),
            'date': Timestamp.fromDate(_selectedDate),
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Clear inputs after saving
      _amountController.clear();
      _noteController.clear();
      _customCategoryController.clear();
      setState(() {
        _type = 'expense';
        _category = 'Food';
        _selectedDate = DateTime.now();
        _isLoading = false;
      });

      Navigator.pop(context);
      _showSnackBar('Transaction added successfully!', Colors.green);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error adding transaction: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B5CF6),
              surface: Color(0xFF1A1B3A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showAddTransactionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          // Constrain the height to prevent overflow
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1B3A), Color(0xFF2E1065), Color(0xFF4C1D95)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fixed Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Transaction',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 20,
                    right: 20,
                    top: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount Field
                      _buildModalField(
                        label: 'Amount (₹)',
                        controller: _amountController,
                        icon: Icons.currency_rupee,
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 16),

                      // Type Selection
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _type == 'expense'
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: _type == 'expense'
                                      ? Colors.red
                                      : Colors.green,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _type,
                                  decoration: const InputDecoration(
                                    labelText: 'Transaction Type',
                                    labelStyle: TextStyle(
                                      color: Colors.white70,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  dropdownColor: const Color(0xFF1A1B3A),
                                  style: const TextStyle(color: Colors.white),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'expense',
                                      child: Text('Expense'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'income',
                                      child: Text('Income'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setModalState(() {
                                      _type = value!;
                                      _category =
                                          _categories[_type]![0]['name'];
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Category Selection
                      Text(
                        'Category',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Reduced height for category grid
                      SizedBox(
                        height: 100,
                        child: GridView.builder(
                          scrollDirection: Axis.horizontal,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                          itemCount: _categories[_type]!.length,
                          itemBuilder: (context, index) {
                            final category = _categories[_type]![index];
                            final isSelected = _category == category['name'];

                            return GestureDetector(
                              onTap: () => setModalState(
                                () => _category = category['name'],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? category['color'].withOpacity(0.3)
                                      : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? category['color']
                                        : Colors.white.withOpacity(0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      category['icon'],
                                      color: category['color'],
                                      size: 22,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      category['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Custom Category Field
                      if (_category == 'Other') ...[
                        const SizedBox(height: 16),
                        _buildModalField(
                          label: 'Specify Category',
                          controller: _customCategoryController,
                          icon: Icons.category,
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Date Selection
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFF8B5CF6),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white70,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Note Field - Reduced max lines
                      _buildModalField(
                        label: 'Note (Optional)',
                        controller: _noteController,
                        icon: Icons.note,
                        maxLines: 2,
                      ),

                      const SizedBox(height: 24),

                      // Save Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addTransaction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Transaction',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> data, String docId) {
    final isIncome = data['type'] == 'income';
    final amount = data['amount'] as num;
    final category = data['category'] as String;
    final note = data['note'] as String? ?? '';
    final date = (data['date'] as Timestamp).toDate();

    final categoryData = _categories[data['type']]?.firstWhere(
      (cat) => cat['name'] == category,
      orElse: () => {
        'name': category,
        'icon': Icons.help_outline,
        'color': Colors.grey,
      },
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (categoryData?['color'] ?? Colors.grey).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            categoryData?['icon'] ?? Icons.help_outline,
            color: categoryData?['color'] ?? Colors.grey,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                note,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          color: const Color(0xFF1A1B3A),
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.white)),
                ],
              ),
              onTap: () => _deleteTransaction(docId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String category, double amount) {
    // Find category data for icon and color
    Map<String, dynamic>? categoryData;
    for (final typeCategories in _categories.values) {
      final found = typeCategories.firstWhere(
        (cat) => cat['name'] == category,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        categoryData = found;
        break;
      }
    }

    categoryData ??= {
      'name': category,
      'icon': Icons.help_outline,
      'color': Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: categoryData['color'].withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              categoryData['icon'],
              color: categoryData['color'],
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: categoryData['color'],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(String docId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(docId)
          .delete();

      _showSnackBar('Transaction deleted', Colors.orange);
    } catch (e) {
      _showSnackBar('Error deleting transaction', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text(
          "Income & Expenditure",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF8B5CF6),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'All Transactions'),
            Tab(text: 'Summary'),
          ],
        ),
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
        child: uid == null
            ? const Center(
                child: Text(
                  "Please log in to view transactions",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  // All Transactions Tab
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('transactions')
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF8B5CF6),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  size: 64,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No transactions yet",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Tap the + button to add your first transaction",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final transactions = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final doc = transactions[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildTransactionCard(data, doc.id);
                        },
                      );
                    },
                  ),

                  // Summary Tab
                  _buildSummaryTab(uid),
                ],
              ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddTransactionSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildSummaryTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No data available",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        final transactions = snapshot.data!.docs;
        double totalIncome = 0;
        double totalExpense = 0;
        Map<String, double> categoryTotals = {};

        for (final doc in transactions) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num).toDouble();
          final type = data['type'] as String;
          final category = data['category'] as String;

          if (type == 'income') {
            totalIncome += amount;
          } else {
            totalExpense += amount;
          }

          categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
        }

        final balance = totalIncome - totalExpense;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance Overview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Current Balance',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: balance >= 0 ? Colors.green : Colors.red,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Income/Expense Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.arrow_downward, color: Colors.green),
                        const SizedBox(height: 8),
                        const Text(
                          'Income',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalIncome.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.arrow_upward, color: Colors.red),
                        const SizedBox(height: 8),
                        const Text(
                          'Expenses',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalExpense.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Category Breakdown
            if (categoryTotals.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.2),
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
                          'Category Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...categoryTotals.entries
                        .map(
                          (entry) => _buildCategoryItem(entry.key, entry.value),
                        )
                        .toList(),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
