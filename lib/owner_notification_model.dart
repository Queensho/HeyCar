const ownerNotificationFilters = ['Tümü', 'Araç', 'Randevular', 'Hizmetler'];
bool isServiceNotification(Map<String, dynamic> n) =>
    n['type'] == 'service_booking' ||
    n['type'] == 'car_wash' ||
    '${n['type']}'.startsWith('valet_');
bool ownerNotificationMatches(Map<String, dynamic> n, int filter) {
  if (filter == 0) return true;
  final service = isServiceNotification(n);
  if (filter == 1)
    return !service &&
        const [
          'message',
          'call_request',
          'move_vehicle',
          'lights_on',
          'damage',
          'vehicle_added',
          'maintenance',
          'maintenance_reminder',
          'vehicle_reminder'
        ].contains(n['type']);
  if (filter == 2)
    return service &&
        (n['service_category'] ?? n['serviceCategory']) != 'valet';
  return service;
}
