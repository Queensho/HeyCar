import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'parking_place.dart';
import 'parking_search_service.dart';
import 'parking_place_detail_page.dart';
import 'parking_navigation.dart';
import 'parking_style.dart';

class ParkingPlacesPage extends StatefulWidget {
  const ParkingPlacesPage({super.key, required this.vehicleId});
  final String vehicleId;
  @override
  State<ParkingPlacesPage> createState() => _ParkingPlacesPageState();
}

class _ParkingPlacesPageState extends State<ParkingPlacesPage>
    with WidgetsBindingObserver {
  final _map = MapController(), _search = TextEditingController();
  Timer? _debounce;
  LatLng? _user, _center, _queued;
  bool _locating = false,
      _settingsPending = false,
      _searching = false,
      _listOnly = false,
      _mapReady = false,
      _stale = false,
      _tileError = false,
      _locationOff = false;
  String? _locationError, _error;
  LocationPermission? _permission;
  int _revision = 0;
  ParkingFilter _filter = ParkingFilter.all;
  List<ParkingPlace> _places = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _search.addListener(_filterChanged);
    _locate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _search.removeListener(_filterChanged);
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _settingsPending) {
      _settingsPending = false;
      _locate();
    }
  }

  void _filterChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _locate({bool request = false}) async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      _locationOff = !await Geolocator.isLocationServiceEnabled();
      if (_locationOff) {
        if (mounted)
          setState(
            () => _locationError =
                'Yakındaki otoparkları görmek için konum servisini aç.',
          );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request)
        permission = await Geolocator.requestPermission();
      _permission = permission;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        if (mounted)
          setState(
            () =>
                _locationError = permission == LocationPermission.deniedForever
                ? 'Konum izni kapalı. Telefon ayarlarından Cepqar için izin verebilirsin.'
                : 'Konumunu yalnızca çevrendeki otoparkları bulmak için kullanacağız.',
          );
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 18),
        ),
      );
      if (!mounted) return;
      final point = LatLng(p.latitude, p.longitude);
      setState(() {
        _user = point;
        _center = point;
      });
      if (_mapReady) _map.move(point, 14);
      _revision++;
      _debounce?.cancel();
      await _load(point);
    } catch (_) {
      if (mounted)
        setState(
          () => _locationError =
              'Konum alınamadı. İnternetini ve konum ayarlarını kontrol et.',
        );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _permissionAction() async {
    if (_locationOff || _permission == LocationPermission.deniedForever) {
      _settingsPending = true;
      try {
        final opened = _locationOff
            ? await Geolocator.openLocationSettings()
            : await Geolocator.openAppSettings();
        if (!opened && mounted) {
          _settingsPending = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Telefon ayarlarından konum iznini aç.'),
            ),
          );
        }
      } catch (_) {
        _settingsPending = false;
      }
    } else {
      await _locate(request: true);
    }
  }

  void _positionChanged(MapCamera camera, bool gesture) {
    if (!gesture) return;
    _center = camera.center;
    _revision++;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () {
      if (mounted) _load(camera.center);
    });
  }

  Future<void> _load(LatLng point) async {
    if (_searching) {
      _queued = point;
      return;
    }
    final revision = _revision;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await ParkingSearchService.shared.nearby(
        point.latitude,
        point.longitude,
      );
      if (mounted && revision == _revision)
        setState(() {
          _places = result.places;
          _stale = result.stale;
        });
    } catch (e) {
      if (mounted && revision == _revision)
        setState(() {
          _places = [];
          _error = e.toString();
        });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
        final next = _queued;
        _queued = null;
        if (next != null) unawaited(_load(next));
      }
    }
  }

  List<ParkingPlace> get _visible {
    final q = parkingSearchText(_search.text.trim());
    final list = _places
        .where(
          (p) =>
              p.matches(_filter) &&
              (q.isEmpty ||
                  parkingSearchText(
                    '${p.name} ${p.address} ${p.tags['operator'] ?? ''}',
                  ).contains(q)),
        )
        .toList();
    final user = _user;
    if (user != null)
      list.sort(
        (a, b) => a
            .distanceFrom(user.latitude, user.longitude)
            .compareTo(b.distanceFrom(user.latitude, user.longitude)),
      );
    return list;
  }

  Future<void> _detail(ParkingPlace p) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ParkingPlaceDetailPage(
          place: p,
          vehicleId: widget.vehicleId,
          userLatitude: _user!.latitude,
          userLongitude: _user!.longitude,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _navigate(ParkingPlace p) async {
    final ok = await navigateToParking(p.latitude, p.longitude, p.name);
    if (!ok && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')),
      );
  }

  Widget _state(
    IconData icon,
    String title,
    String text,
    String action,
    VoidCallback? tap,
  ) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFAE85FF), size: 48),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: parkingMuted, height: 1.5),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: tap,
          style: FilledButton.styleFrom(
            backgroundColor: parkingPurple,
            foregroundColor: Colors.white,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: parkingPurple,
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: parkingBg,
        appBar: AppBar(
          backgroundColor: parkingBg,
          foregroundColor: Colors.white,
          title: const Text(
            'Park Yerleri',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'Konumuma dön',
              onPressed: _locating ? null : () => _locate(request: true),
              icon: const Icon(
                Icons.my_location_rounded,
                color: Color(0xFFAE85FF),
              ),
            ),
          ],
        ),
        body: _user == null
            ? Center(
                child: SingleChildScrollView(
                  child: _locating
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: parkingPurple),
                              SizedBox(height: 18),
                              Text(
                                'Konumun alınıyor…',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : _state(
                          Icons.location_on_outlined,
                          'Çevrendeki otoparkları keşfet',
                          _locationError ?? 'Konum izni gerekli.',
                          _locationOff ||
                                  _permission ==
                                      LocationPermission.deniedForever
                              ? 'Ayarları Aç'
                              : _permission == LocationPermission.denied
                              ? 'Konum İzni Ver'
                              : 'Tekrar Dene',
                          _permissionAction,
                        ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () => _load(_center ?? _user!),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Harita'),
                              icon: Icon(Icons.map_outlined),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Liste'),
                              icon: Icon(Icons.list_rounded),
                            ),
                          ],
                          selected: {_listOnly},
                          onSelectionChanged: (s) => setState(() {
                            _listOnly = s.first;
                            _mapReady = false;
                          }),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (s) => s.contains(WidgetState.selected)
                                  ? parkingPurple
                                  : parkingPanel,
                            ),
                            foregroundColor: const WidgetStatePropertyAll(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!_listOnly)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).height * .38,
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _map,
                                options: MapOptions(
                                  initialCenter: _center ?? _user!,
                                  initialZoom: 14,
                                  minZoom: 11,
                                  maxZoom: 18,
                                  onMapReady: () {
                                    _mapReady = true;
                                  },
                                  onPositionChanged: _positionChanged,
                                  interactionOptions: const InteractionOptions(
                                    flags:
                                        InteractiveFlag.all &
                                        ~InteractiveFlag.rotate,
                                  ),
                                ),
                                children: [
                                  ColorFiltered(
                                    colorFilter: const ColorFilter.matrix([
                                      -.12,
                                      -.24,
                                      -.04,
                                      0,
                                      115,
                                      -.15,
                                      -.30,
                                      -.05,
                                      0,
                                      140,
                                      -.18,
                                      -.36,
                                      -.06,
                                      0,
                                      173,
                                      0,
                                      0,
                                      0,
                                      1,
                                      0,
                                    ]),
                                    child: TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.cepqar.app',
                                      maxNativeZoom: 19,
                                      panBuffer: 0,
                                      errorTileCallback: (_, __, ___) {
                                        if (!_tileError && mounted)
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                if (mounted)
                                                  setState(
                                                    () => _tileError = true,
                                                  );
                                              });
                                      },
                                    ),
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _user!,
                                        width: 36,
                                        height: 36,
                                        child: Semantics(
                                          label: 'Mevcut konumun',
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent
                                                  .withValues(alpha: .22),
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(7),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blueAccent,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 3,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      ...visible.map(
                                        (p) => Marker(
                                          point: LatLng(
                                            p.latitude,
                                            p.longitude,
                                          ),
                                          width: 48,
                                          height: 58,
                                          alignment: Alignment.topCenter,
                                          child: Semantics(
                                            label: p.name,
                                            button: true,
                                            child: GestureDetector(
                                              onTap: () => _detail(p),
                                              child: const ParkingMapPin(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Positioned(
                                right: 8,
                                bottom: 6,
                                child: Material(
                                  color: parkingBg,
                                  child: InkWell(
                                    onTap: () => launchUrl(
                                      Uri.parse(
                                        'https://www.openstreetmap.org/copyright',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Text(
                                        '© OpenStreetMap contributors',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_tileError)
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    color: parkingPanel,
                                    child: const Text(
                                      'Harita yüklenemedi. Otopark listesini kullanabilirsin.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_searching)
                                const Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  child: LinearProgressIndicator(
                                    color: parkingPurple,
                                    backgroundColor: parkingPanel,
                                    minHeight: 3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: TextField(
                          controller: _search,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Otopark ara (ad, cadde, ilçe…)',
                            hintStyle: const TextStyle(color: parkingMuted),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: parkingMuted,
                            ),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: _search.clear,
                                    icon: const Icon(
                                      Icons.close,
                                      color: parkingMuted,
                                    ),
                                  ),
                            filled: true,
                            fillColor: parkingPanel,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: parkingLine),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: parkingLine),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 52,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: ParkingFilter.values.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => ChoiceChip(
                            label: Text(
                              const [
                                'Tümü',
                                'AVM',
                                'Katlı Otopark',
                                'Açık Otopark',
                                'Belediye',
                              ][i],
                            ),
                            selected: _filter == ParkingFilter.values[i],
                            onSelected: (_) => setState(
                              () => _filter = ParkingFilter.values[i],
                            ),
                            showCheckmark: false,
                            selectedColor: parkingPurple,
                            backgroundColor: parkingPanel,
                            labelStyle: TextStyle(
                              color: _filter == ParkingFilter.values[i]
                                  ? Colors.white
                                  : parkingMuted,
                              fontWeight: FontWeight.w700,
                            ),
                            side: const BorderSide(color: parkingLine),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                        child: Text(
                          _stale
                              ? 'Bağlantı yok • Önceki sonuçlar gösteriliyor'
                              : '${visible.length} otopark • Harita merkezinin 3 km çevresi',
                          style: const TextStyle(
                            color: parkingMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (_locationError != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _locationError!,
                            style: const TextStyle(color: Colors.amber),
                          ),
                        ),
                      ),
                    if (_searching && visible.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: parkingPurple,
                            ),
                          ),
                        ),
                      )
                    else if (_error != null)
                      SliverToBoxAdapter(
                        child: _state(
                          Icons.cloud_off_outlined,
                          'Otoparklar yüklenemedi',
                          _error!,
                          'Tekrar Dene',
                          () => _load(_center ?? _user!),
                        ),
                      )
                    else if (visible.isEmpty)
                      SliverToBoxAdapter(
                        child: _state(
                          Icons.local_parking_rounded,
                          'Otopark bulunamadı',
                          'Bu bölgede seçimine uygun kayıt yok. Filtreyi değiştir veya haritayı başka bir bölgeye taşı.',
                          'Filtreyi Temizle',
                          () {
                            _search.clear();
                            setState(() => _filter = ParkingFilter.all);
                          },
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _card(visible[i]),
                          childCount: visible.length,
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(18, 12, 18, 24),
                        child: Text(
                          'Mesafeler kuş uçuşudur. Otopark bilgileri OpenStreetMap katkıcılarından gelir; doluluk bilgisi içermez.',
                          style: TextStyle(
                            color: parkingMuted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _card(ParkingPlace p) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Material(
      color: parkingPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: parkingLine),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _detail(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF50209D), Color(0xFF24213E)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.distanceLabel(_user!.latitude, _user!.longitude),
                      style: const TextStyle(
                        color: Color(0xFFD9C8FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p.address.isEmpty
                          ? 'Adres bilgisi eklenmemiş'
                          : p.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: parkingMuted, fontSize: 12),
                    ),
                    if (p.hours.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        p.hoursLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.hours == '24/7'
                              ? const Color(0xFF60DF95)
                              : parkingMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Yol Tarifi',
                onPressed: () => _navigate(p),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF20223C),
                  foregroundColor: const Color(0xFFAE85FF),
                ),
                icon: const Icon(Icons.navigation_rounded),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ParkingMapPin extends StatelessWidget {
  const ParkingMapPin({super.key});
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.topCenter,
    children: [
      const Positioned(
        bottom: 6,
        child: Icon(
          Icons.arrow_drop_down_rounded,
          color: parkingPurple,
          size: 42,
        ),
      ),
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFAE70FF), parkingPurple],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE1CCFF), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x55813CFF), blurRadius: 10),
          ],
        ),
        child: const Center(
          child: Text(
            'P',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 25,
            ),
          ),
        ),
      ),
    ],
  );
}
