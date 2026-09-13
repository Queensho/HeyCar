import 'dart:convert';
import 'package:http/http.dart' as http;

class VehicleApi {
  static const _base = 'https://vpic.nhtsa.dot.gov/api/vehicles';

  static const List<String> _makes = [
    'Audi','BMW','Citroen','Dacia','Fiat','Ford','Honda','Hyundai','Kia',
    'Mercedes-Benz','Nissan','Opel','Peugeot','Renault','Seat','Skoda',
    'Tesla','Toyota','Volkswagen','Volvo'
  ];

  static const Map<String, List<String>> _fallbackModels = {
    'Audi': ['A3','A4','A5','A6','Q2','Q3','Q5'],
    'BMW': ['1 Series','2 Series','3 Series','4 Series','5 Series','X1','X3','X5'],
    'Citroen': ['C3','C4','C4 X','C5 Aircross'],
    'Dacia': ['Duster','Jogger','Sandero'],
    'Fiat': ['Egea','500','Panda','Doblo'],
    'Ford': ['Focus','Fiesta','Puma','Kuga','Courier'],
    'Honda': ['Civic','City','HR-V','CR-V'],
    'Hyundai': ['i10','i20','i30','Bayon','Tucson'],
    'Kia': ['Picanto','Rio','Stonic','Sportage'],
    'Mercedes-Benz': ['A-Class','C-Class','E-Class','CLA','GLA','GLC'],
    'Nissan': ['Micra','Juke','Qashqai','X-Trail'],
    'Opel': ['Corsa','Astra','Mokka','Grandland'],
    'Peugeot': ['208','308','2008','3008','5008'],
    'Renault': ['Clio','Megane','Taliant','Captur','Austral'],
    'Seat': ['Ibiza','Leon','Arona','Ateca'],
    'Skoda': ['Fabia','Scala','Octavia','Kamiq','Karoq'],
    'Tesla': ['Model 3','Model Y','Model S','Model X'],
    'Toyota': ['Corolla','Yaris','C-HR','RAV4'],
    'Volkswagen': ['Polo','Golf','Passat','T-Roc','Tiguan'],
    'Volvo': ['S60','S90','XC40','XC60','XC90'],
  };

  static Future<List<String>> getMakes() async => _makes;

  static Future<List<String>> getModels(String make) async {
    final clean = make.trim();
    if (clean.isEmpty) return const [];

    final fallback = _fallbackModels[clean] ?? const <String>[];

    try {
      final encoded = Uri.encodeComponent(clean);
      final response = await http
          .get(Uri.parse('$_base/getmodelsformake/$encoded?format=json'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return fallback;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return fallback;

      final rows = decoded['Results'];
      if (rows is! List) return fallback;

      final models = rows
          .whereType<Map<String, dynamic>>()
          .map((e) => e['Model_Name']?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      return models.isEmpty ? fallback : models;
    } catch (_) {
      return fallback;
    }
  }
}
