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
    'Audi': ['A1','A3','A4','A5','A6','A7','A8','Q2','Q3','Q5','Q7','Q8','e-tron','Q4 e-tron'],
    'BMW': ['1 Series','2 Series','3 Series','4 Series','5 Series','7 Series','X1','X2','X3','X4','X5','X6','X7','i4','i5','i7','iX','iX1'],
    'BYD': ['Atto 3','Dolphin','Seal','Seal U','Han','Tang'],
    'Chery': ['Omoda 5','Tiggo 4 Pro','Tiggo 7 Pro','Tiggo 8 Pro'],
    'Citroen': ['C1','C3','C3 Aircross','C4','C4 X','C5 Aircross','Berlingo','Jumpy'],
    'Cupra': ['Formentor','Leon','Born','Ateca','Terramar'],
    'Dacia': ['Duster','Jogger','Sandero','Sandero Stepway','Logan','Lodgy','Dokker','Spring'],
    'Fiat': ['Egea','Egea Cross','500','500X','500L','Panda','Punto','Linea','Bravo','Doblo','Fiorino','Ducato'],
    'Ford': ['Focus','Fiesta','Puma','Kuga','Mondeo','EcoSport','Mustang','Mustang Mach-E','Courier','Tourneo Courier','Tourneo Custom','Transit','Ranger'],
    'Honda': ['Civic','City','Jazz','Accord','HR-V','CR-V','ZR-V'],
    'Hyundai': ['i10','i20','i30','Accent','Elantra','Bayon','Kona','Tucson','Santa Fe','Ioniq 5','Ioniq 6'],
    'Jeep': ['Avenger','Renegade','Compass','Cherokee','Grand Cherokee','Wrangler'],
    'Kia': ['Picanto','Rio','Ceed','Stonic','Niro','Sportage','Sorento','EV3','EV6','EV9'],
    'Land Rover': ['Range Rover','Range Rover Sport','Range Rover Evoque','Discovery','Discovery Sport','Defender'],
    'Lexus': ['LBX','UX','NX','RX','ES','LS'],
    'Mazda': ['Mazda 2','Mazda 3','Mazda 6','CX-3','CX-30','CX-5','CX-60'],
    'Mercedes-Benz': ['A-Class','B-Class','C-Class','E-Class','S-Class','CLA','CLS','GLA','GLB','GLC','GLE','GLS','EQA','EQB','EQE','EQS','Vito'],
    'MG': ['MG3','MG4','MG5','ZS','HS','Marvel R','Cyberster'],
    'Mini': ['Cooper','Countryman','Clubman','Aceman'],
    'Nissan': ['Micra','Note','Almera','Juke','Qashqai','X-Trail','Ariya','Navara'],
    'Opel': ['Corsa','Astra','Insignia','Mokka','Crossland','Grandland','Combo','Zafira'],
    'Peugeot': ['106','206','207','208','301','307','308','407','508','2008','3008','5008','Rifter','Partner'],
    'Porsche': ['718','911','Panamera','Macan','Cayenne','Taycan'],
    'Renault': ['Clio','Symbol','Taliant','Megane','Fluence','Laguna','Captur','Austral','Kadjar','Koleos','Scenic','Kangoo','Express','Master','Rafale'],
    'Seat': ['Ibiza','Leon','Toledo','Cordoba','Arona','Ateca','Tarraco'],
    'Skoda': ['Fabia','Scala','Octavia','Superb','Kamiq','Karoq','Kodiaq','Enyaq'],
    'Suzuki': ['Swift','Ignis','Baleno','Vitara','S-Cross','Jimny'],
    'Tesla': ['Model 3','Model Y','Model S','Model X'],
    'Togg': ['T10X','T10F'],
    'Toyota': ['Yaris','Yaris Cross','Corolla','Corolla Cross','Auris','Avensis','Camry','C-HR','RAV4','Land Cruiser','Hilux','Proace City','bZ4X'],
    'Volkswagen': ['Polo','Golf','Jetta','Passat','Arteon','T-Cross','T-Roc','Tiguan','Touareg','Taigo','Caddy','Transporter','Amarok','ID.3','ID.4','ID.7'],
    'Volvo': ['S40','S60','S90','V40','V60','V90','C30','XC40','XC60','XC90','EX30','EX40'],
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

      if (response.statusCode != 200) return List<String>.from(fallback);

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return List<String>.from(fallback);

      final rows = decoded['Results'];
      if (rows is! List) return List<String>.from(fallback);

      final apiModels = rows
          .whereType<Map<String, dynamic>>()
          .map((e) => e['Model_Name']?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();

      final merged = <String>{...fallback, ...apiModels}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      return merged;
    } catch (_) {
      return List<String>.from(fallback);
    }
  }
}
