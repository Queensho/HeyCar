/// Resolves a native notification's call ID to the exact ringing call.
///
/// Incoming-list endpoints select the newest call, which can be a different
/// one on busy accounts. The ID from CallKit is authoritative and looked up
/// using the user's authenticated, recipient-scoped status endpoint.
class IncomingCallNavigation {
  const IncomingCallNavigation._();

  /// The backend's call.vehicle_id is the QR-bound vehicle, not the
  /// vehicle currently selected on the user's home screen.
  /// Accept a notification plate only for the same vehicle (or older API
  /// records that do not contain vehicle_id); never use global QrDraft.
  static Map<String, dynamic> withVehicleIdentity({
    required Map<String, dynamic> call,
    required Map<String, dynamic> push,
  }) {
    String normalized(Object? value) => value?.toString().trim() ?? '';
    final serverVehicleId = normalized(call['vehicle_id'] ?? call['vehicleId']);
    final pushVehicleId = normalized(push['vehicleId'] ?? push['vehicle_id']);
    final serverPlate = normalized(call['plate']);
    final pushPlate = normalized(push['plate']);
    final sameVehicle = serverVehicleId.isEmpty ||
        (pushVehicleId.isNotEmpty && serverVehicleId == pushVehicleId);
    final plate = serverPlate.isNotEmpty
        ? serverPlate
        : (sameVehicle ? pushPlate : '');
    return <String, dynamic>{
      ...call,
      'vehicleId': serverVehicleId.isNotEmpty ? serverVehicleId : pushVehicleId,
      'plate': plate.toUpperCase(),
    };
  }

  static bool isRinging(Map<String, dynamic>? call) =>
      call != null &&
      (call['id']?.toString() ?? '').isNotEmpty &&
      call['status']?.toString() == 'ringing';

  static Future<Map<String, dynamic>?> resolve({
    required String expectedId,
    bool recoverAccepted = false,
    required Future<Map<String, dynamic>> Function(String) getById,
    required Future<Map<String, dynamic>?> Function() getIncoming,
  }) async {
    final id = expectedId.trim();
    if (id.isNotEmpty) {
      try {
        final exact = await getById(id);
        // Never substitute another caller if the notification specifies an ID.
        if (exact['id']?.toString() != id) return null;
        return isRinging(exact) || (recoverAccepted &&
            exact['status']?.toString() == 'accepted') ? exact : null;
      } catch (_) {
        // A temporarily unavailable specific status may still be found via
        // the older incoming endpoint, but ONLY with an exact ID match.
      }
    }
    final recent = await getIncoming();
    if (!isRinging(recent)) return null;
    if (id.isNotEmpty && recent!['id']?.toString() != id) return null;
    return recent;
  }
}
