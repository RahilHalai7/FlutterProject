import 'package:flutter/material.dart';

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key});

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  final TextEditingController _amountCtrl = TextEditingController(text: '500000');
  final TextEditingController _rateCtrl = TextEditingController(text: '10');
  final TextEditingController _monthsCtrl = TextEditingController(text: '60');
  final TextEditingController _prepayCtrl = TextEditingController(text: '0');

  double? emi;
  double? totalInterest;
  double? totalPayment;
  int? effectiveMonths;
  List<_EmiMonth> schedule = [];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _monthsCtrl.dispose();
    _prepayCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final double principal = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final double annualRate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final int months = int.tryParse(_monthsCtrl.text.trim()) ?? 0;
    final double extraPrepay = double.tryParse(_prepayCtrl.text.trim()) ?? 0;

    if (principal <= 0 || annualRate <= 0 || months <= 0) {
      setState(() {
        emi = null;
        totalInterest = null;
        totalPayment = null;
        effectiveMonths = null;
        schedule = [];
      });
      return;
    }

    final double r = annualRate / 12 / 100; // monthly interest rate
    final double factor = (1 + r);
    final double pow = factor == 0 ? 0 : _pow(factor, months);
    final double baseEmi = principal * r * pow / (pow - 1);

    if (extraPrepay <= 0) {
      final double totalPay = baseEmi * months;
      final double interest = totalPay - principal;
      final List<_EmiMonth> sched = _buildSchedule(principal, r, baseEmi, months, 0);
      setState(() {
        emi = _round(baseEmi);
        totalInterest = _round(interest);
        totalPayment = _round(totalPay);
        effectiveMonths = months;
        schedule = sched;
      });
    } else {
      // Simulate month-by-month with extra prepayment applied each month
      double bal = principal;
      int m = 0;
      double interestAcc = 0;
      final List<_EmiMonth> sched = [];
      while (bal > 0 && m < 6000) { // hard cap for safety
        m += 1;
        final double interest = bal * r;
        final double principalPaid = baseEmi - interest;
        double totalPaidThisMonth = principalPaid + interest + extraPrepay;
        double newBal = bal - principalPaid - extraPrepay;
        if (newBal < 0) {
          totalPaidThisMonth += newBal; // reduce last payment if overshoot
          newBal = 0;
        }
        sched.add(_EmiMonth(
          month: m,
          interest: interest,
          principal: principalPaid + extraPrepay,
          balance: newBal,
        ));
        interestAcc += interest;
        bal = newBal;
      }
      final double totalPay = baseEmi * m + extraPrepay * m;
      setState(() {
        emi = _round(baseEmi);
        totalInterest = _round(interestAcc);
        totalPayment = _round(totalPay);
        effectiveMonths = m;
        schedule = sched;
      });
    }
  }

  double _pow(double a, int n) {
    double res = 1.0;
    for (int i = 0; i < n; i++) {
      res *= a;
    }
    return res;
  }

  double _round(double v) => double.parse(v.toStringAsFixed(2));

  List<_EmiMonth> _buildSchedule(double principal, double r, double emi, int months, double extra) {
    double bal = principal;
    final List<_EmiMonth> sched = [];
    for (int m = 1; m <= months; m++) {
      final double interest = bal * r;
      final double principalPaid = emi - interest + extra;
      bal = bal - (emi - interest) - extra;
      if (bal < 0) bal = 0;
      sched.add(_EmiMonth(
        month: m,
        interest: interest,
        principal: emi - interest + extra,
        balance: bal,
      ));
      if (bal <= 0) break;
    }
    return sched;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMI Calculator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loan Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _numberField(_amountCtrl, 'Loan Amount (₹)', prefix: '₹'),
            const SizedBox(height: 12),
            _numberField(_rateCtrl, 'Annual Interest Rate (%)', suffix: '%'),
            const SizedBox(height: 12),
            _numberField(_monthsCtrl, 'Tenure (months)'),
            const SizedBox(height: 12),
            _numberField(_prepayCtrl, 'Extra Monthly Prepayment (₹)', prefix: '₹'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _calculate,
                child: const Text('Calculate EMI'),
              ),
            ),
            const SizedBox(height: 16),
            if (emi != null) _resultsCard(),
            const SizedBox(height: 8),
            if (schedule.isNotEmpty) _schedulePreview(),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController ctrl, String label, {String? prefix, String? suffix}) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _resultsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _statRow('Monthly EMI', '₹${emi!.toStringAsFixed(2)}'),
            _statRow('Total Interest', '₹${totalInterest!.toStringAsFixed(2)}'),
            _statRow('Total Payment', '₹${totalPayment!.toStringAsFixed(2)}'),
            _statRow('Effective Tenure', '${effectiveMonths} months'),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _schedulePreview() {
    final int count = schedule.length < 12 ? schedule.length : 12;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Amortization (first 12 months)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (int i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Month ${schedule[i].month}'),
                    Text('Interest: ₹${schedule[i].interest.toStringAsFixed(0)}'),
                    Text('Principal: ₹${schedule[i].principal.toStringAsFixed(0)}'),
                    Text('Bal: ₹${schedule[i].balance.toStringAsFixed(0)}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmiMonth {
  final int month;
  final double interest;
  final double principal;
  final double balance;
  _EmiMonth({required this.month, required this.interest, required this.principal, required this.balance});
}