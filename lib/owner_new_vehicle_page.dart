import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'onboarding_backend.dart';
import 'vehicle_api.dart';

class OwnerNewVehicleDraft {
  const OwnerNewVehicleDraft({
    required this.plate,
    required this.make,
    required this.model,
    required this.color,
    required this.year,
  });

  final String plate;
  final String make;
  final String model;
  final String color;
  final int? year;
}

class OwnerNewVehiclePage extends StatefulWidget {
  const OwnerNewVehiclePage({super.key});

  @override
  State<OwnerNewVehiclePage> createState() => _OwnerNewVehiclePageState();
}

class _OwnerNewVehiclePageState extends State<OwnerNewVehiclePage> {
  static const _bg = Color(0xFF070D1B);
  static const _panel = Color(0xFF0D1528);
  static const _panelSoft = Color(0xFF10182D);
  static const _line = Color(0xFF293657);
  static const _purple = Color(0xFF8B46FF);
  static const _purple2 = Color(0xFF5E2BFF);
  static const _muted = Color(0xFF9DA8C2);
  static const _text = Colors.white;

  final plate = TextEditingController();
  String? make;
  String? model;
  String? color;
  int? year;
  List<String> makes = [];
  List<String> models = [];
  bool loadingMakes = true;
  bool loadingModels = false;
  int _modelRequest = 0;
  XFile? photo;

  static const colors = <String>[
    'Beyaz',
    'Siyah',
    'Gri',
    'Gümüş',
    'Lacivert',
    'Mavi',
    'Kırmızı',
    'Yeşil',
    'Sarı',
    'Turuncu',
    'Kahverengi',
    'Bej',
    'Mor',
    'Diğer',
  ];

  List<int> get years {
    final now = DateTime.now().year + 1;
    return List<int>.generate(now - 1989, (i) => now - i);
  }

  @override
  void initState() {
    super.initState();
    VehicleApi.getMakes().then((x) {
      if (!mounted) return;
      final unique = <String, String>{};
      for (final item in x) {
        final clean = item.trim();
        if (clean.isNotEmpty) unique.putIfAbsent(clean.toLowerCase(), () => clean);
      }
      setState(() {
        makes = unique.values.toList();
        loadingMakes = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => loadingMakes = false);
    });
  }

  @override
  void dispose() {
    plate.dispose();
    super.dispose();
  }

  Future<void> _changeMake(String? value) async {
    if (value == null) return;
    final request = ++_modelRequest;
    setState(() {
      make = value;
      model = null;
      models = [];
      loadingModels = true;
    });
    final result = await VehicleApi.getModels(value);
    if (!mounted || request != _modelRequest || make != value) return;
    final unique = <String, String>{};
    for (final item in result) {
      final clean = item.trim();
      if (clean.isNotEmpty) unique.putIfAbsent(clean.toLowerCase(), () => clean);
    }
    setState(() {
      models = unique.values.toList();
      loadingModels = false;
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1400,
    );
    if (picked != null && mounted) setState(() => photo = picked);
  }

  void _submit() {
    final p = plate.text.trim().toUpperCase();
    if (p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plaka bilgisini girin.')),
      );
      return;
    }
    if (make == null || make!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Araç markasını seçin.')),
      );
      return;
    }
    Navigator.pop(
      context,
      OwnerNewVehicleDraft(
        plate: p,
        make: make!,
        model: model ?? '',
        color: color ?? '',
        year: year,
      ),
    );
  }

  String get initials {
    final v = OnboardingDraft.displayName.trim();
    if (v.isEmpty) return 'CQ';
    return v
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();
  }

