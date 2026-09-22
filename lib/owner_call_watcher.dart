import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'anonymous_call_api.dart';
import 'owner_call_page.dart';

class OwnerCallWatcher extends StatefulWidget {
  const OwnerCallWatcher({super.key, required this.child});
  final Widget child;

  @override
  State<OwnerCallWatcher> createState() => _OwnerCallWatcherState();
}

class _OwnerCallWatcherState extends State<OwnerCallWatcher> with WidgetsBindingObserver {
  String? activeCallId;
  bool checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(force: true);
  }

  Future<void> _check({bool force = false}) async {
    if (checking || !mounted) return;
    checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingId = prefs.getString('pending_incoming_call_id') ?? '';
      final call = await AnonymousCallApi.incoming();
      if (!mounted || call == null) return;
      final id = call['id']?.toString() ?? '';
      if (id.isEmpty || id == activeCallId) return;
      if (pendingId.isNotEmpty && pendingId != id && !force) return;
      final autoAcceptId = prefs.getString('pending_incoming_call_auto_accept') ?? '';
      var autoAccept = autoAcceptId == id;
      // When Android launches a terminated app after the native Accept button,
      // the Dart event can be emitted before our listener is attached. Recover
      // the accepted state from CallKit so we never show a second Accept screen.
      if (!autoAccept) {
        try {
          final active = await FlutterCallkitIncoming.activeCalls();
          for (final nativeCall in active) {
            if (nativeCall.id == id && nativeCall.isAccepted == true) {
              autoAccept = true;
              break;
            }
          }
        } catch (_) {}
      }
      await prefs.remove('pending_incoming_call_id');
      if (autoAccept) await prefs.remove('pending_incoming_call_auto_accept');
      activeCallId = id;
      await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => OwnerCallPage(call: call, autoAccept: autoAccept)));
      if (mounted) activeCallId = null;
    } catch (_) {
      // Next wake/poll retries.
    } finally {
      checking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
