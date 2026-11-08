import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Reads only the code. The employee still confirms the customer's plate;
/// business authorization and all redemption checks remain on the backend.
class BusinessCodeScanner extends StatefulWidget {
  const BusinessCodeScanner({super.key});
  @override
  State<BusinessCodeScanner> createState() => _BusinessCodeScannerState();
}

class _BusinessCodeScannerState extends State<BusinessCodeScanner> {
  final controller = MobileScannerController();
  bool returned = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Kampanya QR kodunu okutun')),
      body: MobileScanner(
        controller: controller,
        errorBuilder: (context, error) => Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.no_photography_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                      'Kamera açılamadı. Kamera iznini kontrol edin veya kodu elle girin.',
                      textAlign: TextAlign.center),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Elle kod girişine dön')),
                ]))),
        onDetect: (capture) {
          if (returned) return;
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue?.trim() ?? '';
            if (RegExp(r'^(?:[A-Fa-f0-9]{8}|[A-Fa-f0-9]{32})$')
                .hasMatch(value)) {
              returned = true;
              Navigator.pop(context, value.toUpperCase());
              return;
            }
          }
        },
      ));
}