  InputDecoration _inputDecoration() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 13),
        hintStyle: const TextStyle(
          color: Color(0xFF7F8AA7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _brandHeader() => SizedBox(
        height: 43,
        child: Row(
          children: [
            Image.asset(
              'assets/Logoyeni.png',
              height: 31,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10192E),
                    shape: BoxShape.circle,
                    border: Border.all(color: _line),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const Positioned(
                  right: 1,
                  top: 0,
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: Color(0xFF9B55FF),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF161F38),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF384567)),
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _titleRow() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _panelSoft,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _line),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni Araç',
                  style: TextStyle(
                    color: _text,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Aracınızı ekleyerek CepQontag ile yola çıkın.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _sectionHeader() => Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF221451),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _purple.withValues(alpha: .45)),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: .18),
                  blurRadius: 18,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: Color(0xFF9E5CFF),
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Araç Bilgileri',
                  style: TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Lütfen aracınıza ait bilgileri eksiksiz girin.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _label(String text, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Text(
              text,
              style: const TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              Text(
                trailing,
                style: const TextStyle(
                  color: Color(0xFF8390AE),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _plateField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Plaka', trailing: 'Örn. 34 ABC 123'),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1324),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF344263)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B4DB4), Color(0xFF7428D9)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: plate,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                    decoration: _inputDecoration().copyWith(hintText: '34 ABC 123'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _selector<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String hint,
    required ValueChanged<T?>? onChanged,
    required IconData icon,
    bool loading = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: 11, right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1324),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF344263)),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFA8B2D0), size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: loading
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _purple,
                            ),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<T>(
                            value: value,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF111A2F),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFFA8B2D0),
                              size: 19,
                            ),
                            hint: Text(
                              hint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF7F8AA7),
                                fontSize: 11.5,
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            items: items
                                .map(
                                  (x) => DropdownMenuItem<T>(
                                    value: x,
                                    child: Text(
                                      '$x',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: onChanged,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _photoBox() => InkWell(
        onTap: _pickPhoto,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 116,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF091121),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF65708B),
              style: BorderStyle.solid,
            ),
          ),
          child: photo == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: Color(0xFF20134D),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: Color(0xFF9B55FF),
                        size: 24,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Araç fotoğrafı ekle ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: '(isteğe bağlı)',
                            style: TextStyle(color: _muted),
                          ),
                        ],
                      ),
                      style: TextStyle(fontSize: 11.5),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Aracınızı daha kolay tanımak için fotoğraf ekleyebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                )
              : FutureBuilder<List<int>>(
                  future: photo!.readAsBytes(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _purple,
                        ),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            Uint8List.fromList(snap.data!),
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .62),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      );

  Widget _infoBox() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF15143A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF282653)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF9B55FF),
              size: 20,
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Eklediğiniz araç, CepQontag hesabınıza kayıtlı araçlarınız arasında yer alacaktır.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _submitButton() => SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6D35FF), Color(0xFF9E48FF)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _purple.withValues(alpha: .28),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text(
              'Aracı Ekle',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final safeModel = model != null && models.contains(model) ? model : null;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _brandHeader(),
            const SizedBox(height: 12),
            _titleRow(),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
              decoration: BoxDecoration(
                color: _panel.withValues(alpha: .97),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _purple.withValues(alpha: .48),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withValues(alpha: .07),
                    blurRadius: 22,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _sectionHeader(),
                  const SizedBox(height: 16),
                  _plateField(),
                  const SizedBox(height: 13),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _selector<String>(
                          label: 'Marka',
                          value: make,
                          items: makes,
                          hint: 'Marka seçin',
                          onChanged: loadingMakes ? null : _changeMake,
                          icon: Icons.directions_car_outlined,
                          loading: loadingMakes,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _selector<String>(
                          label: 'Model',
                          value: safeModel,
                          items: models,
                          hint: make == null ? 'Önce marka' : 'Model seçin',
                          onChanged: loadingModels || models.isEmpty
                              ? null
                              : (x) => setState(() => model = x),
                          icon: Icons.directions_car_outlined,
                          loading: loadingModels,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _selector<int>(
                          label: 'Yıl',
                          value: year,
                          items: years,
                          hint: 'Yıl seçin',
                          onChanged: (x) => setState(() => year = x),
                          icon: Icons.calendar_month_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _selector<String>(
                          label: 'Renk',
                          value: color,
                          items: colors,
                          hint: 'Renk seçin',
                          onChanged: (x) => setState(() => color = x),
                          icon: Icons.palette_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _photoBox(),
                  const SizedBox(height: 12),
                  _infoBox(),
                  const SizedBox(height: 13),
                  _submitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
