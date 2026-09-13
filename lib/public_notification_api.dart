import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'public_theme_backend.dart';

class PublicNotificationApi {
  static final ImagePicker _picker = ImagePicker();
  static String? photoUrl;
  static double? latitude;
  static double? longitude;

  static String currentToken() =>
      (Uri.base.queryParameters['tag'] ?? '').trim().toUpperCase();

  static String backendTypeFor(String label) {
    switch (label) {
      case 'Aracınızı çekebilir misiniz?':
        return 'move_vehicle';
      case 'Farlarınız açık':
        return 'lights_on';
      case 'Aracınızda hasar var':
        return 'damage';
      default:
        return 'message';
    }
  }

  static Future<bool> pickAndUploadPhoto() async {
    final token = currentToken();
    if (token.isEmpty) throw Exception('QR_TOKEN_MISSING');
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 68,
      maxWidth: 1280,
    );
    if (file == null) return false;
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? 'image/jpeg';
    final response = await http
        .post(
          Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/notification-photo'),
          headers: {'Content-Type': mime},
          body: bytes,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('PHOTO_UPLOAD_FAILED_${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    photoUrl = data['photoUrl']?.toString();
    return photoUrl != null && photoUrl!.isNotEmpty;
  }

  static Future<bool> pickLocation() async {
    final position = await html.window.navigator.geolocation
        .getCurrentPosition(enableHighAccuracy: true)
        .timeout(const Duration(seconds: 15));
    latitude = position.coords?.latitude?.toDouble();
    longitude = position.coords?.longitude?.toDouble();
    return latitude != null && longitude != null;
  }

  static void clearDraft() {
    photoUrl = null;
    latitude = null;
    longitude = null;
  }

  static Future<void> send({
    required String typeLabel,
    required String message,
  }) async {
    final token = currentToken();
    if (token.isEmpty) throw Exception('QR_TOKEN_MISSING');

    final response = await http
        .post(
          Uri.parse(
            '${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/notifications',
          ),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'type': backendTypeFor(typeLabel),
            'message': message.trim(),
            if (photoUrl != null) 'photoUrl': photoUrl,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('NOTIFICATION_SEND_FAILED_${response.statusCode}');
    }
    clearDraft();
  }

  static Future<void> sendCallRequest() async {
    final token = currentToken();
    if (token.isEmpty) throw Exception('QR_TOKEN_MISSING');
    final response = await http
        .post(
          Uri.parse('${PublicThemeBackend.baseUrl}/api/qr/${Uri.encodeComponent(token)}/notifications'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'type': 'call_request',
            'message': 'Gizli arama isteği gönderildi.',
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('CALL_REQUEST_FAILED_${response.statusCode}');
    }
  }
}
