import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'qr_backend.dart';
import 'onboarding_backend.dart';
import 'cepqar_theme.dart';
import 'street_parking_card.dart';
import 'parking_places_page.dart';
import 'saved_parking_card.dart';
import 'owner_auth.dart';
import 'driver_auth.dart';

class ParkingLocationCard extends StatefulWidget {
  const ParkingLocationCard({super.key, required this.vehicleId, this.driverMode = false});
  final String vehicleId;
  final bool driverMode;
  @override
  State<ParkingLocationCard> createState() => _ParkingLocationCardState();
}

class _ParkingLocationCardState extends State<ParkingLocationCard> {
  int? selected;
  bool premium = false, premiumLoading = true;
  String get owner => OnboardingDraft.userId.trim();
  @override
  void initState() {
    super.initState();
    _loadPremium();
  }

  Future<void> _loadPremium() async {
    try {
      final uri = Uri.parse(
        '${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/maintenance',
      );
      final r = widget.driverMode
          ? await DriverHttp.get(uri, json: false)
          : await OwnerHttp.get(uri, json: false);
      final d = jsonDecode(r.body);
      if (mounted)
        setState(() {
          premium = r.statusCode == 200 && d is Map && d['premium'] == true;
          premiumLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => premiumLoading = false);
    }
  }

  Future<void> _nearby() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ParkingPlacesPage(vehicleId: widget.vehicleId, driverMode: widget.driverMode),
      ),
    );
    if (saved == true && mounted) setState(() => selected = 1);
  }

  void _premiumLocked() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CepqarTheme.panel,
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: CepqarTheme.purple),
            const SizedBox(width: 8),
            Text(
              'Premium özellik',
              style: TextStyle(
                color: CepqarTheme.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: Text(
          widget.driverMode
              ? 'Bu özellik sürücü hesabında Aile Premium ile kullanılabilir. Paketi yalnızca araç sahibi hesabından yükseltebilir.'
              : 'Sokakta park konumunu kaydetme, park süresini görme ve aracına geri dönme Premium üyelikle kullanılabilir.',
          style: TextStyle(color: CepqarTheme.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selected == 0)
      return _back(StreetParkingCard(vehicleId: widget.vehicleId, driverMode: widget.driverMode));
    if (selected == 1)
      return _back(SavedParkingCard(vehicleId: widget.vehicleId, driverMode: widget.driverMode));
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFAAA5B7),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Park', style: const TextStyle(color: Color(0xFF190D30), fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('Aracını nerede bıraktın?', style: const TextStyle(color: Color(0xFF6B6578), fontSize: 13)),
            ])),
            const SizedBox(width: 8),
            Image.asset('assets/images/services/Parkyerim.png', width: 90, height: 76, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.local_parking_rounded, color: Color(0xFF7124F5), size: 44)),
          ]),
          const SizedBox(height: 12),
          _choice(
            Icons.map_outlined,
            'Yakındaki Otoparklar',
            'Haritada bul • Yol tarifi al • Park et',
            false,
            _nearby,
          ),
          const SizedBox(height: 10),
          _choice(
            Icons.location_on_rounded,
            'Sokakta Park Ettim',
            'GPS konumunu kaydet • Park süresini gör',
            premiumLoading ? false : !premium,
            premiumLoading
                ? null
                : () =>
                      premium ? setState(() => selected = 0) : _premiumLocked(),
          ),
          const SizedBox(height: 10),
          _choice(
            Icons.local_parking_rounded,
            'Park Yerim',
            'AVM • Katlı otopark • Kat / alan / park no',
            false,
            () => setState(() => selected = 1),
          ),
        ],
      ),
    );
  }

  Widget _back(Widget child) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: () => setState(() => selected = null),
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('Park seçenekleri'),
      ),
      child,
    ],
  );
  Widget _choice(
    IconData icon,
    String title,
    String sub,
    bool locked,
    VoidCallback? tap,
  ) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9FD),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5DDF2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE3FF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: CepqarTheme.purple, size: 27),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF190D30),
                      fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(sub,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF696477),
                      fontSize: 12, height: 1.3)),
                  if (locked) ...[
                    const SizedBox(height: 5),
                    Text(widget.driverMode ? 'Aile Premium' : 'Premium',
                      style: const TextStyle(color: Color(0xFFFFB800),
                        fontSize: 11, fontWeight: FontWeight.w900)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 32,
              child: Icon(locked ? Icons.lock_rounded : Icons.chevron_right_rounded,
                color: locked ? const Color(0xFFFFB800) : CepqarTheme.purple),
            ),
          ],
        ),
      ),
    ),
  );
}

