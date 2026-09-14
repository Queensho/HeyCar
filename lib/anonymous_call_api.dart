import 'dart:convert';
import 'package:http/http.dart' as http;
import 'public_theme_backend.dart';

class AnonymousCallApi {
  const AnonymousCallApi._();

  static Future<Map<String, dynamic>> create(String token) async {
    final response = await http.post(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/public/calls'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'qrToken': token}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_CREATE_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }
}
