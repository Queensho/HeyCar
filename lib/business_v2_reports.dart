import 'package:flutter/material.dart';
import 'car_wash_api.dart';
import 'car_wash_pages.dart';

class BusinessReports extends StatefulWidget {
  const BusinessReports({super.key, required this.api});
  final CarWashApi api;
  @override
  State<BusinessReports> createState() => _BusinessReportsState();
}

class _BusinessReportsState extends State<BusinessReports> {
  late DateTime from, to;
  late Future<WashJson> future;
  @override
  void initState() {
    super.initState();
    to = DateTime.now().toUtc().add(const Duration(hours: 3));
    from = DateTime(to.year, to.month);
    future = _fetch();
  }

  Future<WashJson> _fetch() => widget.api.call(
      '/api/business/car-wash/reports?from=${washDate(from)}&to=${washDate(to)}');
  void _load() => setState(() {
        future = _fetch();
      });
  @override
  Widget build(BuildContext context) => WashLoader(
      future: future,
      retry: _load,
      builder: (data) {
        final summary = data['summary'] as Map? ?? {};
        final days = washRows(data['daily']);
        final maximum = days.fold<num>(
            0, (n, d) => (d['count'] as num) > n ? d['count'] as num : n);
        return ListView(padding: const EdgeInsets.all(18), children: [
          Text('Raporlar', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final period in {
              'today': 'Bugün',
              'week': 'Bu hafta',
              'month': 'Bu ay'
            }.entries)
              OutlinedButton(
                  onPressed: () {
                    final now =
                        DateTime.now().toUtc().add(const Duration(hours: 3));
                    to = DateTime(now.year, now.month, now.day);
                    from = period.key == 'today'
                        ? to
                        : period.key == 'week'
                            ? to.subtract(Duration(days: to.weekday - 1))
                            : DateTime(to.year, to.month);
                    _load();
                  },
                  child: Text(period.value)),
            OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: const Text('Tarih aralığı'),
                onPressed: () async {
                  final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                      initialDateRange: DateTimeRange(start: from, end: to));
                  if (range != null && mounted) {
                    if (range.duration.inDays > 366) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('En fazla 366 günlük aralık seçin.')));
                      return;
                    }
                    from = range.start;
                    to = range.end;
                    _load();
                  }
                })
          ]),
          const SizedBox(height: 12),
          Text('${data['from']} – ${data['to']} · Türkiye saati'),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final item in {
              'Randevu': '${summary['total_count'] ?? 0}',
              'Tamamlanan işlem': '${summary['completed_count'] ?? 0}',
              'İptal oranı': '%${summary['cancellation_percent'] ?? 0}',
              'Tamamlanan randevu tutarı':
                  washPrice(summary['completed_amount_kurus'])
            }.entries)
              SizedBox(
                  width: 240,
                  child: Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.key),
                                const SizedBox(height: 8),
                                Text(item.value,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700))
                              ]))))
          ]),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                  'Tutar, tamamlanan randevuların kayıtlı toplam bedelidir. Tahsil edilen gelir değildir. İptal oranı: iptal / seçili aralıktaki tüm randevular.')),
          Text('Günlük randevu sayısı',
              style: Theme.of(context).textTheme.titleLarge),
          if (days.isEmpty) const Text('Bu aralıkta randevu bulunmuyor.'),
          for (final day in days)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${day['day']} · ${day['count']} randevu'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                          value: maximum == 0
                              ? 0
                              : (day['count'] as num) / maximum,
                          semanticsLabel: '${day['day']} randevu sayısı',
                          semanticsValue:
                              '${maximum == 0 ? 0 : ((day['count'] as num) / maximum * 100).round()}%',
                          color: const Color(0xFF651FFF),
                          backgroundColor: const Color(0xFFF3EDFF),
                          minHeight: 8)
                    ])),
          const SizedBox(height: 20),
          Text('Hizmet bazlı işlem hacmi',
              style: Theme.of(context).textTheme.titleLarge),
          for (final s in washRows(data['services']))
            Card(
                child: ListTile(
                    title: Text('${s['service_name']}'),
                    subtitle: Text(
                        '${s['count']} randevu · ${s['completed_count']} tamamlanan\nTamamlanan tutarı: ${washPrice(s['completed_amount_kurus'])}'))),
          const SizedBox(height: 20),
          Text('Personel iş yükü',
              style: Theme.of(context).textTheme.titleLarge),
          const Text('İptal ve ret hariç atanan işlem süresi.'),
          for (final s in washRows(data['staff']))
            Card(
                child: ListTile(
                    title: Text('${s['name']}'),
                    subtitle: Text(
                        '${s['count']} randevu · ${s['minutes']} dakika'))),
        ]);
      });
}
