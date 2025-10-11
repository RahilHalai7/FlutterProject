import 'package:flutter/material.dart';
import '../services/ml_prediction_service.dart';

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
      appBar: AppBar(
        title: const Text('Loan Eligibility Checker'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your details to check loan eligibility',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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
            ElevatedButton(
              onPressed: _isLoading ? null : _predictLoanEligibility,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
            
            // Prediction Result
            if (_predictionResult != null) ...[
              const SizedBox(height: 20),
              _buildPredictionResult(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
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
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue[700]!),
          ),
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
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue[700]!),
              ),
            ),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPredictionResult() {
    final isApproved = _predictionResult == 'Y' || _predictionResult == 'Approved';
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isApproved
                ? [Colors.green[400]!, Colors.green[600]!]
                : [Colors.red[400]!, Colors.red[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isApproved ? Icons.check_circle : Icons.cancel,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              isApproved ? 'Loan Approved!' : 'Loan Rejected',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (_predictionProbability != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Confidence: ${(_predictionProbability! * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isMLAPIAvailable ? 'ML' : 'Rule',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _resetForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isApproved ? Colors.green[700] : Colors.red[700],
              ),
              child: const Text('Check Another Application'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _resetForm() {
    setState(() {
      _predictionResult = null;
      _predictionProbability = null;
    });
    
    // Clear all form fields
    _applicantIncomeController.clear();
    _coapplicantIncomeController.clear();
    _loanAmountController.clear();
    _loanTermController.clear();
    
    setState(() {
      _selectedGender = null;
      _selectedMarried = null;
      _selectedDependents = null;
      _selectedEducation = null;
      _selectedSelfEmployed = null;
      _selectedCreditHistory = null;
      _selectedPropertyArea = null;
    });
  }
  
  Future<void> _predictLoanEligibility() async {
    if (!_validateForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final inputData = {
        'Gender': _selectedGender,
        'Married': _selectedMarried,
        'Dependents': _selectedDependents,
        'Education': _selectedEducation,
        'Self_Employed': _selectedSelfEmployed,
        'ApplicantIncome': double.tryParse(_applicantIncomeController.text) ?? 0,
        'CoapplicantIncome': double.tryParse(_coapplicantIncomeController.text) ?? 0,
        'LoanAmount': double.tryParse(_loanAmountController.text) ?? 0,
        'Loan_Amount_Term': double.tryParse(_loanTermController.text) ?? 0,
        'Credit_History': double.tryParse(_selectedCreditHistory ?? '0') ?? 0,
        'Property_Area': _selectedPropertyArea,
      };
      
      final result = await _mlService.predictLoanEligibility(inputData);
      
      setState(() {
        _predictionResult = result['prediction'];
        _predictionProbability = result['probability'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error making prediction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  bool _validateForm() {
    return _selectedGender != null &&
           _selectedMarried != null &&
           _selectedDependents != null &&
           _selectedEducation != null &&
           _selectedSelfEmployed != null &&
           _applicantIncomeController.text.isNotEmpty &&
           _loanAmountController.text.isNotEmpty &&
           _loanTermController.text.isNotEmpty &&
           _selectedCreditHistory != null &&
           _selectedPropertyArea != null;
  }
  
  @override
  void dispose() {
    _applicantIncomeController.dispose();
    _coapplicantIncomeController.dispose();
    _loanAmountController.dispose();
    _loanTermController.dispose();
    super.dispose();
  }
}