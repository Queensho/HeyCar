import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'onboarding_backend.dart';
import 'owner_auth.dart';

const _bg = Color(0xFFF8FAFF);
const _panel = Color(0xFFFFFFFF);
const _ink = Color(0xFF11162F);
const _body = Color(0xFF71798E);
const _purple = Color(0xFF6B31F3);
const _purple2 = Color(0xFF7B43FF);
const _purpleSoft = Color(0xFFF3EEFF);
const _line = Color(0xFFE4E6EE);
const _green = Color(0xFF43B949);
const _greenSoft = Color(0xFFEFFDEB);
const _blue = Color(0xFF2680E8);
const _blueSoft = Color(0xFFEDF5FF);
const _amber = Color(0xFFE89A13);
const _amberSoft = Color(0xFFFFF6E4);
const _red = Color(0xFFE84B5F);
const _redSoft = Color(0xFFFFEFF2);

const _categories = <String, String>{
  'technical': 'Teknik sorun',
  'qr': 'QR / Etiket',
  'vehicle': 'Araç',
  'notifications_calls': 'Bildirim / Arama',
  'offers': 'Fırsatlar',
  'premium_payment': 'Premium / Ödeme',
  'account_security': 'Hesap / Profil',
  'other': 'Diğer',
};

String _statusLabel(String s) => switch (s) {
      'open' => 'Açık',
      'in_review' => 'İncelemede',
      'answered' => 'Yanıtlandı',
      'resolved' => 'Çözüldü',
      _ => s,
    };

Color _statusColor(String s) => switch (s) {
      'open' => _red,
      'in_review' => _amber,
      'answered' => _blue,
      'resolved' => _green,
      _ => _body,
    };

Color _statusSoft(String s) => switch (s) {
      'open' => _redSoft,
      'in_review' => _amberSoft,
      'answered' => _blueSoft,
      'resolved' => _greenSoft,
      _ => const Color(0xFFF4F5F8),
    };

String _date(dynamic raw) {
  final d = DateTime.tryParse('${raw ?? ''}')?.toLocal();
  if (d == null) return '-';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}.${p(d.month)}.${d.year} ${p(d.hour)}:${p(d.minute)}';
}

class SupportTicketPage extends StatefulWidget {
  const SupportTicketPage({super.key});

  @override
  State<SupportTicketPage> createState() => _SupportTicketPageState();
}

class _SupportTicketPageState extends State<SupportTicketPage> {
  final _message = TextEditingController();
  final _picker = ImagePicker();

