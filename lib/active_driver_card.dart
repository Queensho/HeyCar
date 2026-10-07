import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'owner_auth.dart';
import 'cepqar_theme.dart';

class ActiveDriverCard extends StatefulWidget {
  const ActiveDriverCard({super.key});

  @override
  State<ActiveDriverCard> createState() => _S();
}

class _S extends State<ActiveDriverCard> {
  static const api = 'https://heycar-api-185-165-46-213.nip.io';

  bool loading = true;
  bool active = false;
  bool premium = false;
  String? name;
  String? activeVehicleId;
  String? activePlate;
  DateTime? until;

  List<Map<String, dynamic>> drivers = [];
  List<Map<String, dynamic>> ownerVehicles = [];

  String get vehicleId =>
      QrDraft.vehicleId.trim().isEmpty
          ? OnboardingDraft.vehicleId.trim()
          : QrDraft.vehicleId.trim();

  String get ownerId => OnboardingDraft.userId.trim();

  @override
  void initState() {
    super.initState();
    load();
  }

  List<Map<String, dynamic>> _orderedVehicles(
    List<Map<String, dynamic>> vehicles,
  ) {
    final current = vehicleId;
    final copy = [...vehicles];
    copy.sort((a, b) {
      final aid = '${a['id'] ?? ''}';
      final bid = '${b['id'] ?? ''}';
      if (aid == current && bid != current) return -1;
      if (bid == current && aid != current) return 1;
      return 0;
    });
    return copy;
  }

