import 'dart:async';
import 'package:flutter/material.dart';
import 'anonymous_call_api.dart';
import 'owner_call_page.dart';

class OwnerCallWatcher extends StatefulWidget {
  const OwnerCallWatcher({super.key, required this.child});
  final Widget child;

  @override
  State<OwnerCallWatcher> createState() => _OwnerCallWatcherState();
}

class _OwnerCallWatcherState extends State<OwnerCallWatcher> {
  Timer? timer;
  String? activeCallId;
  bool checking = false;

  @override
  void initState() {
    super.initState();
    _check();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  Future<void> _check() async {
    if (checking || !mounted) return;
    checking = true;
    try {
      final call = await AnonymousCallApi.incoming();
      if (!mounted || call == null) return;
      final id = call['id']?.toString() ?? '';
      if (id.isEmpty || id == activeCallId) return;
      activeCallId = id;
      await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => OwnerCallPage(call: call)));
      if (mounted) activeCallId = null;
    } catch (_) {
      // Keep watcher silent; next poll retries.
    } finally {
      checking = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
