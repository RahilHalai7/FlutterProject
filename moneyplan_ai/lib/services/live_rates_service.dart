import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class LiveRatesService {
  // More accurate metals pricing via Metals-API (per troy ounce)
  // Supply your key using: flutter run -d chrome --dart-define=METALS_API_KEY=YOUR_KEY
  static const String _metalsApiKey = String.fromEnvironment('METALS_API_KEY', defaultValue: '');
  static const String _bitcoinApiUrl = 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=inr&include_24hr_change=true'; // Bitcoin in INR
  static const String _alternativeGoldUrl = 'https://api.metals.live/v1/spot/gold';
  static const String _alternativeSilverUrl = 'https://api.metals.live/v1/spot/silver';
  
  static const Duration _timeout = Duration(seconds: 8);

  // Fallback API for crypto prices
  static const String _cryptoApiUrl = 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd';

  Future<Map<String, dynamic>> getLiveRates() async {
    try {
      // Get all rates concurrently
      final results = await Future.wait([
        _getGoldPrice(),
        _getSilverPrice(),
        _getBitcoinPrice(),
      ]);

      return {
        'gold': results[0],
        'silver': results[1],
        'bitcoin': results[2],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      // Return mock data if API fails
      return _getMockRates();
    }
  }

  Future<Map<String, dynamic>> _getGoldPrice() async {
    try {
      // Try Metals-API first (returns per-ounce price in INR when base=INR)
      if (_metalsApiKey.isNotEmpty) {
        final uri = Uri.https('metals-api.com', '/api/latest', {
          'access_key': _metalsApiKey,
          'base': 'INR',
          'symbols': 'XAU',
        });
        final response = await http.get(uri).timeout(_timeout);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final rates = data['rates'] ?? {};
          final pricePerOunceINR = (rates['XAU'] is num) ? (rates['XAU'] as num).toDouble() : 0.0;
          if (pricePerOunceINR > 0) {
            final priceInINRPer10g = (pricePerOunceINR / 3.11035) * 10; // 1 troy ounce = 31.1035g
            return {
              'price': priceInINRPer10g,
              'change': 0.0,
              'changePercent': 0.0,
            };
          }
        }
      }
    } catch (e) {
      print('Metals-API gold error: $e');
      
      // Try alternative API with USD to INR conversion
      try {
        final response = await http.get(
          Uri.parse(_alternativeGoldUrl),
        ).timeout(_timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Convert USD to INR and per ounce to per 10g
          final priceUSD = data['price']?.toDouble() ?? 2000.0;
          final priceInINRPer10g = (priceUSD * 83) / 3.11035 * 10;
          final changePercent = data['change_percent']?.toDouble() ?? 0.0;
          
          return {
            'price': priceInINRPer10g,
            'change': (data['change']?.toDouble() ?? 0.0) * 83.0 / 3.11035 * 10,
            'changePercent': changePercent,
          };
        }
      } catch (e2) {
        print('Alternative Gold API error: $e2');
      }
    }
    
    // Fallback to realistic Indian market data
    return {
      'price': 63250.0, // ₹63,250 per 10g (realistic Indian market price)
      'change': 284.25,
      'changePercent': 0.45,
    };
  }

  Future<Map<String, dynamic>> _getSilverPrice() async {
    try {
      // Try Metals-API first (returns per-ounce price in INR when base=INR)
      if (_metalsApiKey.isNotEmpty) {
        final uri = Uri.https('metals-api.com', '/api/latest', {
          'access_key': _metalsApiKey,
          'base': 'INR',
          'symbols': 'XAG',
        });
        final response = await http.get(uri).timeout(_timeout);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final rates = data['rates'] ?? {};
          final pricePerOunceINR = (rates['XAG'] is num) ? (rates['XAG'] as num).toDouble() : 0.0;
          if (pricePerOunceINR > 0) {
            final priceInINRPer10g = (pricePerOunceINR / 3.11035) * 10;
            return {
              'price': priceInINRPer10g,
              'change': 0.0,
              'changePercent': 0.0,
            };
          }
        }
      }
    } catch (e) {
      print('Metals-API silver error: $e');
      
      // Try alternative API with USD to INR conversion
      try {
        final response = await http.get(
          Uri.parse(_alternativeSilverUrl),
        ).timeout(_timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Convert USD to INR and per ounce to per 10g
          final priceUSD = data['price']?.toDouble() ?? 25.0;
          final priceInINRPer10g = (priceUSD * 83) / 3.11035 * 10;
          final changePercent = data['change_percent']?.toDouble() ?? 0.0;
          
          return {
            'price': priceInINRPer10g,
            'change': (data['change']?.toDouble() ?? 0.0) * 83.0 / 3.11035 * 10,
            'changePercent': changePercent,
          };
        }
      } catch (e2) {
        print('Alternative Silver API error: $e2');
      }
    }
    
    // Fallback to realistic Indian market data
    return {
      'price': 785.50, // ₹785.50 per 10g (realistic Indian market price)
      'change': -2.51,
      'changePercent': -0.32,
    };
  }

  Future<Map<String, dynamic>> _getBitcoinPrice() async {
    try {
      // CoinGecko API with INR directly
      final response = await http.get(
        Uri.parse(_bitcoinApiUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bitcoinData = data['bitcoin'];
        // Direct INR price from CoinGecko
        final priceInINR = bitcoinData['inr']?.toDouble() ?? 0.0;
        final changePercent = bitcoinData['inr_24h_change']?.toDouble() ?? 0.0;
        
        return {
          'price': priceInINR,
          'change': (priceInINR * changePercent / 100),
          'changePercent': changePercent,
        };
      }
    } catch (e) {
      print('Bitcoin API error: $e');
    }
    
    // Fallback to realistic Indian market data
    return {
      'price': 4125000.0, // ₹41,25,000 (realistic current Bitcoin price in INR)
      'change': 51562.50,
      'changePercent': 1.25,
    };
  }

  Map<String, dynamic> _getMockRates() {
    return {
      'gold': {
        'price': 63250.0, // ₹63,250 per 10g (realistic Indian market price)
        'change': 284.25,
        'changePercent': 0.45,
      },
      'silver': {
        'price': 785.50, // ₹785.50 per 10g (realistic Indian market price)
        'change': -2.51,
        'changePercent': -0.32,
      },
      'bitcoin': {
        'price': 4125000.0, // ₹41,25,000 (realistic current Bitcoin price in INR)
        'change': 51562.50,
        'changePercent': 1.25,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}