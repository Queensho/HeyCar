import 'package:flutter/material.dart';
import 'car_wash_api.dart';
import 'car_wash_pages.dart';

class BusinessCustomers extends StatefulWidget {
  const BusinessCustomers(
      {super.key, required this.api, required this.onBooking, this.customerId});
  final CarWashApi api;
  final Future<void> Function(WashJson) onBooking;
  final String? customerId;
  @override
  State<BusinessCustomers> createState() => _BusinessCustomersState();
}

class _BusinessCustomersState extends State<BusinessCustomers> {
  final search = TextEditingController();
  int offset = 0;
  bool completed = false;
  late Future<WashJson> future;
  @override
  void initState() {
    super.initState();
    future = _fetch();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<WashJson> _fetch() => widget.api.call(
      '/api/business/car-wash/customers${widget.customerId == null ? '' : '/${widget.customerId}'}?offset=$offset${widget.customerId == null ? '&completed=$completed${search.text.trim().isEmpty ? '' : '&q=${Uri.encodeQueryComponent(search.text.trim())}'}' : ''}');
  void _load() => setState(() {
        future = _fetch();
      });
  @override
  Widget build(BuildContext context) => WashLoader(
      future: future,
      retry: _load,
      builder: (data) {
        final detail = widget.customerId != null;
        final customer = data['customer'] as Map?;
        return ListView(padding: const EdgeInsets.all(18), children: [
          Text(detail ? '${customer?['name'] ?? 'Müşteri'}' : 'Müşteriler',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Yalnız işletmenizin randevu geçmişi. Telefon ve özel iletişim bilgileri paylaşılmaz.'),
          if (!detail) ...[
            const SizedBox(height: 16),
            TextField(
                controller: search,
                maxLength: 80,
                decoration: InputDecoration(
                    labelText: 'Müşteri adı veya randevudaki plaka',
                    suffixIcon: IconButton(
                        tooltip: 'Ara',
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          offset = 0;
                          _load();
                        })),
                onSubmitted: (_) {
                  offset = 0;
                  _load();
                }),
            FilterChip(
                label: const Text('Tamamlanmış işlemi olanlar'),
                selected: completed,
                onSelected: (v) {
                  completed = v;
                  offset = 0;
                  _load();
                }),
            if (washRows(data['customers']).isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aramanıza uygun müşteri bulunamadı.')),
            for (final c in washRows(data['customers']))
              Card(
                  child: ListTile(
                      title: Text('${c['name']}'),
                      subtitle: Text(
                          '${(c['plates'] as List? ?? []).join(' · ')}\n${c['completed_count']} tamamlanan / ${c['booking_count']} randevu'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => WashScaffold(
                                  title: 'Müşteri geçmişi',
                                  child: BusinessCustomers(
                                      api: widget.api,
                                      onBooking: widget.onBooking,
                                      customerId: '${c['id']}')))))),
          ] else ...[
            Text(
                '${customer?['completed_count']} tamamlanan işlem · ${customer?['booking_count']} randevu'),
            for (final b in washRows(data['bookings']))
              Card(
                  child: ListTile(
                      title:
                          Text('${b['vehicle_plate']} · ${b['service_name']}'),
                      subtitle: Text(
                          '${b['make'] ?? ''} ${b['model'] ?? ''}\n${washTime(b['starts_at'])}\n${washStatuses[b['status']]} · ${washPrice(b['price_kurus'])}'),
                      onTap: () => widget.onBooking(b))),
          ],
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, children: [
            TextButton(
                onPressed: offset > 0
                    ? () {
                        offset -= 50;
                        _load();
                      }
                    : null,
                child: const Text('Önceki')),
            TextButton(
                onPressed: data['hasMore'] == true
                    ? () {
                        offset += 50;
                        _load();
                      }
                    : null,
                child: const Text('Sonraki'))
          ]),
        ]);
      });
}
