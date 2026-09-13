import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'entry.dart' as old;
import 'main.dart' as app;
import 'qr_backend.dart';

class RealQrScanPage extends StatefulWidget {
  const RealQrScanPage({super.key, required this.onFound, required this.onBack});
  final VoidCallback onFound;
  final VoidCallback onBack;

  @override
  State<RealQrScanPage> createState() => _RealQrScanPageState();
}

class _RealQrScanPageState extends State<RealQrScanPage> {
  final controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final code = TextEditingController();
  bool manual = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> useToken(String raw) async {
    if (busy) return;
    final token = QrBackend.normalizeToken(raw);
    if (token.isEmpty || !token.startsWith('HC-')) {
      setState(() => error = 'Geçerli bir HeyCar QR kodu gir.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final data = await QrBackend.lookup(token);
      final status = data['status']?.toString();
      if (status == 'active') throw Exception('Bu QR daha önce bir araca bağlanmış.');
      if (status == 'disabled') throw Exception('Bu QR etiketi devre dışı.');
      QrDraft.token = token;
      await controller.stop();
      if (mounted) widget.onFound();
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void detected(BarcodeCapture capture) {
    if (busy || manual) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        useToken(raw);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) => old.Frame(
        5,
        widget.onBack,
        'QR etiketini aktifleştir',
        'Kutudan çıkan QR etiketini kamerayla okut veya üzerindeki aktivasyon kodunu yaz.',
        Column(children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.qr_code_scanner), label: Text('QR okut')),
              ButtonSegment(value: true, icon: Icon(Icons.keyboard_alt_outlined), label: Text('Kod ile aktif et')),
            ],
            selected: {manual},
            onSelectionChanged: (v) async {
              final next = v.first;
              setState(() { manual = next; error = null; });
              if (next) {
                await controller.stop();
              } else {
                await controller.start();
              }
            },
          ),
          const SizedBox(height: 18),
          if (!manual)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 390,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  MobileScanner(controller: controller, onDetect: detected),
                  Container(color: Colors.black.withValues(alpha: .15)),
                  Center(
                    child: Container(
                      width: 235,
                      height: 235,
                      decoration: BoxDecoration(
                        border: Border.all(color: app.C.orange, width: 3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 22,
                    child: Text('QR\'ı çerçeve içine al', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  if (busy) const Center(child: CircularProgressIndicator(color: app.C.orange)),
                ]),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xffe5e7eb))),
              child: Column(children: [
                TextField(
                  controller: code,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Aktivasyon kodu',
                    hintText: 'HC-XXXXXXXXXX',
                    prefixIcon: Icon(Icons.qr_code_2),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => useToken(code.text),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: app.C.orange, foregroundColor: Colors.black),
                    onPressed: busy ? null : () => useToken(code.text),
                    child: busy ? const CircularProgressIndicator() : const Text('Kodu kontrol et', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ]),
            ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xffffecea), borderRadius: BorderRadius.circular(14)),
              child: Text(error!, style: const TextStyle(color: Color(0xffb42318), fontWeight: FontWeight.w700)),
            ),
          ],
          if (!manual) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => controller.toggleTorch(),
              icon: const Icon(Icons.flashlight_on_outlined),
              label: const Text('Işığı aç / kapat'),
            ),
          ],
        ]),
      );
}

class RealQrConfirmPage extends StatefulWidget {
  const RealQrConfirmPage({super.key, required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<RealQrConfirmPage> createState() => _RealQrConfirmPageState();
}

class _RealQrConfirmPageState extends State<RealQrConfirmPage> {
  bool busy = false;
  String? error;

  Future<void> activate() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      await QrBackend.activate(
        token: QrDraft.token,
        vehicleId: QrDraft.vehicleId,
        plate: QrDraft.plate,
        make: QrDraft.make,
        model: QrDraft.model,
        ownerName: QrDraft.ownerName,
      );
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => old.Frame(
        6,
        widget.onBack,
        'QR bulundu',
        'Bu etiketi oluşturduğun araca bağlamak istiyor musun?',
        Column(children: [
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(color: app.C.navy, borderRadius: BorderRadius.circular(28)),
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.qr_code_2_rounded, size: 132, color: Colors.white),
              const Positioned(right: 12, top: 12, child: CircleAvatar(radius: 24, backgroundColor: app.C.orange, child: Icon(Icons.check, color: Colors.white))),
              Positioned(bottom: 12, child: Text(QrDraft.token, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800))),
            ]),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xfff1f3f6), borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              old.Info('Etiket No', QrDraft.token),
              const SizedBox(height: 12),
              old.Info('Araç', '${QrDraft.plate} • ${QrDraft.make} ${QrDraft.model}'.trim()),
              const SizedBox(height: 12),
              const old.Info('Durum', 'Aktifleştirmeye hazır'),
            ]),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: app.C.orange, foregroundColor: Colors.black),
              onPressed: busy ? null : activate,
              child: busy ? const CircularProgressIndicator() : const Text('Hesabıma bağla', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      );
}
