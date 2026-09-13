import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'onboarding_backend.dart';
import 'public_theme_backend.dart';

class PublicThemeSettingsPage extends StatefulWidget {
  const PublicThemeSettingsPage({super.key, required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;
  @override
  State<PublicThemeSettingsPage> createState() => _PublicThemeSettingsPageState();
}

class _PublicThemeSettingsPageState extends State<PublicThemeSettingsPage> {
  final message = TextEditingController(text: 'Numaram gizli, yolun açık.');
  String preset = 'classic';
  String accent = '#FCA311';
  String backgroundUrl = '';
  double overlay = .72;
  bool busy = false;

  static const options = [
    ('classic', 'Klasik', '#FCA311', Color(0xFF06101B)),
    ('midnight', 'Gece', '#7C8CFF', Color(0xFF0A0B16)),
    ('sport', 'Sport', '#FF5A36', Color(0xFF121212)),
    ('ocean', 'Ocean', '#23B7E5', Color(0xFF07253B)),
    ('forest', 'Forest', '#42D392', Color(0xFF0C2A22)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Color colorOf(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  Future<void> _load() async {
    if (OnboardingDraft.vehicleId.isEmpty || OnboardingDraft.userId.isEmpty) return;
    try {
      final t = await PublicThemeBackend.getTheme(vehicleId: OnboardingDraft.vehicleId, ownerId: OnboardingDraft.userId);
      if (!mounted) return;
      setState(() {
        preset = t.preset;
        accent = t.accentColor;
        backgroundUrl = t.backgroundUrl ?? '';
        overlay = t.overlayStrength;
        message.text = t.publicMessage;
      });
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 72, maxWidth: 1600);
    if (file == null) return;
    setState(() => busy = true);
    try {
      final path = await PublicThemeBackend.uploadBackground(
        vehicleId: OnboardingDraft.vehicleId,
        ownerId: OnboardingDraft.userId,
        bytes: await file.readAsBytes(),
        mimeType: file.mimeType ?? 'image/jpeg',
      );
      if (mounted) setState(() => backgroundUrl = path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await PublicThemeBackend.saveTheme(
        vehicleId: OnboardingDraft.vehicleId,
        ownerId: OnboardingDraft.userId,
        preset: preset,
        accentColor: accent,
        publicMessage: message.text.trim(),
        overlayStrength: overlay,
      );
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = colorOf(accent);
    final bg = PublicThemeBackend.resolveBackground(backgroundUrl);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.chevron_left_rounded)),
        title: const Text('QR görünümünü kişiselleştir', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('QR okutulduğunda görünen sayfayı aracına özel yap.', style: TextStyle(color: Color(0xFF667085))),
          const SizedBox(height: 16),
          Container(
            height: 240,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: const Color(0xFF06101B), borderRadius: BorderRadius.circular(26)),
            child: Stack(fit: StackFit.expand, children: [
              if (bg.isNotEmpty) Image.network(bg, fit: BoxFit.cover),
              ColoredBox(color: const Color(0xFF06101B).withValues(alpha: overlay)),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Icon(Icons.directions_car_filled, color: accentColor), const SizedBox(width: 8), const Text('HeyCar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19))]),
                  const Spacer(),
                  const Text('Bana ulaşmak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 27)),
                  Text('çok kolay.', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 27)),
                  const SizedBox(height: 8),
                  Text(message.text.isEmpty ? 'Numaram gizli, yolun açık.' : message.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Hazır tema', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final p = options[i];
                final selected = preset == p.$1;
                return GestureDetector(
                  onTap: () => setState(() { preset = p.$1; accent = p.$3; }),
                  child: Container(
                    width: 92,
                    decoration: BoxDecoration(color: p.$4, borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? colorOf(p.$3) : Colors.transparent, width: 3)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 12, backgroundColor: colorOf(p.$3)), const SizedBox(height: 7), Text(p.$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: busy ? null : _pickImage, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Kendi arka planını yükle')),
          const SizedBox(height: 14),
          TextField(controller: message, maxLength: 120, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'QR sayfası mesajı', filled: true, fillColor: Colors.white)),
          const Text('Arka plan karartma', style: TextStyle(fontWeight: FontWeight.w800)),
          Slider(value: overlay, min: .25, max: .90, onChanged: (v) => setState(() => overlay = v)),
          SizedBox(height: 52, child: FilledButton(onPressed: busy ? null : _save, style: FilledButton.styleFrom(backgroundColor: accentColor), child: Text(busy ? 'Kaydediliyor...' : 'Kaydet ve devam et'))),
          TextButton(onPressed: widget.onDone, child: const Text('Şimdilik geç')),
        ],
      ),
    );
  }
}
