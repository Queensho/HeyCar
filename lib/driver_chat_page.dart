import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF101A30);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFFA7B0C7);

class DriverChatPage extends StatefulWidget {
  const DriverChatPage({
    super.key,
    required this.userId,
    required this.notificationId,
    required this.plate,
  });

  final String userId;
  final String notificationId;
  final String plate;

  @override
  State<DriverChatPage> createState() => _DriverChatPageState();
}

class _DriverChatPageState extends State<DriverChatPage> {
  static const baseUrl = 'https://heycar-api-185-165-46-213.nip.io';
  final input = TextEditingController();
  final scroll = ScrollController();
  List<Map<String, dynamic>> messages = [];
  String? conversationId;
  String? error;
  bool loading = true;
  bool sending = false;
  Timer? timer;

  Map<String, String> get headers => {'x-user-id': widget.userId};

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _errorFor(int status) {
    if (status == 403) return 'Bu sohbete yalnızca araç sahibi seni aktif sürücü olarak seçtiğinde cevap verebilirsin.';
    if (status == 410) return 'Bu anonim sohbetin 30 dakikalık süresi doldu.';
    if (status == 404) return 'Bu bildirime ait sohbet bulunamadı.';
    return 'Sohbet açılamadı. Tekrar dene.';
  }

  Future<void> _resolve() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/driver/notifications/${Uri.encodeComponent(widget.notificationId)}/conversation'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        if (mounted) setState(() { loading = false; error = _errorFor(r.statusCode); });
        return;
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final id = data['conversationId']?.toString() ?? '';
      if (id.isEmpty) throw Exception('conversation_missing');
      conversationId = id;
      await _load();
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Sohbet açılamadı. Tekrar dene.'; });
    }
  }

  Future<void> _load({bool silent = false}) async {
    final id = conversationId;
    if (id == null || id.isEmpty) return;
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/driver/conversations/${Uri.encodeComponent(id)}'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        if (!silent && mounted) setState(() { loading = false; error = _errorFor(r.statusCode); });
        return;
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final list = data['messages'];
      final next = list is List
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      final changed = next.length != messages.length ||
          (next.isNotEmpty && messages.isNotEmpty && next.last['id']?.toString() != messages.last['id']?.toString());
      setState(() {
        messages = next;
        loading = false;
        error = null;
      });
      if (changed) _scrollToBottom();
    } catch (_) {
      if (!silent && mounted) setState(() { loading = false; error = 'Mesajlar yüklenemedi. Tekrar dene.'; });
    }
  }

  Future<void> _send() async {
    final id = conversationId;
    final text = input.text.trim();
    if (id == null || id.isEmpty || text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/api/driver/conversations/${Uri.encodeComponent(id)}/messages'),
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode({'message': text}),
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorFor(r.statusCode))));
        }
        return;
      }
      input.clear();
      await _load();
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesaj gönderilemedi. Tekrar dene.')));
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.plate.isEmpty ? 'Anonim Sohbet' : widget.plate, style: const TextStyle(fontWeight: FontWeight.w900)),
              const Text('Aktif sürücü olarak anonim cevap veriyorsun', style: TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: _muted, size: 44),
                          const SizedBox(height: 12),
                          Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.4)),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: _resolve,
                            style: FilledButton.styleFrom(backgroundColor: _purple),
                            child: const Text('Tekrar dene'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (_, i) {
                            final m = messages[i];
                            final mine = m['sender']?.toString() == 'driver';
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
                          child: Row(
                            children: [
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
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      );
}
