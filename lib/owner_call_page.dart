import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'anonymous_call_api.dart';

const _ownerCallBg = Color(0xFF07111F);
const _ownerCallPurple = Color(0xFF8B5CFF);
const _ownerCallMuted = Color(0xFFA7B0C7);

class OwnerCallPage extends StatefulWidget {
  const OwnerCallPage({super.key, required this.call, this.autoAccept = false});
  final Map<String, dynamic> call;
  final bool autoAccept;

  @override
  State<OwnerCallPage> createState() => _OwnerCallPageState();
}

class _OwnerCallPageState extends State<OwnerCallPage> {
  RTCPeerConnection? peer;
  MediaStream? localStream;
  final remoteRenderer = RTCVideoRenderer();
  Timer? poller;
  bool connected = false;
  bool busy = false;
  bool muted = false;
  bool closing = false;
  String? error;
  final Set<String> callerCandidateKeys = <String>{};

  String get callId => widget.call['id']?.toString() ?? '';
  String get plate => widget.call['plate']?.toString() ?? 'Araç';

  @override
  void initState() {
    super.initState();
    remoteRenderer.initialize();
    // Ringing calls must also be watched. Previously polling started only
    // after accept, so a caller cancelling left the accept/reject screen open.
    poller = Timer.periodic(const Duration(milliseconds: 700), (_) => _poll());
    Future.microtask(() async {
      await _poll();
      if (widget.autoAccept && mounted && !closing && !connected && !busy) {
        await _accept();
      }
    });
  }

  Future<void> _closeFromRemote() async {
    if (closing) return;
    closing = true;
    poller?.cancel();
    for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await peer?.close();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reject() async {
    if (busy || callId.isEmpty) return;
    setState(() => busy = true);
    try { await AnonymousCallApi.ownerSignal(callId, action: 'reject'); } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _accept() async {
    if (busy || callId.isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      final latest = await AnonymousCallApi.ownerStatus(callId);
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
      peer = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      });
      for (final track in localStream!.getTracks()) {
        await peer!.addTrack(track, localStream!);
      }
      peer!.onTrack = (event) {
        if (event.streams.isNotEmpty) remoteRenderer.srcObject = event.streams.first;
      };
      peer!.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        AnonymousCallApi.ownerSignal(callId, candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }).catchError((_) => <String, dynamic>{});
      };
      await peer!.setRemoteDescription(RTCSessionDescription(offer['sdp']?.toString(), offer['type']?.toString()));
      await _addCallerCandidates(latest['caller_candidates']);
      final answer = await peer!.createAnswer({'offerToReceiveAudio': 1});
      await peer!.setLocalDescription(answer);
      await AnonymousCallApi.ownerSignal(callId, action: 'accept', answer: {'sdp': answer.sdp, 'type': answer.type});
      if (mounted) setState(() { connected = true; busy = false; });
    } catch (e) {
      if (mounted && !closing) setState(() { error = e.toString().replaceFirst('Exception: ', ''); busy = false; });
    }
  }

  Future<void> _addCallerCandidates(dynamic candidates) async {
    if (candidates is! List) return;
    for (final raw in candidates.whereType<Map>()) {
      final key = '${raw['candidate']}|${raw['sdpMid']}|${raw['sdpMLineIndex']}';
      if (!callerCandidateKeys.add(key) || raw['candidate'] == null) continue;
      await peer?.addCandidate(RTCIceCandidate(
        raw['candidate']?.toString(),
        raw['sdpMid']?.toString(),
        raw['sdpMLineIndex'] is int ? raw['sdpMLineIndex'] as int : int.tryParse('${raw['sdpMLineIndex']}'),
      ));
    }
  }

  Future<void> _poll() async {
    if (closing || callId.isEmpty) return;
    try {
      final latest = await AnonymousCallApi.ownerStatus(callId);
      final status = latest['status']?.toString() ?? '';
      if (const {'ended','cancelled','missed','rejected'}.contains(status)) {
        await _closeFromRemote();
        return;
      }
      if (connected) await _addCallerCandidates(latest['caller_candidates']);
    } catch (_) {}
  }

  Future<void> _end() async {
    poller?.cancel();
    try { await AnonymousCallApi.ownerSignal(callId, action: 'end'); } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  void _toggleMute() {
    muted = !muted;
    for (final track in localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    poller?.cancel();
    for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) { track.stop(); }
    peer?.close();
    remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) connected ? _end() : _reject(); },
      child: Scaffold(
        backgroundColor: _ownerCallBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 34, 22, 28),
            child: Column(children: [
              const Text('Cepqar', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              const Spacer(),
              Container(width: 120, height: 120, decoration: const BoxDecoration(color: Color(0xFF1B2850), shape: BoxShape.circle), child: const Icon(Icons.phone_in_talk_rounded, color: _ownerCallPurple, size: 58)),
              const SizedBox(height: 24),
              Text(connected ? 'Anonim görüşme' : 'Cepqar araması', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('$plate aracınız için ${connected ? 'bağlandı' : 'gelen arama'}', textAlign: TextAlign.center, style: const TextStyle(color: _ownerCallMuted, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text('Arayan kişi telefon numaranızı göremez.', style: TextStyle(color: _ownerCallMuted, fontSize: 13)),
              if (error != null) ...[const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))],
              const Spacer(),
              if (!connected)
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _OwnerCallAction(icon: Icons.call_end_rounded, label: 'Reddet', danger: true, onTap: busy ? null : _reject),
                  _OwnerCallAction(icon: Icons.call_rounded, label: busy ? 'Bağlanıyor' : 'Kabul et', accept: true, onTap: busy ? null : _accept),
                ])
              else
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _OwnerCallAction(icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded, label: muted ? 'Sesi aç' : 'Sessiz', onTap: _toggleMute),
                  const SizedBox(width: 36),
                  _OwnerCallAction(icon: Icons.call_end_rounded, label: 'Kapat', danger: true, onTap: _end),
                ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _OwnerCallAction extends StatelessWidget {
  const _OwnerCallAction({required this.icon, required this.label, this.onTap, this.danger = false, this.accept = false});
  final IconData icon; final String label; final VoidCallback? onTap; final bool danger; final bool accept;
  @override
  Widget build(BuildContext context) => Column(children: [
    InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: 72, height: 72, decoration: BoxDecoration(color: danger ? const Color(0xFFE53935) : accept ? const Color(0xFF24B15A) : const Color(0xFF1B2850), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 32))),
    const SizedBox(height: 8),
    Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
  ]);
}
