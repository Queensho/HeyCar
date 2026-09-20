import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'parking_place.dart';

class ParkingSearchResult {
  const ParkingSearchResult(this.places, {this.stale = false});
  final List<ParkingPlace> places;
  final bool stale;
}

class ParkingSearchException implements Exception {
  const ParkingSearchException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Only public OSM coordinates are sent. No owner or vehicle identifiers.
class ParkingSearchService {
  ParkingSearchService({
    http.Client? client,
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : _client = client ?? http.Client(),
       _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;
  static final shared = ParkingSearchService();
  static const ttl = Duration(minutes: 15), staleTtl = Duration(hours: 24);
  static const radius = 3000.0;
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.nchc.org.tw/api/interpreter',
  ];
  final http.Client _client;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;
  final Map<String, _Cache> _cache = {};
  final Map<String, Future<ParkingSearchResult>> _pending = {};
  Future<void> _tail = Future.value();
  Future<void>? _hydration;
  DateTime? _lastRequest, _retryAfter;
  Future<ParkingSearchResult> nearby(double latitude, double longitude) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 85 ||
        longitude.abs() > 180)
      throw const ParkingSearchException('Bu konum için arama yapılamıyor.');
    final lat = (latitude * 100).round() / 100,
        lon = (longitude * 100).round() / 100,
        key = '$lat,$lon';
    await (_hydration ??= _hydrate());
    final saved = _cache[key];
    if (saved != null && _fresh(saved, ttl))
      return _within(ParkingSearchResult(saved.places), latitude, longitude);
    final pending = _pending[key];
    if (pending != null) return _within(await pending, latitude, longitude);
    final task = _fetch(key, lat, lon, saved);
    _pending[key] = task;
    try {
      return _within(await task, latitude, longitude);
    } finally {
      _pending.remove(key);
    }
  }

  bool _fresh(_Cache c, Duration limit) {
    final age = _now().difference(c.at);
    return age >= Duration.zero && age < limit;
  }

