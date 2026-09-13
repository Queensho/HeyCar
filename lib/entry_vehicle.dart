import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  final VoidCallback next, back;

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

  static const Map<String, String> _slugs = {
    'Audi': 'audi',
    'BMW': 'bmw',
    'BYD': 'byd',
    'Chery': 'chery',
    'Citroen': 'citroen',
    'Cupra': 'cupra',
    'Dacia': 'dacia',
    'Fiat': 'fiat',
    'Ford': 'ford',
    'Honda': 'honda',
    'Hyundai': 'hyundai',
    'Jeep': 'jeep',
    'Kia': 'kia',
    'Land Rover': 'landrover',
    'Lexus': 'lexus',
    'Mazda': 'mazda',
    'Mercedes-Benz': 'mercedes',
    'MG': 'mg',
    'Mini': 'mini',
    'Nissan': 'nissan',
    'Opel': 'opel',
    'Peugeot': 'peugeot',
    'Porsche': 'porsche',
    'Renault': 'renault',
    'Seat': 'seat',
    'Skoda': 'skoda',
    'Suzuki': 'suzuki',
    'Tesla': 'tesla',
    'Togg': 'togg',
    'Toyota': 'toyota',
    'Volkswagen': 'volkswagen',
    'Volvo': 'volvo',
  };

  @override
  void initState() {
    super.initState();
    plate.addListener(_refresh);
    _loadMakes();
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

  String get resolvedMake => selectedMake == 'Diğer'
      ? otherMake.text.trim()
      : (selectedMake ?? '');

  String get resolvedModel => selectedMake == 'Diğer'
      ? otherModel.text.trim()
      : (selectedModel ?? '');

  String get vehicleTitle => resolvedModel.isEmpty
      ? (resolvedMake.isEmpty ? 'Marka seç' : resolvedMake)
      : '$resolvedMake $resolvedModel';

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
            const SizedBox(height: 16),
            Container(
              height: 62,
              decoration: old.box(),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Container(
                    width: 56,
                    alignment: Alignment.center,
                    color: const Color(0xFF0A3C91),
                    child: const Text(
                      'TR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: plate,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(
                        hintText: '34 ABC 123',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Araç markası',
              style: TextStyle(
                fontSize: 13,
                color: app.C.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            _brandSelector(),
            if (selectedMake == 'Diğer') ...[
              const SizedBox(height: 12),
              TextField(
                controller: otherMake,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Araç markasını yaz',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: otherModel,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Modeli yaz',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Model',
                style: TextStyle(
                  fontSize: 13,
                  color: app.C.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              _modelSelector(),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: old.box(),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: _brandImage(selectedMake ?? 'Diğer', 46),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plate.text.trim().isEmpty
                              ? 'Plaka girilmedi'
                              : plate.text.trim().toUpperCase(),
                          style: TextStyle(color: app.C.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 20),
            old.Primary('Aracı kaydet', () {
              if (plate.text.trim().isEmpty || resolvedMake.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plaka ve araç markasını girmelisin.')),
                );
                return;
              }
              widget.next();
            }),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Türkiye’de kullanılan araç markaları ve modelleri.',
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
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: old.box(),
        child: Row(
          children: [
            SizedBox(width: 40, height: 40, child: _brandImage(label, 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

  Widget _modelSelector() => Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: old.box(),
        child: loadingModels
            ? const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Modeller yükleniyor...'),
                ],
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: models.contains(selectedModel) ? selectedModel : null,
                  hint: Text(selectedMake == null ? 'Önce marka seç' : 'Model seç'),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: models
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedModel = value),
                ),
              ),
      );

  Future<void> _showBrandSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9DEE7),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Araç markanı seç',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: makes.length,
                  itemBuilder: (_, index) {
                    final make = makes[index];
                    final active = make == selectedMake;
                    return InkWell(
                      onTap: () => Navigator.pop(context, make),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFFFFF6E8) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active ? app.C.orange : app.C.line,
                            width: active ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: _brandImage(make, 40),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              make,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
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
    if (make == 'Diğer' || !_slugs.containsKey(make)) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          make == 'Diğer' ? Icons.more_horiz_rounded : Icons.directions_car_filled_rounded,
          size: size * .65,
          color: app.C.muted,
        ),
      );
    }

    final url = 'https://cdn.simpleicons.org/${_slugs[make]}';
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: app.C.line),
      ),
      child: SvgPicture.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: app.C.orange),
        ),
      ),
    );
  }
}
