import 'dart:convert';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'parking_place.dart';

class ParkingRecordApi {
  static Future<Map<String, dynamic>> save(
    String vehicleId, {
    ParkingPlace? place,
    String area = '',
    String floor = '',
    String spot = '',
    String note = '',
  }) async {
    final owner = OnboardingDraft.userId.trim();
    if (owner.isEmpty || vehicleId.isEmpty)
      throw Exception('Önce giriş yapıp aracını seç.');
    final r = await http
        .put(
          Uri.parse(
            '${QrBackend.baseUrl}/api/vehicles/${Uri.encodeComponent(vehicleId)}/parking',
          ),
          headers: {'Content-Type': 'application/json', 'x-owner-id': owner},
          body: jsonEncode({
            'area': area.trim(),
            'floor': floor.trim(),
            'spot': spot.trim(),
            'note': note.trim(),
            if (place != null) ...{
              'parking_name': place.name,
              'latitude': place.latitude,
              'longitude': place.longitude,
              'osm_id': place.id,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 401 || r.statusCode == 403)
      throw Exception('Bu araç için kayıt yetkisi bulunamadı.');
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception('Park kaydedilemedi. Tekrar dene.');
    final data = jsonDecode(r.body);
    if (data is! Map || data['parking'] is! Map)
      throw Exception('Park kaydı doğrulanamadı.');
    final p = Map<String, dynamic>.from(data['parking']);
    if (place != null &&
        (p['latitude'] is! num ||
            p['longitude'] is! num ||
            p['osm_id'] != place.id ||
            p['started_at'] == null))
      throw Exception('Park servisi güncellenmeli. Konum kaydı doğrulanamadı.');
    return p;
  }
}
