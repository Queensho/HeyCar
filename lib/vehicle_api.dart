import 'dart:convert';
import 'package:http/http.dart' as http;

class VehicleApi {
  static const _base = 'https://vpic.nhtsa.dot.gov/api/vehicles';

  static const List<String> _makes = [
    'Alfa Romeo','Audi','BMW','BYD','Chery','Chevrolet','Chrysler','Citroen','Cupra',
    'Dacia','Daihatsu','DFSK','Dodge','DS Automobiles','Fiat','Ford','Honda','Hyundai',
    'Isuzu','Jaecoo','Jaguar','Jeep','KGM','Kia','Lada','Land Rover','Lexus','Maserati',
    'Maxus','Mazda','Mercedes-Benz','MG','Mini','Mitsubishi','Nissan','Omoda','Opel',
    'Peugeot','Porsche','Proton','Renault','Rover','Saab','Seat','Skoda','Smart','Subaru',
    'Suzuki','SWM','Tesla','Togg','Toyota','Volkswagen','Volvo','Diğer'
  ];

  static const Map<String, String> _logoSlugs = {
    'Alfa Romeo': 'alfaromeo',
    'Audi': 'audi',
    'BMW': 'bmw',
    'BYD': 'byd',
    'Chery': 'chery',
    'Chevrolet': 'chevrolet',
    'Chrysler': 'chrysler',
    'Citroen': 'citroen',
    'Cupra': 'cupra',
    'Dacia': 'dacia',
    'Daihatsu': 'daihatsu',
    'Dodge': 'dodge',
    'DS Automobiles': 'dsautomobiles',
    'Fiat': 'fiat',
    'Ford': 'ford',
    'Honda': 'honda',
    'Hyundai': 'hyundai',
    'Isuzu': 'isuzu',
    'Jaguar': 'jaguar',
    'Jeep': 'jeep',
    'Kia': 'kia',
    'Lada': 'lada',
    'Land Rover': 'landrover',
    'Lexus': 'lexus',
    'Maserati': 'maserati',
    'Mazda': 'mazda',
    'Mercedes-Benz': 'mercedes',
    'MG': 'mg',
    'Mini': 'mini',
    'Mitsubishi': 'mitsubishi',
    'Nissan': 'nissan',
    'Opel': 'opel',
    'Peugeot': 'peugeot',
    'Porsche': 'porsche',
    'Renault': 'renault',
    'Saab': 'saab',
    'Seat': 'seat',
    'Skoda': 'skoda',
    'Smart': 'smart',
    'Subaru': 'subaru',
    'Suzuki': 'suzuki',
    'Tesla': 'tesla',
    'Toyota': 'toyota',
    'Volkswagen': 'volkswagen',
    'Volvo': 'volvo',
  };

  static String? brandLogoUrl(String make) {
    final slug = _logoSlugs[make.trim()];
    if (slug == null) return null;
    return 'https://cdn.simpleicons.org/$slug/FFFFFF';
  }

