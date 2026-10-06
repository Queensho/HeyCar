import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'anonymous_call_api.dart';

const _ownerCallBg = Color(0xFF070B22);
const _ownerCallPurple = Color(0xFF7C2CFF);
const _ownerCallPurple2 = Color(0xFF3D0C9E);
const _ownerCallMuted = Color(0xFFB5B5CA);
const _ownerCallGreen = Color(0xFF20E87A);

class OwnerCallPage extends StatefulWidget {
  const OwnerCallPage({super.key, required this.call, this.autoAccept = false, this.driverMode = false});
  final Map<String, dynamic> call;
  final bool autoAccept;
  final bool driverMode;

  @override
  State<OwnerCallPage> createState() => _OwnerCallPageState();
}

class _OwnerCallPageState extends State<OwnerCallPage> with SingleTickerProviderStateMixin {
  RTCPeerConnection? peer;
  MediaStream? localStream;
  final remoteRenderer = RTCVideoRenderer();
  Timer? poller;
  Timer? durationTimer;
  late final AnimationController pulseController;
  bool connected = false;
  bool busy = false;
  late bool nativeAccepted;
  bool muted = false;
  bool speakerOn = false;
  bool closing = false;
  String? error;
  int connectedSeconds = 0;
  final Set<String> callerCandidateKeys = <String>{};

  String get callId => widget.call['id']?.toString() ?? '';
  String get plate {
    final value = widget.call['plate']?.toString().trim() ?? '';
    return value.isEmpty ? 'Araç' : value;
  }
  String get vehicleName {
    final make = (widget.call['make'] ?? widget.call['brand'])?.toString().trim() ?? '';
    final model = widget.call['model']?.toString().trim() ?? '';
    return [make, model].where((e) => e.isNotEmpty).join(' ');
  }

  Future<Map<String, dynamic>> _status() =>
      widget.driverMode ? AnonymousCallApi.driverStatus(callId) : AnonymousCallApi.ownerStatus(callId);

  Future<Map<String, dynamic>> _signal({
    String? action,
    Map<String, dynamic>? answer,
    Map<String, dynamic>? candidate,
  }) => widget.driverMode
      ? AnonymousCallApi.driverSignal(callId, action: action, answer: answer, candidate: candidate)
      : AnonymousCallApi.ownerSignal(callId, action: action, answer: answer, candidate: candidate);

  @override
  void initState() {
    super.initState();
    nativeAccepted = widget.autoAccept;
    pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    remoteRenderer.initialize();
    poller = Timer.periodic(const Duration(milliseconds: 700), (_) => _poll());
    Future.microtask(() async {
      await _poll();
      if (widget.autoAccept && mounted && !closing && !connected && !busy) await _accept();
    });
  }

  Future<void> _clearNativeCall() async {
    if (callId.isEmpty) return;
    try { await FlutterCallkitIncoming.hideCallkitIncoming(CallKitParams(id: callId)); } catch (_) {}
    try { await FlutterCallkitIncoming.endCall(callId); } catch (_) {}
    try { await FlutterCallkitIncoming.endAllCalls(); } catch (_) {}
  }

