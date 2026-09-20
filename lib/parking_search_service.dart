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
          '[out:json][timeout:20][maxsize:8388608];nwr["amenity"="parking"]["access"!="private"]["access"!="no"](around:4000,$lat,$lon);out center tags;';
      final response = await _client
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 28));
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
      for (final raw in data['elements'] as List) {
        if (raw is! Map) continue;
        final place = ParkingPlace.fromOsm(Map<String, dynamic>.from(raw));
        if (place != null) places[place.id] = place;
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
