import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'anonymous_call_api.dart';

const _callBg = Color(0xFF07111F);
const _callPurple = Color(0xFF7C4DFF);
const _callMuted = Color(0xFFA7B0C7);

class PublicCallPage extends StatefulWidget {
  const PublicCallPage({super.key, required this.qrToken, required this.plate});
  final String qrToken;
  final String plate;

  @override
  State<PublicCallPage> createState() => _PublicCallPageState();
}

class _PublicCallPageState extends State<PublicCallPage> {
  RTCPeerConnection? peer;
  MediaStream? localStream;
  final remoteRenderer = RTCVideoRenderer();
  Timer? poller;
  String? callId;
  String? visitorToken;
  String status = 'preparing';
  String? error;
  bool muted = false;
  bool remoteSet = false;
  final Set<String> ownerCandidateKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await remoteRenderer.initialize();
      final created = await AnonymousCallApi.create(widget.qrToken);
      callId = created['id']?.toString();
      visitorToken = created['visitor_token']?.toString();
      if (callId == null || visitorToken == null) throw Exception('CALL_ID_MISSING');

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
      peer!.onIceCandidate = (candidate) {
        final id = callId;
        final visitor = visitorToken;
        if (candidate.candidate == null || id == null || visitor == null) return;
        AnonymousCallApi.publicSignal(id, visitor, candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }).catchError((_) {});
      };
      peer!.onTrack = (event) {
        if (event.streams.isNotEmpty) remoteRenderer.srcObject = event.streams.first;
      };
      final offer = await peer!.createOffer({'offerToReceiveAudio': 1});
      await peer!.setLocalDescription(offer);
      await AnonymousCallApi.publicSignal(callId!, visitorToken!, offer: {'sdp': offer.sdp, 'type': offer.type});
      if (mounted) setState(() => status = 'ringing');
      poller = Timer.periodic(const Duration(milliseconds: 1200), (_) => _poll());
    } catch (e) {
      if (mounted) setState(() { error = _friendly(e); status = 'failed'; });
    }
  }

  Future<void> _poll() async {
    final id = callId;
    final visitor = visitorToken;
    if (id == null || visitor == null) return;
    try {
      final call = await AnonymousCallApi.publicStatus(id, visitor);
      final next = call['status']?.toString() ?? status;
      final answer = call['answer'];
      if (!remoteSet && answer is Map && answer['sdp'] != null && answer['type'] != null) {
        await peer?.setRemoteDescription(RTCSessionDescription(answer['sdp']?.toString(), answer['type']?.toString()));
        remoteSet = true;
      }
      final candidates = call['owner_candidates'];
      if (candidates is List) {
        for (final raw in candidates.whereType<Map>()) {
          final key = '${raw['candidate']}|${raw['sdpMid']}|${raw['sdpMLineIndex']}';
          if (!ownerCandidateKeys.add(key) || raw['candidate'] == null) continue;
          await peer?.addCandidate(RTCIceCandidate(
            raw['candidate']?.toString(),
            raw['sdpMid']?.toString(),
            raw['sdpMLineIndex'] is int ? raw['sdpMLineIndex'] as int : int.tryParse('${raw['sdpMLineIndex']}'),
          ));
        }
      }
      if (mounted && next != status) setState(() => status = next);
      if (const {'rejected','missed','ended','cancelled'}.contains(next)) poller?.cancel();
    } catch (_) {}
  }

  String _friendly(Object e) {
    final value = e.toString();
    if (value.contains('OWNER_BUSY')) return 'Araç sahibi şu anda başka bir görüşmede.';
    if (value.toLowerCase().contains('permission')) return 'Mikrofon izni verilmedi.';
    return 'Arama başlatılamadı. Tekrar deneyin.';
  }

  Future<void> _hangup() async {
    poller?.cancel();
    final id = callId;
    final visitor = visitorToken;
    if (id != null && visitor != null && !const {'ended','rejected','missed','cancelled'}.contains(status)) {
      try { await AnonymousCallApi.publicSignal(id, visitor, action: 'cancel'); } catch (_) {}
    }
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
    for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    peer?.close();
    remoteRenderer.dispose();
    super.dispose();
  }

  String get title => switch (status) {
    'accepted' => 'Bağlandı',
    'rejected' => 'Arama reddedildi',
    'missed' => 'Cevap verilmedi',
    'ended' => 'Görüşme sona erdi',
    'cancelled' => 'Arama iptal edildi',
    'failed' => 'Bağlantı kurulamadı',
    'preparing' => 'Arama hazırlanıyor…',
    _ => 'Araç sahibi aranıyor…',
  };

  @override
  Widget build(BuildContext context) {
    final connected = status == 'accepted';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _hangup(); },
      child: Scaffold(
        backgroundColor: _callBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 34, 22, 28),
            child: Column(
              children: [
                const Text('HeyCar', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                const Spacer(),
                Container(width: 116, height: 116, decoration: const BoxDecoration(color: Color(0xFF1B2850), shape: BoxShape.circle), child: const Icon(Icons.directions_car_filled_rounded, color: _callPurple, size: 58)),
                const SizedBox(height: 24),
                Text(widget.plate, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _callMuted, fontSize: 17, fontWeight: FontWeight.w700)),
                if (error != null) ...[const SizedBox(height: 10), Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))],
                const SizedBox(height: 20),
                const Text('Telefon numaraları karşı tarafa gösterilmez.', style: TextStyle(color: _callMuted, fontSize: 13)),
                const Spacer(),
                if (connected)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _CircleAction(icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded, label: muted ? 'Sesi aç' : 'Sessiz', onTap: _toggleMute),
                    const SizedBox(width: 34),
                    _CircleAction(icon: Icons.call_end_rounded, label: 'Kapat', danger: true, onTap: _hangup),
                  ])
                else
                  _CircleAction(icon: Icons.call_end_rounded, label: 'İptal', danger: true, onTap: _hangup),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Column(children: [
    InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: 68, height: 68, decoration: BoxDecoration(color: danger ? const Color(0xFFE53935) : const Color(0xFF1B2850), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 30))),
    const SizedBox(height: 8),
    Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
  ]);
}
