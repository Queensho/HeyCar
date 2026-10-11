/// Tracks visible VoIP screens so dashboard background polling can pause
/// during an incoming/ongoing call. No influence on call signaling or FCM.
class CallActivity {
  static int _visibleCount=0;
  static bool get isActive=>_visibleCount>0;
  static void opened(){_visibleCount++;}
  static void closed(){
    if(_visibleCount>0)_visibleCount--;
  }
}
