import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class PublicThemeData {
  const PublicThemeData({
    this.preset = 'classic',
    this.accentColor = '#FCA311',
    this.backgroundUrl,
    this.publicMessage = 'Numaram gizli, yolun açık.',
    this.overlayStrength = .72,
  });

  final String preset;
  final String accentColor;
  final String? backgroundUrl;
  final String publicMessage;
  final double overlayStrength;

  factory PublicThemeData.fromJson(Map<String, dynamic> json) => PublicThemeData(
        preset: json['preset']?.toString() ?? 'classic',
        accentColor: json['accentColor']?.toString() ?? json['accent_color']?.toString() ?? '#FCA311',
        backgroundUrl: json['backgroundUrl']?.toString() ?? json['background_path']?.toString(),
        publicMessage: json['publicMessage']?.toString() ?? json['public_message']?.toString() ?? 'Numaram gizli, yolun açık.',
        overlayStrength: double.tryParse((json['overlayStrength'] ?? json['overlay_strength'] ?? .72).toString()) ?? .72,
      );
}

class PublicThemeBackend {
  static const baseUrl = 'https://heycar-api-185-165-46-213.nip.io';

  static String resolveBackground(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return '$baseUrl$value';
  }

  static Future<PublicThemeData> getTheme({required String vehicleId, required String ownerId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/vehicles/$vehicleId/public-theme'),
      headers: {'x-owner-id': ownerId},
    ).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return PublicThemeData.fromJson((decoded['theme'] as Map?)?.cast<String, dynamic>() ?? const {});
    }
    throw Exception('Tema yüklenemedi.');
  }

  static Future<PublicThemeData> saveTheme({
    required String vehicleId,
    required String ownerId,
    required String preset,
    required String accentColor,
    required String publicMessage,
    required double overlayStrength,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/vehicles/$vehicleId/public-theme'),
      headers: {'Content-Type': 'application/json', 'x-owner-id': ownerId},
      body: jsonEncode({
        'preset': preset,
        'accentColor': accentColor,
        'publicMessage': publicMessage,
        'overlayStrength': overlayStrength,
      }),
    ).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return PublicThemeData.fromJson((decoded['theme'] as Map?)?.cast<String, dynamic>() ?? const {});
    }
    throw Exception('Tema kaydedilemedi.');
  }

  static Future<String> uploadBackground({
    required String vehicleId,
    required String ownerId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/vehicles/$vehicleId/public-theme/background'),
      headers: {'Content-Type': mimeType, 'x-owner-id': ownerId},
      body: bytes,
    ).timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded['backgroundUrl']?.toString() ?? '';
    }
    throw Exception('Arka plan yüklenemedi.');
  }

  static Future<void> removeBackground({required String vehicleId, required String ownerId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/vehicles/$vehicleId/public-theme/background'),
      headers: {'x-owner-id': ownerId},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Arka plan kaldırılamadı.');
    }
  }
}
