import 'dart:convert';
import 'package:http/http.dart' as http;

class QrDraft {
  static String token = '';
  static String plate = '';
  static String make = '';
  static String model = '';
  static String ownerName = 'HeyCar Kullanıcısı';
  static String vehicleId = '';
}

class QrBackend {
  static const String baseUrl = 'https://heycar-api-185-165-46-213.nip.io';

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
    String? vehicleId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/qr/activate'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': normalizeToken(token),
        'vehicleId': (vehicleId ?? QrDraft.vehicleId).trim(),
        'plate': plate.trim().toUpperCase(),
        'make': make.trim(),
        'model': model?.trim(),
        'ownerName': ownerName?.trim(),
      }),
    ).timeout(const Duration(seconds: 12));
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) return decoded;
    final code = decoded is Map ? decoded['error']?.toString() ?? '' : '';
    if (code == 'QR_NOT_FOUND') throw Exception('Bu QR HeyCar sisteminde bulunamadı.');
    if (code == 'QR_ALREADY_BOUND') throw Exception('Bu QR daha önce başka bir araca bağlanmış.');
    if (code == 'QR_DISABLED') throw Exception('Bu QR etiketi devre dışı.');
    if (code == 'VEHICLE_NOT_FOUND') throw Exception('Kayıtlı araç bulunamadı.');
    throw Exception('QR bağlanamadı.');
  }

  static Future<Map<String, dynamic>> lookup(String token) async {
    final normalized = normalizeToken(token);
    final response = await http.get(Uri.parse('$baseUrl/api/qr/${Uri.encodeComponent(normalized)}')).timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) throw Exception('Bu QR HeyCar sisteminde bulunamadı.');
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('QR bilgisi alınamadı.');
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }
}
