import 'dart:convert';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'public_theme_backend.dart';
import 'public_notification_api.dart';

class AnonymousCallApi {
  const AnonymousCallApi._();

  static Future<Map<String, dynamic>> create(String token) async {
    final response = await http.post(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/public/calls'),
      headers: {'Content-Type': 'application/json', 'x-scan-token': await PublicNotificationApi.scanToken()},
      body: jsonEncode({'qrToken': token}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_CREATE_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }

  static Future<Map<String, dynamic>> publicStatus(String callId, String visitorToken) async {
    final response = await http.get(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/public/calls/${Uri.encodeComponent(callId)}'),
      headers: {'x-visitor-token': visitorToken},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_STATUS_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }

  static Future<void> publicSignal(
    String callId,
    String visitorToken, {
    Map<String, dynamic>? offer,
    Map<String, dynamic>? candidate,
    String? action,
  }) async {
    final response = await http.patch(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/public/calls/${Uri.encodeComponent(callId)}'),
      headers: {'Content-Type': 'application/json', 'x-visitor-token': visitorToken},
      body: jsonEncode({
        if (offer != null) 'offer': offer,
        if (candidate != null) 'candidate': candidate,
        if (action != null) 'action': action,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('CALL_SIGNAL_FAILED');
    }
  }

  static Future<Map<String, dynamic>?> incoming() async {
    final ownerId = OnboardingDraft.userId.trim();
    if (ownerId.isEmpty) return null;
    final response = await http.get(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/owner/calls/incoming'),
      headers: {'x-owner-id': ownerId},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final call = data['call'];
    return call is Map ? Map<String, dynamic>.from(call) : null;
  }

  static Future<Map<String, dynamic>> ownerStatus(String callId) async {
    final response = await http.get(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/owner/calls/${Uri.encodeComponent(callId)}'),
      headers: {'x-owner-id': OnboardingDraft.userId.trim()},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_STATUS_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }

  static Future<Map<String, dynamic>> ownerSignal(
    String callId, {
    String? action,
    Map<String, dynamic>? answer,
    Map<String, dynamic>? candidate,
  }) async {
    final response = await http.patch(
      Uri.parse('${PublicThemeBackend.baseUrl}/api/owner/calls/${Uri.encodeComponent(callId)}'),
      headers: {'Content-Type': 'application/json', 'x-owner-id': OnboardingDraft.userId.trim()},
      body: jsonEncode({
        if (action != null) 'action': action,
        if (answer != null) 'answer': answer,
        if (candidate != null) 'candidate': candidate,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'CALL_UPDATE_FAILED');
    }
    return Map<String, dynamic>.from(data['call'] as Map);
  }
}
