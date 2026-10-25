import 'dart:convert';
import 'package:http/http.dart' as http;

/// Production remains the default. Staging never falls back to production.
class AppEnvironment {
  static const name = String.fromEnvironment('APP_ENV', defaultValue: 'production');
  static const productionApi = 'https://heycar-api-185-165-46-213.nip.io';
  static const apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: productionApi);
  static const sshTunnel = bool.fromEnvironment('STAGING_SSH_TUNNEL');
  static const isStaging = name == 'staging';
  static String storageKey(String key) => isStaging ? 'staging:$key' : key;
  static void validate({String environment = name, String api = apiBase, bool tunnel = sshTunnel}) {
    if (!['production', 'staging'].contains(environment)) throw StateError('INVALID_APP_ENV');
    if (environment != 'staging') return;
    final uri = Uri.tryParse(api);
    if (uri == null || uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment || uri.path.isNotEmpty && uri.path != '/') throw StateError('INVALID_STAGING_API');
    final blocked = ['heycar-api-185-165-46-213.nip.io', 'cepqar.com', 'www.cepqar.com', 'cepqontag.com', 'www.cepqontag.com'];
    if (blocked.contains(uri.host.toLowerCase())) throw StateError('STAGING_PRODUCTION_API_FORBIDDEN');
    final privateTunnel = tunnel && uri.scheme == 'http' && ['127.0.0.1', '10.0.2.2'].contains(uri.host) && uri.port == 18091;
    if (!privateTunnel && (uri.scheme != 'https' || uri.host.isEmpty)) throw StateError('STAGING_HTTPS_REQUIRED');
  }
  static Future<void> verifyServer() async {
    validate();
    if (!isStaging) return;
    final response = await http.get(Uri.parse('$apiBase/api/environment')).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('STAGING_IDENTITY_UNAVAILABLE');
    final data = jsonDecode(response.body);
    if (data is! Map || data['environment'] != 'staging' || data['database'] != 'heycar_staging' || data['port'] != 8091 || data['externalServicesDisabled'] != true) throw StateError('STAGING_IDENTITY_MISMATCH');
  }
}
