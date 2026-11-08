import 'dart:convert';
import 'package:http/http.dart' as http;
import '../owner_auth.dart';
import '../driver_auth.dart';
import '../onboarding_backend.dart';

class MarketplaceException implements Exception {
  const MarketplaceException(this.code);
  final String code;
  @override
  String toString() => switch (code) {
        'AUTH_REQUIRED' || 'UNAUTHORIZED' => 'Devam etmek için giriş yapın.',
        'OFFER_NOT_AVAILABLE' => 'Bu kampanya artık kullanılamıyor.',
        'VEHICLE_NOT_OWNED' ||
        'DRIVER_NOT_AUTHORIZED' =>
          'Bu araç için yetkiniz bulunmuyor.',
        'PENDING_VEHICLE_MISMATCH' =>
          'Mevcut kodunuz farklı bir araca ait. Geçmişten görüntüleyin.',
        'ALREADY_USED' => 'Bu kod daha önce kullanılmış.',
        'OFFER_TOTAL_LIMIT_REACHED' ||
        'OFFER_DAILY_LIMIT_REACHED' =>
          'Kampanya kullanım limiti doldu.',
        _ => 'İşlem tamamlanamadı. Lütfen yeniden deneyin.',
      };
}

/// Uses the existing session clients; never sends an owner/driver ID from UI.
class MarketplaceApi {
  MarketplaceApi({this.driverMode = false});
  final bool driverMode;
  String get baseUrl => OnboardingBackend.baseUrl;
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response response;
    if (authenticated) {
      if (driverMode) {
        response = switch (method) {
          'POST' => await DriverHttp.post(uri, body: encoded),
          'DELETE' => await DriverHttp.delete(uri),
          _ => await DriverHttp.get(uri, json: false),
        };
      } else {
        response = switch (method) {
          'POST' => await OwnerHttp.post(uri, body: encoded),
          'DELETE' => await OwnerHttp.delete(uri),
          _ => await OwnerHttp.get(uri, json: false),
        };
      }
    } else {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const MarketplaceException('INVALID_RESPONSE');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map) {
      throw MarketplaceException(decoded is Map
          ? '${decoded['error'] ?? 'SERVER_ERROR'}'
          : 'SERVER_ERROR');
    }
    return Map<String, dynamic>.from(decoded);
  }
}

List<Map<String, dynamic>> marketRows(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
String marketText(Map data, String key, [String fallback = '']) =>
    '${data[key] ?? fallback}';
bool campaignAvailable(Map data, [DateTime? now]) {
  final start = DateTime.tryParse(marketText(data, 'starts_at'));
  final end = DateTime.tryParse(marketText(data, 'ends_at'));
  final time = now ?? DateTime.now();
  return start != null &&
      end != null &&
      !time.isBefore(start) &&
      !time.isAfter(end) &&
      data['is_active'] != false;
}

String campaignDates(Map data) {
  String date(String key) {
    final d = DateTime.tryParse(marketText(data, key))?.toLocal();
    return d == null ? 'Belirtilmemiş' : '${d.day}.${d.month}.${d.year}';
  }

  return '${date('starts_at')} – ${date('ends_at')}';
}

String marketDistance(Map data) {
  final m = double.tryParse(marketText(data, 'distance_m'));
  return m == null
      ? 'Mesafe için konum seçin'
      : m < 1000
          ? '${m.round()} m'
          : '${(m / 1000).toStringAsFixed(1)} km';
}
