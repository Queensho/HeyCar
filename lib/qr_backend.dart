import 'dart:convert';
import 'package:http/http.dart' as http;

class QrDraft {
  static String plate = '';
  static String make = '';
  static String model = '';
  static String ownerName = 'HeyCar Kullanıcısı';
}

class QrBackend {
  static const String baseUrl = 'https://tlwjymvhotnruumoyrit.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRsd2p5bXZob3RucnV1bW95cml0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwNzA4ODksImV4cCI6MjEwMzY0Njg4OX0.2LQrnS74IWw17hs6USKOetQx8rddvJQtj048bH5eOp8';

  static String normalizeToken(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    try {
      final uri = Uri.parse(value);
      final tag = uri.queryParameters['tag'];
      if (tag != null && tag.isNotEmpty) return tag.trim().toUpperCase();
      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last.trim();
        if (last.toUpperCase().startsWith('HC-')) return last.toUpperCase();
      }
    } catch (_) {}
    final match = RegExp(r'HC-[A-Z0-9-]+', caseSensitive: false).firstMatch(value);
    return (match?.group(0) ?? value).trim().toUpperCase();
  }

  static Future<Map<String, dynamic>> activate({
    required String token,
    required String plate,
    required String make,
    String? model,
    String? ownerName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rest/v1/rpc/activate_qr'),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'p_token': normalizeToken(token),
        'p_plate': plate.trim().toUpperCase(),
        'p_make': make.trim(),
        'p_model': model?.trim(),
        'p_owner_name': ownerName?.trim(),
      }),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'QR bağlanamadı.';
      try {
        final body = jsonDecode(response.body);
        final raw = body is Map ? (body['message']?.toString() ?? '') : '';
        if (raw.contains('QR_NOT_FOUND')) message = 'Bu QR HeyCar sisteminde bulunamadı.';
        if (raw.contains('QR_ALREADY_BOUND')) message = 'Bu QR daha önce başka bir araca bağlanmış.';
        if (raw.contains('QR_DISABLED')) message = 'Bu QR etiketi devre dışı.';
      } catch (_) {}
      throw Exception(message);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Sunucudan geçersiz cevap alındı.');
  }

  static Future<Map<String, dynamic>> lookup(String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rest/v1/rpc/get_public_qr'),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'p_token': normalizeToken(token)}),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('QR bilgisi alınamadı.');
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }
}
