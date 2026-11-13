import 'package:flutter/material.dart';
import 'car_wash_api.dart';
import 'car_wash_pages.dart';

class BusinessProfile extends StatefulWidget {
  const BusinessProfile(
      {super.key,
      required this.api,
      required this.upload,
      required this.onSettings});
  final CarWashApi api;
  final Future<String?> Function() upload;
  final Future<void> Function() onSettings;
  @override
  State<BusinessProfile> createState() => _BusinessProfileState();
}

class _BusinessProfileState extends State<BusinessProfile> {
  late Future<WashJson> future;
  final name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController(),
      description = TextEditingController(),
      latitude = TextEditingController(),
      longitude = TextEditingController();
  bool loaded = false, busy = false;
  String? logo, error;
  List<String> photos = [];
  @override
  void initState() {
    super.initState();
    future = widget.api.call('/api/business/car-wash/profile');
  }

  @override
  void dispose() {
    for (final c in [name, phone, address, description, latitude, longitude]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load() {
    setState(() {
      loaded = false;
      future = widget.api.call('/api/business/car-wash/profile');
    });
  }

  Widget image(String url, {double height = 100}) =>
      Image.network(washBusinessImageUrl(url) ?? url,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const SizedBox(
              height: 80, child: Center(child: Text('Görsel yüklenemedi'))));
  @override
  Widget build(BuildContext context) => WashLoader(
      future: future,
      retry: _load,
      builder: (data) {
        if (!loaded) {
          final b = data['business'] as Map? ?? {};
          final l = data['location'] as Map? ?? {};
          name.text = '${b['name'] ?? ''}';
          phone.text = '${b['phone'] ?? ''}';
          address.text = '${b['address'] ?? ''}';
          description.text = '${b['description'] ?? ''}';
          latitude.text = '${b['latitude'] ?? ''}';
          longitude.text = '${b['longitude'] ?? ''}';
          logo = b['logo_url'] as String?;
          photos = (l['photos'] as List? ?? []).cast<String>().toList();
          loaded = true;
        }
        final l = data['location'] as Map? ?? {};
        return ListView(padding: const EdgeInsets.all(18), children: [
          Text('İşletme Profili',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
              'Yayın: ${l['published'] == true ? 'Yayında' : 'Kapalı'} · Randevu kabulü: ${l['booking_enabled'] == true ? 'Açık' : 'Kapalı'}'),
          const SizedBox(height: 16),
          const Text('İşletme logosu'),
          if (logo != null)
            image(logo!)
          else
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Henüz logo yüklenmedi.')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: busy ? null : () => _upload(true),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Logo yükle')),
            if (logo != null)
              TextButton(
                  onPressed: busy ? null : () => setState(() => logo = null),
                  child: const Text('Logoyu kaldır'))
          ]),
          for (final field in [
            (name, 'İşletme adı', 120),
            (phone, 'İletişim telefonu', 30),
            (address, 'Adres', 1000),
            (description, 'Açıklama', 2000)
          ])
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextField(
                    controller: field.$1,
                    maxLength: field.$3,
                    maxLines: field.$1 == description ? 3 : 1,
                    decoration: InputDecoration(labelText: field.$2),
                    enabled: !busy)),
          const Text(
              'Hizmetler işletme adresinde randevuyla sunulur. Konum alanları boş bırakılabilir; girilirse ikisi de geçerli olmalıdır.'),
          for (final field in [(latitude, 'Enlem'), (longitude, 'Boylam')])
            TextField(
                controller: field.$1,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: InputDecoration(labelText: field.$2),
                enabled: !busy),
          const SizedBox(height: 20),
          Text('Kapak ve fotoğraf galerisi',
              style: Theme.of(context).textTheme.titleLarge),
          const Text(
              'İlk fotoğraf müşterilere kapak olarak gösterilir. Yalnız işletmenin yüklediği görseller kullanılır.'),
          for (final entry in photos.asMap().entries)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key == 0
                              ? 'Kapak fotoğrafı'
                              : 'Galeri fotoğrafı ${entry.key + 1}'),
                          const SizedBox(height: 8),
                          image(entry.value, height: 160),
                          Wrap(spacing: 8, children: [
                            if (entry.key != 0)
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(() {
                                            final p =
                                                photos.removeAt(entry.key);
                                            photos.insert(0, p);
                                          }),
                                  child: const Text('Kapak yap')),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(
                                        () => photos.removeAt(entry.key)),
                                child: const Text('Fotoğrafı kaldır'))
                          ])
                        ]))),
          OutlinedButton.icon(
              onPressed:
                  busy || photos.length >= 12 ? null : () => _upload(false),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galeriye fotoğraf yükle')),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
              onPressed: busy ? null : _save,
              child: Text(busy ? 'Kaydediliyor…' : 'Profili kaydet')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      await widget.onSettings();
                      if (mounted) _load();
                    },
              icon: const Icon(Icons.schedule),
              label: const Text('Çalışma saatleri ve yayın ayarları')),
        ]);
      });
  Future<void> _upload(bool isLogo) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final url = await widget.upload();
      if (url != null && mounted)
        setState(() {
          if (isLogo) {
            logo = url;
          } else {
            photos.add(url);
          }
        });
    } catch (e) {
      if (mounted) setState(() => error = washError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    final lat = latitude.text.trim().isEmpty
            ? null
            : double.tryParse(latitude.text.replaceAll(',', '.')),
        lon = longitude.text.trim().isEmpty
            ? null
            : double.tryParse(longitude.text.replaceAll(',', '.'));
    if (name.text.trim().isEmpty ||
        (latitude.text.trim().isNotEmpty &&
            (lat == null || !lat.isFinite || lat < -90 || lat > 90)) ||
        (longitude.text.trim().isNotEmpty &&
            (lon == null || !lon.isFinite || lon < -180 || lon > 180)) ||
        ((lat == null) != (lon == null))) {
      setState(() => error = 'İşletme adı ve konum bilgilerini kontrol edin.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api
          .call('/api/business/car-wash/profile', method: 'PUT', body: {
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'description': description.text,
        'latitude': lat,
        'longitude': lon,
        'logoUrl': logo,
        'photos': photos
      });
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İşletme profili kaydedildi.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = washError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
