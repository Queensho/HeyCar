import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  rain,
  snow,
  thunderstorm,
  night,
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.condition,
    required this.location,
    required this.description,
    required this.fetchedAt,
    required this.isDay,
    this.temperature,
    this.maxTemperature,
    this.minTemperature,
    this.isFallback = false,
  });

  final WeatherCondition condition;
  final String location;
  final String description;
  final DateTime fetchedAt;
  final bool isDay;
  final double? temperature;
  final double? maxTemperature;
  final double? minTemperature;
  final bool isFallback;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'condition': condition.name,
        'location': location,
        'description': description,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'isDay': isDay,
        'temperature': temperature,
        'maxTemperature': maxTemperature,
        'minTemperature': minTemperature,
        'isFallback': isFallback,
      };

  static WeatherSnapshot? fromJson(Map<String, dynamic> json) {
    try {
      final conditionName = '${json['condition'] ?? ''}';
      final condition = WeatherCondition.values.firstWhere(
        (value) => value.name == conditionName,
        orElse: () => WeatherCondition.partlyCloudy,
      );
      final fetchedAt = DateTime.tryParse('${json['fetchedAt'] ?? ''}');
      if (fetchedAt == null) return null;
      double? number(dynamic value) =>
          value is num ? value.toDouble() : double.tryParse('$value');
      return WeatherSnapshot(
        condition: condition,
        location: '${json['location'] ?? ''}'.trim(),
        description: '${json['description'] ?? ''}'.trim(),
        fetchedAt: fetchedAt,
        isDay: json['isDay'] != false,
        temperature: number(json['temperature']),
        maxTemperature: number(json['maxTemperature']),
        minTemperature: number(json['minTemperature']),
        isFallback: json['isFallback'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  static const cacheDuration = Duration(minutes: 30);
  static const _cacheKey = 'owner_weather_snapshot_v1';
  static const _lastLatKey = 'owner_weather_last_lat';
  static const _lastLonKey = 'owner_weather_last_lon';
  static const _lastPlaceKey = 'owner_weather_last_place';
  static const _fallbackCityKey = 'owner_weather_city';

  final http.Client _client;

  Future<WeatherSnapshot> load({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = _readCached(prefs);
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().toUtc().difference(cached.fetchedAt.toUtc()) <
            cacheDuration) {
      return cached;
    }

    try {
      final location = await _resolveLocation(prefs);
      final snapshot = await _fetchWeather(location);
      await prefs.setString(_cacheKey, jsonEncode(snapshot.toJson()));
      return snapshot;
    } catch (_) {
      if (cached != null) return cached;
      final fallbackPlace =
          (prefs.getString(_lastPlaceKey) ??
                  prefs.getString(_fallbackCityKey) ??
                  'İstanbul')
              .trim();
      return WeatherSnapshot(
        condition: WeatherCondition.partlyCloudy,
        location: fallbackPlace.isEmpty ? 'İstanbul' : fallbackPlace,
        description: 'Hava durumu kullanılamıyor',
        fetchedAt: DateTime.now().toUtc(),
        isDay: true,
        isFallback: true,
      );
    }
  }

  WeatherSnapshot? _readCached(SharedPreferences prefs) {
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return WeatherSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<_WeatherLocation> _resolveLocation(SharedPreferences prefs) async {
    Position? position;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (serviceEnabled && granted) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 7),
            ),
          );
        } catch (_) {
          position = await Geolocator.getLastKnownPosition();
        }
      }
    } catch (_) {}

    if (position != null) {
      var label = await _reverseLabel(position.latitude, position.longitude);
      if (label.isEmpty) {
        label = (prefs.getString(_lastPlaceKey) ?? 'Konumum').trim();
      }
      await prefs.setDouble(_lastLatKey, position.latitude);
      await prefs.setDouble(_lastLonKey, position.longitude);
      if (label.isNotEmpty) await prefs.setString(_lastPlaceKey, label);
      return _WeatherLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        label: label.isEmpty ? 'Konumum' : label,
      );
    }

    final savedLat = prefs.getDouble(_lastLatKey);
    final savedLon = prefs.getDouble(_lastLonKey);
    final savedPlace = (prefs.getString(_lastPlaceKey) ?? '').trim();
    if (savedLat != null && savedLon != null) {
      return _WeatherLocation(
        latitude: savedLat,
        longitude: savedLon,
        label: savedPlace.isEmpty ? 'Son konum' : savedPlace,
      );
    }

    final city = (prefs.getString(_fallbackCityKey) ??
            (savedPlace.isNotEmpty ? savedPlace : 'İstanbul'))
        .trim();
    final geocoded = await _geocodeCity(city.isEmpty ? 'İstanbul' : city);
    await prefs.setDouble(_lastLatKey, geocoded.latitude);
    await prefs.setDouble(_lastLonKey, geocoded.longitude);
    await prefs.setString(_lastPlaceKey, geocoded.label);
    return geocoded;
  }

  Future<_WeatherLocation> _geocodeCity(String city) async {
    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      <String, String>{
        'name': city,
        'count': '1',
        'language': 'tr',
        'format': 'json',
        'countryCode': 'TR',
      },
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw Exception('WEATHER_GEOCODE_FAILED');
    final body = jsonDecode(response.body);
    final results = body is Map ? body['results'] : null;
    if (results is! List || results.isEmpty || results.first is! Map) {
      throw Exception('WEATHER_CITY_NOT_FOUND');
    }
    final item = Map<String, dynamic>.from(results.first as Map);
    final lat = _number(item['latitude']);
    final lon = _number(item['longitude']);
    if (lat == null || lon == null) throw Exception('WEATHER_CITY_INVALID');
    final label = '${item['name'] ?? city}'.trim();
    return _WeatherLocation(
      latitude: lat,
      longitude: lon,
      label: label.isEmpty ? city : label,
    );
  }

  Future<String> _reverseLabel(double lat, double lon) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        <String, String>{
          'format': 'jsonv2',
          'lat': lat.toStringAsFixed(6),
          'lon': lon.toStringAsFixed(6),
          'accept-language': 'tr',
        },
      );
      final response = await _client.get(
        uri,
        headers: const {'User-Agent': 'CepQontag/1.0'},
      ).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return '';
      final body = jsonDecode(response.body);
      if (body is! Map || body['address'] is! Map) return '';
      final address = Map<String, dynamic>.from(body['address'] as Map);
      for (final key in const [
        'town',
        'city_district',
        'suburb',
        'municipality',
        'county',
        'city',
      ]) {
        final value = '${address[key] ?? ''}'.trim();
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}
    return '';
  }

  Future<WeatherSnapshot> _fetchWeather(_WeatherLocation location) async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      <String, String>{
        'latitude': location.latitude.toStringAsFixed(5),
        'longitude': location.longitude.toStringAsFixed(5),
        'current': 'temperature_2m,weather_code,is_day',
        'daily': 'temperature_2m_max,temperature_2m_min',
        'timezone': 'auto',
        'forecast_days': '1',
      },
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('WEATHER_API_FAILED');
    final body = jsonDecode(response.body);
    if (body is! Map || body['current'] is! Map || body['daily'] is! Map) {
      throw Exception('WEATHER_API_INVALID');
    }
    final current = Map<String, dynamic>.from(body['current'] as Map);
    final daily = Map<String, dynamic>.from(body['daily'] as Map);
    final code = _integer(current['weather_code']) ?? 2;
    final isDay = (_integer(current['is_day']) ?? 1) == 1;
    final maxValues = daily['temperature_2m_max'];
    final minValues = daily['temperature_2m_min'];

    return WeatherSnapshot(
      condition: conditionFromWmo(code, isDay: isDay),
      location: location.label,
      description: descriptionFromWmo(code, isDay: isDay),
      fetchedAt: DateTime.now().toUtc(),
      isDay: isDay,
      temperature: _number(current['temperature_2m']),
      maxTemperature:
          maxValues is List && maxValues.isNotEmpty ? _number(maxValues.first) : null,
      minTemperature:
          minValues is List && minValues.isNotEmpty ? _number(minValues.first) : null,
    );
  }

  static WeatherCondition conditionFromWmo(
    int code, {
    required bool isDay,
  }) {
    if (!isDay) return WeatherCondition.night;
    if (code == 0) return WeatherCondition.clear;
    if (code == 1 || code == 2) return WeatherCondition.partlyCloudy;
    if (code == 3 || code == 45 || code == 48) {
      return WeatherCondition.cloudy;
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return WeatherCondition.rain;
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return WeatherCondition.snow;
    }
    if (code >= 95) return WeatherCondition.thunderstorm;
    return WeatherCondition.partlyCloudy;
  }

  static String descriptionFromWmo(int code, {required bool isDay}) {
    if (!isDay && code == 0) return 'Açık gece';
    if (code == 0) return 'Açık';
    if (code == 1) return 'Az bulutlu';
    if (code == 2) return 'Parçalı bulutlu';
    if (code == 3) return 'Kapalı';
    if (code == 45 || code == 48) return 'Sisli';
    if (code >= 51 && code <= 57) return 'Çisenti';
    if (code >= 61 && code <= 67) return 'Yağmurlu';
    if (code >= 71 && code <= 77) return 'Karlı';
    if (code >= 80 && code <= 82) return 'Sağanak yağış';
    if (code == 85 || code == 86) return 'Kar sağanağı';
    if (code >= 95) return 'Gök gürültülü';
    return 'Parçalı bulutlu';
  }

  static double? _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  static int? _integer(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  void dispose() => _client.close();
}

class _WeatherLocation {
  const _WeatherLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}
