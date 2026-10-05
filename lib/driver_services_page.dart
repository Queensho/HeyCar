import 'dart:convert';

import 'package:flutter/material.dart';

import 'cepqar_offers_page.dart';
import 'cepqar_theme.dart';
import 'driver_auth.dart';
import 'maintenance_page.dart';
import 'onboarding_backend.dart';
import 'parking_location_card.dart';
import 'roadside_help_page.dart';
import 'valet_info_page.dart';
import 'vehicle_reminders_page.dart';

class DriverServicesPage extends StatefulWidget {
  const DriverServicesPage({super.key});

  @override
  State<DriverServicesPage> createState() => _DriverServicesPageState();
}

class _DriverServicesPageState extends State<DriverServicesPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> vehicles = [];
  String selectedVehicleId = '';

  Map<String, dynamic>? get selectedVehicle {
    if (vehicles.isEmpty) return null;
    for (final vehicle in vehicles) {
      if ('${vehicle['vehicleId'] ?? ''}' == selectedVehicleId) return vehicle;
    }
    return vehicles.first;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final r = await DriverHttp.get(
        Uri.parse('${OnboardingBackend.baseUrl}/api/driver/entitlements'),
        json: false,
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception('Hizmet yetkileri alınamadı.');
      }
      final d = jsonDecode(r.body);
      final list = d is Map && d['vehicles'] is List
          ? (d['vehicles'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      list.sort((a, b) {
        final aa = a['activeDriver'] == true;
        final bb = b['activeDriver'] == true;
        if (aa == bb) return 0;
        return aa ? -1 : 1;
      });
      if (!mounted) return;
      setState(() {
        vehicles = list;
        if (list.isNotEmpty &&
            !list.any((x) => '${x['vehicleId'] ?? ''}' == selectedVehicleId)) {
          selectedVehicleId = '${list.first['vehicleId'] ?? ''}';
        }
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Hizmetler yüklenemedi. Tekrar dene.';
        });
      }
    }
  }

  bool get familyPremium => selectedVehicle?['familyPremium'] == true;
  bool get activeDriver => selectedVehicle?['activeDriver'] == true;

  String get vehicleId => '${selectedVehicle?['vehicleId'] ?? ''}';
  String get plate => '${selectedVehicle?['plate'] ?? ''}';
  String get vehicleTitle {
    final make = '${selectedVehicle?['make'] ?? ''}'.trim();
    final model = '${selectedVehicle?['model'] ?? ''}'.trim();
    return '$make $model'.trim();
  }

  void familyLocked(String feature) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CepqarTheme.panel,
        title: Row(
          children: [
            const Icon(Icons.family_restroom_rounded, color: CepqarTheme.purple),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Aile Premium gerekli',
                style: TextStyle(
                  color: CepqarTheme.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '$feature özelliğini sürücü hesabında kullanmak için araç sahibinin Aile Premium paketine geçmesi gerekir. Premium satın alma ve paket yönetimi yalnızca araç sahibi hesabından yapılır.',
          style: TextStyle(color: CepqarTheme.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void activeDriverRequired(String feature) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CepqarTheme.panel,
        title: Text(
          'Aktif sürücü gerekli',
          style: TextStyle(
            color: CepqarTheme.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          '$feature işlemini yalnızca araç sahibinin o anda aktif olarak seçtiği sürücü başlatabilir.',
          style: TextStyle(color: CepqarTheme.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> openPark() async {
    if (vehicleId.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CepqarTheme.panel,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ParkingLocationCard(
            vehicleId: vehicleId,
            driverMode: true,
          ),
        ),
      ),
    );
  }

  void openTowing() {
    if (vehicleId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoadsideHelpPage(
          driverMode: true,
          vehicleId: vehicleId,
        ),
      ),
    );
  }

  void openValet() {
    if (vehicleId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ValetInfoPage(
          vehicleId: vehicleId,
          driverMode: true,
        ),
      ),
    );
  }

  void openMaintenance() {
    if (!familyPremium) {
      familyLocked('Bakım');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenancePage(
          vehicleId: vehicleId,
          plate: plate,
          title: vehicleTitle,
          driverMode: true,
        ),
      ),
    );
  }

  void openReminders() {
    if (!familyPremium) {
      familyLocked('Araç hatırlatmaları');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleRemindersPage(
          vehicleId: vehicleId,
          driverMode: true,
        ),
      ),
    );
  }

  void openOffers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CepqarOffersPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = CepqarTheme.text;
    final muted = CepqarTheme.muted;
    final panel = CepqarTheme.panel;
    final line = CepqarTheme.line;
    final light = CepqarTheme.isLight;

    if (loading) {
      return ColoredBox(
        color: CepqarTheme.bg,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: CepqarTheme.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: CepqarTheme.purple,
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  light
                      ? 'assets/file_00000000b130820abb8d411e67ab0d25.png'
                      : 'assets/Logoyeni.png',
                  key: ValueKey(light),
                  height: 31,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Hizmetler',
                style: TextStyle(
                  color: text,
                  fontSize: CepqarTheme.pageTitle,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Yetkili olduğun araç için CepQontag hizmetlerini kullan.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              if (error != null)
                _messageCard(
                  error!,
                  Icons.error_outline_rounded,
                  onTap: load,
                )
              else if (vehicles.isEmpty)
                _messageCard(
                  'Henüz yetkili olduğun bir araç bulunmuyor.',
                  Icons.directions_car_outlined,
                )
              else ...[
                _vehicleSelector(panel, line, text, muted),
                const SizedBox(height: 11),
                if (familyPremium)
                  _statusBanner(
                    icon: Icons.family_restroom_rounded,
                    title: 'Aile Premium aktif',
                    subtitle:
                        'Araç sahibinin Aile paketi bu araçta premium sürücü özelliklerini açıyor.',
                    color: const Color(0xFFFFB928),
                  )
                else
                  _statusBanner(
                    icon: Icons.person_outline_rounded,
                    title: 'Bireysel / Standart erişim',
                    subtitle:
                        'Premium sürücü özellikleri için araç sahibi Aile Premium’a geçebilir.',
                    color: CepqarTheme.purple,
                  ),
                const SizedBox(height: 11),
                _serviceCard(
                  Icons.local_parking_rounded,
                  'Park',
                  'Yakındaki otoparkları bul, park bilgilerini kaydet.',
                  const Color(0xFF397DFF),
                  openPark,
                ),
                _serviceCard(
                  Icons.fire_truck_rounded,
                  'Çekici / Yol Yardım',
                  activeDriver
                      ? 'Yolda kaldığında çekici çağır ve canlı takip et.'
                      : 'Görüntüle; çağrı başlatmak için aktif sürücü olmalısın.',
                  const Color(0xFFFF8A43),
                  openTowing,
                ),
                _serviceCard(
                  Icons.local_parking_outlined,
                  'Vale',
                  activeDriver
                      ? 'Vale durumunu takip et ve aracını iste.'
                      : 'Vale durumunu gör; aracı istemek için aktif sürücü olmalısın.',
                  const Color(0xFF8B36FF),
                  openValet,
                ),
                _serviceCard(
                  Icons.build_rounded,
                  'Bakım',
                  familyPremium
                      ? 'Bakım geçmişini görüntüle ve güncelle.'
                      : 'Aile Premium ile sürücü bakım erişimi.',
                  const Color(0xFF23BFA6),
                  openMaintenance,
                  familyLocked: !familyPremium,
                ),
                _serviceCard(
                  Icons.event_available_rounded,
                  'Hatırlatmalar',
                  familyPremium
                      ? 'Muayene, sigorta ve bakım tarihlerini yönet.'
                      : 'Aile Premium ile sürücü hatırlatma erişimi.',
                  const Color(0xFFFF5E76),
                  openReminders,
                  familyLocked: !familyPremium,
                ),
                _serviceCard(
                  Icons.local_offer_rounded,
                  'Fırsatlar',
                  'CepQontag fırsatlarını ve kampanyalarını keşfet.',
                  const Color(0xFF23C976),
                  openOffers,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: line),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        color: muted,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Premium satın alma ve paket değişikliği sürücü hesabından yapılamaz; kontrol araç sahibindedir.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10.7,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleSelector(
    Color panel,
    Color line,
    Color text,
    Color muted,
  ) {
    final current = selectedVehicle!;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 11, 10),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: CepqarTheme.purple.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: CepqarTheme.purple,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedVehicleId,
                isExpanded: true,
                dropdownColor: panel,
                iconEnabledColor: muted,
                items: vehicles
                    .map(
                      (x) => DropdownMenuItem<String>(
                        value: '${x['vehicleId'] ?? ''}',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${x['plate'] ?? 'Araç'}',
                              style: TextStyle(
                                color: text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              [
                                '${x['make'] ?? ''}',
                                '${x['model'] ?? ''}',
                                if (x['activeDriver'] == true) 'Aktif sürücü',
                              ].where((e) => e.trim().isNotEmpty).join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: muted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedVehicleId = value);
                  }
                },
              ),
            ),
          ),
          if (current['activeDriver'] == true)
            Container(
              margin: const EdgeInsets.only(left: 7),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF24C77A).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                'Aktif',
                style: TextStyle(
                  color: Color(0xFF16945B),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: CepqarTheme.isLight ? .08 : .13),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: CepqarTheme.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: CepqarTheme.muted,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback tap, {
    bool familyLocked = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CepqarTheme.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CepqarTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: CepqarTheme.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (familyLocked) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB928)
                                  .withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'AİLE',
                              style: TextStyle(
                                color: Color(0xFFFFB928),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: CepqarTheme.muted,
                        fontSize: CepqarTheme.body,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                familyLocked
                    ? Icons.lock_outline_rounded
                    : Icons.chevron_right_rounded,
                color: familyLocked
                    ? const Color(0xFFFFB928)
                    : CepqarTheme.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageCard(
    String value,
    IconData icon, {
    Future<void> Function()? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CepqarTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CepqarTheme.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: CepqarTheme.purple, size: 34),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CepqarTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => onTap(),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ],
      ),
    );
  }
}
