import 'dart:async';
import 'package:flutter/material.dart';
import 'public_notification_api.dart';

const _bg = Color(0xFF07101F);
const _panel = Color(0xFF101A31);
const _purple = Color(0xFF7C4DFF);
const _lime = Color(0xFFB6FF2A);
const _muted = Color(0xFFAAB3C8);

class GuestChatPage extends StatefulWidget {
  const GuestChatPage({super.key, required this.conversationId});
  final String conversationId;

  @override
  State<GuestChatPage> createState() => _GuestChatPageState();
}

class _GuestChatPageState extends State<GuestChatPage> {
  final input = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  bool loading = true;
  bool sending = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final data = await PublicNotificationApi.fetchConversation(widget.conversationId);
      if (mounted) setState(() { messages = data; loading = false; });
    } catch (_) {
      if (!silent && mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await PublicNotificationApi.sendChatMessage(widget.conversationId, text);
      input.clear();
      await _load();
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
          centerTitle: true,
          title: const Column(children: [
            Text('Araç Sahibi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text('Anonim sohbet', style: TextStyle(color: _muted, fontSize: 11)),
          ]),
        ),
        body: Column(children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
            child: const Row(children: [
              Icon(Icons.shield_rounded, color: _lime, size: 20),
              SizedBox(width: 9),
              Expanded(child: Text('Telefon numarası ve kimlik bilgileri karşılıklı olarak gizli kalır.', style: TextStyle(color: _muted, fontSize: 12.5, height: 1.3))),
            ]),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: _lime))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      final mine = m['sender']?.toString() == 'guest';
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
              color: const Color(0xFF0C1528),
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
                  style: IconButton.styleFrom(backgroundColor: _lime, foregroundColor: Colors.black),
                  icon: sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                ),
              ]),
            ),
          ),
        ]),
      );
}
