import 'package:flutter/material.dart';
import '../services/ml_prediction_service.dart';
import '../services/profile_service.dart';

class LoanEligibilityScreen extends StatefulWidget {
  const LoanEligibilityScreen({super.key});

  @override
  State<LoanEligibilityScreen> createState() => _LoanEligibilityScreenState();
}

class _LoanEligibilityScreenState extends State<LoanEligibilityScreen> {
  final MLPredictionService _mlService = MLPredictionService();
  
  // Prediction state
  String? _predictionResult;
  double? _predictionProbability;
  bool _isMLAPIAvailable = false;
  Map<String, dynamic>? _modelInfo;
  
  @override
  void initState() {
    super.initState();
    _checkMLAPIStatus();
    _prefillFromProfile();
  }
  
  Future<void> _checkMLAPIStatus() async {
    try {
      final isAvailable = await _mlService.isMLAPIAvailable();
      final modelInfo = await _mlService.getMLModelInfo();
      
      setState(() {
        _isMLAPIAvailable = isAvailable;
        _modelInfo = modelInfo;
      });
    } catch (e) {
      print('Error checking ML API status: $e');
    }
  }

  Future<void> _prefillFromProfile() async {
    try {
      final p = await ProfileService.fetchBasicProfile();
      if (p != null) {
        setState(() {
          _applicantIncomeController.text =
              p.income > 0 ? p.income.toStringAsFixed(0) : '';
        });
      }
    } catch (e) {
      // silently ignore; form remains empty
    }
  }
  
  // Form controllers
  final TextEditingController _applicantIncomeController = TextEditingController();
  final TextEditingController _coapplicantIncomeController = TextEditingController();
  final TextEditingController _loanAmountController = TextEditingController();
  final TextEditingController _loanTermController = TextEditingController();
  
  // Dropdown values
  String? _selectedGender;
  String? _selectedMarried;
  String? _selectedDependents;
  String? _selectedEducation;
  String? _selectedSelfEmployed;
  String? _selectedCreditHistory;
  String? _selectedPropertyArea;
  
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text(
          'Loan Eligibility Checker',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your details to check loan eligibility',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // ML API Status Card
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isMLAPIAvailable ? Icons.check_circle : Icons.warning,
                          color: _isMLAPIAvailable ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Prediction Engine Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isMLAPIAvailable 
                          ? 'Using Random Forest ML Model'
                          : 'Using Rule-based Fallback System',
                      style: TextStyle(
                        color: _isMLAPIAvailable ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_modelInfo != null) ...[
                      const SizedBox(height: 8),
                      if (_modelInfo!['accuracy'] != null)
                        Text(
                          'Model Accuracy: ${((_modelInfo!['accuracy'] as double? ?? 0.0) * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      if (_modelInfo!['n_features'] != null)
                        Text(
                          'Features: ${_modelInfo!['n_features'] ?? 'Unknown'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Personal Information
            _buildSectionTitle('Personal Information'),
            _buildDropdownField('Gender', _selectedGender, ['Male', 'Female'], (value) {
              setState(() => _selectedGender = value);
            }),
            _buildDropdownField('Married', _selectedMarried, ['Yes', 'No'], (value) {
              setState(() => _selectedMarried = value);
            }),
            _buildDropdownField('Dependents', _selectedDependents, ['0', '1', '2', '3+'], (value) {
              setState(() => _selectedDependents = value);
            }),
            _buildDropdownField('Education', _selectedEducation, ['Graduate', 'Not Graduate'], (value) {
              setState(() => _selectedEducation = value);
            }),
            _buildDropdownField('Self Employed', _selectedSelfEmployed, ['Yes', 'No'], (value) {
              setState(() => _selectedSelfEmployed = value);
            }),
            
            const SizedBox(height: 20),
            
            // Financial Information
            _buildSectionTitle('Financial Information'),
            _buildTextField('Applicant Income (₹)', _applicantIncomeController, TextInputType.number),
            _buildTextField('Coapplicant Income (₹)', _coapplicantIncomeController, TextInputType.number),
            _buildTextField('Loan Amount (₹)', _loanAmountController, TextInputType.number),
            _buildTextField('Loan Amount Term (months)', _loanTermController, TextInputType.number),
            
            const SizedBox(height: 20),
            
            // Credit and Property Information
            _buildSectionTitle('Credit & Property Information'),
            _buildDropdownField('Credit History', _selectedCreditHistory, ['1.0', '0.0'], (value) {
              setState(() => _selectedCreditHistory = value);
            }, helper: '1.0 = Good Credit, 0.0 = Poor Credit'),
            _buildDropdownField('Property Area', _selectedPropertyArea, ['Urban', 'Semiurban', 'Rural'], (value) {
              setState(() => _selectedPropertyArea = value);
            }),
            
            const SizedBox(height: 30),
            
            // Predict Button
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _predictLoanEligibility,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.analytics),
                        const SizedBox(width: 8),
                        Text(
                          _isMLAPIAvailable 
                              ? 'Check Loan Eligibility (ML Model)'
                              : 'Check Loan Eligibility (Rule-based)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ),
              ),
            
            // Prediction Result
            if (_predictionResult != null) ...[
              const SizedBox(height: 20),
              _buildPredictionResult(),
            ],
          ],
        ),
      ),
    ),
  );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildTextField(String label, TextEditingController controller, TextInputType keyboardType) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFF8B5CF6), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
  
  Widget _buildDropdownField(String label, String? value, List<String> items, Function(String?) onChanged, {String? helper}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: value,
            style: const TextStyle(color: Colors.white),
            dropdownColor: const Color(0xFF1A1B3A),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: Color(0xFF8B5CF6), width: 2),
              ),
            ),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: onChanged,
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(helper, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
        ],
      ),
    );
  }
  
  Future<void> _predictLoanEligibility() async {
    setState(() => _isLoading = true);
    try {
      final input = {
        'Gender': _selectedGender ?? 'Male',
        'Married': _selectedMarried ?? 'No',
        'Dependents': _selectedDependents ?? '0',
        'Education': _selectedEducation ?? 'Graduate',
        'Self_Employed': _selectedSelfEmployed ?? 'No',
        'ApplicantIncome': int.tryParse(_applicantIncomeController.text.trim()) ?? 0,
        'CoapplicantIncome': int.tryParse(_coapplicantIncomeController.text.trim()) ?? 0,
        'LoanAmount': int.tryParse(_loanAmountController.text.trim()) ?? 0,
        'Loan_Amount_Term': int.tryParse(_loanTermController.text.trim()) ?? 0,
        'Credit_History': double.tryParse(_selectedCreditHistory ?? '') ?? 1.0,
        'Property_Area': _selectedPropertyArea ?? 'Urban',
      };

      final result = await _mlService.predictLoanEligibility(input);
      setState(() {
        _predictionResult = (result['prediction']?.toString() ?? 'Unknown');
        _predictionProbability = (result['probability'] as double?);
      });
    } catch (e) {
      setState(() {
        _predictionResult = 'Error during prediction';
        _predictionProbability = null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Widget _buildPredictionResult() {
    final isEligible = _predictionResult?.toLowerCase() == 'approved';
    return Card(
      color: isEligible ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isEligible ? Icons.check_circle : Icons.cancel, color: isEligible ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(
                  isEligible ? 'Eligible for Loan' : 'Not Eligible',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isEligible ? Colors.green[800] : Colors.red[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_predictionProbability != null)
              Text(
                'Confidence: ${(100 * _predictionProbability!).toStringAsFixed(1)}%',
                style: TextStyle(color: Colors.grey[700]),
              ),
          ],
        ),
      ),
    );
  }
}