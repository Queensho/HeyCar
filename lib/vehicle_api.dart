import 'dart:convert';
import 'package:http/http.dart' as http;

class VehicleApi {
  static const _base = 'https://vpic.nhtsa.dot.gov/api/vehicles';

  static const List<String> _makes = [
    'Audi','BMW','BYD','Chery','Citroen','Cupra','Dacia','Fiat','Ford','Honda',
    'Hyundai','Jeep','Kia','Land Rover','Lexus','Mazda','Mercedes-Benz','MG',
    'Mini','Nissan','Opel','Peugeot','Porsche','Renault','Seat','Skoda','Suzuki',
    'Tesla','Togg','Toyota','Volkswagen','Volvo','Diğer'
  ];

  static const Map<String, List<String>> _fallbackModels = {
    'Audi': ['A3','A4','A5','A6','Q2','Q3','Q5'],
    'BMW': ['1 Series','2 Series','3 Series','4 Series','5 Series','X1','X3','X5'],
    'BYD': ['Atto 3','Dolphin','Seal U','Seal'],
    'Chery': ['Omoda 5','Tiggo 7 Pro','Tiggo 8 Pro'],
    'Citroen': ['C3','C4','C4 X','C5 Aircross'],
    'Cupra': ['Formentor','Leon','Born'],
    'Dacia': ['Duster','Jogger','Sandero'],
    'Fiat': ['Egea','500','Panda','Doblo'],
    'Ford': ['Focus','Fiesta','Puma','Kuga','Courier'],
    'Honda': ['Civic','City','HR-V','CR-V'],
    'Hyundai': ['i10','i20','i30','Bayon','Tucson','Ioniq 5'],
    'Jeep': ['Avenger','Renegade','Compass'],
    'Kia': ['Picanto','Rio','Stonic','Sportage','EV3'],
    'Land Rover': ['Range Rover Evoque','Discovery Sport','Defender'],
    'Lexus': ['LBX','NX','RX'],
    'Mazda': ['Mazda 2','Mazda 3','CX-30','CX-5'],
    'Mercedes-Benz': ['A-Class','C-Class','E-Class','CLA','GLA','GLC'],
    'MG': ['MG4','ZS','HS'],
    'Mini': ['Cooper','Countryman'],
    'Nissan': ['Micra','Juke','Qashqai','X-Trail'],
    'Opel': ['Corsa','Astra','Mokka','Grandland'],
    'Peugeot': ['208','308','2008','3008','5008'],
    'Porsche': ['Macan','Cayenne','Taycan'],
    'Renault': ['Clio','Megane','Taliant','Captur','Austral'],
    'Seat': ['Ibiza','Leon','Arona','Ateca'],
    'Skoda': ['Fabia','Scala','Octavia','Kamiq','Karoq','Superb'],
    'Suzuki': ['Swift','Vitara','S-Cross'],
    'Tesla': ['Model 3','Model Y','Model S','Model X'],
    'Togg': ['T10X','T10F'],
    'Toyota': ['Corolla','Yaris','C-HR','RAV4'],
    'Volkswagen': ['Polo','Golf','Passat','T-Roc','Tiguan'],
    'Volvo': ['S60','S90','EX30','XC40','XC60','XC90'],
  };

  static Future<List<String>> getMakes() async => _makes;

  static Future<List<String>> getModels(String make) async {
    final clean = make.trim();
    if (clean.isEmpty || clean == 'Diğer') return const [];

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
