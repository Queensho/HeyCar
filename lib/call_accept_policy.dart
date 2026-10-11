/// A just-validated incoming call is already scoped to the signed-in owner
/// or driver and includes the WebRTC offer. Avoid a redundant /status fetch
/// on Accept, but never reuse a closed, accepted or incomplete call snapshot.
class CallAcceptPolicy {
  static bool hasReadyRingingOffer(Map<String, dynamic> call) {
    if(call['status']?.toString()!='ringing')return false;
    final offer=call['offer'];
    return offer is Map &&
        offer['sdp']?.toString().isNotEmpty==true &&
        offer['type']?.toString().isNotEmpty==true;
  }
}
