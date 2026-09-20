import 'dart:math' as math;

enum ParkingFilter { all, mall, multiStorey, surface, municipal }

String parkingSearchText(String text) => text
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

class ParkingPlace {
  const ParkingPlace({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.tags,
  });
  final String id;
  final double latitude, longitude;
  final Map<String, String> tags;
  static ParkingPlace? fromOsm(Map<String, dynamic> element) {
    final center = element['center'];
    final lat = element['lat'] ?? (center is Map ? center['lat'] : null),
        lon = element['lon'] ?? (center is Map ? center['lon'] : null);
    if (lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        element['id'] == null)
      return null;
    if (!['node', 'way', 'relation'].contains(element['type'])) return null;
    final raw = element['tags'], tags = <String, String>{};
    if (raw is Map)
      raw.forEach((k, v) {
        if (v is String) tags['$k'] = v;
      });
    if (tags['amenity'] != 'parking' ||
        ['private', 'no'].contains(tags['access']))
      return null;
    return ParkingPlace(
      id: '${element['type']}/${element['id']}',
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      tags: Map.unmodifiable(tags),
    );
  }

  Map<String, dynamic> toOsm() => {
    'type': id.split('/').first,
    'id': id.split('/').last,
    'lat': latitude,
    'lon': longitude,
    'tags': tags,
  };
  String get name => tags['name:tr'] ?? tags['name'] ?? 'İsimsiz otopark';
  String get address {
    if ((tags['addr:full'] ?? '').isNotEmpty) return tags['addr:full']!;
    return [
      tags['addr:street'],
      tags['addr:housenumber'],
      tags['addr:suburb'],
      tags['addr:district'],
      tags['addr:city'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
  }

  String get hours => tags['opening_hours'] ?? '';
  // Only unambiguous 24/7 data gets an "open" label. Do not guess complex schedules.
  String get hoursLabel => hours == '24/7' ? '24 saat açık' : hours;
  bool get isMall => RegExp(
    r'\b(avm|mall|alisveris)\b',
  ).hasMatch(parkingSearchText('$name ${tags['operator'] ?? ''}'));
  bool get isMunicipal =>
      ['public', 'government'].contains(tags['operator:type']) ||
      RegExp(
        r'belediye|ispark|municipal',
      ).hasMatch(parkingSearchText('${tags['operator'] ?? ''} $name'));
  bool matches(ParkingFilter f) => switch (f) {
    ParkingFilter.all => true,
    ParkingFilter.mall => isMall,
    ParkingFilter.multiStorey => tags['parking'] == 'multi-storey',
    ParkingFilter.surface => tags['parking'] == 'surface',
    ParkingFilter.municipal => isMunicipal,
  };
  String get typeLabel => switch (tags['parking']) {
    'multi-storey' => 'Katlı Otopark',
    'surface' => 'Açık Otopark',
    'underground' => 'Yeraltı Otoparkı',
    'rooftop' => 'Çatı Otoparkı',
    _ => 'Tip belirtilmemiş',
  };
  double distanceFrom(double lat, double lon) =>
      distanceMeters(lat, lon, latitude, longitude);
  String distanceLabel(double lat, double lon) {
    final d = distanceFrom(lat, lon);
    return d < 1000
        ? '${d.round()} m'
        : '${(d / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}

double distanceMeters(double aLat, double aLon, double bLat, double bLon) {
  const rad = math.pi / 180;
  final dLat = (bLat - aLat) * rad, dLon = (bLon - aLon) * rad;
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(aLat * rad) *
          math.cos(bLat * rad) *
          math.pow(math.sin(dLon / 2), 2);
  return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
}
