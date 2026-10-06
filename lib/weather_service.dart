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

class WeatherHourlyForecast {
  const WeatherHourlyForecast({
    required this.time,
    required this.condition,
    required this.conditionCode,
    required this.isDay,
    this.temperature,
    this.feelsLike,
    this.humidity,
    this.windSpeed,
    this.visibility,
    this.precipitationProbability,
  });

  final DateTime time;
  final WeatherCondition condition;
  final int conditionCode;
  final bool isDay;
  final double? temperature;
  final double? feelsLike;
  final double? humidity;
  final double? windSpeed;
  final double? visibility;
  final double? precipitationProbability;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': time.toIso8601String(),
        'condition': condition.name,
        'conditionCode': conditionCode,
        'isDay': isDay,
        'temperature': temperature,
        'feelsLike': feelsLike,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'visibility': visibility,
        'precipitationProbability': precipitationProbability,
      };

  static WeatherHourlyForecast? fromJson(Map<String, dynamic> json) {
    final time = DateTime.tryParse('${json['time'] ?? ''}');
    if (time == null) return null;
    final code = WeatherService.integer(json['conditionCode']) ?? 2;
    final isDay = json['isDay'] != false;
    return WeatherHourlyForecast(
      time: time,
      condition: WeatherService.conditionFromWmo(code, isDay: isDay),
      conditionCode: code,
      isDay: isDay,
      temperature: WeatherService.number(json['temperature']),
      feelsLike: WeatherService.number(json['feelsLike']),
      humidity: WeatherService.number(json['humidity']),
      windSpeed: WeatherService.number(json['windSpeed']),
      visibility: WeatherService.number(json['visibility']),
      precipitationProbability:
          WeatherService.number(json['precipitationProbability']),
    );
  }
}

class WeatherDailyForecast {
  const WeatherDailyForecast({
    required this.date,
    required this.condition,
    required this.conditionCode,
    this.maxTemperature,
    this.minTemperature,
    this.precipitationProbability,
    this.sunrise,
    this.sunset,
  });