  ParkingSearchResult _within(ParkingSearchResult r, double lat, double lon) =>
      ParkingSearchResult(
        r.places.where((p) => p.distanceFrom(lat, lon) <= radius).toList(),
        stale: r.stale,
      );
  Future<ParkingSearchResult> _fetch(
    String key,
    double lat,
    double lon,
    _Cache? saved,
  ) {
    final task = _fetchQueued(_tail, key, lat, lon, saved);
    _tail = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  Future<ParkingSearchResult> _fetchQueued(
    Future<void> before,
    String key,
    double lat,
    double lon,
    _Cache? saved,
  ) async {
    await before;
    try {
      if (_retryAfter != null && _now().isBefore(_retryAfter!))
        throw const ParkingSearchException(
          'Otopark servisi yoğun. Biraz sonra tekrar dene.',
        );
      if (_lastRequest != null) {
        final wait =
            const Duration(seconds: 5) - _now().difference(_lastRequest!);
        if (wait > Duration.zero) await _delay(wait);
      }
      _lastRequest = _now();
      // 4 km query covers 3 km radius plus 0.01-degree cache-grid rounding.
      final query =
          '[out:json][timeout:20][maxsize:8388608];('
          'nwr["amenity"="parking"]["access"!="private"]["access"!="no"](around:4000,$lat,$lon);'
          'nwr["shop"="mall"](around:4000,$lat,$lon);'
          ');out center tags;';';
      http.Response? response;
      Object? lastError;
      for (final endpoint in _endpoints) {
        try {
          final candidate = await _client
              .post(
                Uri.parse(endpoint),
                headers: const {
                  'Content-Type':
                      'application/x-www-form-urlencoded; charset=UTF-8',
                  'Accept': 'application/json',
                  'User-Agent': 'Cepqar/1.0 (parking search)',
                },
                body: 'data=${Uri.encodeQueryComponent(query)}',
              )
              .timeout(const Duration(seconds: 10));
          if (candidate.statusCode == 200) {
            response = candidate;
            break;
          }
          lastError = candidate.statusCode;
          if (candidate.statusCode != 400 &&
              candidate.statusCode != 403 &&
              candidate.statusCode != 406 &&
              candidate.statusCode != 429 &&
              candidate.statusCode < 500) {
            response = candidate;
            break;
          }
        } catch (e) {
          lastError = e;
        }
      }
      if (response == null) {
        if (lastError == 429) {
          _retryAfter = _now().add(const Duration(seconds: 60));
          throw const ParkingSearchException(
            'Otopark servisi yoğun. Biraz sonra tekrar dene.',
          );
        }
        throw const ParkingSearchException('Otopark servisine ulaşılamadı.');
      }
      if (response.statusCode == 429 || response.statusCode >= 500)
        _retryAfter = _now().add(const Duration(seconds: 60));
      if (response.statusCode != 200)
        throw const ParkingSearchException('Otopark servisine ulaşılamadı.');
      final data = jsonDecode(response.body);
      if (data is! Map || data['elements'] is! List || data['remark'] != null)
        throw const ParkingSearchException(
          'Otopark sonuçları tamamlanamadı. Tekrar dene.',
        );
      final places = <String, ParkingPlace>{};
      final malls = <({double lat, double lon, String name})>[];
      for (final raw in data['elements'] as List) {
        if (raw is! Map) continue;
        final element = Map<String, dynamic>.from(raw);
        final tags = element['tags'];
        if (tags is Map && tags['shop'] == 'mall') {
          final center = element['center'];
          final mallLat = element['lat'] ?? (center is Map ? center['lat'] : null);
          final mallLon = element['lon'] ?? (center is Map ? center['lon'] : null);
          if (mallLat is num && mallLon is num) {
            malls.add((lat: mallLat.toDouble(), lon: mallLon.toDouble(),
              name: '${tags['name:tr'] ?? tags['name'] ?? ''}'));
          }
          continue;
        }
        final place = ParkingPlace.fromOsm(element);
        if (place != null) places[place.id] = place;
      }
      for (final entry in places.entries.toList()) {
        final place = entry.value;
        if (place.isMall) continue;
        ({double lat, double lon, String name})? nearest;
        var nearestDistance = 250.0;
        for (final mall in malls) {
          final distance = distanceMeters(place.latitude, place.longitude, mall.lat, mall.lon);
          if (distance <= nearestDistance) { nearest = mall; nearestDistance = distance; }
        }
        if (nearest != null) {
          final tags = Map<String, String>.from(place.tags)..['cepqar:mall'] = 'yes';
          if (place.name == 'İsimsiz otopark' && nearest.name.isNotEmpty) {
            tags['name'] = '${nearest.name} Otoparkı';
          }
          places[entry.key] = ParkingPlace(id: place.id, latitude: place.latitude,
            longitude: place.longitude, tags: Map.unmodifiable(tags));
        }
      }
      final cache = _Cache(_now(), places.values.toList());
      _cache.remove(key);
      _cache[key] = cache;
      while (_cache.length > 12) {
        _cache.remove(_cache.keys.first);
      }
      await _persist();
      return ParkingSearchResult(cache.places);
    } catch (e) {
      if (saved != null && _fresh(saved, staleTtl))
        return ParkingSearchResult(saved.places, stale: true);
      if (e is ParkingSearchException) rethrow;
      throw const ParkingSearchException(
        'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.',
      );
    }
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await _preferences(),
          raw = prefs.getString('cepqar_osm_parking_v1');
      if (raw == null) return;
      final rows = jsonDecode(raw);
      if (rows is! List) return;
      for (final row in rows.take(12)) {
        if (row is! Map || row['places'] is! List) continue;
        final at = DateTime.tryParse('${row['at']}');
        if (at == null) continue;
        final c = _Cache(
          at,
          (row['places'] as List)
              .whereType<Map>()
              .map((p) => ParkingPlace.fromOsm(Map<String, dynamic>.from(p)))
              .whereType<ParkingPlace>()
              .toList(),
        );
        if (_fresh(c, staleTtl)) _cache.putIfAbsent('${row['key']}', () => c);
      }
    } catch (_) {
      /* A broken cache must not prevent a live lookup. */
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await _preferences();
      await prefs.setString(
        'cepqar_osm_parking_v1',
        jsonEncode(
          _cache.entries
              .map(
                (e) => {
                  'key': e.key,
                  'at': e.value.at.toIso8601String(),
                  'places': e.value.places.map((p) => p.toOsm()).toList(),
                },
              )
              .toList(),
        ),
      );
    } catch (_) {}
  }
}

class _Cache {
  const _Cache(this.at, this.places);
  final DateTime at;
  final List<ParkingPlace> places;
}
