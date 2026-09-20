import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heycar_app/parking_place.dart';
import 'package:heycar_app/parking_search_service.dart';

Map<String, dynamic> osm(
        {String type = 'node',
        int id = 1,
        double lat = 41,
        double lon = 29,
        Map<String, String> tags = const {}}) =>
    {
      'type': type,
      'id': id,
      if (type == 'node') ...{'lat': lat, 'lon': lon} else
        'center': {'lat': lat, 'lon': lon},
      'tags': {'amenity': 'parking', ...tags}
    };
http.Response success(List<dynamic> rows) =>
    http.Response(jsonEncode({'elements': rows}), 200);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('parses nodes, way/relation centers; rejects invalid/private places',
      () {
    for (final type in ['node', 'way', 'relation']) {
      final p = ParkingPlace.fromOsm(osm(type: type))!;
      expect(p.id, '$type/1');
      expect(p.latitude, 41);
    }
    expect(ParkingPlace.fromOsm(osm(lat: 91)), isNull);
    expect(ParkingPlace.fromOsm(osm(tags: {'access': 'private'})), isNull);
    expect(
        ParkingPlace.fromOsm({
          'type': 'way',
          'id': 1,
          'tags': {'amenity': 'parking'}
        }),
        isNull);
  });
  test(
      'filters use real tags and Turkish-normalized text; missing data stays unknown',
      () {
    final p = ParkingPlace.fromOsm(osm(tags: {
      'name': 'İSPARK AVM Otoparkı',
      'parking': 'multi-storey',
      'opening_hours': 'Mo-Fr 08:00-20:00'
    }))!;
    expect(p.matches(ParkingFilter.mall), isTrue);
    expect(p.matches(ParkingFilter.municipal), isTrue);
    expect(p.matches(ParkingFilter.multiStorey), isTrue);
    expect(p.matches(ParkingFilter.surface), isFalse);
    expect(p.hoursLabel, 'Mo-Fr 08:00-20:00');
    expect(parkingSearchText('İSPARK ÇAĞLAYAN'), 'ispark caglayan');
    final missing = ParkingPlace.fromOsm(osm())!;
    expect(missing.hours, '');
    expect(missing.address, '');
    expect(missing.typeLabel, 'Tip belirtilmemiş');
    expect(
        ParkingPlace.fromOsm(osm(tags: {'opening_hours': '24/7'}))!.hoursLabel,
        '24 saat açık');
  });
  test('mall filter associates separately mapped nearby mall', () async {
    final s = ParkingSearchService(client: MockClient((_) async => success([
      osm(id: 1, lat: 41, lon: 29),
      {'type': 'way', 'id': 99, 'center': {'lat': 41.0005, 'lon': 29.0005},
       'tags': {'shop': 'mall', 'name': 'Torium AVM'}}
    ])));
    final places = (await s.nearby(41, 29)).places;
    expect(places.single.matches(ParkingFilter.mall), isTrue);
    expect(places.single.name, 'Torium AVM Otoparkı');
  });
  test('distance is measured from the user, not map center', () {
    expect(distanceMeters(41, 29, 41, 29), 0);
    expect(distanceMeters(0, 0, 0, 1), closeTo(111195, 2));
  });
  test(
      'same-cell concurrent lookups share one live request and cache survives reopening',
      () async {
    var calls = 0;
    final gate = Completer<void>();
    final service = ParkingSearchService(client: MockClient((r) async {
      calls++;
      expect(r.method, 'POST');
      expect(r.url.host, 'overpass-api.de');
      expect(r.body, contains('amenity'));
      expect(r.body, isNot(contains('owner')));
      await gate.future;
      return success([osm(), osm()]);
    }));
    final a = service.nearby(41, 29), b = service.nearby(41.001, 29.001);
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    expect((await a).places.length, 1);
    expect((await b).places.length, 1);
    expect(calls, 1);
    await service.nearby(41, 29);
    expect(calls, 1);
    final reopened = ParkingSearchService(client: MockClient((_) async {
      fail('fresh disk cache should avoid network');
    }));
    expect((await reopened.nearby(41, 29)).places.length, 1);
  });
  test(
      'radius clipping is computed for each caller, including shared cache cell',
      () async {
    final s = ParkingSearchService(
        client:
            MockClient((_) async => success([osm(), osm(id: 2, lat: 41.06)])));
    expect((await s.nearby(41, 29)).places.map((p) => p.id), ['node/1']);
  });
  test('empty results are valid and cached', () async {
    var calls = 0;
    final s = ParkingSearchService(client: MockClient((_) async {
      calls++;
      return success([]);
    }));
    expect((await s.nearby(41, 29)).places, isEmpty);
    await s.nearby(41, 29);
    expect(calls, 1);
  });
  for (final bad in [
    http.Response('not json', 200),
    http.Response(
        '{"elements":[],"remark":"runtime error: Query timed out"}', 200),
    http.Response('{}', 200),
    http.Response('unavailable', 503)
  ]) {
    test(
        'bad or partial response does not masquerade as empty success: ${bad.body}',
        () async {
      final s = ParkingSearchService(client: MockClient((_) async => bad));
      await expectLater(
          s.nearby(41, 29), throwsA(isA<ParkingSearchException>()));
    });
  }
  test('network failure uses labelled stale cache for up to 24h only',
      () async {
    var clock = DateTime.utc(2026, 9, 20), failNetwork = false, calls = 0;
    final s = ParkingSearchService(
        now: () => clock,
        client: MockClient((_) async {
          calls++;
          if (failNetwork) throw http.ClientException('offline');
          return success([osm()]);
        }));
    await s.nearby(41, 29);
    clock = clock.add(const Duration(minutes: 16));
    failNetwork = true;
    final r = await s.nearby(41, 29);
    expect(r.stale, isTrue);
    expect(r.places.length, 1);
    expect(calls, 2);
    clock = clock.add(const Duration(hours: 24));
    await expectLater(s.nearby(41, 29), throwsA(isA<ParkingSearchException>()));
  });
  test('429 establishes shared cooldown rather than hammering another area',
      () async {
    var calls = 0;
    final s = ParkingSearchService(client: MockClient((_) async {
      calls++;
      return http.Response('', 429);
    }));
    await expectLater(s.nearby(41, 29), throwsA(isA<ParkingSearchException>()));
    await expectLater(s.nearby(42, 29), throwsA(isA<ParkingSearchException>()));
    expect(calls, 1);
  });
  test('corrupt disk cache falls through to live results', () async {
    SharedPreferences.setMockInitialValues({'cepqar_osm_parking_v1': 'broken'});
    final s =
        ParkingSearchService(client: MockClient((_) async => success([osm()])));
    expect((await s.nearby(41, 29)).places.length, 1);
  });
  test('request spacing is applied when moving between uncached areas',
      () async {
    final waits = <Duration>[];
    final clock = DateTime.utc(2026);
    var calls = 0;
    final s = ParkingSearchService(
        now: () => clock,
        delay: (d) async {
          waits.add(d);
        },
        client: MockClient((_) async {
          calls++;
          return success([]);
        }));
    await s.nearby(41, 29);
    await s.nearby(42, 29);
    expect(calls, 2);
    expect(waits, [const Duration(seconds: 5)]);
  });
}
