import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'qr_backend.dart';
import 'correction_request_page.dart';

const _bg = Color(0xFF07111F);
const _panel = Color(0xFF101A2F);
const _line = Color(0xFF33436A);
const _purple = Color(0xFF8B5CFF);
const _purple2 = Color(0xFF6D3EFF);
const _muted = Color(0xFFAAB4CF);

class RealQrScanPage extends StatefulWidget {
  const RealQrScanPage({super.key, required this.onFound, required this.onBack});
  final VoidCallback onFound;
  final VoidCallback onBack;

  @override
  State<RealQrScanPage> createState() => _RealQrScanPageState();
}

class _RealQrScanPageState extends State<RealQrScanPage> {
  final MobileScannerController scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final TextEditingController code = TextEditingController();
  bool manual = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    scanner.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _useToken(String raw) async {
    if (busy) return;
    final token = QrBackend.normalizeToken(raw);
    if (token.isEmpty || !QrBackend.isValidToken(token)) {
      setState(() => error = 'Geçerli bir Cepqar QR kodu gir.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await QrBackend.lookup(token);
      final status = data['status']?.toString();
      if (status == 'active') {
        throw Exception('Bu QR daha önce bir araca bağlanmış.');
      }
      if (status == 'disabled') {
        throw Exception('Bu QR etiketi devre dışı.');
      }
      QrDraft.token = token;
      await scanner.stop();
      if (mounted) widget.onFound();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (busy || manual) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _useToken(raw);
        return;
      }
    }
  }

  Future<void> _setManual(bool value) async {
    if (manual == value) return;
    setState(() {
      manual = value;
      error = null;
    });
    if (value) {
      await scanner.stop();
    } else {
      await scanner.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 820;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(22, compact ? 14 : 20, 22, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: const LinearProgressIndicator(
                      value: .72,
                      minHeight: 7,
                      backgroundColor: Color(0xFF34425B),
                      valueColor: AlwaysStoppedAnimation(_purple),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 22 : 32),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'QR etiketini ', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'okut', style: TextStyle(color: _purple)),
                ],
              ),
              style: TextStyle(
                fontSize: 34,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Kutudan çıkan QR etiketini kamerayla okut veya kod ile aktif et.',
              style: TextStyle(color: _muted, fontSize: 16, height: 1.45),
            ),
            const SizedBox(height: 22),
            _ModeSwitch(manual: manual, onChanged: _setManual),
            const SizedBox(height: 18),
            if (manual)
              _ManualPanel(
                code: code,
                busy: busy,
                onSubmit: () => _useToken(code.text),
                onCamera: () => _setManual(false),
              )
            else
              _ScannerPanel(
                controller: scanner,
                busy: busy,
                onDetect: _onDetect,
                onManual: () => _setManual(true),
              ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF351827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF7C2947)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFFF708D), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFFFA5B5), fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.manual, required this.onChanged});
  final bool manual;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF091425),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF7180A3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              active: !manual,
              icon: Icons.qr_code_2_rounded,
              label: 'QR okut',
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ModeButton(
              active: manual,
              icon: Icons.keyboard_alt_outlined,
              label: 'Kod ile aktif et',
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.active, required this.icon, required this.label, required this.onTap});
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: active ? const LinearGradient(colors: [_purple, _purple2]) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? Colors.white : const Color(0xFFD3D8E6), size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFFD3D8E6),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerPanel extends StatelessWidget {
  const _ScannerPanel({
    required this.controller,
    required this.busy,
    required this.onDetect,
    required this.onManual,
  });
  final MobileScannerController controller;
  final bool busy;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height < 820 ? 390.0 : 430.0;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: controller, onDetect: onDetect),
                Container(color: Colors.black.withValues(alpha: .22)),
                const Center(child: _ScanFrame()),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Material(
                    color: const Color(0xDD151B2D),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: controller.toggleTorch,
                      child: const SizedBox(
                        width: 58,
                        height: 58,
                        child: Icon(Icons.flashlight_on_outlined, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
                if (busy)
                  Container(
                    color: Colors.black.withValues(alpha: .35),
                    child: const Center(child: CircularProgressIndicator(color: _purple)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'QR’ı çerçeve içine al',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFD5CBFF),
            side: const BorderSide(color: Color(0xFF5A678D)),
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          onPressed: onManual,
          icon: const Icon(Icons.keyboard_alt_outlined),
          label: const Text('Kodu manuel gir', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(
        children: const [
          _Corner(alignment: Alignment.topLeft, turns: 0),
          _Corner(alignment: Alignment.topRight, turns: 1),
          _Corner(alignment: Alignment.bottomRight, turns: 2),
          _Corner(alignment: Alignment.bottomLeft, turns: 3),
          Center(
            child: SizedBox(
              width: 230,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _purple,
                  boxShadow: [BoxShadow(color: _purple, blurRadius: 10)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment, required this.turns});
  final Alignment alignment;
  final int turns;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: RotatedBox(
        quarterTurns: turns,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: _purple, width: 6),
              left: BorderSide(color: _purple, width: 6),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(14)),
          ),
        ),
      ),
    );
  }
}

class _ManualPanel extends StatelessWidget {
  const _ManualPanel({required this.code, required this.busy, required this.onSubmit, required this.onCamera});
  final TextEditingController code;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.keyboard_alt_outlined, color: _purple, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aktivasyon kodunu gir',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'QR etiketinin üzerindeki kodu aşağıya yaz.',
            style: TextStyle(color: _muted, fontSize: 14),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: 'CP-QAR-01',
              hintStyle: const TextStyle(color: Color(0xFF6F7891)),
              prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white70),
              filled: true,
              fillColor: const Color(0xFF0D172B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _purple, width: 1.5),
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: busy ? null : onSubmit,
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Kodu Aktif Et', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Kamerayla okutmaya dön'),
              style: TextButton.styleFrom(foregroundColor: _purple),
            ),
          ),
        ],
      ),
    );
  }
}

