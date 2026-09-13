import 'package:flutter/material.dart';

void main() => runApp(const HeyCarAdminApp());

class HeyCarAdminApp extends StatelessWidget {
  const HeyCarAdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF6F7F9),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFCA311)),
        ),
        home: const AdminShell(),
      );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int selected = 0;
  final items = const [
    ('Genel Bakış', Icons.space_dashboard_rounded),
    ('QR Etiketleri', Icons.qr_code_2_rounded),
    ('Araçlar', Icons.directions_car_filled_rounded),
    ('Kullanıcılar', Icons.people_alt_rounded),
    ('Bildirimler', Icons.notifications_rounded),
    ('Ayarlar', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: Row(children: [
        if (wide)
          Container(
            width: 250,
            color: const Color(0xFF14213D),
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.directions_car_filled_rounded, color: Color(0xFFFCA311), size: 31),
                SizedBox(width: 10),
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'Car', style: TextStyle(color: Color(0xFFFCA311))),
                ]), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 6),
              const Text('Yönetim Paneli', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 30),
              ...List.generate(items.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selected == i ? const Color(0x22FCA311) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => selected = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          child: Row(children: [
                            Icon(items[i].$2, color: selected == i ? const Color(0xFFFCA311) : Colors.white70),
                            const SizedBox(width: 12),
                            Text(items[i].$1, style: TextStyle(color: selected == i ? Colors.white : Colors.white70, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                  )),
              const Spacer(),
              const Divider(color: Colors.white12),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: Color(0xFFFCA311), child: Icon(Icons.person_rounded, color: Colors.black)),
                title: Text('HeyCar Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                subtitle: Text('Yönetici', style: TextStyle(color: Colors.white54)),
              )
            ]),
          ),
        Expanded(
          child: SafeArea(
            child: Column(children: [
              _topBar(wide),
              Expanded(child: _page()),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected.clamp(0, 3),
              onDestinationSelected: (i) => setState(() => selected = i),
              destinations: items.take(4).map((e) => NavigationDestination(icon: Icon(e.$2), label: e.$1)).toList(),
            ),
    );
  }

  Widget _topBar(bool wide) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        color: Colors.white,
        child: Row(children: [
          if (!wide) ...[
            const Icon(Icons.directions_car_filled_rounded, color: Color(0xFFFCA311), size: 28),
            const SizedBox(width: 8),
            const Text('HeyCar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ] else
            Text(items[selected].$1, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF14213D))),
          const Spacer(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
        ]),
      );

  Widget _page() {
    switch (selected) {
      case 1:
        return const QrAdminPage();
      case 2:
        return const SimpleAdminPage(title: 'Araçlar', icon: Icons.directions_car_filled_rounded, text: 'Kayıtlı araçlar burada yönetilecek.');
      case 3:
        return const SimpleAdminPage(title: 'Kullanıcılar', icon: Icons.people_alt_rounded, text: 'Araç sahipleri ve hesap durumları burada yönetilecek.');
      case 4:
        return const SimpleAdminPage(title: 'Bildirimler', icon: Icons.notifications_rounded, text: 'Toplu bildirimler ve sistem duyuruları.');
      case 5:
        return const SimpleAdminPage(title: 'Ayarlar', icon: Icons.settings_rounded, text: 'HeyCar sistem ve yönetici ayarları.');
      default:
        return const DashboardPage();
    }
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text('Genel Bakış', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF14213D))),
          const SizedBox(height: 4),
          const Text('HeyCar sisteminin anlık özeti', style: TextStyle(color: Color(0xFF77808E))),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 1000 ? 4 : c.maxWidth > 620 ? 2 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: cols == 1 ? 3.0 : 2.2,
              children: const [
                StatCard(title: 'Toplam QR', value: '5', icon: Icons.qr_code_2_rounded),
                StatCard(title: 'Aktif QR', value: '1', icon: Icons.verified_rounded),
                StatCard(title: 'Boş QR', value: '4', icon: Icons.inventory_2_rounded),
                StatCard(title: 'Kayıtlı Araç', value: '1', icon: Icons.directions_car_filled_rounded),
              ],
            );
          }),
          const SizedBox(height: 22),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Son İşlemler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 14),
                Activity(icon: Icons.link_rounded, title: 'HC-DEMO-005 araca bağlandı', subtitle: 'BMW 3 Series · 34 TEST 05'),
                Divider(height: 26),
                Activity(icon: Icons.qr_code_2_rounded, title: '4 QR etiketi kullanılabilir', subtitle: 'HC-DEMO-001 — HC-DEMO-004'),
              ]),
            ),
          ),
        ],
      );
}

