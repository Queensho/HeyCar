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
  List<String> makes = const [];
  List<String> models = const [];
  String? selectedMake = 'BMW';
  String? selectedModel = '3 Series';
  bool loadingMakes = true;
  bool loadingModels = false;

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
    setState(() {
      makes = result;
      if (!makes.contains(selectedMake)) {
        selectedMake = makes.contains('BMW') ? 'BMW' : (makes.isNotEmpty ? makes.first : null);
      }
      loadingMakes = false;
    });
    if (selectedMake != null) await _loadModels(selectedMake!);
  }

  Future<void> _loadModels(String make) async {
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

  String get vehicleTitle {
    final make = selectedMake ?? 'Marka seç';
    final model = selectedModel;
    return model == null || model.isEmpty ? make : '$make $model';
  }

  @override
  Widget build(BuildContext context) => old.Frame(
        4,
        widget.back,
        'Aracını ekle',
        'Plakanı yaz, ardından araç marka ve modelini seç.',
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
                    child: const Text(
                      'TR',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
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
            _selector(
              loading: loadingMakes,
              value: selectedMake,
              items: makes,
              hint: 'Marka seç',
              onChanged: (value) {
                if (value == null) return;
                setState(() => selectedMake = value);
                _loadModels(value);
              },
            ),
            const SizedBox(height: 14),
            Text('Model', style: TextStyle(fontSize: 13, color: app.C.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            _selector(
              loading: loadingModels,
              value: models.contains(selectedModel) ? selectedModel : null,
              items: models,
              hint: selectedMake == null ? 'Önce marka seç' : 'Model seç',
              onChanged: loadingModels ? null : (value) => setState(() => selectedModel = value),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: old.box(),
              child: Row(
                children: [
                  SizedBox(width: 98, height: 62, child: Image.asset('assets/Arac.png', fit: BoxFit.contain)),
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
              if (plate.text.trim().isEmpty || selectedMake == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plaka ve araç markasını seçmelisin.')),
                );
                return;
              }
              widget.next();
            }),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Marka ve model listesi ücretsiz NHTSA vPIC servisinden alınır.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: app.C.muted),
              ),
            ),
          ],
        ),
      );

  Widget _selector({
    required bool loading,
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?>? onChanged,
  }) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: old.box(),
      child: loading
          ? const Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 12), Text('Yükleniyor...')])
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                hint: Text(hint),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: onChanged,
              ),
            ),
    );
  }
}
