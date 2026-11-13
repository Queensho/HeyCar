import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'owner_auth.dart';

typedef WashJson = Map<String, dynamic>;

String washKey() {
  final r = Random.secure();
  return List.generate(
      24, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

String washDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String washTime(Object? value) {
  final d = DateTime.tryParse('$value')?.toUtc().add(const Duration(hours: 3));
  return d == null
      ? ''
      : '${washDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String washPrice(Object? value) {
  final amount = num.tryParse('$value');
  if (amount == null || !amount.isFinite || amount < 0 || amount % 1 != 0)
    return 'Fiyat belirtilmedi';
  return '${(amount / 100).toStringAsFixed(2)} ₺';
}

const washStatuses = {
  'pending': 'Bekliyor',
  'confirmed': 'Onaylandı',
  'in_progress': 'İşlemde',
  'completed': 'Tamamlandı',
  'cancelled': 'İptal edildi',
  'rejected': 'Reddedildi'
};
const washEvents = {
  'created': 'Randevu oluşturuldu',
  'rescheduled': 'Yeniden planlandı',
  'reminder': 'Randevu yaklaşıyor',
  ...washStatuses
};
List<WashJson> washRows(Object? value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : [];

class CarWashApi {
  CarWashApi({this.businessToken, this.baseUrl = OnboardingBackend.baseUrl});
  final String? businessToken;
  final String baseUrl;
  Future<WashJson> call(String path,
      {String method = 'GET', WashJson? body, String? key}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (key != null) 'Idempotency-Key': key
    };
    late http.Response r;
    if (businessToken != null) {
      headers['Authorization'] = 'Bearer $businessToken';
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      r = await http.Response.fromStream(
          await request.send().timeout(const Duration(seconds: 20)));
    } else if (method == 'POST') {
      r = await OwnerHttp.post(uri,
              headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 20));
    } else {
      r = await OwnerHttp.get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
    }
    // A missing API route can return the hosting site's HTML fallback.
    // Never surface a raw JSON FormatException (or HTML) to customers.
    final contentType = r.headers['content-type']?.toLowerCase() ?? '';
    if (r.body.trimLeft().startsWith('<') ||
        (contentType.contains('text/html') && !contentType.contains('json'))) {
      throw Exception(
          'Oto yıkama servisine şu anda ulaşılamıyor. Lütfen daha sonra tekrar deneyin.');
    }
    Object? data;
    try {
      data = jsonDecode(r.body);
    } on FormatException {
      throw Exception(
          'Sunucudan geçerli bir yanıt alınamadı. Lütfen tekrar deneyin.');
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final code = data is Map ? '${data['error']}' : '';
      throw Exception(const {
            'CAR_WASH_DISABLED': 'Oto yıkama hizmeti şu anda kullanılamıyor.',
            'SLOT_UNAVAILABLE': 'Bu saat doldu. Lütfen başka bir saat seçin.',
            'OUTSIDE_WORKING_HOURS': 'İşletme bu saatte kapalı.',
            'AUTH_REQUIRED': 'Lütfen mevcut hesabınızla giriş yapın.',
            'INVALID_SESSION': 'İşletme oturumunuz sona erdi.',
            'VEHICLE_NOT_OWNED': 'Bu araç artık hesabınıza bağlı değil.',
            'INVALID_TRANSITION': 'Randevunun durumu bu işleme uygun değil.',
            'RESOURCE_HAS_BOOKINGS':
                'Bu kapasite kaynağının aktif randevuları var.',
            'SCHEDULE_HAS_BOOKINGS':
                'Yeni saatler veya tatiller mevcut randevularla çakışıyor. Önce bu randevuları yönetin.',
            'TOO_EARLY': 'Hizmet başlama saati henüz gelmedi.',
            'SERVICE_DURATION_CHANGED':
                'Hizmet süresi değişti. İşletmeyle iletişime geçin.',
            'BOOKING_NOT_FOUND': 'Randevu bulunamadı.',
            'CATEGORY_NOT_AUTHORIZED': 'Bu hizmet kategorisi için işletme yetkiniz bulunmuyor.',
            'INVALID_PACKAGE': 'Paket yalnız tekil hizmetlerden oluşmalıdır.',
            'INVALID_COORDINATES': 'Geçerli enlem ve boylam bilgilerini birlikte girin.',
            'NOT_FOUND': 'Kayıt bulunamadı veya bu işletmeye ait değil.',
          }[code] ??
          'İşlem tamamlanamadı. Lütfen bilgileri kontrol edip tekrar deneyin.');
    }
    if (data is! Map) throw Exception('Sunucu yanıtı okunamadı.');
    return Map<String, dynamic>.from(data);
  }
}
