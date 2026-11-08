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
            'imageUrl': image
          }));
      if (r.statusCode != 200)
        throw Exception('Kampanya kaydedilemedi (${r.statusCode}).');
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
        for (final entry in {
          'title': 'Başlık',
          'description': 'Açıklama',
          'badge': 'İndirim etiketi',
          'terms': 'Koşullar',
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
