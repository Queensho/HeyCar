import 'dart:convert';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'owner_auth.dart';

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
        final last = uri.pathSegments.last.trim().toUpperCase();
        if (isValidToken(last)) return last;
      }
    } catch (_) {}
    final match = RegExp(r'(?:CP-QAR-[0-9]+|HC-[A-Z0-9-]+)', caseSensitive: false).firstMatch(value);
    return (match?.group(0) ?? value).trim().toUpperCase();
  }

  static bool isValidToken(String raw) {
    final token = raw.trim().toUpperCase();
    return RegExp(r'^CP-QAR-[0-9]+
  static Future<Map<String, dynamic>> activate({
    required String token,
    required String plate,
    required String make,
    String? model,
    String? ownerName,
    String? vehicleId,
  }) async {
    final ownerId = OnboardingDraft.userId.trim();
    final resolvedVehicleId = (vehicleId ?? QrDraft.vehicleId).trim();
    if (ownerId.isEmpty) throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');
    if (resolvedVehicleId.isEmpty) throw Exception('Kayıtlı araç bulunamadı.');

    final response = await OwnerHttp.post(
      Uri.parse('$baseUrl/api/qr/activate'),
      body: jsonEncode({
        'token': normalizeToken(token),
        'vehicleId': resolvedVehicleId,
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
    if (code == 'QR_ALREADY_BOUND') throw Exception('Bu QR başka bir araca zaten bağlı. Değişiklik için düzeltme talebi oluştur.');
    if (code == 'VEHICLE_ALREADY_HAS_QR') throw Exception('Bu araca zaten aktif bir QR bağlı. QR değişikliği için düzeltme talebi oluştur.');
    if (code == 'QR_DISABLED') throw Exception('Bu QR etiketi devre dışı.');
    if (code == 'VEHICLE_NOT_FOUND') throw Exception('Kayıtlı araç bulunamadı.');
    if (code == 'OWNER_REQUIRED') throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');
    if (code == 'FORBIDDEN') throw Exception('Bu araç bu hesaba ait değil.');
    throw Exception('QR bağlanamadı.');
  }

  static Future<Map<String, dynamic>> createCorrectionRequest({
    required String requestType,
    String message = '',
    String contactEmail = '',
  }) async {
    final ownerId = OnboardingDraft.userId.trim();
    if (ownerId.isEmpty) throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');

    final response = await OwnerHttp
        .post(
          Uri.parse('$baseUrl/api/owner/correction-requests'),
          body: jsonEncode({
            'vehicleId': QrDraft.vehicleId.trim().isEmpty ? OnboardingDraft.vehicleId.trim() : QrDraft.vehicleId.trim(),
            'qrToken': normalizeToken(QrDraft.token),
            'requestType': requestType,
            'message': message.trim(),
            'contactEmail': contactEmail.trim(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) return decoded;
    final code = decoded is Map ? decoded['error']?.toString() ?? '' : '';
    if (code == 'FORBIDDEN') throw Exception('Bu araç bu hesaba ait değil.');
    if (code == 'OWNER_REQUIRED') throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');
    if (code == 'INVALID_REQUEST_TYPE') throw Exception('Geçersiz talep türü.');
    throw Exception('Düzeltme talebi oluşturulamadı. Tekrar dene.');
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
).hasMatch(token) ||
        RegExp(r'^HC-[A-Z0-9-]+
  static Future<Map<String, dynamic>> activate({
    required String token,
    required String plate,
    required String make,
    String? model,
    String? ownerName,
    String? vehicleId,
  }) async {
    final ownerId = OnboardingDraft.userId.trim();
    final resolvedVehicleId = (vehicleId ?? QrDraft.vehicleId).trim();
    if (ownerId.isEmpty) throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');
    if (resolvedVehicleId.isEmpty) throw Exception('Kayıtlı araç bulunamadı.');

    final response = await OwnerHttp.post(
      Uri.parse('$baseUrl/api/qr/activate'),
      body: jsonEncode({
        'token': normalizeToken(token),
        'vehicleId': resolvedVehicleId,
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
    if (code == 'QR_ALREADY_BOUND') throw Exception('Bu QR başka bir araca zaten bağlı. Değişiklik için düzeltme talebi oluştur.');
    if (code == 'VEHICLE_ALREADY_HAS_QR') throw Exception('Bu araca zaten aktif bir QR bağlı. QR değişikliği için düzeltme talebi oluştur.');
    if (code == 'QR_DISABLED') throw Exception('Bu QR etiketi devre dışı.');
    if (code == 'VEHICLE_NOT_FOUND') throw Exception('Kayıtlı araç bulunamadı.');
    if (code == 'OWNER_REQUIRED') throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');
    if (code == 'FORBIDDEN') throw Exception('Bu araç bu hesaba ait değil.');
    throw Exception('QR bağlanamadı.');
  }

  static Future<Map<String, dynamic>> createCorrectionRequest({
    required String requestType,
    String message = '',
    String contactEmail = '',
  }) async {
    final ownerId = OnboardingDraft.userId.trim();
    if (ownerId.isEmpty) throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');

    final response = await OwnerHttp
        .post(
          Uri.parse('$baseUrl/api/owner/correction-requests'),
          body: jsonEncode({
            'vehicleId': QrDraft.vehicleId.trim().isEmpty ? OnboardingDraft.vehicleId.trim() : QrDraft.vehicleId.trim(),
            'qrToken': normalizeToken(QrDraft.token),
            'requestType': requestType,
            'message': message.trim(),
            'contactEmail': contactEmail.trim(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) return decoded;
    final code = decoded is Map ? decoded['error']?.toString() ?? '' : '';
    if (code == 'FORBIDDEN') throw Exception('Bu araç bu hesaba ait değil.');
    if (code == 'OWNER_REQUIRED') throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');
    if (code == 'INVALID_REQUEST_TYPE') throw Exception('Geçersiz talep türü.');
    throw Exception('Düzeltme talebi oluşturulamadı. Tekrar dene.');
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
).hasMatch(token);
  }

  static Future<Map<String, dynamic>> activate({
    required String token,
    required String plate,
    required String make,
    String? model,
    String? ownerName,
    String? vehicleId,
  }) async {
    final ownerId = OnboardingDraft.userId.trim();
    final resolvedVehicleId = (vehicleId ?? QrDraft.vehicleId).trim();
    if (ownerId.isEmpty) throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');
    if (resolvedVehicleId.isEmpty) throw Exception('Kayıtlı araç bulunamadı.');

    final response = await OwnerHttp.post(
      Uri.parse('$baseUrl/api/qr/activate'),
      body: jsonEncode({
        'token': normalizeToken(token),
        'vehicleId': resolvedVehicleId,
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
    if (code == 'QR_ALREADY_BOUND') throw Exception('Bu QR başka bir araca zaten bağlı. Değişiklik için düzeltme talebi oluştur.');
    if (code == 'VEHICLE_ALREADY_HAS_QR') throw Exception('Bu araca zaten aktif bir QR bağlı. QR değişikliği için düzeltme talebi oluştur.');
    if (code == 'QR_DISABLED') throw Exception('Bu QR etiketi devre dışı.');
    if (code == 'VEHICLE_NOT_FOUND') throw Exception('Kayıtlı araç bulunamadı.');
    if (code == 'OWNER_REQUIRED') throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');
    if (code == 'FORBIDDEN') throw Exception('Bu araç bu hesaba ait değil.');
    throw Exception('QR bağlanamadı.');
  }

  static Future<Map<String, dynamic>> createCorrectionRequest({
    required String requestType,
    String message = '',
    String contactEmail = '',
  }) async {
    final ownerId = OnboardingDraft.userId.trim();
    if (ownerId.isEmpty) throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');

    final response = await OwnerHttp
        .post(
          Uri.parse('$baseUrl/api/owner/correction-requests'),
          body: jsonEncode({
            'vehicleId': QrDraft.vehicleId.trim().isEmpty ? OnboardingDraft.vehicleId.trim() : QrDraft.vehicleId.trim(),
            'qrToken': normalizeToken(QrDraft.token),
            'requestType': requestType,
            'message': message.trim(),
            'contactEmail': contactEmail.trim(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) return decoded;
    final code = decoded is Map ? decoded['error']?.toString() ?? '' : '';
    if (code == 'FORBIDDEN') throw Exception('Bu araç bu hesaba ait değil.');
    if (code == 'OWNER_REQUIRED') throw Exception('Oturum bilgisi bulunamadı. Tekrar giriş yap.');
    if (code == 'INVALID_REQUEST_TYPE') throw Exception('Geçersiz talep türü.');
    throw Exception('Düzeltme talebi oluşturulamadı. Tekrar dene.');
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