  final DateTime date;
  final WeatherCondition condition;
  final int conditionCode;
  final double? maxTemperature;
  final double? minTemperature;
  final double? precipitationProbability;
  final DateTime? sunrise;
  final DateTime? sunset;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date.toIso8601String(),
        'condition': condition.name,
        'conditionCode': conditionCode,
        'maxTemperature': maxTemperature,
        'minTemperature': minTemperature,
        'precipitationProbability': precipitationProbability,
        'sunrise': sunrise?.toIso8601String(),
        'sunset': sunset?.toIso8601String(),
      };

  static WeatherDailyForecast? fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse('${json['date'] ?? ''}');
    if (date == null) return null;
    final code = WeatherService.integer(json['conditionCode']) ?? 2;
    return WeatherDailyForecast(
      date: date,
      condition: WeatherService.conditionFromWmo(code, isDay: true),
      conditionCode: code,
      maxTemperature: WeatherService.number(json['maxTemperature']),
      minTemperature: WeatherService.number(json['minTemperature']),
      precipitationProbability:
          WeatherService.number(json['precipitationProbability']),
      sunrise: DateTime.tryParse('${json['sunrise'] ?? ''}'),
      sunset: DateTime.tryParse('${json['sunset'] ?? ''}'),
    );
  }
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.condition,
    required this.conditionCode,
    required this.location,
    required this.description,
    required this.fetchedAt,
    required this.isDay,
    this.temperature,
    this.feelsLike,
    this.minTemperature,
    this.maxTemperature,
    this.humidity,
    this.windSpeed,
    this.visibility,
    this.precipitationProbability,
    this.hourlyForecast = const [],
    this.dailyForecast = const [],
    this.sunrise,
    this.sunset,
    this.isFallback = false,
  });

  final WeatherCondition condition;
  final int conditionCode;
  final String location;
  final String description;
  final DateTime fetchedAt;
  final bool isDay;
  final double? temperature;
  final double? feelsLike;
  final double? minTemperature;
  final double? maxTemperature;
  final double? humidity;
  final double? windSpeed;
  final double? visibility;
  final double? precipitationProbability;
  final List<WeatherHourlyForecast> hourlyForecast;
  final List<WeatherDailyForecast> dailyForecast;
  final DateTime? sunrise;
  final DateTime? sunset;
  final bool isFallback;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'condition': condition.name,
        'conditionCode': conditionCode,
        'location': location,
        'description': description,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'isDay': isDay,
        'temperature': temperature,
        'feelsLike': feelsLike,
        'minTemperature': minTemperature,
        'maxTemperature': maxTemperature,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'visibility': visibility,
        'precipitationProbability': precipitationProbability,
        'hourlyForecast': hourlyForecast.map((item) => item.toJson()).toList(),
        'dailyForecast': dailyForecast.map((item) => item.toJson()).toList(),
        'sunrise': sunrise?.toIso8601String(),
        'sunset': sunset?.toIso8601String(),
        'isFallback': isFallback,
      };

  static WeatherSnapshot? fromJson(Map<String, dynamic> json) {
    try {
      final fetchedAt = DateTime.tryParse('${json['fetchedAt'] ?? ''}');
      if (fetchedAt == null) return null;
      final code = WeatherService.integer(json['conditionCode']) ?? 2;
      final isDay = json['isDay'] != false;
      final hourly = (json['hourlyForecast'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => WeatherHourlyForecast.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .whereType<WeatherHourlyForecast>()
          .toList();
      final daily = (json['dailyForecast'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => WeatherDailyForecast.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .whereType<WeatherDailyForecast>()
          .toList();
      return WeatherSnapshot(
        condition: WeatherService.conditionFromWmo(code, isDay: isDay),
        conditionCode: code,
        location: '${json['location'] ?? ''}'.trim(),
        description: '${json['description'] ?? ''}'.trim(),
        fetchedAt: fetchedAt,
        isDay: isDay,
        temperature: WeatherService.number(json['temperature']),
        feelsLike: WeatherService.number(json['feelsLike']),
        minTemperature: WeatherService.number(json['minTemperature']),
        maxTemperature: WeatherService.number(json['maxTemperature']),
        humidity: WeatherService.number(json['humidity']),
        windSpeed: WeatherService.number(json['windSpeed']),
        visibility: WeatherService.number(json['visibility']),
        precipitationProbability:
            WeatherService.number(json['precipitationProbability']),
        hourlyForecast: hourly,
        dailyForecast: daily,
        sunrise: DateTime.tryParse('${json['sunrise'] ?? ''}'),
        sunset: DateTime.tryParse('${json['sunset'] ?? ''}'),
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
  static const _cacheKey = 'owner_weather_snapshot_v2';
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
        conditionCode: 2,
        location: fallbackPlace.isEmpty ? 'İstanbul' : fallbackPlace,
        description: 'Hava durumu şu anda alınamıyor.',
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
      return WeatherSnapshot.fromJson(Map<String, dynamic>.from(decoded));
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
    final lat = number(item['latitude']);
    final lon = number(item['longitude']);
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
        'current':
            'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m',
        'hourly':
            'temperature_2m,apparent_temperature,relative_humidity_2m,precipitation_probability,weather_code,wind_speed_10m,visibility,is_day',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset',
        'timezone': 'auto',
        'forecast_days': '7',
      },
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('WEATHER_API_FAILED');
    final body = jsonDecode(response.body);
    if (body is! Map ||
        body['current'] is! Map ||
        body['hourly'] is! Map ||
        body['daily'] is! Map) {
      throw Exception('WEATHER_API_INVALID');
    }

    final current = Map<String, dynamic>.from(body['current'] as Map);
    final hourly = Map<String, dynamic>.from(body['hourly'] as Map);
    final daily = Map<String, dynamic>.from(body['daily'] as Map);
    final code = integer(current['weather_code']) ?? 2;
    final isDay = (integer(current['is_day']) ?? 1) == 1;

    final hourlyItems = _parseHourly(hourly);
    final dailyItems = _parseDaily(daily);
    final now = DateTime.now();
    WeatherHourlyForecast? nearest;
    if (hourlyItems.isNotEmpty) {
      nearest = hourlyItems.reduce((a, b) =>
          a.time.difference(now).abs() <= b.time.difference(now).abs() ? a : b);
    }
    final today = dailyItems.isEmpty ? null : dailyItems.first;

    return WeatherSnapshot(
      condition: conditionFromWmo(code, isDay: isDay),
      conditionCode: code,
      location: location.label,
      description: descriptionFromWmo(code, isDay: isDay),
      fetchedAt: DateTime.now().toUtc(),
      isDay: isDay,
      temperature: number(current['temperature_2m']),
      feelsLike: number(current['apparent_temperature']) ?? nearest?.feelsLike,
      minTemperature: today?.minTemperature,
      maxTemperature: today?.maxTemperature,
      humidity: number(current['relative_humidity_2m']) ?? nearest?.humidity,
      windSpeed: number(current['wind_speed_10m']) ?? nearest?.windSpeed,
      visibility: nearest?.visibility,
      precipitationProbability: nearest?.precipitationProbability,
      hourlyForecast: _upcomingHourly(hourlyItems, now),
      dailyForecast: dailyItems.take(7).toList(),
      sunrise: today?.sunrise,
      sunset: today?.sunset,
    );
  }

  List<WeatherHourlyForecast> _parseHourly(Map<String, dynamic> data) {
    final times = data['time'] as List? ?? const [];
    final temperatures = data['temperature_2m'] as List? ?? const [];
    final feels = data['apparent_temperature'] as List? ?? const [];
    final humidity = data['relative_humidity_2m'] as List? ?? const [];
    final precipitation =
        data['precipitation_probability'] as List? ?? const [];
    final codes = data['weather_code'] as List? ?? const [];
    final winds = data['wind_speed_10m'] as List? ?? const [];
    final visibility = data['visibility'] as List? ?? const [];
    final dayFlags = data['is_day'] as List? ?? const [];
    final length = [
      times.length,
      temperatures.length,
      codes.length,
    ].reduce((a, b) => a < b ? a : b);
    final result = <WeatherHourlyForecast>[];
    for (var i = 0; i < length; i++) {
      final time = DateTime.tryParse('${times[i]}');
      if (time == null) continue;
      final code = integer(codes[i]) ?? 2;
      final isDay = i < dayFlags.length ? (integer(dayFlags[i]) ?? 1) == 1 : true;
      result.add(WeatherHourlyForecast(
        time: time,
        condition: conditionFromWmo(code, isDay: isDay),
        conditionCode: code,
        isDay: isDay,
        temperature: number(temperatures[i]),
        feelsLike: i < feels.length ? number(feels[i]) : null,
        humidity: i < humidity.length ? number(humidity[i]) : null,
        windSpeed: i < winds.length ? number(winds[i]) : null,
        visibility: i < visibility.length ? number(visibility[i]) : null,
        precipitationProbability:
            i < precipitation.length ? number(precipitation[i]) : null,
      ));
    }
    return result;
  }

  List<WeatherHourlyForecast> _upcomingHourly(
    List<WeatherHourlyForecast> items,
    DateTime now,
  ) {
    final threshold = now.subtract(const Duration(minutes: 45));
    final upcoming = items.where((item) => item.time.isAfter(threshold)).toList();
    return upcoming.take(36).toList();
  }

  List<WeatherDailyForecast> _parseDaily(Map<String, dynamic> data) {
    final dates = data['time'] as List? ?? const [];
    final codes = data['weather_code'] as List? ?? const [];
    final maxValues = data['temperature_2m_max'] as List? ?? const [];
    final minValues = data['temperature_2m_min'] as List? ?? const [];
    final precip = data['precipitation_probability_max'] as List? ?? const [];
    final sunriseValues = data['sunrise'] as List? ?? const [];
    final sunsetValues = data['sunset'] as List? ?? const [];
    final length = [
      dates.length,
      codes.length,
      maxValues.length,
      minValues.length,
    ].reduce((a, b) => a < b ? a : b);
    final result = <WeatherDailyForecast>[];
    for (var i = 0; i < length; i++) {
      final date = DateTime.tryParse('${dates[i]}');
      if (date == null) continue;
      final code = integer(codes[i]) ?? 2;
      result.add(WeatherDailyForecast(
        date: date,
        condition: conditionFromWmo(code, isDay: true),
        conditionCode: code,
        maxTemperature: number(maxValues[i]),
        minTemperature: number(minValues[i]),
        precipitationProbability:
            i < precip.length ? number(precip[i]) : null,
        sunrise: i < sunriseValues.length
            ? DateTime.tryParse('${sunriseValues[i]}')
            : null,
        sunset: i < sunsetValues.length
            ? DateTime.tryParse('${sunsetValues[i]}')
            : null,
      ));
    }
    return result;
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
    if (!isDay && (code == 1 || code == 2)) return 'Parçalı bulutlu gece';
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

  static double? number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  static int? integer(dynamic value) =>
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
