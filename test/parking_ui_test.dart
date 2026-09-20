import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:heycar_app/parking_places_page.dart';
import 'package:heycar_app/parking_place_detail_page.dart';
import 'package:heycar_app/parking_place.dart';

class FakeLocation extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  bool enabled = true, settingsOpened = false;
  int requests = 0, positions = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    settingsOpened = true;
    return true;
  }

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    positions++;
    throw Exception('GPS unavailable');
  }
}

void main() {
  late GeolocatorPlatform original;
  late FakeLocation location;
  setUp(() {
    original = GeolocatorPlatform.instance;
    location = FakeLocation();
    GeolocatorPlatform.instance = location;
  });
  tearDown(() => GeolocatorPlatform.instance = original);
  testWidgets(
      'permission denial has explicit opt-in and never queries position',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: ParkingPlacesPage(vehicleId: 'v1')));
    await tester.pumpAndSettle();
    expect(find.text('Konum İzni Ver'), findsOneWidget);
    expect(location.requests, 0);
    expect(location.positions, 0);
    await tester.tap(find.text('Konum İzni Ver'));
    await tester.pumpAndSettle();
    expect(location.requests, 1);
    expect(location.positions, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'permanent denial opens settings instead of requesting repeatedly',
      (tester) async {
    location.permission = LocationPermission.deniedForever;
    await tester.pumpWidget(
        const MaterialApp(home: ParkingPlacesPage(vehicleId: 'v1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayarları Aç'));
    await tester.pumpAndSettle();
    expect(location.settingsOpened, isTrue);
    expect(location.requests, 0);
  });
  testWidgets('disabled location has recovery action', (tester) async {
    location.enabled = false;
    await tester.pumpWidget(
        const MaterialApp(home: ParkingPlacesPage(vehicleId: 'v1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('konum servisini aç'), findsOneWidget);
    await tester.tap(find.text('Ayarları Aç'));
    await tester.pumpAndSettle();
    expect(location.settingsOpened, isTrue);
  });
  testWidgets('GPS error ends loading and offers retry', (tester) async {
    location.permission = LocationPermission.whileInUse;
    await tester.pumpWidget(
        const MaterialApp(home: ParkingPlacesPage(vehicleId: 'v1')));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(location.positions, 1);
  });
  testWidgets(
      'detail fits narrow screen with larger text and displays missing-data state',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const place = ParkingPlace(
        id: 'way/1',
        latitude: 41,
        longitude: 29,
        tags: {'name': 'Uzun İsimli Belediye Otoparkı', 'amenity': 'parking'});
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: const ParkingPlaceDetailPage(
            place: place,
            vehicleId: 'v1',
            userLatitude: 41,
            userLongitude: 29)));
    await tester.pumpAndSettle();
    expect(find.text('Burada Park Ettim'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('Saat bilgisi eklenmemiş'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
