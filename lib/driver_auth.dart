import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _driverApiBase = 'https://heycar-api-185-165-46-213.nip.io';

class DriverAuth {
  static String accessToken = '';
  static String refreshToken = '';

  static Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    accessToken = p.getString('driver_access_token') ?? '';
    refreshToken = p.getString('driver_refresh_token') ?? '';
  }

  static Future<void> saveFrom(Map data) async {
    accessToken = '${data['accessToken'] ?? ''}';
    refreshToken = '${data['refreshToken'] ?? ''}';
    final p = await SharedPreferences.getInstance();
    if (accessToken.isNotEmpty) await p.setString('driver_access_token', accessToken);
    if (refreshToken.isNotEmpty) await p.setString('driver_refresh_token', refreshToken);
  }

  static Future<void> clear() async {
    accessToken = '';
    refreshToken = '';
    final p = await SharedPreferences.getInstance();
    await p.remove('driver_access_token');
    await p.remove('driver_refresh_token');
  }

  static Future<bool> refresh() async {
    if (refreshToken.isEmpty) await restore();
    if (refreshToken.isEmpty) return false;
    try {
      final r = await http
          .post(
            Uri.parse('$_driverApiBase/api/driver/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) return false;
      final d = jsonDecode(r.body);
      if (d is! Map) return false;
      await saveFrom(d);
      return accessToken.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>> headers({bool json = true}) async {
    if (accessToken.isEmpty) await restore();
    return {
      if (json) 'Content-Type': 'application/json',
      if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
    };
  }

  static Future<void> logout() async {
    if (refreshToken.isEmpty) await restore();
    final token = refreshToken;
    try {
      if (token.isNotEmpty) {
        await http
            .post(
              Uri.parse('$_driverApiBase/api/driver/auth/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': token}),
            )
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {}
    await clear();
  }
}

class DriverHttp {
  static Future<http.Response> get(Uri u, {bool json = true, Map<String, String>? headers}) =>
      _send((h) => http.get(u, headers: {...h, ...?headers}), json: json);

  static Future<http.Response> delete(Uri u, {bool json = true, Map<String, String>? headers}) =>
      _send((h) => http.delete(u, headers: {...h, ...?headers}), json: json);

  static Future<http.Response> post(Uri u, {Object? body, bool json = true, Map<String, String>? headers}) =>
      _send((h) => http.post(u, headers: {...h, ...?headers}, body: body), json: json);

  static Future<http.Response> put(Uri u, {Object? body, bool json = true, Map<String, String>? headers}) =>
      _send((h) => http.put(u, headers: {...h, ...?headers}, body: body), json: json);

  static Future<http.Response> patch(Uri u, {Object? body, bool json = true, Map<String, String>? headers}) =>
      _send((h) => http.patch(u, headers: {...h, ...?headers}, body: body), json: json);

  static Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String>) fn, {
    bool json = true,
  }) async {
    var r = await fn(await DriverAuth.headers(json: json));
    if (r.statusCode == 401 && await DriverAuth.refresh()) {
      r = await fn(await DriverAuth.headers(json: json));
    }
    return r;
  }
}
