import 'package:flutter/material.dart';
import 'entry.dart' as old;
import 'main.dart' as app;
import 'vehicle_api.dart';

void main() => runApp(const EntryVehicleApp());

class EntryVehicleApp extends StatelessWidget {
  const EntryVehicleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: app.C.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: app.C.orange),
          fontFamily: 'sans',
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: app.C.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: app.C.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: app.C.orange, width: 1.6),
            ),
          ),
        ),
        home: const OnboardingVehicle(),
      );
}

class OnboardingVehicle extends StatefulWidget {
  const OnboardingVehicle({super.key});

  @override
  State<OnboardingVehicle> createState() => _OnboardingVehicleState();
}

class _OnboardingVehicleState extends State<OnboardingVehicle> {
  int index = 0;

  void next() => setState(() => index = (index + 1).clamp(0, 7));
  void back() => setState(() => index = (index - 1).clamp(0, 7));
  void done() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const app.Shell()),
      );

  @override
  Widget build(BuildContext context) => [
        old.Welcome(next),
        old.Phone(next, back),
        old.Otp(next, back),
        old.Account(next, back),
        VehiclePicker(next, back),
        old.QrScan(next, back),
        old.QrOk(next, back),
        old.Guide(done, back),
      ][index];
}

class VehiclePicker extends StatefulWidget {
  const VehiclePicker(this.next, this.back, {super.key});

  final VoidCallback next;
  final VoidCallback back;

  @override
  State<VehiclePicker> createState() => _VehiclePickerState();
}

class _VehiclePickerState extends State<VehiclePicker> {
  final plate = TextEditingController(text: '34 ABC 123');
  final otherMake = TextEditingController();
  final otherModel = TextEditingController();
  List<String> makes = const [];
  List<String> models = const [];
  String? selectedMake = 'BMW';
  String? selectedModel = '3 Series';
  bool loadingModels = false;

  static const Map<String, String> _domains = {
    'Audi': 'audi.com.tr',
    'BMW': 'bmw.com.tr',
    'BYD': 'bydauto.com.tr',
    'Chery': 'cherytr.com',
    'Citroen': 'citroen.com.tr',
    'Cupra': 'cupraofficial.com.tr',
    'Dacia': 'dacia.com.tr',
    'Fiat': 'fiat.com.tr',
    'Ford': 'ford.com.tr',
    'Honda': 'honda.com.tr',
    'Hyundai': 'hyundai.com.tr',
    'Jeep': 'jeep.com.tr',
    'Kia': 'kia.com.tr',
    'Land Rover': 'landrover.com.tr',
    'Lexus': 'lexus.com.tr',
    'Mazda': 'mazda.com.tr',
    'Mercedes-Benz': 'mercedes-benz.com.tr',
    'MG': 'mg-turkey.com',
    'Mini': 'mini.com.tr',
    'Nissan': 'nissan.com.tr',
    'Opel': 'opel.com.tr',
    'Peugeot': 'peugeot.com.tr',
    'Porsche': 'porsche.com',
    'Renault': 'renault.com.tr',
    'Seat': 'seat.com.tr',
    'Skoda': 'skoda.com.tr',
    'Suzuki': 'suzuki.com.tr',
    'Tesla': 'tesla.com',
    'Togg': 'togg.com.tr',
    'Toyota': 'toyota.com.tr',
    'Volkswagen': 'volkswagen.com.tr',
    'Volvo': 'volvocars.com.tr',
  };

  @override
  void initState() {
    super.initState();
    _loadMakes();
    plate.addListener(_refresh);
  }

