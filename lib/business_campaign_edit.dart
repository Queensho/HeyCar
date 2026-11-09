import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'offers/marketplace_api.dart';
import 'offers/marketplace_widgets.dart';

class BusinessCampaignEdit extends StatefulWidget {
  const BusinessCampaignEdit(
      {super.key,
      required this.token,
      required this.campaign,
      required this.pickImage});
  final String token;
  final Map<String, dynamic> campaign;
  final Future<String?> Function() pickImage;
  @override
  State<BusinessCampaignEdit> createState() => _BusinessCampaignEditState();
}

class _BusinessCampaignEditState extends State<BusinessCampaignEdit> {
  final fields = <String, TextEditingController>{};
  late DateTime start, end;
  late String image;
  late String offerType;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    for (final key in [
      'title',
      'description',
      'badge',
      'terms',
      'daily_limit',
      'regular_price',
      'offer_price',
      'discount_percent',
      'total_limit'
    ]) {
      fields[key] =
          TextEditingController(text: marketText(widget.campaign, key));
    }
    start = DateTime.tryParse(marketText(widget.campaign, 'starts_at'))
            ?.toLocal() ??
        DateTime.now();
    end =
        DateTime.tryParse(marketText(widget.campaign, 'ends_at'))?.toLocal() ??
            start.add(const Duration(days: 30));
    image = marketText(widget.campaign, 'image_url');
    offerType = marketText(widget.campaign, 'offer_type', 'discount');
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final daily = fields['daily_limit']!.text.trim(),
        total = fields['total_limit']!.text.trim();
    if (!end.isAfter(start) ||
        [daily, total].any((s) =>
            s.isNotEmpty && (int.tryParse(s) == null || int.parse(s) < 1))) {
      marketMessage(
          context, 'Tarihleri ve pozitif tam sayı limitleri kontrol edin.');
      return;
    }
    for (final key in ['regular_price', 'offer_price']) {
      final value = fields[key]!.text.trim();
      final amount = double.tryParse(value.replaceAll(',', '.'));
      if (value.isNotEmpty && (amount == null || amount < 0)) {
        marketMessage(context, 'Fiyatları geçerli bir sayı olarak girin.');
        return;
      }
    }
    final discount = fields['discount_percent']!.text.trim();
    if (discount.isNotEmpty &&
        (int.tryParse(discount) == null ||
            int.parse(discount) < 1 ||
            int.parse(discount) > 100)) {
      marketMessage(context, 'İndirim oranı 1 ile 100 arasında olmalıdır.');
      return;
    }
    if (fields['title']!.text.trim().isEmpty) {
      marketMessage(context, 'Kampanya başlığı boş bırakılamaz.');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await http.patch(
          Uri.parse(
              '${OnboardingBackend.baseUrl}/api/business/campaigns/${widget.campaign['id']}'),
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'title': fields['title']!.text.trim(),
            'description': fields['description']!.text,
            'badge': fields['badge']!.text,
            'terms': fields['terms']!.text,
            'dailyLimit': int.tryParse(daily),
            'totalLimit': int.tryParse(total),
            'startsAt': start.toUtc().toIso8601String(),
            'endsAt': end.toUtc().toIso8601String(),
            'imageUrl': image,
            'offerType': offerType,
            'regularPrice': double.tryParse(
                fields['regular_price']!.text.replaceAll(',', '.')),
            'offerPrice': double.tryParse(
                fields['offer_price']!.text.replaceAll(',', '.')),
            'discountPercent': int.tryParse(discount)
          }));
      if (r.statusCode != 200) {
        String reason = 'Kampanya kaydedilemedi (${r.statusCode}).';
        try {
          final data = jsonDecode(r.body);
          if (data is Map && data['error'] == 'CAMPAIGN_INVALID') {
            reason = 'Kampanya bilgilerini, tarihleri ve limitleri kontrol edin.';
          } else if (data is Map && data['error'] == 'INVALID_SESSION') {
            reason = 'İşletme oturumu sona erdi. Yeniden giriş yapın.';
          } else if (data is Map && data['error'] == 'NOT_FOUND') {
            reason = 'Kampanya bulunamadı veya bu işletmeye ait değil.';
          }
        } catch (_) {}
        throw Exception(reason);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) marketMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _date(bool first) async {
    final value = await showDatePicker(
        context: context,
        initialDate: first ? start : end,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (value == null) return;
    setState(() {
      if (first) {
        start = value;
      } else {
        end = DateTime(value.year, value.month, value.day, 23, 59, 59);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: offerTheme, child: Builder(builder: _build));
  Widget _build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Kampanyayı düzenle')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Değişiklikler yeniden admin onayına gönderilir.'),
        const SizedBox(height: 16),
        MarketPhoto(image),
        TextButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final value = await widget.pickImage();
                    if (value != null && mounted) setState(() => image = value);
                  },
            icon: const Icon(Icons.photo_outlined),
            label: const Text('Kampanya fotoğrafını değiştir')),
        DropdownButtonFormField<String>(
            initialValue: offerType,
            decoration: const InputDecoration(labelText: 'Fırsat türü'),
            items: const [
              DropdownMenuItem(value: 'discount', child: Text('İndirim')),
              DropdownMenuItem(
                  value: 'special_price', child: Text('Özel fiyat')),
              DropdownMenuItem(value: 'gift', child: Text('Avantaj / hediye'))
            ],
            onChanged: (v) => setState(() => offerType = v ?? 'discount')),
        const SizedBox(height: 16),
        for (final entry in {
          'title': 'Başlık',
          'description': 'Açıklama',
          'badge': 'İndirim etiketi',
          'terms': 'Koşullar',
          'regular_price': 'Normal fiyat (TL)',
          'offer_price': 'Fırsat fiyatı (TL)',
          'discount_percent': 'İndirim oranı (%)',
          'daily_limit': 'Günlük limit (boş: sınırsız)',
          'total_limit': 'Toplam limit (boş: sınırsız)'
        }.entries)
          Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                  controller: fields[entry.key],
                  minLines: 1,
                  maxLines: entry.key == 'description' || entry.key == 'terms'
                      ? 5
                      : 1,
                  decoration: InputDecoration(labelText: entry.value))),
        OutlinedButton(
            onPressed: () => _date(true),
            child:
                Text('Başlangıç: ${start.day}.${start.month}.${start.year}')),
        OutlinedButton(
            onPressed: () => _date(false),
            child: Text('Bitiş: ${end.day}.${end.month}.${end.year}')),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: busy ? null : _save,
            child: Text(busy ? 'Kaydediliyor…' : 'Kaydet ve onaya gönder')),
      ]));
}