  String _category = 'technical';
  String _filter = 'all';
  XFile? _image;
  Uint8List? _imageBytes;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _message.addListener(_messageChanged);
    _load();
  }

  @override
  void dispose() {
    _message.removeListener(_messageChanged);
    _message.dispose();
    super.dispose();
  }

  void _messageChanged() {
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_filter == 'all') return _items;
    return _items.where((x) => (x['status'] ?? '').toString() == _filter).toList();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await OwnerHttp.get(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/support-tickets'),
        json: false,
      ).timeout(const Duration(seconds: 15));
      final d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception('Destek talepleri alınamadı.');
      }
      final raw = d is Map ? d['items'] : null;
      final rows = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _items = rows);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Görsel en fazla 5 MB olabilir.'),
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _image = x;
          _imageBytes = bytes;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görsel seçilemedi.')),
        );
      }
    }
  }

  Future<void> _send() async {
    final message = _message.text.trim();
    if (message.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sorununu en az 10 karakterle açıkla.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final r = await OwnerHttp.post(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/support-tickets'),
        body: jsonEncode({
          'category': _category,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 20));

      final d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        final code = d is Map ? d['error']?.toString() : '';
        if (code == 'TOO_MANY_SUPPORT_TICKETS') {
          throw Exception(
            'Kısa sürede çok fazla talep oluşturdun. Biraz sonra tekrar dene.',
          );
        }
        throw Exception('Destek talebi oluşturulamadı.');
      }

      final ticket = d is Map ? d['ticket'] : null;
      final ticketId = ticket is Map ? '${ticket['id'] ?? ''}' : '';
      bool imageOk = true;

      if (ticketId.isNotEmpty && _imageBytes != null && _image != null) {
        final name = _image!.name.toLowerCase();
        final mime = name.endsWith('.png')
            ? 'image/png'
            : name.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg';

        final up = await OwnerHttp.post(
          Uri.parse(
            '${OnboardingBackend.baseUrl}/api/owner/support-tickets/$ticketId/attachment',
          ),
          json: false,
          headers: {'Content-Type': mime},
          body: _imageBytes!,
        ).timeout(const Duration(seconds: 30));
        imageOk = up.statusCode >= 200 && up.statusCode < 300;
      }

      _message.clear();
      setState(() {
        _image = null;
        _imageBytes = null;
        _category = 'technical';
      });
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              imageOk
                  ? 'Destek talebin oluşturuldu.'
                  : 'Talep oluşturuldu; görsel yüklenemedi.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showHelpCenter() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DCE6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _purpleSoft,
                    child: Icon(
                      Icons.headset_mic_rounded,
                      color: _purple,
                      size: 23,
                    ),
                  ),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Yardım Merkezi',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _FaqRow(
                title: 'QR etiketi çalışmıyor',
                body:
                    'QR okunmuyorsa etiket kodunu manuel girerek araca ulaşmayı deneyebilirsin.',
              ),
              _FaqRow(
                title: 'Bildirim veya arama gelmiyor',
                body:
                    'Bildirim izinlerini ve telefonun pil optimizasyonu ayarlarını kontrol et.',
              ),
              _FaqRow(
                title: 'Hesap bilgilerimi değiştirmek istiyorum',
                body:
                    'Profil > Hesap Bilgileri bölümünden ad, telefon ve e-posta bilgilerini düzenleyebilirsin.',
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tamam',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTicket(Map<String, dynamic> x) {
    final status = (x['status'] ?? 'open').toString();
    final reply = (x['admin_reply'] ?? '').toString().trim();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DCE6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${x['id']} • ${_categories[(x['category'] ?? '').toString()] ?? 'Destek'}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _StatusPill(status: status),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                (x['message'] ?? '').toString(),
                style: const TextStyle(
                  color: _body,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _date(x['created_at']),
                style: const TextStyle(
                  color: Color(0xFF9AA1B2),
                  fontSize: 10,
                ),
              ),
              if (reply.isNotEmpty) ...[
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _purpleSoft,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE1D6FB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.support_agent_rounded,
                            color: _purple,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'CepQontag Destek',
                            style: TextStyle(
                              color: _purple,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reply,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 11.5,
                          height: 1.4,
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

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _purple,
          onRefresh: _load,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 16,
                  8,
                  compact ? 14 : 16,
                  28,
                ),
                children: [
                  _SupportTopBar(
                    onBack: () => Navigator.pop(context),
                    onHelp: _showHelpCenter,
                  ),
                  const SizedBox(height: 14),
                  const _SupportHero(),
                  const SizedBox(height: 12),
                  _HelpBanner(onTap: _showHelpCenter),
                  const SizedBox(height: 12),
                  _formCard(compact),
                  const SizedBox(height: 16),
                  _ticketsHeader(),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _purple,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  else if (_error != null)
                    _ErrorCard(message: _error!, onRetry: _load)
                  else if (_filteredItems.isEmpty)
                    const _EmptyCard()
                  else
                    ..._filteredItems.map(_ticketCard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard(bool compact) => Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 14 : 16,
          14,
          compact ? 14 : 16,
          15,
        ),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEEF0F5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0B1330),
              blurRadius: 20,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Yeni destek talebi',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F6FB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _line),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        color: Color(0xFF778097),
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Kişisel bilgileriniz gizli kalır.',
                        style: TextStyle(
                          color: Color(0xFF778097),
                          fontSize: 8.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            const Text(
              'Kategori',
              style: TextStyle(
                color: _body,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              value: _category,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF6D7488),
                size: 22,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.grid_view_rounded,
                  color: Color(0xFF6D7488),
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: _purple,
                    width: 1.3,
                  ),
                ),
              ),
              style: const TextStyle(
                color: _ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
              items: _categories.entries
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (v) => setState(() => _category = v ?? 'technical'),
            ),
            const SizedBox(height: 11),
            const Text(
              'Sorununuzu detaylı olarak anlatın',
              style: TextStyle(
                color: _body,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: _message,
              enabled: !_sending,
              maxLength: 2000,
              minLines: 4,
              maxLines: 5,
              style: const TextStyle(
                color: _ink,
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Sorununuzu yazın...',
                hintStyle: const TextStyle(
                  color: Color(0xFFB0B6C4),
                  fontSize: 11.5,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 72),
                  child: Icon(
                    Icons.article_outlined,
                    color: Color(0xFF7F879B),
                    size: 20,
                  ),
                ),
                counterText:
                    '${_message.text.characters.length.clamp(0, 2000)}/2000',
                counterStyle: const TextStyle(
                  color: Color(0xFF9AA1B2),
                  fontSize: 9.5,
                ),
                filled: true,
                fillColor: const Color(0xFFFDFDFF),
                contentPadding: const EdgeInsets.fromLTRB(11, 12, 11, 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: _purple,
                    width: 1.3,
                  ),
                ),
              ),
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    Image.memory(
                      _imageBytes!,
                      height: 115,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      right: 7,
                      top: 7,
                      child: InkWell(
                        onTap: _sending
                            ? null
                            : () => setState(() {
                                  _image = null;
                                  _imageBytes = null;
                                }),
                        child: Container(
                          width: 29,
                          height: 29,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .60),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
            ],
            Row(
              children: [
                Expanded(
                  child: _AttachmentButton(
                    icon: Icons.image_outlined,
                    label: _imageBytes == null
                        ? 'Ekran görüntüsü ekle'
                        : 'Görseli değiştir',
                    onTap: _sending ? null : () => _pick(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AttachmentButton(
                    icon: Icons.photo_camera_outlined,
                    label: 'Fotoğraf ekle',
                    onTap: _sending ? null : () => _pick(ImageSource.camera),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_purple, _purple2],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(
                    _sending ? 'Gönderiliyor...' : 'Talebi Gönder',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _ticketsHeader() => Row(
        children: [
          const Expanded(
            child: Text(
              'Taleplerim',
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filter,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: Color(0xFF687087),
                ),
                dropdownColor: Colors.white,
                style: const TextStyle(
                  color: _body,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tümü')),
                  DropdownMenuItem(value: 'open', child: Text('Açık')),
                  DropdownMenuItem(
                    value: 'in_review',
                    child: Text('İncelemede'),
                  ),
                  DropdownMenuItem(
                    value: 'answered',
                    child: Text('Yanıtlandı'),
                  ),
                  DropdownMenuItem(
                    value: 'resolved',
                    child: Text('Çözüldü'),
                  ),
                ],
                onChanged: (v) => setState(() => _filter = v ?? 'all'),
              ),
            ),
          ),
        ],
      );

  Widget _ticketCard(Map<String, dynamic> x) {
    final status = (x['status'] ?? 'open').toString();
    final category = (x['category'] ?? '').toString();
    final color = _statusColor(status);
    final bg = _statusSoft(status);
    final reply = (x['admin_reply'] ?? '').toString().trim();

    IconData icon = Icons.chat_bubble_rounded;
    if (category == 'technical') icon = Icons.build_rounded;
    if (category == 'qr') icon = Icons.qr_code_2_rounded;
    if (category == 'account_security') icon = Icons.person_rounded;
    if (category == 'premium_payment') icon = Icons.credit_card_rounded;

    return InkWell(
      onTap: () => _showTicket(x),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: .16)),
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${x['id']} • ${_categories[category] ?? 'Destek'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (x['message'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _body,
                      fontSize: 9.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _date(x['created_at']),
                    style: const TextStyle(
                      color: Color(0xFF9CA3B3),
                      fontSize: 8.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusPill(status: status),
                const SizedBox(height: 8),
                Icon(
                  reply.isNotEmpty
                      ? Icons.mark_chat_read_outlined
                      : Icons.chevron_right_rounded,
                  color: const Color(0xFF667086),
                  size: 19,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportTopBar extends StatelessWidget {
  const _SupportTopBar({
    required this.onBack,
    required this.onHelp,
  });

  final VoidCallback onBack;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 38,
              minHeight: 38,
            ),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _ink,
              size: 25,
            ),
          ),
          const SizedBox(width: 6),
          Image.asset(
            'assets/file_00000000b130820abb8d411e67ab0d25.png',
            height: 31,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onHelp,
            style: OutlinedButton.styleFrom(
              foregroundColor: _purple,
              side: const BorderSide(color: Color(0xFFE0D6FA)),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
            icon: const Icon(Icons.help_outline_rounded, size: 17),
            label: const Text(
              'Yardım Merkezi',
              style: TextStyle(
                fontSize: 9.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
}

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Destek Talepleri',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 27,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.6,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Sorununuzu bize iletin, en kısa sürede size dönüş yapalım.',
                  style: TextStyle(
                    color: _body,
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 5,
            top: 0,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: _purpleSoft,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.headset_mic_rounded,
                    color: _purple,
                    size: 49,
                  ),
                  Positioned(
                    left: 9,
                    top: 10,
                    child: Container(
                      width: 37,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _purple,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '•••',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _HelpBanner extends StatelessWidget {
  const _HelpBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5FF),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE9E1FA)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 23,
                backgroundColor: _purpleSoft,
                child: Icon(
                  Icons.headset_mic_rounded,
                  color: _purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nasıl yardımcı olabiliriz?',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sık sorulan sorulara göz atabilir veya bizimle iletişime geçebilirsiniz.',
                      style: TextStyle(
                        color: _body,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _ink,
                size: 22,
              ),
            ],
          ),
        ),
      );
}

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 55,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            side: const BorderSide(color: _line),
            backgroundColor: const Color(0xFFFDFDFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: _purple, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 10.2,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                color: _body,
                fontSize: 10.2,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _redSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _red.withValues(alpha: .20)),
        ),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _red,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _line),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.support_agent_outlined,
              color: Color(0xFF9BA2B2),
              size: 32,
            ),
            SizedBox(height: 7),
            Text(
              'Bu filtrede destek talebi yok.',
              style: TextStyle(
                color: _body,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}
