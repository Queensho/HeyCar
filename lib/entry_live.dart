import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'entry.dart' as old;
import 'main.dart' as app;
import 'vehicle_api.dart';
import 'qr_backend.dart';

void main() => runApp(const EntryLiveApp());

class EntryLiveApp extends StatelessWidget {
  const EntryLiveApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: app.C.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: app.C.orange),
          fontFamily: 'sans',
        ),
        home: const LiveOnboarding(),
      );
}

class LiveOnboarding extends StatefulWidget {
  const LiveOnboarding({super.key});
  @override
  State<LiveOnboarding> createState() => _LiveOnboardingState();
}

class _LiveOnboardingState extends State<LiveOnboarding> {
  int index = 0;
  String activatedToken = '';

  void next() => setState(() => index = (index + 1).clamp(0, 7));
  void back() => setState(() => index = (index - 1).clamp(0, 7));
  void activated(String token) => setState(() {
        activatedToken = token;
        index = 6;
      });
  void done() => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const app.Shell()));

  @override
  Widget build(BuildContext context) => [
        old.Welcome(next),
        old.Phone(next, back),
        old.Otp(next, back),
        old.Account(next, back),
        LiveVehiclePicker(next, back),
        QrActivationPage(onActivated: activated, onBack: back),
        QrBoundPage(token: activatedToken, onNext: next, onBack: back),
        old.Guide(done, back),
      ][index];
}

class LiveVehiclePicker extends StatefulWidget {
  const LiveVehiclePicker(this.next, this.back, {super.key});
  final VoidCallback next, back;
  @override
  State<LiveVehiclePicker> createState() => _LiveVehiclePickerState();
}

class _LiveVehiclePickerState extends State<LiveVehiclePicker> {
  final plate = TextEditingController(text: '34 ABC 123');
  List<String> makes = const [];
  List<String> models = const [];
  String? make = 'BMW';
  String? model = '3 Series';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadMakes();
  }

  @override
  void dispose() {
    plate.dispose();
    super.dispose();
  }

  Future<void> _loadMakes() async {
    final result = await VehicleApi.getMakes();
    if (!mounted) return;
    setState(() => makes = result.where((e) => e != 'Diğer').toList());
    await _loadModels(make!);
  }

  Future<void> _loadModels(String selected) async {
    setState(() {
      loading = true;
      models = const [];
      model = null;
    });
    final result = await VehicleApi.getModels(selected);
    if (!mounted) return;
    setState(() {
      models = result;
      model = result.isEmpty ? null : result.first;
      loading = false;
    });
  }

  void save() {
    if (plate.text.trim().isEmpty || make == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plaka ve marka gerekli.')));
      return;
    }
    QrDraft.plate = plate.text.trim().toUpperCase();
    QrDraft.make = make!;
    QrDraft.model = model ?? '';
    widget.next();
  }

  @override
  Widget build(BuildContext context) => old.Frame(
        4,
        widget.back,
        'Aracını ekle',
        'QR etiketini bağlayacağın aracı seç.',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Plaka', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          TextField(
            controller: plate,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              hintText: '34 ABC 123',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: app.C.line)),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Marka', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            value: makes.contains(make) ? make : null,
            items: makes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => make = v);
              _loadModels(v);
            },
            decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18))),
          ),
          const SizedBox(height: 14),
          const Text('Model', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          if (loading)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else
            DropdownButtonFormField<String>(
              value: models.contains(model) ? model : null,
              items: models.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => model = v),
              decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18))),
            ),
          const SizedBox(height: 20),
          old.Primary('Aracı kaydet', save),
        ]),
      );
}

class QrActivationPage extends StatefulWidget {
  const QrActivationPage({super.key, required this.onActivated, required this.onBack});
  final ValueChanged<String> onActivated;
  final VoidCallback onBack;
  @override
  State<QrActivationPage> createState() => _QrActivationPageState();
}

class _QrActivationPageState extends State<QrActivationPage> {
  final manual = TextEditingController();
  final scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool busy = false;
  bool scanned = false;
  String? error;

  @override
  void dispose() {
    manual.dispose();
    scanner.dispose();
    super.dispose();
  }

  Future<void> bind(String raw) async {
    if (busy) return;
    final token = QrBackend.normalizeToken(raw);
    if (token.isEmpty) return;
    setState(() {
      busy = true;
      scanned = true;
      error = null;
    });
    await scanner.stop();
    try {
      await QrBackend.activate(
        token: token,
        plate: QrDraft.plate,
        make: QrDraft.make,
        model: QrDraft.model,
        ownerName: QrDraft.ownerName,
      );
      if (!mounted) return;
      widget.onActivated(token);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        scanned = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
      await scanner.start();
    }
  }

  @override
  Widget build(BuildContext context) => old.Frame(
        5,
        widget.onBack,
        'QR etiketini aktifleştir',
        '${QrDraft.plate} plakalı ${QrDraft.make} ${QrDraft.model} için etiketi okut.',
        Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 330,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                MobileScanner(
                  controller: scanner,
                  onDetect: (capture) {
                    if (scanned || capture.barcodes.isEmpty) return;
                    final raw = capture.barcodes.first.rawValue;
                    if (raw != null) bind(raw);
                  },
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: app.C.orange, width: 4),
                      ),
                    ),
                  ),
                ),
                if (busy) const ColoredBox(color: Color(0x88000000), child: Center(child: CircularProgressIndicator(color: app.C.orange))),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          const Text('QR kodu çerçeve içine al', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: manual,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Veya aktivasyon kodunu yaz',
              hintText: 'HC-DEMO-001',
              suffixIcon: IconButton(onPressed: busy ? null : () => bind(manual.text), icon: const Icon(Icons.arrow_forward_rounded)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFECEA), borderRadius: BorderRadius.circular(14)),
              child: Text(error!, style: const TextStyle(color: app.C.red, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      );
}

class QrBoundPage extends StatelessWidget {
  const QrBoundPage({super.key, required this.token, required this.onNext, required this.onBack});
  final String token;
  final VoidCallback onNext, onBack;

  @override
  Widget build(BuildContext context) => old.Frame(
        6,
        onBack,
        'QR başarıyla bağlandı',
        'Bu etiket artık yalnızca seçtiğin araca bağlı.',
        Column(children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(color: app.C.navy, borderRadius: BorderRadius.circular(28)),
            child: const Icon(Icons.verified_rounded, size: 92, color: app.C.orange),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: old.box(),
            child: Column(children: [
              _row('Etiket', token),
              const SizedBox(height: 10),
              _row('Araç', '${QrDraft.make} ${QrDraft.model}'),
              const SizedBox(height: 10),
              _row('Plaka', QrDraft.plate),
              const SizedBox(height: 10),
              _row('Durum', 'Aktif'),
            ]),
          ),
          const SizedBox(height: 20),
          old.Primary('Devam et', onNext),
        ]),
      );

  Widget _row(String a, String b) => Row(children: [Expanded(child: Text(a, style: TextStyle(color: app.C.muted))), Text(b, style: const TextStyle(fontWeight: FontWeight.w900))]);
}
