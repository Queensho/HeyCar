import 'package:flutter/material.dart';

enum BusinessSection {
  overview('Genel Bakış', Icons.dashboard_outlined),
  bookings('Randevular', Icons.calendar_month_outlined),
  services('Hizmetler', Icons.design_services_outlined),
  customers('Müşteriler', Icons.people_outline),
  staff('Personel', Icons.badge_outlined),
  capacity('Kapasite ve Çalışma Saatleri', Icons.schedule_outlined),
  reports('Raporlar', Icons.bar_chart_outlined),
  profile('İşletme Profili', Icons.storefront_outlined),
  settings('Ayarlar', Icons.settings_outlined);

  const BusinessSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// A single business session and data source; navigation never creates accounts.
class BusinessV2Shell extends StatefulWidget {
  const BusinessV2Shell({super.key, required this.builder});
  final Widget Function(BusinessSection section) builder;
  @override
  State<BusinessV2Shell> createState() => _BusinessV2ShellState();
}

class _BusinessV2ShellState extends State<BusinessV2Shell> {
  BusinessSection section = BusinessSection.overview;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth >= 1000 &&
            MediaQuery.textScalerOf(context).scale(14) <= 23;
        final content = widget.builder(section);
        if (!wide) {
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<BusinessSection>(
                key: ValueKey(section),
                initialValue: section,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'İşletme bölümü', border: OutlineInputBorder()),
                items: [
                  for (final item in BusinessSection.values)
                    DropdownMenuItem(
                        value: item, child: Text(item.label, maxLines: 2))
                ],
                onChanged: (value) {
                  if (value != null) setState(() => section = value);
                },
              ),
            ),
            Expanded(child: content),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: 260,
              child: Material(
                  color: Colors.white,
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    children: [
                      for (final item in BusinessSection.values)
                        ListTile(
                          key: ValueKey('business-section-${item.name}'),
                          selected: item == section,
                          selectedColor: const Color(0xFF651FFF),
                          selectedTileColor: const Color(0xFFF3EDFF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          leading: Icon(item.icon),
                          title: Text(item.label),
                          onTap: () => setState(() => section = item),
                        )
                    ],
                  ))),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ]);
      });
}