class QrAdminPage extends StatefulWidget {
  const QrAdminPage({super.key});
  @override
  State<QrAdminPage> createState() => _QrAdminPageState();
}

class _QrAdminPageState extends State<QrAdminPage> {
  final rows = <QrRow>[
    QrRow('HC-DEMO-001', 'Boş', '-', '-'),
    QrRow('HC-DEMO-002', 'Boş', '-', '-'),
    QrRow('HC-DEMO-003', 'Boş', '-', '-'),
    QrRow('HC-DEMO-004', 'Boş', '-', '-'),
    QrRow('HC-DEMO-005', 'Aktif', '34 TEST 05', 'BMW 3 Series'),
  ];
  String filter = 'Tümü';

  @override
  Widget build(BuildContext context) {
    final shown = rows.where((e) => filter == 'Tümü' || e.status == filter).toList();
    return ListView(padding: const EdgeInsets.all(22), children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('QR Etiketleri', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF14213D))),
          SizedBox(height: 4),
          Text('Etiket üret, takip et ve araç bağlantılarını yönet.', style: TextStyle(color: Color(0xFF77808E))),
        ])),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFCA311), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
          onPressed: _generate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('QR Üret', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ]),
      const SizedBox(height: 20),
      Wrap(spacing: 8, children: ['Tümü', 'Boş', 'Aktif', 'İptal'].map((e) => ChoiceChip(label: Text(e), selected: filter == e, onSelected: (_) => setState(() => filter = e))).toList()),
      const SizedBox(height: 16),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [DataColumn(label: Text('QR Kodu')), DataColumn(label: Text('Durum')), DataColumn(label: Text('Plaka')), DataColumn(label: Text('Araç')), DataColumn(label: Text('İşlem'))],
            rows: shown.map((r) => DataRow(cells: [
              DataCell(Text(r.token, style: const TextStyle(fontWeight: FontWeight.w900))),
              DataCell(_status(r.status)),
              DataCell(Text(r.plate)),
              DataCell(Text(r.vehicle)),
              DataCell(PopupMenuButton<String>(itemBuilder: (_) => const [
                PopupMenuItem(value: 'detail', child: Text('Detay')), PopupMenuItem(value: 'disable', child: Text('Devre dışı bırak')),
              ])),
            ])).toList(),
          ),
        ),
      ),
    ]);
  }

  Widget _status(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: s == 'Aktif' ? const Color(0xFFE8F7EE) : const Color(0xFFFFF4DF), borderRadius: BorderRadius.circular(99)),
        child: Text(s, style: TextStyle(fontWeight: FontWeight.w800, color: s == 'Aktif' ? const Color(0xFF16864B) : const Color(0xFFA86900))),
      );

  Future<void> _generate() async {
    int count = 10;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
        title: const Text('Toplu QR üret'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Şimdilik mock üretim. Fiziksel baskı aşamasında gerçek stok sistemi açılacak.'),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(value: count, items: [10, 50, 100, 500].map((e) => DropdownMenuItem(value: e, child: Text('$e adet'))).toList(), onChanged: (v) => setLocal(() => count = v ?? 10)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('$count adet mock QR üretim kuyruğuna alındı.'))); }, child: const Text('Üret')),
        ],
      )),
    );
  }
}

class QrRow {
  QrRow(this.token, this.status, this.plate, this.vehicle);
  final String token, status, plate, vehicle;
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.icon});
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFFFF3DE), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: const Color(0xFFFCA311), size: 28)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, style: const TextStyle(color: Color(0xFF77808E), fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF14213D))),
            ]),
          ]),
        ),
      );
}

class Activity extends StatelessWidget {
  const Activity({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Row(children: [
        CircleAvatar(backgroundColor: const Color(0xFFFFF3DE), child: Icon(icon, color: const Color(0xFFFCA311))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: Color(0xFF77808E)))])),
      ]);
}

class SimpleAdminPage extends StatelessWidget {
  const SimpleAdminPage({super.key, required this.title, required this.icon, required this.text});
  final String title, text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 90, height: 90, decoration: BoxDecoration(color: const Color(0xFFFFF3DE), borderRadius: BorderRadius.circular(28)), child: Icon(icon, size: 44, color: const Color(0xFFFCA311))),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF14213D))),
          const SizedBox(height: 7),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF77808E))),
        ]),
      ));
}
