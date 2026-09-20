import 'package:flutter/material.dart';
import 'cepqar_theme.dart';
import 'parking_record_api.dart';

Future<bool?> showParkingRecordEditor(
  BuildContext context,
  String vehicleId, {
  Map<String, dynamic>? initial,
  bool dark = false,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) =>
      _ParkingRecordEditor(vehicleId: vehicleId, initial: initial, dark: dark),
);

class _ParkingRecordEditor extends StatefulWidget {
  const _ParkingRecordEditor({
    required this.vehicleId,
    this.initial,
    required this.dark,
  });
  final String vehicleId;
  final Map<String, dynamic>? initial;
  final bool dark;
  @override
  State<_ParkingRecordEditor> createState() => _ParkingRecordEditorState();
}

class _ParkingRecordEditorState extends State<_ParkingRecordEditor> {
  late final _area = TextEditingController(
        text: '${widget.initial?['area'] ?? ''}',
      ),
      _floor = TextEditingController(text: '${widget.initial?['floor'] ?? ''}'),
      _spot = TextEditingController(text: '${widget.initial?['spot'] ?? ''}'),
      _note = TextEditingController(text: '${widget.initial?['note'] ?? ''}');
  bool _saving = false;
  String? _error;
  Color get _bg => widget.dark ? CepqarTheme.darkBg : CepqarTheme.bg;
  Color get _panel => widget.dark ? CepqarTheme.darkPanel : CepqarTheme.panel;
  Color get _text => widget.dark ? Colors.white : CepqarTheme.text;
  Color get _muted => widget.dark ? CepqarTheme.darkMuted : CepqarTheme.muted;
  @override
  void dispose() {
    _area.dispose();
    _floor.dispose();
    _spot.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ParkingRecordApi.save(
        widget.vehicleId,
        area: _area.text,
        floor: _floor.text,
        spot: _spot.text,
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Bilgiler kaydedilemedi. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Park Bilgileri',
                  style: TextStyle(
                    color: _text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.initial?['latitude'] != null
                      ? 'Parkın kaydedildi. Bu bilgileri istersen ekleyebilirsin.'
                      : 'Kat, alan veya park numaranı ekle.',
                  style: TextStyle(color: _muted),
                ),
                const SizedBox(height: 16),
                _field(_floor, 'Kat', '-2', 20),
                _field(_area, 'Alan / Bölge', 'A Blok', 40),
                _field(_spot, 'Park No', '148', 30),
                _field(_note, 'Not', 'Asansörün karşısı', 180),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        child: Text('Kapat', style: TextStyle(color: _muted)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: CepqarTheme.purple,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _field(
    TextEditingController c,
    String label,
    String hint,
    int limit,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      enabled: !_saving,
      maxLength: limit,
      style: TextStyle(color: _text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: _muted),
        hintStyle: TextStyle(color: _muted),
        counterText: '',
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