  Future<void> _cleanupMedia() async {
    durationTimer?.cancel();
    for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) { track.stop(); }
    try { await peer?.close(); } catch (_) {}
  }

  Future<void> _closeFromRemote() async {
    if (closing) return;
    closing = true;
    poller?.cancel();
    await _cleanupMedia();
    await _clearNativeCall();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reject() async {
    if (busy || closing || callId.isEmpty) return;
    setState(() => busy = true);
    try { await _signal(action: 'reject'); } catch (_) {}
    await _clearNativeCall();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _accept() async {
    if (busy || closing || callId.isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      final latest = await _status();
      final currentStatus = latest['status']?.toString() ?? '';
      if (const {'ended','cancelled','missed','rejected'}.contains(currentStatus)) {
        await _closeFromRemote();
        return;
      }
      final offer = latest['offer'];
      if (offer is! Map || offer['sdp'] == null || offer['type'] == null) {
        throw Exception('Arama bağlantısı henüz hazır değil.');
      }
      localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      for (final track in localStream!.getAudioTracks()) { track.enabled = true; }
      try { await Helper.setSpeakerphoneOn(false); } catch (_) {}
      speakerOn = false;
      peer = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      });
      for (final track in localStream!.getTracks()) { await peer!.addTrack(track, localStream!); }
      peer!.onTrack = (event) {
        if (event.streams.isNotEmpty) remoteRenderer.srcObject = event.streams.first;
      };
      peer!.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        _signal(candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }).catchError((_) => <String, dynamic>{});
      };
      await peer!.setRemoteDescription(RTCSessionDescription(offer['sdp']?.toString(), offer['type']?.toString()));
      await _addCallerCandidates(latest['caller_candidates']);
      final answer = await peer!.createAnswer({'offerToReceiveAudio': 1});
      await peer!.setLocalDescription(answer);
      await _signal(action: 'accept', answer: {'sdp': answer.sdp, 'type': answer.type});
      try { await FlutterCallkitIncoming.setCallConnected(callId); } catch (_) {}
      try { await Helper.setSpeakerphoneOn(false); } catch (_) {}
      for (final track in localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) { track.enabled = true; }
      durationTimer?.cancel();
      durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && connected) setState(() => connectedSeconds++);
      });
      if (mounted) setState(() { connected = true; busy = false; nativeAccepted = false; });
    } catch (e) {
      if (mounted && !closing) setState(() { error = e.toString().replaceFirst('Exception: ', ''); busy = false; nativeAccepted = false; });
    }
  }

  Future<void> _addCallerCandidates(dynamic candidates) async {
    if (candidates is! List) return;
    for (final raw in candidates.whereType<Map>()) {
      final key = "${raw['candidate']}|${raw['sdpMid']}|${raw['sdpMLineIndex']}";
      if (!callerCandidateKeys.add(key) || raw['candidate'] == null) continue;
      await peer?.addCandidate(RTCIceCandidate(
        raw['candidate']?.toString(),
        raw['sdpMid']?.toString(),
        raw['sdpMLineIndex'] is int ? raw['sdpMLineIndex'] as int : int.tryParse("${raw['sdpMLineIndex']}"),
      ));
    }
  }

  Future<void> _poll() async {
    if (closing || callId.isEmpty) return;
    try {
      final latest = await _status();
      final status = latest['status']?.toString() ?? '';
      if (const {'ended','cancelled','missed','rejected'}.contains(status)) {
        await _closeFromRemote();
        return;
      }
      if (connected) await _addCallerCandidates(latest['caller_candidates']);
    } catch (_) {}
  }

  Future<void> _end() async {
    if (closing) return;
    closing = true;
    poller?.cancel();
    try { await _signal(action: 'end'); } catch (_) {}
    await _cleanupMedia();
    await _clearNativeCall();
    if (mounted) Navigator.pop(context);
  }

  void _toggleMute() {
    muted = !muted;
    for (final track in localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) { track.enabled = !muted; }
    if (mounted) setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    final next = !speakerOn;
    try {
      await Helper.setSpeakerphoneOn(next);
      if (mounted) setState(() => speakerOn = next);
    } catch (_) {
      if (mounted) setState(() => error = 'Ses çıkışı değiştirilemedi.');
    }
  }

  String get _duration {
    final m = (connectedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (connectedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    poller?.cancel();
    durationTimer?.cancel();
    pulseController.dispose();
    for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) { track.stop(); }
    peer?.close();
    remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _ownerCallBg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) { if (!didPop) connected ? _end() : _reject(); },
        child: Scaffold(
          backgroundColor: _ownerCallBg,
          body: Stack(children: [
            const Positioned.fill(child: _CallBackground()),
            SafeArea(
              child: LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxHeight < 700;
                return Padding(
                  padding: EdgeInsets.fromLTRB(22, compact ? 14 : 24, 22, compact ? 14 : 22),
                  child: Column(children: [
                    Image.asset('assets/Logoyeni.png', height: compact ? 42 : 52, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text('CepQontag', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900))),
                    const Spacer(),
                    _PulseAvatar(controller: pulseController, active: !connected),
                    SizedBox(height: compact ? 14 : 22),
                    if (!connected) const _IncomingPill(),
                    if (!connected) SizedBox(height: compact ? 14 : 22),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(plate, maxLines: 1, style: TextStyle(color: Colors.white, fontSize: compact ? 38 : 48, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    ),
                    if (vehicleName.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(vehicleName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: compact ? 21 : 25, fontWeight: FontWeight.w500)),
                    ],
                    if (connected) ...[
                      const SizedBox(height: 14),
                      Text(_duration, style: const TextStyle(color: _ownerCallGreen, fontSize: 19, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                    ] else ...[
                      SizedBox(height: compact ? 16 : 24),
                      const _PrivacyCard(),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFFF808A), fontWeight: FontWeight.w600)),
                    ],
                    const Spacer(),
                    if (!connected && (nativeAccepted || busy))
                      const Column(children: [
                        SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: _ownerCallGreen)),
                        SizedBox(height: 10),
                        Text('Kabul ediliyor…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ])
                    else if (!connected)
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _CallAction(icon: Icons.call_end_rounded, label: 'Reddet', color: const Color(0xFFFF3F4A), onTap: _reject, semantics: 'Gelen çağrıyı reddet'),
                        _CallAction(icon: Icons.call_rounded, label: 'Kabul Et', color: const Color(0xFF18D968), onTap: _accept, semantics: 'Gelen çağrıyı kabul et'),
                      ])
                    else
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _CallAction(icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded, label: muted ? 'Sessizde' : 'Mikrofon', color: const Color(0xFF24144D), outlined: true, onTap: _toggleMute, semantics: muted ? 'Mikrofonu aç' : 'Mikrofonu sessize al'),
                        _CallAction(icon: speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded, label: 'Hoparlör', color: speakerOn ? _ownerCallPurple : const Color(0xFF24144D), outlined: true, onTap: _toggleSpeaker, semantics: speakerOn ? 'Hoparlörü kapat' : 'Hoparlörü aç'),
                        _CallAction(icon: Icons.call_end_rounded, label: 'Kapat', color: const Color(0xFFFF3F4A), onTap: _end, semantics: 'Görüşmeyi kapat'),
                      ]),
                    SizedBox(height: compact ? 4 : 10),
                  ]),
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CallBackground extends StatelessWidget {
  const _CallBackground();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF071126), Color(0xFF100A35), Color(0xFF25056A)]),
    ),
    child: CustomPaint(painter: _BackgroundPainter()),
  );
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..shader = RadialGradient(colors: [const Color(0xFF7C2CFF).withValues(alpha: .18), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(size.width * .5, size.height * .34), radius: size.width * .62));
    canvas.drawCircle(Offset(size.width * .5, size.height * .34), size.width * .62, glow);
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = const Color(0xFF8B5CFF).withValues(alpha: .075);
    for (final r in [size.width * .29, size.width * .42, size.width * .56]) {
      canvas.drawCircle(Offset(size.width * .5, size.height * .34), r, ring);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulseAvatar extends StatelessWidget {
  const _PulseAvatar({required this.controller, required this.active});
  final AnimationController controller;
  final bool active;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190, height: 190,
    child: AnimatedBuilder(animation: controller, builder: (context, _) {
      Widget ring(double phase) {
        final t = active ? (controller.value + phase) % 1.0 : 0.0;
        return Transform.scale(
          scale: active ? .75 + .48 * t : .82,
          child: Opacity(
            opacity: active ? (.25 * (1 - t)).clamp(0.0, 1.0) : .08,
            child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _ownerCallPurple, width: 2))),
          ),
        );
      }
      return Stack(alignment: Alignment.center, children: [
        ring(0), ring(.34), ring(.67),
        Container(
          width: 112, height: 112,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF8F6FF), boxShadow: [BoxShadow(color: _ownerCallPurple.withValues(alpha: .35), blurRadius: 30, spreadRadius: 5)]),
          child: const Icon(Icons.qr_code_2_rounded, color: _ownerCallPurple, size: 66),
        ),
      ]);
    }),
  );
}

