import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import 'cepqar_theme.dart';
import 'owner_auth.dart';
import 'qr_backend.dart';

class NfcSetupPage extends StatefulWidget {
  const NfcSetupPage({
    super.key,
    required this.vehicleId,
    required this.plate,
  });

  final String vehicleId;
  final String plate;

  @override
  State<NfcSetupPage> createState() => _NfcSetupPageState();
}

class _NfcSetupPageState extends State<NfcSetupPage> {
  bool loading = true;
  bool writing = false;
  bool rotating = false;
  String? error;
  String nfcUrl = '';
  bool nfcEnabled = false;
  String? nfcWrittenAt;
  String? productId;

  Color get bg => CepqarTheme.bg;
  Color get panel => CepqarTheme.panel;
  Color get line => CepqarTheme.line;
  Color get text => CepqarTheme.text;
  Color get muted => CepqarTheme.muted;
  Color get purple => CepqarTheme.purple;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final r = await OwnerHttp.get(
        Uri.parse(
          '${QrBackend.baseUrl}/api/owner/vehicles/${Uri.encodeComponent(widget.vehicleId)}/touchpoints',
        ),
      ).timeout(const Duration(seconds: 15));
      final d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode != 200 || d is! Map) {
        throw Exception('NFC_CONFIG_FAILED_${r.statusCode}');
      }
      final product = d['product'] is Map
          ? Map<String, dynamic>.from(d['product'] as Map)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        productId = '${product['id'] ?? ''}';
        nfcUrl = '${product['nfcUrl'] ?? ''}';
        nfcEnabled = product['nfcEnabled'] == true;
        nfcWrittenAt = product['nfcWrittenAt']?.toString();
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'NFC bilgileri yüklenemedi.';
        });
      }
    }
  }

  NdefMessage _message(String url) {
    final bytes = Uint8List.fromList(utf8.encode(url));
    return NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.absoluteUri,
          type: bytes,
          identifier: Uint8List(0),
          payload: Uint8List(0),
        ),
      ],
    );
  }

  Future<void> _confirmWritten() async {
    final r = await OwnerHttp.post(
      Uri.parse(
        '${QrBackend.baseUrl}/api/owner/vehicles/${Uri.encodeComponent(widget.vehicleId)}/nfc/confirm',
      ),
      body: jsonEncode(const {}),
    ).timeout(const Duration(seconds: 15));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('NFC_CONFIRM_FAILED_${r.statusCode}');
    }
  }

  Future<void> writeNfc() async {
    if (writing || nfcUrl.isEmpty) return;
    if (kIsWeb) {
      _snack('NFC yazma işlemi Android veya iPhone uygulamasından yapılabilir.');
      return;
    }

    setState(() {
      writing = true;
      error = null;
    });

    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (availability != NfcAvailability.enabled) {
        throw Exception('NFC_DISABLED');
      }

      var finished = false;
      final message = _message(nfcUrl);

      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        alertMessageIos: 'CepQontag NFC etiketini telefona yaklaştırın.',
        onDiscovered: (tag) async {
          if (finished) return;
          try {
            if (defaultTargetPlatform == TargetPlatform.android) {
              final ndef = NdefAndroid.from(tag);
              if (ndef != null) {
                if (!ndef.isWritable) {
                  throw Exception('NFC_READ_ONLY');
                }
                if (ndef.maxSize < message.byteLength) {
                  throw Exception('NFC_TOO_SMALL');
                }
                await ndef.writeNdefMessage(message);
              } else {
                final formatable = NdefFormatableAndroid.from(tag);
                if (formatable == null) {
                  throw Exception('NFC_NOT_NDEF');
                }
                await formatable.format(message);
              }
            } else if (defaultTargetPlatform == TargetPlatform.iOS) {
              final ndef = NdefIos.from(tag);
              if (ndef == null) {
                throw Exception('NFC_NOT_NDEF');
              }
              await ndef.writeNdef(message);
            } else {
              throw Exception('NFC_PLATFORM_UNSUPPORTED');
            }

            await _confirmWritten();
            finished = true;
            await NfcManager.instance.stopSession(
              alertMessageIos: 'CepQontag NFC etiketi hazır.',
            );
            if (!mounted) return;
            setState(() {
              nfcEnabled = true;
              writing = false;
              nfcWrittenAt = DateTime.now().toIso8601String();
            });
            _snack('NFC etiketi başarıyla hazırlandı.');
          } catch (e) {
            finished = true;
            await NfcManager.instance.stopSession(
              errorMessageIos: _friendlyError(e),
            );
            if (!mounted) return;
            setState(() {
              writing = false;
              error = _friendlyError(e);
            });
          }
        },
      );
    } catch (e) {
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        writing = false;
        error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final value = e.toString();
    if (value.contains('NFC_DISABLED')) {
      return 'NFC kapalı veya bu telefonda desteklenmiyor.';
    }
    if (value.contains('NFC_READ_ONLY')) {
      return 'Bu NFC etiketi salt okunur; üzerine yazılamıyor.';
    }
    if (value.contains('NFC_TOO_SMALL')) {
      return 'Bu NFC etiketinin hafızası bağlantı için yetersiz.';
    }
    if (value.contains('NFC_NOT_NDEF')) {
      return 'Bu NFC etiketi uygun formatta değil.';
    }
    return 'NFC etiketi yazılamadı. Tekrar deneyin.';
  }

  Future<void> rotate() async {
    if (rotating) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: panel,
        title: Text(
          'NFC bağlantısını yenile',
          style: TextStyle(color: text, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Mevcut NFC bağlantısı devre dışı kalır. Etiketi yeni bağlantıyla tekrar yazmanız gerekir.',
          style: TextStyle(color: muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Yenile'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    setState(() => rotating = true);
    try {
      final r = await OwnerHttp.post(
        Uri.parse(
          '${QrBackend.baseUrl}/api/owner/vehicles/${Uri.encodeComponent(widget.vehicleId)}/nfc/rotate',
        ),
        body: jsonEncode(const {}),
      ).timeout(const Duration(seconds: 15));
      final d = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode != 200 || d is! Map) {
        throw Exception();
      }
      if (!mounted) return;
      setState(() {
        nfcUrl = '${d['nfcUrl'] ?? ''}';
        nfcEnabled = false;
        nfcWrittenAt = null;
        rotating = false;
      });
      _snack('NFC bağlantısı yenilendi. Etiketi tekrar yazın.');
    } catch (_) {
      if (mounted) {
        setState(() => rotating = false);
        _snack('NFC bağlantısı yenilenemedi.');
      }
    }
  }

  String _writtenText() {
    final d = DateTime.tryParse(nfcWrittenAt ?? '')?.toLocal();
    if (d == null) return 'Henüz etikete yazılmadı';
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.${d.year} • $hour:$minute';
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _statusCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: purple.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.nfc_rounded, color: purple, size: 27),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'NFC Etiketi',
                          style: TextStyle(
                            color: text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (nfcEnabled
                                  ? const Color(0xFF38D178)
                                  : const Color(0xFFFFB84D))
                              .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          nfcEnabled ? 'Aktif' : 'Hazır değil',
                          style: TextStyle(
                            color: nfcEnabled
                                ? const Color(0xFF38D178)
                                : const Color(0xFFFFA726),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _writtenText(),
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        title: const Text(
          'NFC Etiketi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: purple))
          : RefreshIndicator(
              onRefresh: load,
              color: purple,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Text(
                    widget.plate.isEmpty ? 'Seçili araç' : widget.plate,
                    style: TextStyle(
                      color: text,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'QR etiketiyle aynı araç iletişim sayfasını NFC üzerinden de açın.',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  _statusCard(),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nasıl çalışır?',
                          style: TextStyle(
                            color: text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        _step('1', 'Boş, yazılabilir bir NFC etiketi alın.'),
                        _step('2', 'Aşağıdaki butona basıp etiketi telefona yaklaştırın.'),
                        _step('3', 'CepQontag bağlantısı etikete yazılır ve aktif olur.'),
                        _step('4', 'Telefon etikete yaklaştırıldığında araç sayfanız açılır.'),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5364).withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFF5364).withValues(alpha: .25),
                        ),
                      ),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xFFFF5364),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: writing || nfcUrl.isEmpty ? null : writeNfc,
                      style: FilledButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: writing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.nfc_rounded),
                      label: Text(
                        writing
                            ? 'Etiketi telefona yaklaştırın...'
                            : nfcEnabled
                                ? 'NFC Etiketini Yeniden Yaz'
                                : 'NFC Etiketini Hazırla',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  TextButton.icon(
                    onPressed: rotating ? null : rotate,
                    icon: rotating
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('Güvenlik bağlantısını yenile'),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: purple.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security_rounded, color: purple, size: 19),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'NFC etiketi araç sahibinin telefon numarasını içermez. Yalnızca tekil CepQontag bağlantısı yazılır; gerektiğinde bağlantı uzaktan geçersiz kılınabilir.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 10.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _step(String no, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: purple.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Text(
                no,
                style: TextStyle(
                  color: purple,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  label,
                  style: TextStyle(color: muted, fontSize: 11.5, height: 1.3),
                ),
              ),
            ),
          ],
        ),
      );
}
