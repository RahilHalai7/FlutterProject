import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for integrating with Indian banking systems
///
/// IMPORTANT: For production use, integrate with one of these providers:
///
/// 1. SETU (Account Aggregator) - https://setu.co/
///    - Best for Indian banks
///    - Supports RBI-regulated Account Aggregator framework
///
/// 2. Razorpay - https://razorpay.com/
///    - Payment gateway with bank account verification
///    - Supports UPI, bank transfers
///
/// 3. PhonePe/Google Pay Business APIs
///    - For UPI integration
///
/// 4. Finbox - https://finbox.in/
///    - Bank statement analysis
///    - Credit underwriting
///
/// Note: Plaid does NOT support Indian banks/UPI

class BankIntegrationService {
  // Replace with your actual API credentials
  static const String _apiKey = 'YOUR_API_KEY';
  static const String _apiSecret = 'YOUR_API_SECRET';

  // For Setu: https://docs.setu.co/
  static const String _setuBaseUrl =
      'https://uat.setu.co'; // Use production URL in prod

  // For Razorpay: https://razorpay.com/docs/
  static const String _razorpayBaseUrl = 'https://api.razorpay.com/v1';

  /// Initialize bank linking session (Setu Account Aggregator)
  ///
  /// This creates a consent request for the user to approve
  /// linking their bank account through the AA framework
  Future<Map<String, dynamic>> initiateBankLinking({
    required String userId,
    required String mobileNumber,
  }) async {
    try {
      // Example: Setu Account Aggregator API
      final response = await http.post(
        Uri.parse('$_setuBaseUrl/api/consent'),
        headers: {
          'Content-Type': 'application/json',
          'x-client-id': _apiKey,
          'x-client-secret': _apiSecret,
        },
        body: jsonEncode({
          'Detail': {
            'consentStart': DateTime.now().toIso8601String(),
            'consentExpiry': DateTime.now()
                .add(const Duration(days: 365))
                .toIso8601String(),
            'Customer': {'id': userId},
            'FIDataRange': {
              'from': DateTime.now()
                  .subtract(const Duration(days: 365))
                  .toIso8601String(),
              'to': DateTime.now().toIso8601String(),
            },
            'consentMode': 'STORE',
            'consentTypes': ['TRANSACTIONS', 'PROFILE', 'SUMMARY'],
            'fetchType': 'PERIODIC',
            'Frequency': {'unit': 'MONTH', 'value': 1},
            'DataFilter': [
              {'type': 'TRANSACTIONAMOUNT', 'value': '0', 'operator': '>='},
            ],
            'DataLife': {'unit': 'MONTH', 'value': 12},
            'DataConsumer': {'id': 'your-app-aa-id'},
            'Purpose': {'code': '101', 'text': 'Wealth management service'},
          },
          'redirectUrl': 'moneyplanai://callback',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'consentId': data['id'],
          'consentUrl': data['url'],
          'status': data['status'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to initiate bank linking: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error initiating bank linking: $e'};
    }
  }

  /// Verify UPI ID (Using Razorpay Fund Account Validation)
  Future<Map<String, dynamic>> verifyUPI(String upiId) async {
    try {
      // Razorpay Fund Account Validation API
      final response = await http.post(
        Uri.parse('$_razorpayBaseUrl/fund_accounts/validations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$_apiKey:$_apiSecret'))}',
        },
        body: jsonEncode({
          'account_number': upiId,
          'fund_account': {
            'account_type': 'vpa',
            'vpa': {'address': upiId},
          },
          'amount': 100, // ₹1.00 for verification
          'currency': 'INR',
          'notes': {'purpose': 'UPI Verification'},
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'verified': data['status'] == 'completed',
          'upiId': upiId,
          'name': data['results']?['account_name'],
        };
      } else {
        return {'success': false, 'error': 'UPI verification failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error verifying UPI: $e'};
    }
  }

  /// Get consent status (Setu)
  Future<Map<String, dynamic>> getConsentStatus(String consentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_setuBaseUrl/api/consent/$consentId'),
        headers: {'x-client-id': _apiKey, 'x-client-secret': _apiSecret},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': data['status'], // PENDING, ACTIVE, PAUSED, REVOKED, EXPIRED
          'consentId': consentId,
        };
      } else {
        return {'success': false, 'error': 'Failed to get consent status'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error getting consent status: $e'};
    }
  }

  /// Fetch bank account data (after consent is approved)
  Future<Map<String, dynamic>> fetchBankData({
    required String consentId,
    required String sessionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_setuBaseUrl/api/data/fetch'),
        headers: {
          'Content-Type': 'application/json',
          'x-client-id': _apiKey,
          'x-client-secret': _apiSecret,
        },
        body: jsonEncode({
          'consentId': consentId,
          'sessionId': sessionId,
          'DataRange': {
            'from': DateTime.now()
                .subtract(const Duration(days: 90))
                .toIso8601String(),
            'to': DateTime.now().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'dataId': data['id'],
          'accounts': _parseAccountData(data),
        };
      } else {
        return {'success': false, 'error': 'Failed to fetch bank data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error fetching bank data: $e'};
    }
  }

  /// Parse account data from Setu response
  List<Map<String, dynamic>> _parseAccountData(Map<String, dynamic> data) {
    final accounts = <Map<String, dynamic>>[];

    try {
      final fiData = data['FI'] as List?;
      if (fiData == null) return accounts;

      for (final fi in fiData) {
        final account = fi['data'] as Map<String, dynamic>?;
        if (account == null) continue;

        accounts.add({
          'accountNumber': account['maskedAccNumber'],
          'accountType': account['type'],
          'ifsc': account['ifsc'],
          'branch': account['branch'],
          'balance': account['currentBalance'],
          'currency': account['currency'],
        });
      }
    } catch (e) {
      print('Error parsing account data: $e');
    }

    return accounts;
  }

  /// Verify bank account using penny drop (Razorpay)
  Future<Map<String, dynamic>> verifyBankAccount({
    required String accountNumber,
    required String ifsc,
    required String accountHolderName,
  }) async {
    try {
      // Razorpay Fund Account Validation for bank accounts
      final response = await http.post(
        Uri.parse('$_razorpayBaseUrl/fund_accounts/validations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$_apiKey:$_apiSecret'))}',
        },
        body: jsonEncode({
          'account_number': accountNumber,
          'fund_account': {
            'account_type': 'bank_account',
            'bank_account': {
              'name': accountHolderName,
              'ifsc': ifsc,
              'account_number': accountNumber,
            },
          },
          'amount': 100, // ₹1.00 for penny drop verification
          'currency': 'INR',
          'notes': {'purpose': 'Bank Account Verification'},
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'verified': data['status'] == 'completed',
          'accountNumber': accountNumber,
          'accountHolderName': data['results']?['account_name'],
          'ifsc': ifsc,
        };
      } else {
        return {'success': false, 'error': 'Bank account verification failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error verifying bank account: $e'};
    }
  }

  /// Create payment order (for testing payment flow)
  Future<Map<String, dynamic>> createPaymentOrder({
    required String amount,
    required String currency,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_razorpayBaseUrl/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$_apiKey:$_apiSecret'))}',
        },
        body: jsonEncode({
          'amount': (double.parse(amount) * 100).toInt(), // Convert to paise
          'currency': currency,
          'receipt': 'receipt_$userId',
          'notes': {'userId': userId},
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'orderId': data['id'],
          'amount': data['amount'],
          'currency': data['currency'],
        };
      } else {
        return {'success': false, 'error': 'Failed to create payment order'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error creating payment order: $e'};
    }
  }

  /// Get transaction history (mock implementation)
  /// In production, this would fetch from Setu AA or your backend
  Future<List<Map<String, dynamic>>> getTransactionHistory({
    required String accountId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Mock data - replace with actual API call
      await Future.delayed(const Duration(seconds: 1));

      return [
        {
          'date': DateTime.now().subtract(const Duration(days: 1)),
          'description': 'Amazon Payment',
          'amount': -1250.00,
          'type': 'debit',
          'balance': 45250.00,
        },
        {
          'date': DateTime.now().subtract(const Duration(days: 2)),
          'description': 'Salary Credit',
          'amount': 50000.00,
          'type': 'credit',
          'balance': 46500.00,
        },
        {
          'date': DateTime.now().subtract(const Duration(days: 3)),
          'description': 'Electricity Bill',
          'amount': -850.00,
          'type': 'debit',
          'balance': 15350.00,
        },
      ];
    } catch (e) {
      return [];
    }
  }

  /// Revoke bank consent (Setu)
  Future<Map<String, dynamic>> revokeConsent(String consentId) async {
    try {
      final response = await http.post(
        Uri.parse('$_setuBaseUrl/api/consent/$consentId/revoke'),
        headers: {
          'Content-Type': 'application/json',
          'x-client-id': _apiKey,
          'x-client-secret': _apiSecret,
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Consent revoked successfully'};
      } else {
        return {'success': false, 'error': 'Failed to revoke consent'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error revoking consent: $e'};
    }
  }
}

/// Helper class for UPI operations
class UPIHelper {
  /// Validate UPI ID format
  static bool isValidUPIId(String upiId) {
    // UPI ID format: username@bankcode
    final regex = RegExp(r'^[\w.-]+@[\w]+)$');
    return regex.hasMatch(upiId);
  }

  /// Extract bank code from UPI ID
  static String? getBankCode(String upiId) {
    if (!isValidUPIId(upiId)) return null;
    return upiId.split('@').last;
  }

  /// Common UPI providers
  static const Map<String, String> upiProviders = {
    'paytm': 'Paytm',
    'googlepay': 'Google Pay',
    'phonepe': 'PhonePe',
    'ybl': 'Paytm/Yes Bank',
    'okhdfcbank': 'HDFC Bank',
    'okicici': 'ICICI Bank',
    'oksbi': 'State Bank of India',
    'okaxis': 'Axis Bank',
  };

  /// Get provider name from UPI ID
  static String getProviderName(String upiId) {
    final bankCode = getBankCode(upiId);
    if (bankCode == null) return 'Unknown';
    return upiProviders[bankCode.toLowerCase()] ?? bankCode.toUpperCase();
  }
}
