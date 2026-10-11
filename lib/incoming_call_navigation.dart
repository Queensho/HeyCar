/// Resolves a native notification's call ID to the exact ringing call.
///
/// Incoming-list endpoints select the newest call, which can be a different
/// one on busy accounts. The ID from CallKit is authoritative and looked up
/// using the user's authenticated, recipient-scoped status endpoint.
class IncomingCallNavigation {
  const IncomingCallNavigation._();

  static bool isRinging(Map<String, dynamic>? call) =>
      call != null &&
      (call['id']?.toString() ?? '').isNotEmpty &&
      call['status']?.toString() == 'ringing';

  static Future<Map<String, dynamic>?> resolve({
    required String expectedId,
    required Future<Map<String, dynamic>> Function(String) getById,
    required Future<Map<String, dynamic>?> Function() getIncoming,
  }) async {
    final id = expectedId.trim();
    if (id.isNotEmpty) {
      try {
        final exact = await getById(id);
        // Never substitute another caller if the notification specifies an ID.
        if (exact['id']?.toString() != id) return null;
        return isRinging(exact) ? exact : null;
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
