import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';

const _bg = Color(0xFF101A30);
const _line = Color(0xFF27355D);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFFA7B0C7);

Future<String> _resolveOwnerQrToken() async {
  var token = QrDraft.token.trim().toUpperCase();
  if (token.isNotEmpty) return token;

  final phone = OnboardingDraft.phone.trim();
  if (phone.isEmpty) return '';

  try {
    final response = await http.post(
      Uri.parse('https://heycar-api-185-165-46-213.nip.io/api/owner/login-phone'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otpCode': '123456'}),
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) return '';

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return '';
    final vehicles = data['vehicles'];
    if (vehicles is! List || vehicles.isEmpty) return '';

    Map<String, dynamic>? selected;
    final wantedId = QrDraft.vehicleId.trim();
    for (final item in vehicles) {
      if (item is! Map) continue;
      final vehicle = Map<String, dynamic>.from(item);
      if (wantedId.isNotEmpty && vehicle['id']?.toString() == wantedId) {
        selected = vehicle;
        break;
      }
      selected ??= vehicle;
    }

    final status = selected?['qr_status']?.toString() ?? '';
    final remoteToken = selected?['qr_token']?.toString().trim().toUpperCase() ?? '';
    if (status == 'active' && remoteToken.isNotEmpty) {
      QrDraft.token = remoteToken;
      return remoteToken;
    }
  } catch (_) {}
  return '';
}

Future<void> showOwnerQrDialog(BuildContext context) async {
  final token = await _resolveOwnerQrToken();
  if (!context.mounted) return;
  final publicUrl = token.isEmpty
      ? ''
      : 'https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(token)}';

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .72),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _line),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 12)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'QR Kodum',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (publicUrl.isNotEmpty) ...[
                Container(
                  width: 224,
                  height: 224,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Image.network(
                    'https://quickchart.io/qr?text=${Uri.encodeComponent(publicUrl)}&size=420',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2_rounded, size: 150, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  token,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  publicUrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
              ] else ...[
                const SizedBox(height: 10),
                const Icon(Icons.qr_code_2_rounded, size: 72, color: _purple),
                const SizedBox(height: 10),
                const Text(
                  'Aktif QR kodu bulunamadı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
