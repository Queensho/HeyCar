import 'dart:convert';
import 'package:http/http.dart' as http;

class RegistrationDraft {
  static String phone = '';
  static String displayName = '';
  static String email = '';
  static String password = '';
  static String? userId;
  static String? vehicleId;
}

class RegistrationBackend {
  static const baseUrl = 'https://heycar-api-185-165-46-213.nip.io';

  static Future<Map<String, dynamic>> register({
    required String plate,
    required String make,
    String? model,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': RegistrationDraft.phone.trim(),
        'displayName': RegistrationDraft.displayName.trim(),
        'email': RegistrationDraft.email.trim(),
        'password': RegistrationDraft.password,
        'plate': plate.trim().toUpperCase(),
        'make': make.trim(),
        'model': model?.trim() ?? '',
      }),
    ).timeout(const Duration(seconds: 15));

    Map<String, dynamic> body = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) {
      RegistrationDraft.userId = body['user']?['id']?.toString();
      RegistrationDraft.vehicleId = body['vehicle']?['id']?.toString();
      return body;
    }

    final code = body['error']?.toString() ?? '';
    if (code == 'MISSING_REQUIRED_FIELDS') {
      throw Exception('Ad soyad, şifre, plaka ve marka gerekli.');
    }
    if (code == 'EMAIL_IN_USE') {
      throw Exception('Bu e-posta adresi zaten kullanılıyor.');
    }
    throw Exception('Kayıt sunucuya kaydedilemedi.');
  }
}
