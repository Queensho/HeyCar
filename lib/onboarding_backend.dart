import 'dart:convert';
import 'package:http/http.dart' as http;
import 'qr_backend.dart';
import 'owner_auth.dart';

class OnboardingDraft {
  static String phone = '';
  static String displayName = '';
  static String email = '';
  static String password = '';
  static String otpCode = '';
  static String userId = '';
  static String vehicleId = '';
  static String transferCode = '';
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
    String transferCode = '',
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
            'transferCode': transferCode.trim().toUpperCase(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is Map<String, dynamic>) {
      await OwnerAuth.saveFrom(decoded);
      final user = decoded['user'];
      final vehicle = decoded['vehicle'];
      if (user is Map) OnboardingDraft.userId = user['id']?.toString() ?? '';
      if (vehicle is Map) OnboardingDraft.vehicleId = vehicle['id']?.toString() ?? '';

      QrDraft.vehicleId = OnboardingDraft.vehicleId;
      QrDraft.plate = vehicle is Map ? (vehicle['plate']?.toString() ?? plate.trim().toUpperCase()) : plate.trim().toUpperCase();
      QrDraft.make = vehicle is Map ? (vehicle['make']?.toString() ?? make.trim()) : make.trim();
      QrDraft.model = vehicle is Map ? (vehicle['model']?.toString() ?? model.trim()) : model.trim();
      if (vehicle is Map && vehicle['qr_token'] != null) QrDraft.token = vehicle['qr_token'].toString();
      QrDraft.ownerName = displayName.trim().isEmpty ? 'HeyCar Kullanıcısı' : displayName.trim();

      return decoded;
    }

    final code = decoded is Map ? decoded['error']?.toString() ?? '' : '';
    if (code == 'EMAIL_EXISTS') throw Exception('Bu e-posta adresi zaten kayıtlı.');
    if (code == 'PHONE_EXISTS') throw Exception('Bu telefon numarası zaten kayıtlı.');
    if (code == 'INVALID_PHONE') throw Exception('Geçerli bir cep telefonu numarası gir.');
    if (code == 'INVALID_INPUT') throw Exception('Bilgileri kontrol edip tekrar dene.');
    if (code == 'TRANSFER_NOT_FOUND') throw Exception('Devir kodu bulunamadı.');
    if (code == 'TRANSFER_EXPIRED') throw Exception('Devir kodunun süresi dolmuş veya kod kullanılmış.');
    throw Exception('Kayıt tamamlanamadı. Tekrar dene.');
  }
}
