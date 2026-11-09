import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/api_environment.dart';
import 'package:heycar_app/onboarding_backend.dart';
import 'package:heycar_app/qr_backend.dart';
import 'package:heycar_app/owner_login.dart';
import 'package:heycar_app/car_wash_api.dart';

void main() {
  test('owner auth, vehicles, QR and car wash share the selected API origin',
      () {
    expect(OnboardingBackend.baseUrl, apiBaseUrl);
    expect(QrBackend.baseUrl, apiBaseUrl);
    expect(OwnerLoginBackend.baseUrl, apiBaseUrl);
    expect(CarWashApi().baseUrl, apiBaseUrl);
    validateApiEnvironment();
    if (isStagingBuild) {
      expect(Uri.parse(apiBaseUrl).host, contains('staging'));
    } else {
      expect(apiBaseUrl, 'https://heycar-api-185-165-46-213.nip.io');
    }
  });
}