class _IncomingPill extends StatelessWidget {
  const _IncomingPill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    decoration: BoxDecoration(color: const Color(0xFF071B18).withValues(alpha: .72), borderRadius: BorderRadius.circular(30), border: Border.all(color: _ownerCallGreen, width: 1.5)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 9, height: 9, child: DecoratedBox(decoration: BoxDecoration(color: _ownerCallGreen, shape: BoxShape.circle))),
      SizedBox(width: 9),
      Text('Araçtan Gelen Çağrı', style: TextStyle(color: _ownerCallGreen, fontWeight: FontWeight.w800, fontSize: 15)),
    ]),
  );
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 360),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(color: const Color(0xFF19143B).withValues(alpha: .72), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: .08))),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 22, backgroundColor: Color(0xFF2A1C58), child: Icon(Icons.lock_rounded, color: Colors.white, size: 22)),
        SizedBox(width: 13),
        Flexible(child: Text('Telefon numaranız\nkarşı tarafa gösterilmez.', style: TextStyle(color: Colors.white, height: 1.35, fontSize: 14))),
      ]),
    ),
  );
}

class _CallAction extends StatelessWidget {
  const _CallAction({required this.icon, required this.label, required this.color, required this.onTap, required this.semantics, this.outlined = false});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String semantics;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true, label: semantics, enabled: onTap != null,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedOpacity(
          opacity: onTap == null ? .5 : 1,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: outlined ? Border.all(color: _ownerCallPurple.withValues(alpha: .7), width: 1.5) : null,
              boxShadow: [BoxShadow(color: color.withValues(alpha: .24), blurRadius: 24, spreadRadius: 2)],
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
      ),
      const SizedBox(height: 9),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
    ]),
  );
}
