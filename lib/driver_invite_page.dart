import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _api = 'https://heycar-api-185-165-46-213.nip.io';

const _bg = Color(0xFF06111F);
const _card = Color(0xFF101A30);
const _card2 = Color(0xFF121C33);
const _border = Color(0xFF29375F);
const _purple = Color(0xFF8B5CFF);
const _purpleSoft = Color(0xFFC8B4FF);
const _muted = Color(0xFFA7B0C7);

class DriverCodeEntryPage extends StatefulWidget {
  const DriverCodeEntryPage({super.key});

  @override
  State<DriverCodeEntryPage> createState() => _DriverCodeEntryPageState();
}

class _DriverCodeEntryPageState extends State<DriverCodeEntryPage> {
  final code = TextEditingController(text: 'PQ');
  String? error;
  bool busy = false;

  Future<void> go() async {
    final value = code.text.trim().toUpperCase().replaceAll(' ', '');
    if (!RegExp(r'^PQ[A-Z2-9]{6}$').hasMatch(value)) {
      setState(() => error = 'PQ ile başlayan 8 karakterli davet kodunu gir.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final response = await http.get(Uri.parse('$_api/api/driver/invites/$value'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DriverInvitePage(token: value)),
        );
      } else {
        setState(() => error = 'Davet kodu geçersiz veya süresi dolmuş.');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Bağlantı hatası.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF110F16),
        title: const Text('Davet Kodu'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              const Icon(Icons.group_add_rounded, size: 72, color: _purple),
              const SizedBox(height: 20),
              const Text(
                'Sürücü davet kodunu gir',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Araç sahibinin verdiği PQ ile başlayan kodu kullan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
                decoration: const InputDecoration(
                  labelText: 'Davet Kodu',
                  hintText: 'PQ7M4K2A',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : go,
                child: Text(busy ? 'Kontrol ediliyor...' : 'Devam Et'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverInvitePage extends StatefulWidget {
  final String token;

  const DriverInvitePage({super.key, required this.token});

  @override
  State<DriverInvitePage> createState() => _DriverInvitePageState();
}

class _DriverInvitePageState extends State<DriverInvitePage> {
  final phone = TextEditingController();
  final name = TextEditingController();
  final pass = TextEditingController();

  Map<String, dynamic>? invite;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final response = await http.get(
        Uri.parse('$_api/api/driver/invites/${widget.token.toUpperCase()}'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => invite = jsonDecode(response.body)['invite']);
      } else {
        setState(() => error = 'Davet geçersiz veya süresi dolmuş.');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Davet yüklenemedi.');
    }
  }

  Future<void> accept() async {
    setState(() => busy = true);
    try {
      final response = await http.post(
        Uri.parse('$_api/api/driver/invites/${widget.token.toUpperCase()}/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone.text,
          'displayName': name.text,
          'password': pass.text,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('driver_logged_in', true);
        await prefs.setString('driver_user_id', data['user']['id'].toString());
        await prefs.setString(
          'driver_name',
          data['user']['displayName'].toString(),
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DriverHomePage(
                userId: data['user']['id'].toString(),
              ),
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          error = data['error'] == 'PASSWORD_INVALID'
              ? 'Bu telefon kayıtlı. Şifreni kontrol et.'
              : 'Davet kabul edilemedi.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Bağlantı hatası.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF110F16),
        title: const Text('Sürücü Daveti'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (invite != null) ...[
              const Icon(
                Icons.directions_car_rounded,
                size: 64,
                color: _purple,
              ),
              const SizedBox(height: 14),
              Text(
                '${invite!['plate']} • ${invite!['make']} ${invite!['model'] ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${invite!['owner_name']} seni bu araca yetkili sürücü olarak davet etti.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Ad Soyad'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Şifre (en az 6 karakter)',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: busy ? null : accept,
                child: Text(busy ? 'Bekle...' : 'Daveti Kabul Et'),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DriverHomePage extends StatefulWidget {
  final String userId;

  const DriverHomePage({super.key, required this.userId});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  List<dynamic> vehicles = [];
  List<dynamic> notifications = [];
  bool loading = true;
  String driverName = 'Sürücü';
  int navIndex = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('driver_name')?.trim();
      final headers = {'x-user-id': widget.userId};
      final responses = await Future.wait([
        http.get(Uri.parse('$_api/api/driver/vehicles'), headers: headers),
        http.get(Uri.parse('$_api/api/driver/notifications'), headers: headers),
      ]);

      if (!mounted) return;
      setState(() {
        if (savedName != null && savedName.isNotEmpty) driverName = savedName;
        vehicles = responses[0].statusCode == 200
            ? (jsonDecode(responses[0].body)['vehicles'] ?? [])
            : [];
        notifications = responses[1].statusCode == 200
            ? (jsonDecode(responses[1].body)['notifications'] ?? [])
            : [];
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get hasActiveVehicle =>
      vehicles.any((vehicle) => vehicle['active'] == true);

  String _firstName() {
    final value = driverName.trim();
    if (value.isEmpty) return 'Sürücü';
    return value.split(RegExp(r'\s+')).first;
  }

  String _vehicleTitle(dynamic vehicle) {
    final plate = vehicle['plate']?.toString().trim() ?? '';
    final make = vehicle['make']?.toString().trim() ?? '';
    final model = vehicle['model']?.toString().trim() ?? '';
    return '$plate • $make $model'.trim();
  }

  IconData _notificationIcon(dynamic notification) {
    final text = '${notification['type'] ?? ''} ${notification['message'] ?? ''}'
        .toLowerCase();
    if (text.contains('far')) return Icons.highlight_rounded;
    if (text.contains('park') || text.contains('çıkış') || text.contains('cikis')) {
      return Icons.local_parking_rounded;
    }
    if (text.contains('çek') || text.contains('cek')) return Icons.car_crash_rounded;
    if (text.contains('call') || text.contains('ara')) return Icons.phone_rounded;
    return Icons.qr_code_rounded;
  }

  String _notificationTitle(dynamic notification) {
    final message = notification['message']?.toString().trim() ?? '';
    final type = notification['type']?.toString().trim().toLowerCase() ?? '';
    final lower = message.toLowerCase();
    if (lower.contains('far')) return 'Farlar açık kalmış';
    if (lower.contains('çıkış') || lower.contains('cikis')) {
      return 'Araç çıkışı kapatıyor';
    }
    if (lower.contains('çek') || lower.contains('cek')) return 'Çekilme riski var';
    if (type.contains('call')) return 'Arama isteği';
    if (type.contains('message')) return 'Yeni mesaj';
    return 'Yeni QR bildirimi';
  }

  String _relativeTime(dynamic notification) {
    final raw = notification['created_at']?.toString();
    final date = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (date == null) return 'Şimdi';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return '${diff.inDays} gün önce';
  }

  bool _isUnread(dynamic notification) {
    final status = notification['status']?.toString().toLowerCase();
    return status == null || status.isEmpty || status == 'new' || status == 'unread';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A1020),
        surfaceTintColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 28),
              )
            : null,
        title: const Text(
          'Cepqar • Sürücü',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.refresh_rounded, size: 28),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : RefreshIndicator(
              color: _purple,
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                children: [
                  _Hero(driverName: _firstName()),
                  const SizedBox(height: 28),
                  const _SectionTitle('Yetkili olduğun araçlar'),
                  const SizedBox(height: 12),
                  if (vehicles.isEmpty)
                    const _EmptyVehicleCard()
                  else
                    for (final vehicle in vehicles) ...[
                      _VehicleCard(
                        title: _vehicleTitle(vehicle),
                        active: vehicle['active'] == true,
                      ),
                      const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 8),
                  _ActiveStatusCard(active: hasActiveVehicle),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      const Expanded(child: _SectionTitle('Bana gelen bildirimler')),
                      _CountBadge(count: notifications.length),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (notifications.isEmpty)
                    const _EmptyNotificationCard()
                  else
                    for (final notification in notifications) ...[
                      _NotificationCard(
                        icon: _notificationIcon(notification),
                        title: _notificationTitle(notification),
                        message: notification['message']?.toString().trim().isNotEmpty == true
                            ? notification['message'].toString()
                            : 'Araç için yeni bir QR bildirimi geldi.',
                        time: _relativeTime(notification),
                        unread: _isUnread(notification),
                        onTap: () => _showNotification(notification),
                      ),
                      const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 10),
                  const _InfoCard(),
                ],
              ),
            ),
      bottomNavigationBar: _DriverBottomNav(
        index: navIndex,
        onTap: (value) {
          setState(() => navIndex = value);
          if (value == 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bildirimler bu ekranda listeleniyor.')),
            );
          } else if (value == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Yetkili araçların yukarıda listeleniyor.')),
            );
          } else if (value == 3) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sürücü ayarları yakında.')),
            );
          }
        },
      ),
    );
  }

  void _showNotification(dynamic notification) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10182A),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _notificationTitle(notification),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                notification['message']?.toString() ?? 'Bildirim detayı bulunamadı.',
                style: const TextStyle(color: _muted, fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 14),
              Text(
                _relativeTime(notification),
                style: const TextStyle(color: _purpleSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String driverName;

  const _Hero({required this.driverName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1427), Color(0xFF121331)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            bottom: -4,
            child: Opacity(
              opacity: .95,
              child: Container(
                width: 170,
                height: 128,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: [
                      _purple.withOpacity(.04),
                      _purple.withOpacity(.20),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 26,
                      bottom: 25,
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        size: 84,
                        color: Color(0xFF6F4FEA),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      top: 25,
                      child: Icon(
                        Icons.person_rounded,
                        size: 66,
                        color: Color(0xFFA381FF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 160, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merhaba $driverName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Yetkili olduğun araç bildirimleri burada görünür.',
                  style: TextStyle(color: _muted, fontSize: 14, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final String title;
  final bool active;

  const _VehicleCard({required this.title, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7F55E9), Color(0xFF432278)],
              ),
              border: Border.all(color: _purple.withOpacity(.6)),
            ),
            child: const Icon(Icons.directions_car_filled_rounded, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  active
                      ? 'Araç sahibi seni şu an aktif sürücü olarak seçti.'
                      : 'Yetkili sürücüsün. Aktif sürücüyü araç sahibi belirler.',
                  style: const TextStyle(color: _muted, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _purple.withOpacity(.13),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _purple.withOpacity(.75)),
            ),
            child: Text(
              active ? 'Aktif' : 'Yetkili',
              style: const TextStyle(
                color: _purpleSoft,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveStatusCard extends StatelessWidget {
  final bool active;

  const _ActiveStatusCard({required this.active});

  @override
  Widget build(BuildContext context) {
    final statusColor = active ? const Color(0xFF55E6A5) : const Color(0xFFFF8191);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF18213A),
              border: Border.all(color: _border),
            ),
            child: Icon(Icons.person_rounded, color: active ? _purpleSoft : _muted, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aktif sürücü durumu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: statusColor.withOpacity(.75)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? Icons.check_circle_rounded : Icons.remove_circle_rounded,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        active ? 'Aktif' : 'Pasif',
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  active
                      ? 'QR bildirimleri şu anda sana yönlendiriliyor.'
                      : 'Araç sahibi seni aktif sürücü olarak seçtiğinde QR bildirimleri sana yönlenir.',
                  style: const TextStyle(color: _muted, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String time;
  final bool unread;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = unread ? const Color(0xFFE568FF) : const Color(0xFF748CFF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withOpacity(.42)),
          boxShadow: unread
              ? [
                  BoxShadow(
                    color: accent.withOpacity(.08),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(.18),
                border: Border.all(color: accent.withOpacity(.48)),
              ),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniChip(
                        icon: unread ? Icons.circle : Icons.done_rounded,
                        text: unread ? 'Yeni' : 'Okundu',
                        color: accent,
                      ),
                      _MiniChip(
                        icon: Icons.schedule_rounded,
                        text: time,
                        color: _muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Icon(Icons.chevron_right_rounded, color: accent, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MiniChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: icon == Icons.circle ? 8 : 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        shape: count < 10 ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: count < 10 ? null : BorderRadius.circular(99),
        color: _purple.withOpacity(.45),
        border: Border.all(color: _purple.withOpacity(.75)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _EmptyVehicleCard extends StatelessWidget {
  const _EmptyVehicleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Color(0xFF23194B),
            child: Icon(Icons.directions_car_outlined, color: _purpleSoft),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Henüz yetkili olduğun bir araç bulunmuyor.',
              style: TextStyle(color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotificationCard extends StatelessWidget {
  const _EmptyNotificationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF1C2340),
            child: Icon(Icons.notifications_none_rounded, color: _purpleSoft, size: 32),
          ),
          SizedBox(height: 14),
          Text(
            'Henüz bildirim yok',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 7),
          Text(
            'Araç sahibi seni aktif sürücü seçtiğinde gelen QR bildirimleri burada görünür.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101930),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _purpleSoft, size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Aktif sürücü seçildiğinde yeni QR bildirimleri burada listelenir.',
              style: TextStyle(color: _purpleSoft, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _DriverBottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF08111F),
        border: Border(top: BorderSide(color: Color(0xFF1C2848))),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 72,
          backgroundColor: Colors.transparent,
          indicatorColor: _purple.withOpacity(.18),
          selectedIndex: index,
          onDestinationSelected: onTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: _purple),
              label: 'Ana Sayfa',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_none_rounded),
              selectedIcon: Icon(Icons.notifications_rounded, color: _purple),
              label: 'Bildirimler',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car_rounded, color: _purple),
              label: 'Araçlar',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded, color: _purple),
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }
}
