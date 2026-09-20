import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'qr_backend.dart';
import 'onboarding_backend.dart';
import 'cepqar_theme.dart';
import 'street_parking_card.dart';
import 'parking_places_page.dart';
import 'saved_parking_card.dart';

class ParkingLocationCard extends StatefulWidget {
  const ParkingLocationCard({super.key, required this.vehicleId});
  final String vehicleId;
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
      final r = await http.get(
        Uri.parse(
          '${QrBackend.baseUrl}/api/vehicles/${widget.vehicleId}/maintenance',
        ),
        headers: {'x-owner-id': owner},
      );
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
        builder: (_) => ParkingPlacesPage(vehicleId: widget.vehicleId),
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
          'Sokakta park konumunu kaydetme, park süresini görme ve aracına geri dönme Premium üyelikle kullanılabilir.',
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
      return _back(StreetParkingCard(vehicleId: widget.vehicleId));
    if (selected == 1)
      return _back(SavedParkingCard(vehicleId: widget.vehicleId));
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
      decoration: BoxDecoration(
        color: CepqarTheme.panel,
        borderRadius: BorderRadius.circular(24),
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
                color: CepqarTheme.line,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Park',
            style: TextStyle(
              color: CepqarTheme.text,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aracını nerede bıraktın?',
            style: TextStyle(color: CepqarTheme.muted, fontSize: 14),
          ),
          const SizedBox(height: 16),
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
  ) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: CepqarTheme.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CepqarTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CepqarTheme.purple.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: CepqarTheme.purple, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: CepqarTheme.text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: TextStyle(
                    color: CepqarTheme.muted,
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (locked) ...[
            const Icon(Icons.lock_rounded, color: Color(0xFFFFB800), size: 17),
            const SizedBox(width: 5),
            const Text(
              'Premium',
              style: TextStyle(
                color: Color(0xFFFFB800),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ] else
            Icon(Icons.chevron_right_rounded, color: CepqarTheme.muted),
        ],
      ),
    ),
  );
}