  static const Map<String, List<String>> _fallbackModels = {
    'Alfa Romeo': ['145','146','147','156','159','Giulietta','MiTo','Giulia','Stelvio','Tonale','Junior'],
    'Audi': ['A1','A3','A4','A5','A6','A7','A8','TT','Q2','Q3','Q4 e-tron','Q5','Q6 e-tron','Q7','Q8','e-tron','e-tron GT'],
    'BMW': ['1 Series','2 Series','3 Series','4 Series','5 Series','6 Series','7 Series','8 Series','X1','X2','X3','X4','X5','X6','X7','Z4','i3','i4','i5','i7','iX','iX1','iX2','iX3'],
    'BYD': ['Atto 2','Atto 3','Dolphin','Seal','Seal U','Sealion 7','Han','Tang'],
    'Chery': ['Omoda 5','Tiggo 4 Pro','Tiggo 7 Pro','Tiggo 8 Pro'],
    'Chevrolet': ['Aveo','Cruze','Lacetti','Kalos','Spark','Captiva','Trax','Epica','Camaro','Corvette'],
    'Chrysler': ['300C','Sebring','PT Cruiser','Voyager','Grand Voyager','Crossfire'],
    'Citroen': ['Saxo','C1','C2','C3','C3 Aircross','C4','C4 X','C4 Cactus','C4 Picasso','C5','C5 Aircross','C-Elysee','Berlingo','Nemo','Jumpy','Ami'],
    'Cupra': ['Leon','Formentor','Born','Ateca','Terramar','Tavascan'],
    'Dacia': ['Logan','Sandero','Sandero Stepway','Duster','Jogger','Lodgy','Dokker','Spring'],
    'Daihatsu': ['Sirion','YRV','Terios','Cuore','Materia'],
    'DFSK': ['Fengon 500','Fengon 5','Fengon 580','E5','C31','C32'],
    'Dodge': ['Caliber','Avenger','Journey','Nitro','Challenger','Charger','Ram'],
    'DS Automobiles': ['DS 3','DS 4','DS 5','DS 7','DS 9'],
    'Fiat': ['Albea','Brava','Bravo','Egea Sedan','Egea Hatchback','Egea Cross','Grande Panda','Linea','Marea','Palio','Panda','Punto','Grande Punto','Siena','Tipo','500','500e','500L','500X','Doblo','Fiorino','Ducato','Freemont'],
    'Ford': ['Escort','Fiesta','Focus','Fusion','Mondeo','Puma','EcoSport','Kuga','Capri','Explorer','Mustang','Mustang Mach-E','B-Max','C-Max','S-Max','Galaxy','Tourneo Courier','Tourneo Connect','Tourneo Custom','Transit Courier','Transit Connect','Transit Custom','Transit','Ranger'],
    'Honda': ['Civic','City','Accord','Jazz','CR-Z','HR-V','CR-V','ZR-V','Prelude'],
    'Hyundai': ['Accent','Accent Era','Accent Blue','Getz','i10','i20','i30','Elantra','Bayon','Kona','Tucson','ix35','Santa Fe','Sonata','Matrix','Ioniq','Ioniq 5','Ioniq 6','Ioniq 9','Inster','Staria'],
    'Isuzu': ['D-Max','NPR','NQR','NLR','NMR'],
    'Jaecoo': ['Jaecoo 7'],
    'Jaguar': ['X-Type','S-Type','XE','XF','XJ','F-Type','E-Pace','F-Pace','I-Pace'],
    'Jeep': ['Avenger','Renegade','Compass','Cherokee','Grand Cherokee','Wrangler'],
    'KGM': ['Tivoli','XLV','Korando','Torres','Rexton','Musso'],
    'Kia': ['Picanto','Rio','Cerato','Ceed','ProCeed','XCeed','Stonic','Soul','Niro','Sportage','Sorento','EV3','EV6','EV9'],
    'Lada': ['Samara','Vega','Niva','Kalina'],
    'Land Rover': ['Freelander','Discovery','Discovery Sport','Defender','Range Rover','Range Rover Sport','Range Rover Evoque','Range Rover Velar'],
    'Lexus': ['CT','IS','ES','LS','LBX','UX','NX','RX'],
    'Maserati': ['Ghibli','Quattroporte','Levante','Grecale','GranTurismo','GranCabrio','MC20'],
    'Maxus': ['e-Deliver 3','e-Deliver 5','e-Deliver 7','e-Deliver 9','T90 EV'],
    'Mazda': ['Mazda 2','Mazda 3','Mazda 6','CX-3','CX-30','CX-5','CX-60','MX-5'],
    'Mercedes-Benz': ['A-Class','B-Class','C-Class','E-Class','S-Class','CLA','CLS','CLE','CLK','SLK','SLC','SL','GLA','GLB','GLC','GLE','GLS','G-Class','EQA','EQB','EQE','EQS','Vito','V-Class'],
    'MG': ['MG3','MG4','MG5','MG7','ZS','HS','Marvel R','Cyberster'],
    'Mini': ['Cooper','Countryman','Clubman','Paceman','Aceman'],
    'Mitsubishi': ['Colt','Lancer','Carisma','ASX','Eclipse Cross','Outlander','Pajero','L200','Space Star'],
    'Nissan': ['Micra','Almera','Primera','Note','Juke','Qashqai','X-Trail','Pathfinder','Navara','Leaf','Ariya'],
    'Omoda': ['Omoda 5','Omoda 7'],
    'Opel': ['Corsa','Astra','Vectra','Insignia','Omega','Calibra','Meriva','Zafira','Adam','Mokka','Crossland','Grandland','Frontera','Combo'],
    'Peugeot': ['106','206','206+','207','208','301','306','307','308','406','407','508','2008','3008','4008','5008','RCZ','Partner','Rifter','Expert'],
    'Porsche': ['718','Boxster','Cayman','911','Panamera','Macan','Cayenne','Taycan'],
    'Proton': ['Saga','Wira','Gen-2','Persona','Savvy'],
    'Renault': ['Clio','Symbol','Thalia','Megane','Megane Sedan','Megane E-Tech','Fluence','Taliant','Captur','Kadjar','Austral','Boreal','Duster','Koleos','Scenic','Scenic E-Tech','Laguna','Latitude','Rafale','Kangoo','Express','Master','Renault 5'],
    'Rover': ['25','45','75','200','400','600','800'],
    'Saab': ['9-3','9-5','900','9000'],
    'Seat': ['Ibiza','Cordoba','Leon','Toledo','Altea','Arona','Ateca','Tarraco'],
    'Skoda': ['Fabia','Rapid','Scala','Octavia','Superb','Roomster','Yeti','Kamiq','Karoq','Kodiaq','Enyaq','Enyaq Coupe','Elroq'],
    'Smart': ['Fortwo','Forfour','#1','#3','#5'],
    'Subaru': ['Impreza','Legacy','XV','Crosstrek','Forester','Outback','BRZ','Solterra'],
    'Suzuki': ['Swift','Baleno','Ignis','Vitara','Grand Vitara','S-Cross','SX4','Jimny'],
    'SWM': ['G01','G01F','G03F','G05','G05 Pro'],
    'Tesla': ['Model S','Model 3','Model X','Model Y'],
    'Togg': ['T10X','T10F'],
    'Toyota': ['Corolla','Corolla Cross','Auris','Yaris','Yaris Cross','C-HR','RAV4','Avensis','Camry','Prius','Verso','Corolla Verso','Land Cruiser','Hilux','Proace City','bZ4X'],
    'Volkswagen': ['Polo','Golf','Passat','Jetta','Bora','Vento','Beetle','Scirocco','Arteon','CC','Taigo','T-Cross','T-Roc','Tayron','Tiguan','Touareg','ID.3','ID.4','ID.5','ID.7','Caddy','Transporter','Caravelle','Amarok'],
    'Volvo': ['S40','S60','S80','S90','V40','V60','V90','C30','C40','XC40','XC60','XC70','XC90','EX30','EX40','EX90'],
  };

  static Future<List<String>> getMakes() async => _makes;

  static Future<List<String>> getModels(String make) async {
    final clean = make.trim();
    if (clean.isEmpty || clean == 'Diğer') return const [];
    final fallback = _fallbackModels[clean] ?? const <String>[];

    try {
      final apiMake = switch (clean) {
        'KGM' => 'SsangYong',
        'DS Automobiles' => 'DS',
        _ => clean,
      };
      final encoded = Uri.encodeComponent(apiMake);
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
      final unique = <String, String>{};
      for (final item in [...fallback, ...apiModels]) {
        final cleanItem = item.trim();
        if (cleanItem.isEmpty) continue;
        unique.putIfAbsent(cleanItem.toLowerCase(), () => cleanItem);
      }
      final merged = unique.values.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return merged;
    } catch (_) {
      return List<String>.from(fallback);
    }
  }
}