  @override
  void dispose() {
    plate.removeListener(_refresh);
    plate.dispose();
    otherMake.dispose();
    otherModel.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMakes() async {
    final result = await VehicleApi.getMakes();
    if (!mounted) return;
    setState(() => makes = result);
    if (selectedMake != null && selectedMake != 'Diğer') {
      await _loadModels(selectedMake!);
    }
  }

  Future<void> _loadModels(String make) async {
    if (make == 'Diğer') {
      setState(() {
        models = const [];
        selectedModel = null;
        loadingModels = false;
      });
      return;
    }
    setState(() {
      loadingModels = true;
      models = const [];
      selectedModel = null;
    });
    final result = await VehicleApi.getModels(make);
    if (!mounted) return;
    setState(() {
      models = result;
      if (models.isNotEmpty) {
        selectedModel = models.firstWhere(
          (m) => make == 'BMW' && m.toLowerCase().contains('3'),
          orElse: () => models.first,
        );
      }
      loadingModels = false;
    });
  }

  String get resolvedMake => selectedMake == 'Diğer' ? otherMake.text.trim() : (selectedMake ?? '');
  String get resolvedModel => selectedMake == 'Diğer' ? otherModel.text.trim() : (selectedModel ?? '');

  String get vehicleTitle {
    final make = resolvedMake.isEmpty ? 'Marka seç' : resolvedMake;
    return resolvedModel.isEmpty ? make : '$make $resolvedModel';
  }

  @override
  Widget build(BuildContext context) => old.Frame(
        4,
        widget.back,
        'Aracını ekle',
        'Plakanı yaz, ardından Türkiye’deki araç markalarından birini seç.',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const old.Tabs('Plaka ile ekle', 'Ruhsat fotoğrafı ile'),
            const SizedBox(height: 18),
            Container(
              height: 66,
              decoration: old.box(),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Container(
                    width: 58,
                    alignment: Alignment.center,
                    color: const Color(0xFF0A3C91),
                    child: const Text('TR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: plate,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(
                        hintText: '34 ABC 123',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 19),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Araç markası', style: TextStyle(fontSize: 13, color: app.C.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            _brandSelector(),
            if (selectedMake == 'Diğer') ...[
              const SizedBox(height: 14),
              TextField(
                controller: otherMake,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Araç markasını yaz', prefixIcon: Icon(Icons.directions_car_outlined)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: otherModel,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Modeli yaz', prefixIcon: Icon(Icons.badge_outlined)),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Text('Model', style: TextStyle(fontSize: 13, color: app.C.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              _modelSelector(),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: old.box(),
              child: Row(
                children: [
                  SizedBox(width: 64, height: 64, child: _brandImage(selectedMake ?? 'Diğer', 48)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vehicleTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(plate.text.trim().isEmpty ? 'Plaka girilmedi' : plate.text.trim().toUpperCase(), style: TextStyle(color: app.C.muted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 24),
            old.Primary('Aracı kaydet', () {
              if (plate.text.trim().isEmpty || resolvedMake.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plaka ve araç markasını girmelisin.')));
                return;
              }
              widget.next();
            }),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Markalar Türkiye odaklıdır. Model verisi gerektiğinde ücretsiz NHTSA vPIC servisinden alınır.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: app.C.muted),
              ),
            ),
          ],
        ),
      );

  Widget _brandSelector() {
    final label = selectedMake ?? 'Marka seç';
    return InkWell(
      onTap: _showBrandSheet,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: old.box(),
        child: Row(
          children: [
            SizedBox(width: 42, height: 42, child: _brandImage(label, 34)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

  Widget _modelSelector() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: old.box(),
      child: loadingModels
          ? const Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 12), Text('Modeller yükleniyor...')])
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: models.contains(selectedModel) ? selectedModel : null,
                hint: Text(selectedMake == null ? 'Önce marka seç' : 'Model seç'),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: models.map((e) => DropdownMenuItem<String>(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (value) => setState(() => selectedModel = value),
              ),
            ),
    );
  }

  Future<void> _showBrandSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFD9DEE7), borderRadius: BorderRadius.circular(20))),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Align(alignment: Alignment.centerLeft, child: Text('Araç markanı seç', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: .95, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: makes.length,
                  itemBuilder: (_, index) {
                    final make = makes[index];
                    final active = make == selectedMake;
                    return InkWell(
                      onTap: () => Navigator.pop(context, make),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFFFFF6E8) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: active ? app.C.orange : app.C.line, width: active ? 1.5 : 1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 54, height: 54, child: _brandImage(make, 44)),
                            const SizedBox(height: 8),
                            Text(make, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      selectedMake = picked;
      selectedModel = null;
      models = const [];
    });
    if (picked != 'Diğer') await _loadModels(picked);
  }

  Widget _brandImage(String make, double size) {
    if (make == 'Diğer' || !_domains.containsKey(make)) {
      return Container(
        decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.more_horiz_rounded, size: size * .65, color: app.C.muted),
      );
    }
    final domain = _domains[make]!;
    final url = 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.C.line)),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.directions_car_filled_rounded, color: app.C.orange, size: size * .7),
      ),
    );
  }
}
