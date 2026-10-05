import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cepqar_theme.dart';
import 'owner_auth.dart';
import 'driver_auth.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'vehicle_photo.dart';

class TowingFlowPage extends StatefulWidget {
  const TowingFlowPage({
    super.key,
    this.driverMode = false,
    this.vehicleId,
  });

  final bool driverMode;
  final String? vehicleId;

  @override
  State<TowingFlowPage> createState() => _TowingFlowPageState();
}

class _TowingFlowPageState extends State<TowingFlowPage> {
  static const _purple = Color(0xFF6F35F4);
  static const _purple2 = Color(0xFF8D4DFF);
  static const _ink = Color(0xFF101828);
  static const _muted = Color(0xFF7D8494);
  static const _line = Color(0xFFE6E8EF);
  static const _soft = Color(0xFFF7F7FB);

  final MapController _mapController = MapController();
  final TextEditingController dest = TextEditingController();

  int step = 0;
  bool busy = false;
  bool locating = false;
  bool notRunning = true;
  bool destSearching = false;

  String vehicleType = 'car';
  String truck = 'platform';
  String truckName = 'Standart çekici';
  String vehicleIdResolved = '';
  String vehiclePlate = '';
  String vehicleMake = '';
  String vehicleModel = '';

  double? a, b, x, y;
  double startingFee = 750;
  double perKmFee = 25;
  Map<String, Map<String, dynamic>> vehiclePricing = {};
  String pickup = 'Konumum';
  String dropoff = 'Adres veya yer adı yaz';

  Map<String, dynamic>? quote;
  List<Map<String, dynamic>> destResults = [];
  Timer? destDebounce;

