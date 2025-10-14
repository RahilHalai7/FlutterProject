import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CibilLocalService {
  // Use platform-aware base URL: web -> localhost, android emulator -> 10.0.2.2
  static final String _baseUrl = kIsWeb ? 'http://localhost:5000' : 'http://10.0.2.2:5000';
  static const String _endpoint = '/cibil/predict';

  static final CibilLocalService _instance = CibilLocalService._internal();
  factory CibilLocalService() => _instance;
  CibilLocalService._internal();

  Future<Map<String, dynamic>> getCibilCreditReport({
    required String fullName,
    required String mobileNumber,
    required String dateOfBirth,
    required String panNumber,
  }) async {
    final url = Uri.parse('$_baseUrl$_endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final body = json.encode({
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'date_of_birth': dateOfBirth,
      'pan_number': panNumber.toUpperCase(),
    });

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      final Map<String, dynamic> payload = json.decode(response.body);

      if (response.statusCode == 200 && (payload['success'] == true)) {
        // Adapt ML API response to the screen’s expected UI shape
        return {
          'success': true,
          'data': {
            'status': 'success',
            'message': 'CIBIL report fetched successfully',
            'data': payload['data'],
          },
        };
      }

      return {
        'success': false,
        'error': payload['error'] ?? 'Failed to fetch CIBIL report',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}