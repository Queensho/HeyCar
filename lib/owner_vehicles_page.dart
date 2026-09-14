import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'qr_backend.dart';
import 'vehicle_api.dart';
import 'owner_qr_dialog.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF101A30);
const _line = Color(0xFF27355D);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFFA7B0C7);
const _blue = Color(0xFF42A5FF);
const _red = Color(0xFFFF4D63);
const _lime = Color(0xFF79FF45);

class OwnerVehiclesPage extends StatelessWidget {
  const OwnerVehiclesPage({super.key});

  String get _plate => QrDraft.plate.trim().isEmpty ? '34 ABC 123' : QrDraft.plate.trim();
  String get _make => QrDraft.make.trim().isEmpty ? 'Volkswagen' : QrDraft.make.trim();
  String get _model => QrDraft.model.trim();
  String get _title => _model.isEmpty ? _make : '$_make $_model';
  String get _token => QrDraft.token.trim();
  String get _publicUrl => _token.isEmpty ? '' : 'https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(_token)}';

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(14, top + 14, 14, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Araçlarım', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
                      SizedBox(height: 4),
                      Text('Kayıtlı araçlarını ve QR kodlarını yönet.', style: TextStyle(color: _muted, fontSize: 13)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yeni araç ekleme akışı açılacak.'))),
                    style: FilledButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('Yeni Araç', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _VehicleCard(
              title: _title,
              plate: _plate,
              make: _make,
              isDefault: true,
              onQr: () => showOwnerQrDialog(context),
              onShare: () async {
                if (_publicUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu araç için aktif QR etiketi bulunamadı.')));
                  return;
                }
                await Clipboard.setData(ClipboardData(text: _publicUrl));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Araç bağlantısı kopyalandı.')));
              },
              onEdit: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Araç düzenleme ekranı açılacak.'))),
              onDelete: () => _confirmDelete(context),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: _purple, size: 25),
                  SizedBox(width: 11),
                  Expanded(child: Text('Her araç için farklı QR kodu kullanabilirsin. QR etiketini aracına yapıştırarak sana kolayca ulaşılmasını sağla.', style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Aracı sil?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('Bu işlem henüz backend tarafında aktif değil.', style: TextStyle(color: _muted)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç'))],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.title, required this.plate, required this.make, required this.isDefault, required this.onQr, required this.onShare, required this.onEdit, required this.onDelete});
  final String title, plate, make;
  final bool isDefault;
  final VoidCallback onQr, onShare, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final logo = VehicleApi.brandLogoUrl(make);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: isDefault ? _purple : _line, width: isDefault ? 1.5 : 1)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 78,
                height: 68,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF0B1529), borderRadius: BorderRadius.circular(17), border: Border.all(color: _line)),
                child: logo == null
                    ? const Icon(Icons.directions_car_filled_rounded, color: _purple, size: 34)
                    : Image.network(logo, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_filled_rounded, color: _purple, size: 34)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900))), if (isDefault) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _purple.withValues(alpha: .22), borderRadius: BorderRadius.circular(12)), child: const Text('Varsayılan', style: TextStyle(color: Color(0xFFB99CFF), fontSize: 10.5, fontWeight: FontWeight.w800)))]),
                    const SizedBox(height: 8),
                    Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Text(plate, style: const TextStyle(color: Color(0xFF101828), fontSize: 14, fontWeight: FontWeight.w900))), const SizedBox(width: 7), IconButton(onPressed: () => Clipboard.setData(ClipboardData(text: plate)), visualDensity: VisualDensity.compact, constraints: const BoxConstraints(), padding: EdgeInsets.zero, icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18))]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(child: _ActionButton(icon: Icons.qr_code_2_rounded, color: _lime, label: 'QR Kodu', onTap: onQr)),
              const SizedBox(width: 7),
              Expanded(child: _ActionButton(icon: Icons.share_rounded, color: _blue, label: 'Paylaş', onTap: onShare)),
              const SizedBox(width: 7),
              Expanded(child: _ActionButton(icon: Icons.edit_outlined, color: _purple, label: 'Düzenle', onTap: onEdit)),
              const SizedBox(width: 7),
              SizedBox(width: 58, child: _ActionButton(icon: Icons.delete_outline_rounded, color: _red, label: 'Sil', onTap: onDelete)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.color, required this.label, required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF0B1529),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 22), const SizedBox(height: 4), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800))]),
          ),
        ),
      );
}
