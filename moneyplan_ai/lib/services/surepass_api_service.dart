import 'dart:convert';
import 'package:http/http.dart' as http;

class SurepassApiService {
  static const String _baseUrl = 'https://kyc-api.surepass.io/api/v1';
  static const String _apiKey = 'YOUR_SUREPASS_API_KEY'; // Replace with actual API key
  
  // CIBIL Credit Report endpoint
  static const String _cibilEndpoint = '/cibil-report';
  
  static final SurepassApiService _instance = SurepassApiService._internal();
  factory SurepassApiService() => _instance;
  SurepassApiService._internal();
  
  /// Get CIBIL Credit Report
  /// Requires: fullName, mobileNumber, dateOfBirth (YYYY-MM-DD), panNumber
  Future<Map<String, dynamic>> getCibilCreditReport({
    required String fullName,
    required String mobileNumber,
    required String dateOfBirth,
    required String panNumber,
  }) async {
    // Mock implementation for testing - replace with actual API call when you have a valid API key
    print('Mock CIBIL API request for: $fullName, $mobileNumber, $dateOfBirth, $panNumber');
    
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Return mock successful response
    return {
      'success': true,
      'data': {
        'status': 'success',
        'message': 'CIBIL report fetched successfully',
        'data': {
          'personal_info': {
            'full_name': fullName,
            'mobile_number': mobileNumber,
            'pan_number': panNumber.toUpperCase(),
            'date_of_birth': dateOfBirth,
            'address': '123 Mock Street, Test City, Test State - 123456',
          },
          'cibil_score': {
            'score': 750,
            'score_description': 'Good',
            'score_range': '300-900',
            'last_updated': '2024-01-15',
          },
          'credit_accounts': [
            {
              'account_type': 'Credit Card',
              'bank_name': 'HDFC Bank',
              'account_number': 'XXXX-XXXX-XXXX-1234',
              'credit_limit': 200000,
              'outstanding_amount': 15000,
              'payment_status': 'Regular',
            },
            {
              'account_type': 'Personal Loan',
              'bank_name': 'ICICI Bank',
              'account_number': 'XXXX-XXXX-5678',
              'credit_limit': 500000,
              'outstanding_amount': 125000,
              'payment_status': 'Regular',
            },
          ],
        },
      },
    };
    
    /* Uncomment this section when you have a valid Surepass API key:
    try {
      final url = Uri.parse('$_baseUrl$_cibilEndpoint');
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'Accept': 'application/json',
      };
      
      final body = json.encode({
        'full_name': fullName,
        'mobile_number': mobileNumber,
        'date_of_birth': dateOfBirth,
        'pan_number': panNumber.toUpperCase(),
      });
      
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to fetch CIBIL report',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
    */
  }
  
  /// Validate PAN number format
  static bool isValidPanNumber(String pan) {
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return panRegex.hasMatch(pan.toUpperCase());
  }
  
  /// Validate mobile number format (Indian)
  static bool isValidMobileNumber(String mobile) {
    final mobileRegex = RegExp(r'^[6-9]\d{9}$');
    return mobileRegex.hasMatch(mobile);
  }
  
  /// Validate date format (YYYY-MM-DD)
  static bool isValidDateFormat(String date) {
    try {
      DateTime.parse(date);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Format date from DateTime to YYYY-MM-DD
  static String formatDateForApi(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}