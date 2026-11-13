import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_environment.dart';
import 'owner_auth.dart';
import 'car_wash_api.dart';
import 'car_wash_pages.dart';

Future<void> openOwnerServiceNotification(
    BuildContext context, Map<String, dynamic> n, {CarWashApi? api}) async {
  final category =
          '${n['service_category'] ?? n['serviceCategory'] ?? (n['type'] == 'car_wash' ? 'car_wash' : '')}',
      id = '${n['booking_id'] ?? n['bookingId'] ?? n['appointmentId'] ?? ''}';
  if (!RegExp(r'^[a-z][a-z0-9_]{1,63}$').hasMatch(category) ||
      id.isEmpty ||
      id.length > 128) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const [
                'car_wash',
                'interior',
                'polish',
                'ceramic',
                'ppf',
                'inspection'
              ].contains(category) &&
              RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)
          ? WashBookingDetailPage(api: api ?? CarWashApi(), id: id)
          : OwnerServiceHistoryPage(category: category, appointmentId: id)));
}

class OwnerServiceHistoryPage extends StatefulWidget {
  const OwnerServiceHistoryPage(
      {super.key, required this.category, required this.appointmentId});
  final String category, appointmentId;
  @override
  State<OwnerServiceHistoryPage> createState() => _HistoryState();
}

class _HistoryState extends State<OwnerServiceHistoryPage> {
  late final Future<List<dynamic>> history = _load();
  Future<List<dynamic>> _load() async {
    final r = await OwnerHttp.get(
        Uri.parse(
            '$apiBaseUrl/api/owner/notifications/services/${Uri.encodeComponent(widget.category)}/${Uri.encodeComponent(widget.appointmentId)}'),
        json: false);
    if (r.statusCode != 200) throw Exception('Bildirim geçmişi alınamadı.');
    return (jsonDecode(r.body) as Map)['history'] as List;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: const Text('Hizmet bildirimleri'),
          backgroundColor: Colors.white),
      body: FutureBuilder<List<dynamic>>(
          future: history,
          builder: (context, s) {
            if (s.hasError)
              return const Center(child: Text('Bildirim geçmişi alınamadı.'));
            if (!s.hasData)
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF651FFF)));
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('Kayıt: ${widget.appointmentId}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              for (final n in s.data!)
                ListTile(
                    leading:
                        const Icon(Icons.event_note, color: Color(0xFF651FFF)),
                    title: Text('${n['title']}'),
                    subtitle: Text('${n['message']}\n${n['created_at']}'))
            ]);
          }));
}