  String get api => OnboardingBackend.baseUrl;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    destDebounce?.cancel();
    dest.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      locate(silent: true),
      _loadVehicle(),
      _loadOptions(),
    ]);
  }

  void msg(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Future<void> _loadVehicle() async {
    try {
      final uri = Uri.parse(
        '$api${widget.driverMode ? '/api/driver/vehicles' : '/api/owner/vehicles'}',
      );
      final response = widget.driverMode
          ? await DriverHttp.get(uri, json: false)
          : await OwnerHttp.get(uri, json: false);
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      final rows = decoded is Map && decoded['vehicles'] is List
          ? (decoded['vehicles'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (rows.isEmpty) return;

      final wanted = (widget.driverMode
              ? (widget.vehicleId ?? '')
              : QrDraft.vehicleId)
          .trim();

      Map<String, dynamic> selected = rows.first;
      for (final row in rows) {
        final id = '${row[widget.driverMode ? 'vehicle_id' : 'id'] ?? ''}';
        if (wanted.isNotEmpty && id == wanted) {
          selected = row;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        vehicleIdResolved =
            '${selected[widget.driverMode ? 'vehicle_id' : 'id'] ?? wanted}';
        vehiclePlate = '${selected['plate'] ?? ''}'.trim();
        vehicleMake = '${selected['make'] ?? ''}'.trim();
        vehicleModel = '${selected['model'] ?? ''}'.trim();
      });
    } catch (_) {}
  }

  Future<void> _loadOptions() async {
    try {
      final r = await http
          .get(Uri.parse('$api/api/towing/options'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return;
      final d = jsonDecode(r.body);
      if (d is! Map || d['truckTypes'] is! List || d['vehicleTypes'] is! List) {
        return;
      }

      final trucks = (d['truckTypes'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final vehicles = (d['vehicleTypes'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (trucks.isEmpty || vehicles.isEmpty) return;

      Map<String, dynamic> selectedTruck = trucks.first;
      for (final item in trucks) {
        if ('${item['code']}' == truck) {
          selectedTruck = item;
          break;
        }
      }

      final pricing = <String, Map<String, dynamic>>{};
      for (final item in vehicles) {
        final code = '${item['code'] ?? ''}'.trim();
        if (code.isNotEmpty) pricing[code] = item;
      }
      final selectedVehicle = pricing[vehicleType];

      if (!mounted) return;
      setState(() {
        vehiclePricing = pricing;
        truck = '${selectedTruck['code'] ?? truck}';
        truckName = '${selectedTruck['name'] ?? 'Standart çekici'}';
        startingFee = double.tryParse(
              '${selectedVehicle?['base_fee'] ?? selectedVehicle?['minimum_fee'] ?? 750}',
            ) ??
            750;
        perKmFee =
            double.tryParse('${selectedVehicle?['per_km_fee'] ?? 25}') ?? 25;
      });
    } catch (_) {}
  }

  void _selectVehicleType(String id) {
    final pricing = vehiclePricing[id];
    setState(() {
      vehicleType = id;
      quote = null;
      if (pricing != null) {
        startingFee = double.tryParse(
              '${pricing['base_fee'] ?? pricing['minimum_fee'] ?? startingFee}',
            ) ??
            startingFee;
        perKmFee =
            double.tryParse('${pricing['per_km_fee'] ?? perKmFee}') ?? perKmFee;
      }
    });
  }

  Future<String> address(double lat, double lng) async {
    try {
      final r = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=jsonv2&lat=$lat&lon=$lng&accept-language=tr',
        ),
        headers: {'User-Agent': 'CepQontag/1.0'},
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final m = d['address'] ?? {};
        final district =
            m['town'] ?? m['city_district'] ?? m['suburb'] ?? m['city'];
        final city = m['province'] ?? m['city'];
        if (district != null && city != null) return '$district, $city';
      }
    } catch (_) {}
    return 'Seçilen konum';
  }

  Future<void> locate({bool silent = false}) async {
    if (mounted) setState(() => locating = true);
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        throw Exception();
      }
      final z = await Geolocator.getCurrentPosition();
      final ad = await address(z.latitude, z.longitude);
      if (!mounted) return;
      setState(() {
        a = z.latitude;
        b = z.longitude;
        pickup = ad;
      });
      try {
        _mapController.move(LatLng(z.latitude, z.longitude), 14);
      } catch (_) {}
    } catch (_) {
      if (!silent) msg('Konum alınamadı.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  double get km => (a == null || x == null)
      ? 0
      : Geolocator.distanceBetween(a!, b!, x!, y!) / 1000;

  String get pickupTitle {
    final parts = pickup.split(',');
    return parts.first.trim().isEmpty ? 'Konumum' : parts.first.trim();
  }

  String get pickupSubtitle {
    final parts = pickup.split(',');
    if (parts.length > 1) {
      return '${parts.skip(1).join(',').trim()}, Türkiye';
    }
    return 'İstanbul, Türkiye';
  }

  Future<void> chooseDrop(LatLng p) async {
    final ad = await address(p.latitude, p.longitude);
    if (!mounted) return;
    setState(() {
      x = p.latitude;
      y = p.longitude;
      dropoff = ad;
      dest.text = ad;
      destResults = [];
      quote = null;
    });
  }

  Future<void> searchDestination(String value) async {
    destDebounce?.cancel();
    final q = value.trim();
    if (q.length < 3) {
      if (mounted) setState(() => destResults = []);
      return;
    }

    destDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (mounted) setState(() => destSearching = true);
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'format': 'jsonv2',
          'q': q,
          'countrycodes': 'tr',
          'limit': '5',
          'addressdetails': '1',
          'accept-language': 'tr',
        });
        final r =
            await http.get(uri, headers: {'User-Agent': 'CepQontag/1.0'});
        if (r.statusCode == 200 && mounted) {
          final list =
              (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
          setState(() => destResults = list);
        }
      } catch (_) {
        if (mounted) setState(() => destResults = []);
      } finally {
        if (mounted) setState(() => destSearching = false);
      }
    });
  }

  void selectDestination(Map<String, dynamic> item) {
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    if (lat == null || lon == null) return;
    final label = '${item['display_name'] ?? 'Seçilen adres'}';
    FocusScope.of(context).unfocus();
    setState(() {
      x = lat;
      y = lon;
      dropoff = label;
      dest.text = label;
      destResults = [];
      quote = null;
    });
  }

  void _swapLocations() {
    if (a == null || b == null || x == null || y == null) {
      msg('Önce bırakma noktasını seç.');
      return;
    }
    setState(() {
      final oldA = a;
      final oldB = b;
      final oldPickup = pickup;
      a = x;
      b = y;
      pickup = dropoff;
      x = oldA;
      y = oldB;
      dropoff = oldPickup;
      dest.text = oldPickup;
      quote = null;
    });
  }

  void _vehicleHelp() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Hangi aracı seçmeliyim?',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 12),
              Text('Binek: Sedan, hatchback ve standart otomobiller.'),
              SizedBox(height: 7),
              Text('SUV / 4x4: Yüksek ve ağır arazi tipi araçlar.'),
              SizedBox(height: 7),
              Text('Hafif Ticari: Panelvan, minivan ve hafif ticari araçlar.'),
              SizedBox(height: 7),
              Text('Motosiklet: Scooter ve motosikletler.'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> price() async {
    if (a == null || x == null) {
      msg('Alım ve bırakma konumunu seç.');
      return;
    }
    setState(() => busy = true);
    try {
      final uri = Uri.parse(
        '$api${widget.driverMode ? '/api/driver/towing/quote' : '/api/owner/towing/quote'}',
      );
      final body = jsonEncode({
        'distanceKm': km,
        'vehicleType': vehicleType,
        'truckType': truck,
      });
      final r = widget.driverMode
          ? await DriverHttp.post(uri, body: body)
          : await OwnerHttp.post(uri, body: body);
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['quote'] is Map && mounted) {
        setState(() {
          quote = Map<String, dynamic>.from(d['quote']);
          step = 1;
        });
      } else {
        final e = '${d['error'] ?? ''}';
        msg(
          e == 'TOWING_OPTION_NOT_AVAILABLE'
              ? 'Bu araç/çekici tipi için fiyatlandırma henüz aktif değil.'
              : e == 'OWNER_REQUIRED'
                  ? 'Oturum süren dolmuş. Tekrar giriş yap.'
                  : 'Fiyat hesaplanamadı.',
        );
      }
    } catch (_) {
      msg('Fiyat hesaplanamadı. Bağlantını kontrol et.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> call() async {
    if (a == null || b == null || x == null || y == null) {
      msg('Alım ve bırakma konumunu seç.');
      return;
    }
    setState(() => busy = true);
    try {
      final selectedVehicle = vehicleIdResolved.isNotEmpty
          ? vehicleIdResolved
          : (widget.driverMode ? (widget.vehicleId ?? '') : QrDraft.vehicleId);
      final uri = Uri.parse(
        '$api${widget.driverMode ? '/api/driver/towing/requests' : '/api/owner/towing/requests'}',
      );
      final body = jsonEncode({
        'vehicleId': selectedVehicle,
        'vehicleType': vehicleType,
        'truckType': truck,
        'issueType': notRunning ? 'Araç çalışmıyor' : 'Çekici',
        'pickupLat': a,
        'pickupLng': b,
        'pickupAddress': pickup,
        'destinationLat': x,
        'destinationLng': y,
        'destinationAddress': dropoff,
        'distanceKm': km,
      });
      final r = widget.driverMode
          ? await DriverHttp.post(uri, body: body)
          : await OwnerHttp.post(uri, body: body);
      final d = jsonDecode(r.body);
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final id = '${d['request']['id']}';
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TowingTrackingPage(id: id, driverMode: widget.driverMode),
            ),
          );
        }
      } else {
        final e = '${d['error'] ?? ''}';
        msg(
          e == 'ACTIVE_TOWING_REQUEST_EXISTS'
              ? 'Aktif çekici çağrın zaten var.'
              : e == 'DRIVER_NOT_ACTIVE'
                  ? 'Çekiciyi yalnızca aktif sürücü çağırabilir.'
                  : 'Çağrı oluşturulamadı.',
        );
      }
    } catch (_) {
      msg('Çağrı oluşturulamadı.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _map() {
    final center = LatLng(a ?? 41.0, b ?? 28.9);
    return SizedBox(
      height: 164,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                  minZoom: 11,
                  maxZoom: 18,
                  onTap: (_, p) => chooseDrop(p),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      -.12, -.24, -.04, 0, 105,
                      -.15, -.30, -.05, 0, 123,
                      -.18, -.36, -.06, 0, 156,
                      0, 0, 0, 1, 0,
                    ]),
                    child: TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cepqar.app',
                      maxNativeZoom: 19,
                      panBuffer: 0,
                    ),
                  ),
                  if (a != null && x != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [LatLng(a!, b!), LatLng(x!, y!)],
                          strokeWidth: 4,
                          color: _purple.withValues(alpha: .75),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (a != null)
                        Marker(
                          point: LatLng(a!, b!),
                          width: 48,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _purple.withValues(alpha: .24),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _purple,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: _purple.withValues(alpha: .45),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (x != null)
                        Marker(
                          point: LatLng(x!, y!),
                          width: 46,
                          height: 54,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: _purple2,
                            size: 46,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: locating ? null : () => locate(),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: locating
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child:
                                CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(
                            Icons.my_location_rounded,
                            color: _purple,
                            size: 23,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickupCard() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: _purple, size: 25),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickupTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pickupSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: _line),
          const SizedBox(width: 9),
          const Text(
            'Konumu\nharitada gör',
            textAlign: TextAlign.left,
            style: TextStyle(
              color: _purple,
              fontSize: 9.2,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.chevron_right_rounded, color: _purple, size: 20),
        ],
      ),
    );
  }

  Widget _currentLocationRow() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: locating ? null : () => locate(),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded,
                      color: _purple, size: 24),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Konumum',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Mevcut konumumu kullan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 9.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: _swapLocations,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _purple, width: 1.7),
            ),
            child:
                const Icon(Icons.swap_vert_rounded, color: _purple, size: 25),
          ),
        ),
      ],
    );
  }

  Widget _destinationField() {
    return Column(
      children: [
        TextField(
          controller: dest,
          onChanged: searchDestination,
          style: const TextStyle(
            color: _ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Adres veya yer adı yaz',
            hintStyle: const TextStyle(
              color: Color(0xFF9298A8),
              fontWeight: FontWeight.w600,
            ),
            prefixIcon:
                const Icon(Icons.location_on_rounded, color: _purple, size: 24),
            suffixIcon: destSearching
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : dest.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            dest.clear();
                            dropoff = 'Adres veya yer adı yaz';
                            x = null;
                            y = null;
                            destResults = [];
                            quote = null;
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: _purple, width: 1.6),
            ),
          ),
        ),
        if (destResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: destResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = destResults[i];
                return ListTile(
                  dense: true,
                  leading:
                      const Icon(Icons.place_outlined, color: _purple),
                  title: Text(
                    '${item['display_name'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => selectDestination(item),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _vehicleSummaryCard() {
    final makeModel = [vehicleMake, vehicleModel]
        .where((e) => e.trim().isNotEmpty)
        .join(' ');
    return Container(
      height: 62,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF2EEFF),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: VehiclePhoto(
              make: vehicleMake,
              model: vehicleModel,
              width: 86,
              height: 46,
              borderRadius: 13,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Binek Otomobil',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (makeModel.isNotEmpty) makeModel,
                    if (vehiclePlate.isNotEmpty) vehiclePlate,
                  ].join(' • ').isEmpty
                      ? 'Araç bilgisi'
                      : [
                          if (makeModel.isNotEmpty) makeModel,
                          if (vehiclePlate.isNotEmpty) vehiclePlate,
                        ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFF747B8C), size: 21),
        ],
      ),
    );
  }

  Widget _vehicleChip(String id, IconData icon, String label) {
    final selected = vehicleType == id;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _selectVehicleType(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 54,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [_purple2, _purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? Colors.transparent : _line,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _purple.withValues(alpha: .18),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF3E4658),
                size: 21,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : _ink,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _towOptionCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 94,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fire_truck_rounded,
                  size: 48,
                  color: Color(0xFF556071),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truckName.isEmpty ? 'Standart çekici' : truckName,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Binek araçlar için uygundur',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Container(height: 1, color: _line),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 31,
                      height: 31,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF9EF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: Color(0xFF12A84D),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tahmini varış',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '12 dk',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 34, color: _line),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 37,
                      height: 37,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3EDFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stacked_bar_chart_rounded,
                        color: _purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Başlangıç ücreti',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₺${startingFee.toStringAsFixed(startingFee % 1 == 0 ? 0 : 2)}',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mainForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth > 600 ? 22.0 : 12.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(side, 0, side, 10),
          child: Column(
            children: [
              _map(),
              Transform.translate(
                offset: const Offset(0, -12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x10000000),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nereden alınacak?',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _pickupCard(),
                      const SizedBox(height: 7),
                      _currentLocationRow(),
                      const SizedBox(height: 12),
                      const Text(
                        'Nereye bırakılacak?',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _destinationField(),
                      const SizedBox(height: 5),
                      const Text(
                        'İstersen bırakma noktasını haritada seçebilirsin.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Araç tipi',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _vehicleHelp,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: _purple,
                                    size: 17,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Hangi aracı seçmeliyim?',
                                    style: TextStyle(
                                      color: _purple,
                                      fontSize: 10.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      _vehicleSummaryCard(),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _vehicleChip(
                            'car',
                            Icons.directions_car_filled_rounded,
                            'Binek',
                          ),
                          const SizedBox(width: 7),
                          _vehicleChip(
                            'suv_pickup',
                            Icons.directions_car_rounded,
                            'SUV / 4x4',
                          ),
                          const SizedBox(width: 7),
                          _vehicleChip(
                            'light_commercial',
                            Icons.local_shipping_outlined,
                            'Hafif Ticari',
                          ),
                          const SizedBox(width: 7),
                          _vehicleChip(
                            'motorcycle',
                            Icons.two_wheeler_rounded,
                            'Motosiklet',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Çekici seçeneği',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _towOptionCard(),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_purple2, _purple],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: _purple.withValues(alpha: .24),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: busy ? null : call,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (busy)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                else ...[
                                  const Icon(
                                    Icons.fire_truck_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                  const SizedBox(width: 7),
                                  const Text(
                                    'Çekici Çağır',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quoteStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _map(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tahmini Ücret',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _routeRow(Icons.my_location_rounded, pickup),
                const SizedBox(height: 9),
                _routeRow(Icons.location_on_rounded, dropoff),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${km.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${quote?['total'] ?? '-'} ${quote?['currency'] ?? 'TL'}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: busy ? null : call,
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fire_truck_rounded),
                    label: Text(
                      busy ? 'Gönderiliyor...' : 'Çekici Çağır',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _purple, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _soft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _ink,
        centerTitle: true,
        elevation: 0,
        title: Text(
          step == 0 ? 'Çekici Çağır' : 'Tahmini Ücret',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            if (step == 1) {
              setState(() => step = 0);
            } else {
              Navigator.maybePop(context);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 26),
        ),
      ),
      body: SafeArea(
        top: false,
        child: step == 0 ? _mainForm() : _quoteStep(),
      ),
    );
  }
}

class TowingTrackingPage extends StatefulWidget {
  const TowingTrackingPage({
    super.key,
    required this.id,
    this.driverMode = false,
  });

  final String id;
  final bool driverMode;

  @override
  State<TowingTrackingPage> createState() => _TowingTrackingPageState();
}

class _TowingTrackingPageState extends State<TowingTrackingPage> {
  static const _purple = Color(0xFF6C31F4);
  static const _purple2 = Color(0xFF8A4DFF);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF7D8496);
  static const _line = Color(0xFFE7E9F0);
  static const _bg = Color(0xFFF8F9FD);

  Map<String, dynamic>? data;
  Timer? timer;
  bool cancelling = false;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final uri = Uri.parse(
        '${OnboardingBackend.baseUrl}'
        '${widget.driverMode ? '/api/driver/towing/requests/' : '/api/owner/towing/requests/'}'
        '${widget.id}/tracking',
      );
      final r = widget.driverMode
          ? await DriverHttp.get(uri)
          : await OwnerHttp.get(uri);
      if (r.statusCode == 200 && mounted) {
        setState(() {
          data = Map<String, dynamic>.from(
            jsonDecode(r.body)['tracking'],
          );
        });
      }
    } catch (_) {}
  }

  double? _number(dynamic value) => double.tryParse('${value ?? ''}');

  String _statusLabel(String status) => {
        'searching': 'Yakındaki çekiciler aranıyor',
        'accepted': 'Çekici bulundu',
        'arriving': 'Çekici size geliyor',
        'arrived': 'Çekici geldi',
        'vehicle_loaded': 'Aracınız yüklendi',
        'in_transit': 'Aracınız hedefe gidiyor',
        'delivered': 'Teslim edildi',
        'cancelled': 'İptal edildi',
      }[status] ??
      status;

  String _etaText(String status) {
    dynamic value;
    if (status == 'vehicle_loaded' || status == 'in_transit') {
      value = data?['destination_eta_minutes'];
    } else {
      value = data?['pickup_eta_minutes'];
    }
    final parsed = _number(value);
    if (parsed == null) return '-';
    final minutes = parsed <= 1 ? 1 : parsed.round();
    return '$minutes dk';
  }

  String _distanceText(String status) {
    dynamic value;
    if (status == 'vehicle_loaded' || status == 'in_transit') {
      value = data?['destination_distance_km'];
    } else {
      value = data?['pickup_distance_km'];
    }
    final parsed = _number(value);
    if (parsed == null) return '-';
    return '${parsed.toStringAsFixed(2)} km';
  }

  String _shortAddress(dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return '-';
    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) return '${parts[0]}, ${parts[1]}';
    return parts.first;
  }

  Future<void> callDriver() async {
    final phone = '${data?['driver_phone'] ?? ''}'.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sürücü telefon numarası bulunamadı.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon araması başlatılamadı.')),
      );
    }
  }

  Future<void> cancelRequest() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Çekici çağrısını iptal et?'),
            content: const Text(
              'Aktif çekici çağrın iptal edilecek. Sonrasında yeni bir çağrı oluşturabilirsin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Çağrıyı İptal Et'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok || !mounted) return;
    setState(() => cancelling = true);

    try {
      final uri = Uri.parse(
        '${OnboardingBackend.baseUrl}'
        '${widget.driverMode ? '/api/driver/towing/requests/' : '/api/owner/towing/requests/'}'
        '${widget.id}/cancel',
      );
      final r = widget.driverMode
          ? await DriverHttp.post(
              uri,
              body: jsonEncode({'reason': 'Kullanıcı tarafından iptal edildi'}),
            )
          : await OwnerHttp.post(
              uri,
              body: jsonEncode({'reason': 'Kullanıcı tarafından iptal edildi'}),
            );
      final body = r.body.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(r.body));

      if (r.statusCode >= 200 && r.statusCode < 300) {
        timer?.cancel();
        await load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Çekici çağrısı iptal edildi.')),
          );
        }
      } else if (mounted) {
        final error = '${body['error'] ?? ''}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error == 'TOWING_REQUEST_NOT_CANCELLABLE'
                  ? 'Bu aşamada çağrı artık iptal edilemiyor.'
                  : 'Çağrı iptal edilemedi.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çağrı iptal edilemedi. Bağlantını kontrol et.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => cancelling = false);
    }
  }

  Widget _searching() {
    return Container(
      height: 255,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF111318),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _purple.withValues(alpha: .22),
                  width: 14,
                ),
              ),
              child: Center(
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _purple.withValues(alpha: .55),
                      width: 9,
                    ),
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: _purple2,
                    size: 42,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Yakındaki çekiciler aranıyor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Uygun bir çekici bulunduğunda burada göreceksiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trackingMap() {
    final driverLat = _number(data?['driver_lat']);
    final driverLng = _number(data?['driver_lng']);
    final pickupLat = _number(data?['pickup_lat']);
    final pickupLng = _number(data?['pickup_lng']);

    final driver = driverLat == null || driverLng == null
        ? null
        : LatLng(driverLat, driverLng);
    final pickup = pickupLat == null || pickupLng == null
        ? null
        : LatLng(pickupLat, pickupLng);
    final center = driver ?? pickup ?? const LatLng(41.0, 28.9);

    return Container(
      height: 255,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.5,
            minZoom: 10,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                .72, .12, .12, 0, 40,
                .12, .72, .12, 0, 40,
                .12, .12, .72, 0, 40,
                0, 0, 0, 1, 0,
              ]),
              child: TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cepqar.app',
                maxNativeZoom: 19,
                panBuffer: 0,
              ),
            ),
            if (driver != null && pickup != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [driver, pickup],
                    strokeWidth: 5,
                    color: _purple,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (driver != null)
                  Marker(
                    point: driver,
                    width: 88,
                    height: 88,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: .13),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(13),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _purple.withValues(alpha: .18),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fire_truck_rounded,
                          color: _purple,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                if (pickup != null)
                  Marker(
                    point: pickup,
                    width: 72,
                    height: 72,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: .10),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(11),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _purple,
                          size: 31,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _etaCard(String eta) {
    return Container(
      width: 122,
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: _purple,
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tahmini varış',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  eta,
                  style: const TextStyle(
                    color: _purple,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverInfo() {
    final provider = '${data?['provider_name'] ?? ''}'.trim();
    final driver = '${data?['driver_name'] ?? ''}'.trim();
    final plate = '${data?['towing_plate'] ?? ''}'.trim();
    final brand = '${data?['towing_brand'] ?? ''}'.trim();
    final model = '${data?['towing_model'] ?? ''}'.trim();
    final title = provider.isNotEmpty
        ? provider
        : (driver.isNotEmpty ? driver : 'Çekici sürücüsü');
    final towLine = [
      if (plate.isNotEmpty) plate,
      if (brand.isNotEmpty) brand,
      if (model.isNotEmpty) model,
    ].join(' ');

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFF1E9FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: _purple,
            size: 30,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (driver.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'Sürücü: $driver',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (towLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Çekici: $towLine',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _routeInfo() {
    final pickup = _shortAddress(data?['pickup_address']);
    final destination = _shortAddress(data?['destination_address']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 15,
                height: 15,
                decoration: const BoxDecoration(
                  color: _purple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.circle,
                  color: Colors.white,
                  size: 5,
                ),
              ),
              Container(
                width: 2,
                height: 36,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Icon(
                Icons.location_on_rounded,
                color: _purple,
                size: 28,
              ),
            ],
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alım',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                pickup,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Bırakma',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                destination,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _foundCard(String status) {
    final eta = _etaText(status);
    final distance = _distanceText(status);
    final canCancel =
        ['searching', 'accepted', 'arriving', 'arrived'].contains(status);
    final canCall =
        '${data?['driver_phone'] ?? ''}'.trim().isNotEmpty &&
        status != 'searching' &&
        status != 'cancelled';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: const Color(0xFFF0F1F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusLabel(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1.04,
                      ),
                    ),
                    if (status != 'cancelled' && status != 'delivered') ...[
                      const SizedBox(height: 5),
                      Text(
                        '$eta • $distance',
                        style: const TextStyle(
                          color: _purple,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (status != 'cancelled' && status != 'delivered') ...[
                const SizedBox(width: 10),
                _etaCard(eta),
              ],
            ],
          ),
          const SizedBox(height: 17),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 15),
          _driverInfo(),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 14),
          _routeInfo(),
          if (canCall) ...[
            const SizedBox(height: 17),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_purple2, _purple],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(17),
                    onTap: callDriver,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 11),
                        Text(
                          'Sürücüyü Ara',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: cancelling ? null : cancelRequest,
                icon: cancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close_rounded, size: 25),
                label: Text(
                  cancelling ? 'İptal ediliyor...' : 'Çağrıyı İptal Et',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF2638),
                  side: const BorderSide(
                    color: Color(0xFFFF2638),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final status = '${data!['status']}';
    final searchingNow = status == 'searching';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        centerTitle: true,
        title: Text(
          searchingNow ? 'Çekici aranıyor' : 'Çekici Takibi',
          style: const TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 27),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 8),
          children: [
            searchingNow ? _searching() : _trackingMap(),
            if (searchingNow)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  children: [
                    Text(
                      'Talebin çevredeki uygun çekicilere gönderildi.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: cancelling ? null : cancelRequest,
                        icon: cancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.close_rounded),
                        label: Text(
                          cancelling
                              ? 'İptal ediliyor...'
                              : 'Çağrıyı İptal Et',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF2638),
                          side: const BorderSide(
                            color: Color(0xFFFF2638),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              _foundCard(status),
          ],
        ),
      ),
    );
  }
}
