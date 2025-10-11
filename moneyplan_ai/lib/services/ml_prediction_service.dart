import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;

class MLPredictionService {
  // Since Flutter doesn't natively support Python pickle files,
  // we'll implement a simplified version of the Random Forest model
  // or use a rule-based system that mimics ML predictions

  // This could be replaced with:
  // 1. A REST API that serves the Python model
  // 2. TensorFlow Lite model conversion
  // 3. ONNX model conversion
  // 4. Rule-based system (implemented below)

  Future<Map<String, dynamic>> predictLoanEligibility(
    Map<String, dynamic> inputData,
  ) async {
    // Try to use the actual ML API first, fallback to rule-based system
    try {
      return await _predictViaMLAPI(inputData);
    } catch (e) {
      print('ML API unavailable, using fallback prediction: $e');
      return await _predictViaRuleBasedSystem(inputData);
    }
  }

  Future<Map<String, dynamic>> _predictViaMLAPI(
    Map<String, dynamic> inputData,
  ) async {
    const String apiUrl = 'http://localhost:5000/predict';

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(inputData),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return {
          'prediction': result['prediction'],
          'probability': result['probability'],
          'source': 'ML_API',
        };
      } else {
        throw Exception('API returned status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('ML API call failed: $e');
    }
  }

  Future<Map<String, dynamic>> _predictViaRuleBasedSystem(
    Map<String, dynamic> inputData,
  ) async {
    // Simulate API call delay
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Extract and normalize input features
      final features = _preprocessInputData(inputData);

      // Apply simplified Random Forest-like logic
      final prediction = _makeDecisionTreePrediction(features);
      final probability = _calculateProbability(features);

      return {
        'prediction': prediction,
        'probability': probability,
        'source': 'RULE_BASED',
      };
    } catch (e) {
      throw Exception('Failed to make prediction: $e');
    }
  }

  Map<String, dynamic> _preprocessInputData(Map<String, dynamic> inputData) {
    // Convert categorical variables to numerical
    final processed = <String, dynamic>{};

    // Gender: Male = 1, Female = 0
    processed['Gender'] = inputData['Gender'] == 'Male' ? 1 : 0;

    // Married: Yes = 1, No = 0
    processed['Married'] = inputData['Married'] == 'Yes' ? 1 : 0;

    // Dependents: Convert to numerical
    final dependents = inputData['Dependents'].toString();
    processed['Dependents'] = dependents == '3+' ? 3 : int.parse(dependents);

    // Education: Graduate = 1, Not Graduate = 0
    processed['Education'] = inputData['Education'] == 'Graduate' ? 1 : 0;

    // Self_Employed: Yes = 1, No = 0
    processed['Self_Employed'] = inputData['Self_Employed'] == 'Yes' ? 1 : 0;

    // Numerical features
    processed['ApplicantIncome'] = inputData['ApplicantIncome'];
    processed['CoapplicantIncome'] = inputData['CoapplicantIncome'];
    processed['LoanAmount'] = inputData['LoanAmount'];
    processed['Loan_Amount_Term'] = inputData['Loan_Amount_Term'];
    processed['Credit_History'] = inputData['Credit_History'];

    // Property_Area: Urban = 2, Semiurban = 1, Rural = 0
    final propertyArea = inputData['Property_Area'];
    processed['Property_Area'] = propertyArea == 'Urban'
        ? 2
        : propertyArea == 'Semiurban'
        ? 1
        : 0;

    // Calculate derived features
    processed['TotalIncome'] =
        processed['ApplicantIncome'] + processed['CoapplicantIncome'];
    processed['LoanAmountLog'] = _safeLog(processed['LoanAmount']);
    processed['TotalIncomeLog'] = _safeLog(processed['TotalIncome']);

    return processed;
  }

  double _safeLog(double value) {
    return value > 0 ? (value + 1).log() : 0.0;
  }

  String _makeDecisionTreePrediction(Map<String, dynamic> features) {
    // Simplified decision tree logic based on common loan approval criteria
    double score = 0.0;

    // Credit History is the most important factor
    if (features['Credit_History'] == 1.0) {
      score += 40;
    } else {
      score -= 30;
    }

    // Income to Loan Amount ratio
    final totalIncome = features['TotalIncome'];
    final loanAmount = features['LoanAmount'];
    final incomeToLoanRatio = totalIncome / loanAmount;

    if (incomeToLoanRatio > 0.3) {
      score += 25;
    } else if (incomeToLoanRatio > 0.2) {
      score += 15;
    } else if (incomeToLoanRatio > 0.1) {
      score += 5;
    } else {
      score -= 20;
    }

    // Education factor
    if (features['Education'] == 1) {
      score += 10;
    }

    // Employment status
    if (features['Self_Employed'] == 0) {
      score += 8; // Salaried is generally preferred
    }

    // Marital status
    if (features['Married'] == 1) {
      score += 5;
    }

    // Property area
    if (features['Property_Area'] == 2) {
      // Urban
      score += 8;
    } else if (features['Property_Area'] == 1) {
      // Semiurban
      score += 5;
    }

    // Dependents (fewer dependents is better)
    score -= features['Dependents'] * 3;

    // Loan term factor
    final loanTerm = features['Loan_Amount_Term'];
    if (loanTerm >= 300 && loanTerm <= 480) {
      score += 5; // Standard loan terms
    }

    // Income level factor
    if (totalIncome > 10000) {
      score += 10;
    } else if (totalIncome > 5000) {
      score += 5;
    }

    // Final decision based on score
    return score >= 50 ? 'Y' : 'N';
  }

  double _calculateProbability(Map<String, dynamic> features) {
    // Calculate a probability score based on multiple factors
    double probability = 0.5; // Base probability

    // Credit History impact
    if (features['Credit_History'] == 1.0) {
      probability += 0.3;
    } else {
      probability -= 0.4;
    }

    // Income to Loan ratio impact
    final totalIncome = features['TotalIncome'];
    final loanAmount = features['LoanAmount'];
    final incomeToLoanRatio = totalIncome / loanAmount;

    if (incomeToLoanRatio > 0.3) {
      probability += 0.25;
    } else if (incomeToLoanRatio > 0.2) {
      probability += 0.15;
    } else if (incomeToLoanRatio > 0.1) {
      probability += 0.05;
    } else {
      probability -= 0.2;
    }

    // Education impact
    if (features['Education'] == 1) {
      probability += 0.1;
    }

    // Employment type impact
    if (features['Self_Employed'] == 0) {
      probability += 0.08;
    }

    // Property area impact
    if (features['Property_Area'] == 2) {
      probability += 0.05;
    } else if (features['Property_Area'] == 1) {
      probability += 0.03;
    }

    // Add some randomness to simulate model uncertainty
    final random = math.Random();
    probability += (random.nextDouble() - 0.5) * 0.1;

    // Ensure probability is between 0 and 1
    return probability.clamp(0.0, 1.0);
  }

  // Check if ML API server is available
  Future<bool> isMLAPIAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:5000/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['model_loaded'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get model information from API
  Future<Map<String, dynamic>?> getMLModelInfo() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:5000/model-info'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get feature importance from ML API
  Future<Map<String, dynamic>?> getMLFeatureImportance() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:5000/feature-importance'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Method to get feature importance (for educational purposes)
  Map<String, double> getFeatureImportance() {
    return {
      'Credit_History': 0.35,
      'TotalIncome': 0.20,
      'LoanAmount': 0.15,
      'Education': 0.10,
      'Property_Area': 0.08,
      'Self_Employed': 0.05,
      'Married': 0.04,
      'Dependents': 0.03,
    };
  }

  // Method to get model statistics (simulated)
  Map<String, dynamic> getModelStats() {
    return {
      'accuracy': 0.847,
      'precision': 0.823,
      'recall': 0.891,
      'f1_score': 0.856,
      'model_type': 'Random Forest (Simulated)',
      'training_samples': 614,
      'features_count': 11,
    };
  }
}

// Extension to add log function to double
extension DoubleExtension on double {
  double log() => math.log(this);
}