import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'correction_request_page.dart';
import 'qr_backend.dart';

const _bg = Color(0xFFFDFDFF);
const _panel = Colors.white;
const _soft = Color(0xFFF7F5FC);
const _line = Color(0xFFE5E7EF);
const _purple = Color(0xFF5E24F5);
const _purple2 = Color(0xFF7A35FF);
const _text = Color(0xFF090B18);
const _muted = Color(0xFF747A8D);

class RealQrScanPage extends StatefulWidget {
  const RealQrScanPage({
    super.key,
    required this.onFound,
    required this.onBack,
  });

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
      setState(() => error = 'Geçerli bir CepQontag QR kodu gir.');
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
        setState(
          () => error = e.toString().replaceFirst('Exception: ', ''),
        );
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
    final compact = MediaQuery.sizeOf(context).height < 760;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                compact ? 10 : 14,
                20,
                28,
              ),
              children: [
                _OnboardingStepHeader(
                  onBack: widget.onBack,
                  progress: 1,
                  stepText: '3/3',
                ),
                const SizedBox(height: 9),
                const _StageTrail(active: 3),
                SizedBox(height: compact ? 14 : 18),
                Row(
                  children: [
                    Image.asset(
                      'assets/file_00000000b130820abb8d411e67ab0d25.png',
                      height: compact ? 28 : 30,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E8FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'QR ETİKET',
                        style: TextStyle(
                          color: _purple,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 15 : 18),
                Text.rich(
                  TextSpan(
                    children: const [
                      TextSpan(
                        text: 'QR etiketini ',
                        style: TextStyle(color: _text),
                      ),
                      TextSpan(
                        text: 'bağla',
                        style: TextStyle(color: _purple),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 25,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Kutudan çıkan etiketi kamerayla okut veya üzerindeki aktivasyon kodunu gir.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 15),
                _ModeSwitch(
                  manual: manual,
                  onChanged: _setManual,
                ),
                const SizedBox(height: 13),
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
                  const SizedBox(height: 12),
                  _ErrorBox(text: error!),
                ],
                const SizedBox(height: 14),
                const _NextHint(
                  text:
                      'Sonraki: QR bilgilerini kontrol edip araca bağlamayı onayla.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingStepHeader extends StatelessWidget {
  const _OnboardingStepHeader({
    required this.onBack,
    required this.progress,
    required this.stepText,
  });

  final VoidCallback onBack;
  final double progress;
  final String stepText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _line),
            ),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: _text,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE9E3F7),
              valueColor: const AlwaysStoppedAnimation(_purple),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          stepText,
          style: const TextStyle(
            color: _text,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _StageTrail extends StatelessWidget {
  const _StageTrail({required this.active});
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StageItem(
          index: 1,
          label: 'Hesap',
          done: active > 1,
          active: active == 1,
        ),
        const _StageLine(),
        _StageItem(
          index: 2,
          label: 'Araç',
          done: active > 2,
          active: active == 2,
        ),
        const _StageLine(),
        _StageItem(
          index: 3,
          label: 'QR Etiket',
          done: active > 3,
          active: active == 3,
        ),
      ],
    );
  }
}

class _StageItem extends StatelessWidget {
  const _StageItem({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final selected = done || active;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _purple : const Color(0xFFF0EDF7),
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 12,
                )
              : Text(
                  '$index',
                  style: TextStyle(
                    color: active ? Colors.white : _muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: active ? _text : _muted,
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StageLine extends StatelessWidget {
  const _StageLine();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: _line,
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.manual,
    required this.onChanged,
  });

  final bool manual;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FA),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _line),
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
              label: 'Kod ile bağla',
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: active
                ? const LinearGradient(
                    colors: [_purple, _purple2],
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? Colors.white : _muted,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : _muted,
                  fontSize: 11.5,
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
    final compact = MediaQuery.sizeOf(context).height < 760;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: compact ? 300 : 340,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: onDetect,
                  ),
                  Container(
                    color: Colors.black.withValues(alpha: .18),
                  ),
                  const Center(
                    child: _ScanFrame(),
                  ),
                  Positioned(
                    right: 11,
                    bottom: 11,
                    child: Material(
                      color: const Color(0xD91A1E2C),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: controller.toggleTorch,
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.flashlight_on_outlined,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (busy)
                    Container(
                      color: Colors.black.withValues(alpha: .35),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: _purple,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'QR kodunu çerçevenin içine getir',
            style: TextStyle(
              color: _text,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: onManual,
              style: OutlinedButton.styleFrom(
                foregroundColor: _purple,
                side: const BorderSide(
                  color: Color(0xFFD8CDFB),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.keyboard_alt_outlined,
                size: 18,
              ),
              label: const Text(
                'Kodu manuel gir',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        children: const [
          _Corner(
            alignment: Alignment.topLeft,
            turns: 0,
          ),
          _Corner(
            alignment: Alignment.topRight,
            turns: 1,
          ),
          _Corner(
            alignment: Alignment.bottomRight,
            turns: 2,
          ),
          _Corner(
            alignment: Alignment.bottomLeft,
            turns: 3,
          ),
          Center(
            child: SizedBox(
              width: 210,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _purple,
                  boxShadow: [
                    BoxShadow(
                      color: _purple,
                      blurRadius: 10,
                    ),
                  ],
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
  const _Corner({
    required this.alignment,
    required this.turns,
  });

  final Alignment alignment;
  final int turns;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: RotatedBox(
        quarterTurns: turns,
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: _purple,
                width: 5,
              ),
              left: BorderSide(
                color: _purple,
                width: 5,
              ),
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(13),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualPanel extends StatelessWidget {
  const _ManualPanel({
    required this.code,
    required this.busy,
    required this.onSubmit,
    required this.onCamera,
  });

  final TextEditingController code;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.keyboard_alt_outlined,
                color: _purple,
                size: 22,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Aktivasyon kodunu gir',
                  style: TextStyle(
                    color: _text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Etiketin üzerinde yazan kodu eksiksiz gir.',
            style: TextStyle(
              color: _muted,
              fontSize: 10.5.5,
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
            decoration: InputDecoration(
              hintText: 'CP-QONTAG-XXXX',
              hintStyle: const TextStyle(
                color: Color(0xFF9AA0AF),
              ),
              prefixIcon: const Icon(
                Icons.qr_code_scanner_rounded,
                color: _purple,
                size: 18,
              ),
              filled: true,
              fillColor: const Color(0xFFF9F8FC),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: _purple,
                  width: 1.5,
                ),
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: busy ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    _purple.withValues(alpha: .55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Kodu Kontrol Et',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 7),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 5),
          Center(
            child: TextButton.icon(
              onPressed: onCamera,
              icon: const Icon(
                Icons.qr_code_2_rounded,
                size: 17,
              ),
              label: const Text(
                'Kamerayla okutmaya dön',
              ),
              style: TextButton.styleFrom(
                foregroundColor: _purple,
                textStyle: const TextStyle(
                  fontSize: 10.5.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD1D8),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFD63B55),
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFB62842),
                fontSize: 10.5.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextHint extends StatelessWidget {
  const _NextHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE7E0FA),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.arrow_forward_rounded,
            color: _purple,
            size: 16,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RealQrConfirmPage extends StatefulWidget {
  const RealQrConfirmPage({
    super.key,
    required this.onDone,
    required this.onBack,
  });

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
        setState(
          () => error = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get canCreateCorrectionRequest =>
      error != null &&
      (error!.contains('düzeltme talebi') ||
          error!.contains('zaten bağlı'));

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                28,
              ),
              children: [
                _OnboardingStepHeader(
                  onBack: widget.onBack,
                  progress: 1,
                  stepText: '3/3',
                ),
                const SizedBox(height: 9),
                const _StageTrail(active: 3),
                SizedBox(height: compact ? 15 : 18),
                const Text(
                  'QR bulundu',
                  style: TextStyle(
                    color: _text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Etiket bilgilerini kontrol et ve oluşturduğun araca bağlamayı onayla.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: compact ? 150 : 170,
                    height: compact ? 150 : 170,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3FF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFD9CCFF),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          size: 106,
                          color: _purple,
                        ),
                        const Positioned(
                          right: 9,
                          top: 9,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: _purple,
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Etiket No',
                        value: QrDraft.token,
                      ),
                      const Divider(
                        color: _line,
                        height: 20,
                      ),
                      _InfoRow(
                        label: 'Araç',
                        value:
                            '${QrDraft.plate} • ${QrDraft.make} ${QrDraft.model}'
                                .trim(),
                      ),
                      const Divider(
                        color: _line,
                        height: 20,
                      ),
                      const _InfoRow(
                        label: 'Durum',
                        value: 'Bağlanmaya hazır',
                        success: true,
                      ),
                    ],
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(text: error!),
                  if (canCreateCorrectionRequest) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CorrectionRequestPage(
                              initialType: 'qr_change',
                              initialMessage: error ?? '',
                            ),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _purple,
                          side: const BorderSide(
                            color: Color(0xFFD8CDFB),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.support_agent_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Düzeltme talebi oluştur',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 15),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: busy ? null : _activateQr,
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          _purple.withValues(alpha: .55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 19,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'QR Etiketini Araca Bağla',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 11),
                const _NextHint(
                  text:
                      'Sonraki: Etiketi araca doğru şekilde yerleştir ve kurulumu tamamla.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.success = false,
  });

  final String label;
  final String value;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 10.5.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: success
                  ? const Color(0xFF24A457)
                  : _text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
