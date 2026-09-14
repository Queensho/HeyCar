import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF101A30);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFFA7B0C7);

class OwnerChatPage extends StatefulWidget {
  const OwnerChatPage({super.key, required this.notificationId, required this.plate});
  final String notificationId;
  final String plate;

  @override
  State<OwnerChatPage> createState() => _OwnerChatPageState();
}

class _OwnerChatPageState extends State<OwnerChatPage> {
  static const baseUrl = 'https://heycar-api-185-165-46-213.nip.io';
  final input = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  String? conversationId;
  bool loading = true;
  bool sending = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final ownerId = OnboardingDraft.userId.trim();
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/owner/notifications/${Uri.encodeComponent(widget.notificationId)}/conversation'),
        headers: {'x-owner-id': ownerId},
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      conversationId = data['conversationId']?.toString();
      await _load();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _load({bool silent = false}) async {
    final id = conversationId;
    if (id == null || id.isEmpty) return;
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/owner/conversations/${Uri.encodeComponent(id)}'),
        headers: {'x-owner-id': OnboardingDraft.userId.trim()},
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final list = data['messages'];
      if (r.statusCode >= 200 && r.statusCode < 300 && list is List && mounted) {
        setState(() {
          messages = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          loading = false;
        });
      }
    } catch (_) {
      if (!silent && mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final id = conversationId;
    final text = input.text.trim();
    if (id == null || id.isEmpty || text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/owner/conversations/${Uri.encodeComponent(id)}/messages'),
        headers: {'Content-Type': 'application/json', 'x-owner-id': OnboardingDraft.userId.trim()},
        body: jsonEncode({'message': text}),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        input.clear();
        await _load();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.plate.isEmpty ? 'Anonim Sohbet' : widget.plate, style: const TextStyle(fontWeight: FontWeight.w900)),
            const Text('Kimlik bilgileri karşılıklı gizlidir', style: TextStyle(color: _muted, fontSize: 11)),
          ]),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : conversationId == null
                ? const Center(child: Text('Bu bildirim için sohbet bulunamadı.', style: TextStyle(color: _muted)))
                : Column(children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final m = messages[i];
                          final mine = m['sender']?.toString() == 'owner';
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: mine ? _purple : _panel,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(mine ? 18 : 4),
                                  bottomRight: Radius.circular(mine ? 4 : 18),
                                ),
                              ),
                              child: Text(m['message']?.toString() ?? '', style: const TextStyle(color: Colors.white, height: 1.3)),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        color: const Color(0xFF0B1426),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: input,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Mesaj yaz...',
                                hintStyle: const TextStyle(color: _muted),
                                filled: true,
                                fillColor: _panel,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: sending ? null : _send,
                            style: IconButton.styleFrom(backgroundColor: _purple),
                            icon: sending
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send_rounded),
                          ),
                        ]),
                      ),
                    ),
                  ]),
      );
}
