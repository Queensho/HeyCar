import 'dart:convert';
import 'package:http/http.dart' as http;
import 'public_theme_backend.dart';

class PublicNotificationApi {
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
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('NOTIFICATION_SEND_FAILED_${response.statusCode}');
    }
  }
}
