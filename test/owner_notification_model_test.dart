import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/owner_notification_model.dart';

void main() {
  test(
      'single center filters QR, appointments and present/future service categories',
      () {
    final qr = {'type': 'message'},
        wash = {'type': 'service_booking', 'service_category': 'car_wash'},
        valet = {'type': 'service_booking', 'service_category': 'valet'},
        ppf = {'type': 'service_booking', 'service_category': 'ppf'},
        expert = {'type': 'service_booking', 'service_category': 'expertise'};
    expect(
        ownerNotificationFilters, ['Tümü', 'Araç', 'Randevular', 'Hizmetler']);
    for (final n in [qr, wash, valet, ppf, expert]) {
      expect(ownerNotificationMatches(n, 0), true);
    }
    expect(ownerNotificationMatches(qr, 1), true);
    expect(ownerNotificationMatches(qr, 2), false);
    for (final n in [wash, ppf, expert]) {
      expect(ownerNotificationMatches(n, 1), false);
      expect(ownerNotificationMatches(n, 2), true);
      expect(ownerNotificationMatches(n, 3), true);
    }
    expect(ownerNotificationMatches(valet, 2), false);
    expect(ownerNotificationMatches(valet, 3), true);
  });
}