  Future<void> load() async {
    if (ownerId.isEmpty) {
      if (mounted) setState(() => loading = false);
      return;
    }

    if (mounted) setState(() => loading = true);

    try {
      final vehicleResponse = await OwnerHttp.get(
        Uri.parse('$api/api/owner/vehicles'),
        json: false,
      );

      if (vehicleResponse.statusCode != 200) {
        throw Exception('OWNER_VEHICLES_FAILED');
      }

      final vehicleJson = jsonDecode(vehicleResponse.body);
      final vehicles = vehicleJson is Map && vehicleJson['vehicles'] is List
          ? (vehicleJson['vehicles'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final ordered = _orderedVehicles(vehicles);
      final allDrivers = <Map<String, dynamic>>[];

      String? nextActiveVehicleId;
      String? nextActivePlate;
      String? nextName;
      DateTime? nextUntil;

      for (final vehicle in ordered) {
        final id = '${vehicle['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;

        final plate = '${vehicle['plate'] ?? ''}'.trim();

        final responses = await Future.wait<http.Response>([
          OwnerHttp.get(
            Uri.parse('$api/api/owner/vehicles/$id/drivers'),
            json: false,
          ),
          OwnerHttp.get(
            Uri.parse('$api/api/owner/vehicles/$id/active-driver'),
            json: false,
          ),
        ]);

        if (responses[0].statusCode == 200) {
          final data = jsonDecode(responses[0].body);
          final rows = data is Map && data['drivers'] is List
              ? data['drivers'] as List
              : const [];

          for (final raw in rows.whereType<Map>()) {
            final row = Map<String, dynamic>.from(raw);
            row['_vehicle_id'] = id;
            row['_plate'] = plate;
            row['_make'] = '${vehicle['make'] ?? ''}'.trim();
            row['_model'] = '${vehicle['model'] ?? ''}'.trim();
            allDrivers.add(row);
          }
        }

        if (nextActiveVehicleId == null && responses[1].statusCode == 200) {
          final data = jsonDecode(responses[1].body);
          if (data is Map && data['active'] == true) {
            nextActiveVehicleId = id;
            nextActivePlate = plate;
            nextName = data['driverName']?.toString();
            nextUntil = DateTime.tryParse(
              data['activeUntil']?.toString() ?? '',
            )?.toLocal();
          }
        }
      }

      final seen = <String>{};
      final uniqueDrivers = <Map<String, dynamic>>[];
      for (final driver in allDrivers) {
        final key =
            '${driver['_vehicle_id'] ?? ''}|${driver['driver_user_id'] ?? ''}';
        if (seen.add(key)) uniqueDrivers.add(driver);
      }

      if (!mounted) return;
      setState(() {
        premium = vehicleJson is Map && vehicleJson['familyPremium'] == true;
        ownerVehicles = vehicles;
        drivers = uniqueDrivers;
        active = nextActiveVehicleId != null;
        activeVehicleId = nextActiveVehicleId;
        activePlate = nextActivePlate;
        name = nextName;
        until = nextUntil;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void locked() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CepqarTheme.panel,
        title: Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFF8B5CFF)),
            SizedBox(width: 8),
            Text(
              'Aile Premium',
              style: TextStyle(color: CepqarTheme.text),
            ),
          ],
        ),
        content: Text(
          'Yetkili sürücü davet etme ve aktif sürücü seçme Aile Premium ile kullanılabilir. Paketi yalnızca araç sahibi hesabından yükseltebilirsin.',
          style: TextStyle(color: CepqarTheme.muted),
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

  Future<Map<String, dynamic>?> _pickInviteVehicle() async {
    if (ownerVehicles.isEmpty) return null;
    if (ownerVehicles.length == 1) return ownerVehicles.first;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Sürücüyü hangi araca davet edeceksin?',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Sürücü daveti seçtiğin araca yetki verir.',
              ),
            ),
            for (final vehicle in _orderedVehicles(ownerVehicles))
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.directions_car_rounded),
                ),
                title: Text(
                  '${vehicle['plate'] ?? 'Araç'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim(),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(c, vehicle),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> invite() async {
    if (!premium) {
      locked();
      return;
    }

    final target = await _pickInviteVehicle();
    if (target == null || !mounted) return;

    final targetVehicleId = '${target['id'] ?? ''}'.trim();
    if (targetVehicleId.isEmpty) return;

    setState(() => loading = true);
    try {
      final r = await OwnerHttp.post(
        Uri.parse(
          '$api/api/owner/vehicles/$targetVehicleId/driver-invites',
        ),
      );
      final j = jsonDecode(r.body);

      if (r.statusCode >= 200 && r.statusCode < 300) {
        final code = j['code'].toString();
        if (!mounted) return;

        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (c) => Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sürücü davet kodu',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${target['plate'] ?? 'Araç'} için oluşturuldu. Bu kodu sürücüyle paylaş. CepQontag giriş ekranında “Davet kodum var” seçeneğinden kabul edebilir.',
                ),
                const SizedBox(height: 18),
                Center(
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Kod 7 gün geçerlidir.',
                    style: TextStyle(color: CepqarTheme.muted),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sürücü davet kodu kopyalandı',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Kodu Kopyala'),
                  ),
                ),
              ],
            ),
          ),
        );

        await load();
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sürücü daveti oluşturulamadı.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> choose() async {
    if (!premium) {
      locked();
      return;
    }

    await load();
    if (!mounted) return;

    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kabul edilmiş sürücü bulunamadı. Davet kodunun sürücü tarafından kabul edildiğini kontrol et.',
          ),
        ),
      );
      return;
    }

    final d = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Şu an kim kullanıyor?',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Tüm araçlarına eklenmiş sürücüler aşağıda gösterilir.',
              ),
            ),
            for (final x in drivers)
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(
                  x['driver_name']?.toString() ?? 'Sürücü',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${x['_plate'] ?? ''}'
                  '${('${x['_make'] ?? ''} ${x['_model'] ?? ''}').trim().isEmpty ? '' : ' • ${('${x['_make'] ?? ''} ${x['_model'] ?? ''}').trim()}'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(c, x),
              ),
          ],
        ),
      ),
    );

    if (d == null || !mounted) return;

    final h = await showModalBottomSheet<dynamic>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: Text(
                '${d['driver_name']} • ${d['_plate']} ne kadar kullanacak?',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            for (final x in [1, 3, 6, 12, 24])
              ListTile(
                title: Text('$x saat'),
                onTap: () => Navigator.pop(c, x),
              ),
            ListTile(
              title: const Text('Ben kapatana kadar'),
              onTap: () => Navigator.pop(c, 'forever'),
            ),
          ],
        ),
      ),
    );

    if (h == null) return;

    final targetVehicleId = '${d['_vehicle_id'] ?? ''}'.trim();
    if (targetVehicleId.isEmpty) return;

    setState(() => loading = true);
    try {
      final r = await OwnerHttp.put(
        Uri.parse(
          '$api/api/owner/vehicles/$targetVehicleId/selected-driver',
        ),
        body: jsonEncode({
          'driverUserId': d['driver_user_id'],
          'hours': h == 'forever' ? null : h,
        }),
      );

      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception();
      }

      await load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aktif sürücü seçilemedi.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> stop() async {
    if (!premium) {
      locked();
      return;
    }

    final targetVehicleId =
        activeVehicleId?.trim().isNotEmpty == true
            ? activeVehicleId!.trim()
            : vehicleId;

    if (targetVehicleId.isEmpty) return;

    setState(() => loading = true);
    try {
      await OwnerHttp.delete(
        Uri.parse(
          '$api/api/owner/vehicles/$targetVehicleId/selected-driver',
        ),
        json: false,
      );
      await load();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: premium ? null : locked,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF6F3DE8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8F6BFF),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFF3EEFF),
                    child: Icon(
                      Icons.group_rounded,
                      color: Color(0xFF4D347C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'Şu an kim kullanıyor?',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (!loading && !premium) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.lock_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              const Text(
                                'Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          active && premium
                              ? '${name ?? ''} • ${activePlate ?? 'Araç'} kullanıyor${until == null ? '' : ' • ${until!.hour.toString().padLeft(2, '0')}:${until!.minute.toString().padLeft(2, '0')}’a kadar'}'
                              : drivers.isNotEmpty
                                  ? '${drivers.length} yetkili sürücü hazır. Aktif sürücüyü seç.'
                                  : 'Araç sahibi aktif sürücüyü seçer.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        onPressed: loading ? null : (premium ? invite : locked),
                        icon: Icon(
                          premium
                              ? Icons.person_add_rounded
                              : Icons.lock_rounded,
                          size: 15,
                        ),
                        label: Text(
                          premium ? 'Sürücü Davet Et' : 'Premium',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5A4D86),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF5A4D86),
                          disabledForegroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        onPressed:
                            loading
                                ? null
                                : (premium
                                    ? (active ? stop : choose)
                                    : locked),
                        child: Text(
                          premium
                              ? (active ? 'Sürüşü Bitir' : 'Sürücü Seç')
                              : 'Premium',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.2,
                            fontWeight: FontWeight.w800,
                          ),
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