class RealQrConfirmPage extends StatefulWidget {
  const RealQrConfirmPage({super.key, required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<RealQrConfirmPage> createState() => _RealQrConfirmPageState();
}

class _RealQrConfirmPageState extends State<RealQrConfirmPage> {
  bool busy = false;
  String? error;

  Future<void> _activateQr() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await QrBackend.activate(
        token: QrDraft.token,
        vehicleId: QrDraft.vehicleId,
        plate: QrDraft.plate,
        make: QrDraft.make,
        model: QrDraft.model,
        ownerName: QrDraft.ownerName,
      );
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get canCreateCorrectionRequest =>
      error != null && (error!.contains('düzeltme talebi') || error!.contains('zaten bağlı'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 38),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'QR bulundu',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Bu etiketi oluşturduğun araca bağlamak istiyor musun?',
              style: TextStyle(color: _muted, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 28),
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _line),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 140, color: Colors.white),
                    const Positioned(
                      right: 14,
                      top: 14,
                      child: CircleAvatar(
                        radius: 23,
                        backgroundColor: _purple,
                        child: Icon(Icons.check_rounded, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      bottom: 14,
                      child: Text(
                        QrDraft.token,
                        style: const TextStyle(color: _muted, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _line),
              ),
              child: Column(
                children: [
                  _InfoRow(label: 'Etiket No', value: QrDraft.token),
                  const Divider(color: _line, height: 24),
                  _InfoRow(label: 'Araç', value: '${QrDraft.plate} • ${QrDraft.make} ${QrDraft.model}'.trim()),
                  const Divider(color: _line, height: 24),
                  const _InfoRow(label: 'Durum', value: 'Aktifleştirmeye hazır'),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(error!, style: const TextStyle(color: Color(0xFFFF8AA0), fontWeight: FontWeight.w700)),
              if (canCreateCorrectionRequest) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: _purple),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CorrectionRequestPage(
                          initialType: 'qr_change',
                          initialMessage: error ?? '',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Düzeltme talebi oluştur', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: busy ? null : _activateQr,
                child: busy
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Hesabıma bağla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
