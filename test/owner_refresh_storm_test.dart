import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/owner_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a late 401 reuses a newer stored access token instead of rotating refresh again', () async {
    SharedPreferences.setMockInitialValues({
      'owner_access_token': 'stale-access-token',
      'owner_refresh_token': 'private-refresh-token',
    });
    await OwnerAuth.restore();

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var rejectedOld = 0;
    var acceptedNew = 0;
    final listener = server.listen((request) async {
      final auth = request.headers.value(HttpHeaders.authorizationHeader);
      request.response.headers.contentType = ContentType.json;
      if (auth == 'Bearer stale-access-token') {
        rejectedOld++;
        final prefs = await SharedPreferences.getInstance();
        // Another request or tab has already finished a successful refresh.
        await prefs.setString('owner_access_token', 'newer-access-token');
        request.response.statusCode = 401;
        request.response.write('{"error":"AUTH_SESSION_REVOKED"}');
      } else if (auth == 'Bearer newer-access-token') {
        acceptedNew++;
        request.response.statusCode = 200;
        request.response.write('{"vehicles":[]}');
      } else {
        request.response.statusCode = 400;
        request.response.write('{"error":"UNEXPECTED_AUTHORIZATION"}');
      }
      await request.response.close();
    });

    try {
      final url = Uri.parse('http://127.0.0.1:${server.port}/api/owner/vehicles');
      final response = await OwnerHttp.get(url).timeout(const Duration(seconds: 8));
      expect(response.statusCode, 200);
      expect(rejectedOld, 1);
      expect(acceptedNew, 1);
      expect(OwnerAuth.accessToken, 'newer-access-token');
      // The refresh token must remain intact; no rotation was necessary.
      expect(OwnerAuth.refreshToken, 'private-refresh-token');
    } finally {
      await listener.cancel();
      await server.close(force: true);
      await OwnerAuth.clear();
    }
  });
}
