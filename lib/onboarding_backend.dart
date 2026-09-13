import 'dart:convert';
import 'package:http/http.dart' as http;
import 'qr_backend.dart';

class OnboardingDraft {
  static String phone = '';
  static String displayName = '';
  static String email = '';
  static String password = '';
  static String userId = '';
  static String vehicleId = '';
}

class OnboardingBackend {
  static const String baseUrl = 'https://heycar-api-185-165-46-213.nip.io';

  static Future<Map<String, dynamic>> registerWithVehicle({
    required String phone,
    required String displayName,
    required String email,
    required String password,
    required String plate,
    required String make,
    required String model,
    String color = '',
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/onboarding/register'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': phone.trim(),
            'displayName': displayName.trim(),
            'email': email.trim(),
            'password': password,
            'plate': plate.trim().toUpperCase(),
            'make': make.trim(),
            'model': model.trim(),
            'color': color.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is Map<String, dynamic>) {
      final user = decoded['user'];
      final vehicle = decoded['vehicle'];
      if (user is Map) OnboardingDraft.userId = user['id']?.toString() ?? '';
      if (vehicle is Map) OnboardingDraft.vehicleId = vehicle['id']?.toString() ?? '';

      QrDraft.vehicleId = OnboardingDraft.vehicleId;
      QrDraft.plate = plate.trim().toUpperCase();
      QrDraft.make = make.trim();
      QrDraft.model = model.trim();
      QrDraft.ownerName = displayName.trim().isEmpty ? 'HeyCar Kullanıcısı' : displayName.trim();

      return decoded;
    }

    final code = decoded is Map ? decoded['error']?.toString() ?? '' : '';
    if (code == 'EMAIL_EXISTS') {
      throw Exception('Bu e-posta adresi zaten kayıtlı.');
    }
    if (code == 'INVALID_INPUT') {
      throw Exception('Bilgileri kontrol edip tekrar dene.');
    }
    throw Exception('Kayıt tamamlanamadı. Tekrar dene.');
  }
}
