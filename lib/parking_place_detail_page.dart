import 'package:flutter/material.dart';
import 'parking_place.dart';
import 'parking_style.dart';
import 'parking_navigation.dart';
import 'parking_record_api.dart';
import 'parking_record_editor.dart';

class ParkingPlaceDetailPage extends StatefulWidget {
  const ParkingPlaceDetailPage({
    super.key,
    required this.place,
    required this.vehicleId,
    required this.userLatitude,
    required this.userLongitude,
  });
  final ParkingPlace place;
  final String vehicleId;
  final double userLatitude, userLongitude;
  @override
  State<ParkingPlaceDetailPage> createState() => _ParkingPlaceDetailPageState();
}

class _ParkingPlaceDetailPageState extends State<ParkingPlaceDetailPage> {
  bool _saving = false;
  String? _error;
  Future<void> _navigate() async {
    final p = widget.place;
    final ok = await navigateToParking(p.latitude, p.longitude, p.name);
    if (!ok && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')),
      );
  }

  Future<void> _park() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final record = await ParkingRecordApi.save(
        widget.vehicleId,
        place: widget.place,
      );
      if (!mounted) return;
      await showParkingRecordEditor(
        context,
        widget.vehicleId,
        initial: record,
        dark: true,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _value(String v) =>
      {
        'yes': 'Evet',
        'no': 'Hayır',
        'limited': 'Sınırlı',
        'customers': 'Müşterilere özel',
        'permissive': 'İzin verilen kullanım',
        'public': 'Halka açık',
        'designated': 'Ayrılmış',
      }[v] ??
      v;
  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final features = <String, String>{
      if (p.tags['operator'] != null) 'İşletmeci': p.tags['operator']!,
      if (p.tags['capacity'] != null) 'Kapasite': p.tags['capacity']!,
      if (p.tags['fee'] != null) 'Ücretli': _value(p.tags['fee']!),
      if (p.tags['charge'] != null) 'Ücret bilgisi': p.tags['charge']!,
      if (p.tags['access'] != null) 'Erişim': _value(p.tags['access']!),
      if (p.tags['wheelchair'] != null)
        'Tekerlekli sandalye': _value(p.tags['wheelchair']!),
      if (p.tags['capacity:disabled'] != null)
        'Engelli park yeri': p.tags['capacity:disabled']!,
      if (p.tags['maxheight'] != null) 'Yükseklik sınırı': p.tags['maxheight']!,
      if (p.tags['covered'] != null) 'Üstü kapalı': _value(p.tags['covered']!),
      if (p.tags['lit'] != null) 'Aydınlatma': _value(p.tags['lit']!),
      if (p.tags['supervised'] != null)
        'Gözetimli': _value(p.tags['supervised']!),
    };
    return PopScope(
      canPop: !_saving,
      child: Theme(
        data: ThemeData.dark(useMaterial3: true),
        child: Scaffold(
          backgroundColor: parkingBg,
          appBar: AppBar(
            backgroundColor: parkingBg,
            foregroundColor: Colors.white,
            title: const Text(
              'Otopark Detay',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                height: 126,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3D1D77), parkingPanel],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: parkingLine),
                ),
                child: const Center(
                  child: Icon(
                    Icons.local_parking_rounded,
                    color: Colors.white,
                    size: 72,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                p.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${p.distanceLabel(widget.userLatitude, widget.userLongitude)} • Kuş uçuşu',
                style: const TextStyle(
                  color: Color(0xFFBA94FF),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _info(
                Icons.location_on_outlined,
                'Adres',
                p.address.isEmpty ? 'Adres bilgisi eklenmemiş' : p.address,
              ),
              _info(
                Icons.schedule_rounded,
                'Çalışma Saatleri',
                p.hours.isEmpty ? 'Saat bilgisi eklenmemiş' : p.hoursLabel,
              ),
              _info(Icons.local_parking_outlined, 'Otopark Tipi', p.typeLabel),
              if (p.isMall)
                _info(Icons.shopping_bag_outlined, 'Kategori', 'AVM'),
              if (p.isMunicipal)
                _info(
                  Icons.account_balance_outlined,
                  'İşletme',
                  'Belediye otoparkı',
                ),
              ...features.entries.map(
                (e) => _info(Icons.info_outline, e.key, e.value),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _navigate,
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Yol Tarifi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBA94FF),
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: parkingPurple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Bilgiler OpenStreetMap katkıcılarından gelir. Saatler ve özellikler güncel olmayabilir; müsait yer garantisi verilmez.',
                style: TextStyle(
                  color: parkingMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: FilledButton.icon(
                onPressed: _saving ? null : _park,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.local_parking_rounded),
                label: Text(
                  _saving ? 'Kaydediliyor…' : 'Burada Park Ettim',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: parkingPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: parkingPanel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: parkingLine),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFBA94FF)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: parkingMuted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
