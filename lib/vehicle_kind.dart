/// Vehicle-specific presentation and input policy.
///
/// The backend already persists vehicle_type per vehicle. The active home
/// vehicle decides the dashboard, not the account or scanned QR identity.
class VehicleKind {
  static const car = 'car';
  static const motorcycle = 'motorcycle';

  static String normalize(Object? value) {
    final raw=(value??'').toString().trim().toLowerCase();
    return raw==motorcycle||raw=='moto'||raw=='scooter'
        ?motorcycle:car;
  }

  static bool isMotorcycle(Object? value) => normalize(value)==motorcycle;
  static String label(Object? value) =>
      isMotorcycle(value)?'Motosiklet':'Otomobil';

  // Car model databases are incomplete for Turkish scooters and motorcycles.
  // Let the rider type their model without substituting a car model.
  static const motorcycleMakes=<String>[
    'Aprilia','Arora','Bajaj','Benelli','BMW','CFMoto','Ducati',
    'Harley-Davidson','Hero','Honda','Husqvarna','Kawasaki','Keeway',
    'Kuba','KTM','Kymco','Mondial','Motolux','Moto Guzzi','MV Agusta',
    'Peugeot Motocycles','Piaggio','QJ Motor','RKS','Royal Enfield',
    'Suzuki','SYM','Triumph','TVS','Vespa','Yamaha','Yuki','Zontes','Diğer',
  ];

  static String maintenanceHint(Object? value) =>
      isMotorcycle(value)
          ?'Motor yağı, zincir, lastik, fren ve akü bakımını takip edin.'
          :'Yağ, lastik, fren ve periyodik bakımı takip edin.';
}
