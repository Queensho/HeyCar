import 'package:flutter/material.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';

class CorrectionRequestPage extends StatefulWidget {
  const CorrectionRequestPage({
    super.key,
    this.initialType = 'qr_change',
    this.initialMessage = '',
  });

  final String initialType;
  final String initialMessage;

  @override
  State<CorrectionRequestPage> createState() => _CorrectionRequestPageState();
}

class _CorrectionRequestPageState extends State<CorrectionRequestPage> {
  late String type;
  late final TextEditingController message;
  late final TextEditingController email;
  bool busy = false;
  String? error;
  bool sent = false;

  @override
  void initState() {
    super.initState();
    type = widget.initialType;
    message = TextEditingController(text: widget.initialMessage);
    email = TextEditingController(text: OnboardingDraft.email);
  }

  @override
  void dispose() {
    message.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await QrBackend.createCorrectionRequest(
        requestType: type,
        message: message.text.trim(),
        contactEmail: email.text.trim(),
      );
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF07111F);
    const panel = Color(0xFF101A2F);
    const line = Color(0xFF33436A);
    const purple = Color(0xFF8B5CFF);
    const muted = Color(0xFFAAB4CF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        title: const Text('Düzeltme talebi', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (sent)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: line),
                ),
                child: const Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFF224D3D),
                      child: Icon(Icons.check_rounded, color: Color(0xFF6EE7B7), size: 34),
                    ),
                    SizedBox(height: 14),
                    Text('Talebin alındı', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    SizedBox(height: 8),
                    Text('HeyCar yönetimi talebini admin panelinden inceleyecek. Sonuçlandığında hesabındaki talep durumu güncellenecek.', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.45)),
                  ],
                ),
              )
            else ...[
              const Text('Ne düzeltilsin?', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('QR değişikliği veya araç bilgisi düzeltmesi için talep oluştur.', style: TextStyle(color: muted, height: 1.4)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'qr_change',
                      groupValue: type,
                      onChanged: (v) => setState(() => type = v!),
                      activeColor: purple,
                      title: const Text('QR değişikliği', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      subtitle: const Text('Yeni QR bağlama / eski QR değiştirme', style: TextStyle(color: muted)),
                    ),
                    RadioListTile<String>(
                      value: 'vehicle_info',
                      groupValue: type,
                      onChanged: (v) => setState(() => type = v!),
                      activeColor: purple,
                      title: const Text('Araç bilgisi düzeltme', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      subtitle: const Text('Plaka, marka, model gibi bilgiler', style: TextStyle(color: muted)),
                    ),
                    RadioListTile<String>(
                      value: 'other',
                      groupValue: type,
                      onChanged: (v) => setState(() => type = v!),
                      activeColor: purple,
                      title: const Text('Diğer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('İletişim e-postası', panel, line, muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: message,
                maxLines: 5,
                maxLength: 1000,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('Açıklama', panel, line, muted),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Talep bilgisi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('QR: ${QrDraft.token.isEmpty ? '-' : QrDraft.token}', style: const TextStyle(color: muted)),
                    Text('Araç: ${QrDraft.plate.isEmpty ? '-' : QrDraft.plate}', style: const TextStyle(color: muted)),
                  ],
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Color(0xFFFF8AA0), fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Talep oluştur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, Color panel, Color line, Color muted) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: muted),
        filled: true,
        fillColor: panel,
        counterStyle: TextStyle(color: muted),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF8B5CFF), width: 1.5)),
      );
}
