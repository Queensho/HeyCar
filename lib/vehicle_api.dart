import 'dart:convert';
import 'package:http/http.dart' as http;

class VehicleApi {
  static const _base = 'https://vpic.nhtsa.dot.gov/api/vehicles';

  static Future<List<String>> getMakes() async {
    try {
      final response = await http
          .get(Uri.parse('$_base/getallmakes?format=json'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = (json['Results'] as List<dynamic>? ?? const []);
      final makes = rows
          .map((e) => (e as Map<String, dynamic>)['Make_Name']?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return makes;
    } catch (_) {
      return const [
        'Audi','BMW','Citroen','Dacia','Fiat','Ford','Honda','Hyundai','Kia',
        'Mercedes-Benz','Nissan','Opel','Peugeot','Renault','Seat','Skoda',
        'Tesla','Toyota','Volkswagen','Volvo'
      ];
    }
  }

  static Future<List<String>> getModels(String make) async {
    if (make.trim().isEmpty) return const [];
    try {
      final encoded = Uri.encodeComponent(make);
      final response = await http
          .get(Uri.parse('$_base/getmodelsformake/$encoded?format=json'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = (json['Results'] as List<dynamic>? ?? const []);
      final models = rows
          .map((e) => (e as Map<String, dynamic>)['Model_Name']?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return models;
    } catch (_) {
      return const [];
    }
  }
}
