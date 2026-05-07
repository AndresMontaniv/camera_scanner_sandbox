import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_overlay.dart';
import 'scanner_screen.dart';

class PosBarcodeScannerScreen extends StatefulWidget {
  final void Function(String barcode, int qty) onScan;
  final List<BarcodeFormat> allowedFormats;
  final int detectionTimeoutMs;
  final int sameItemCooldownMs;
  final bool enableSoundAndVibration;
  final Offset? offsetFromCenter;
  final ScannerOverlayStyle? overlayStyle;

  const PosBarcodeScannerScreen({
    super.key,
    required this.onScan,
    this.allowedFormats = const <BarcodeFormat>[],
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.enableSoundAndVibration = true,
    this.offsetFromCenter,
    this.overlayStyle,
  });

  @override
  State<PosBarcodeScannerScreen> createState() => _PosBarcodeScannerScreenState();
}

class _PosBarcodeScannerScreenState extends State<PosBarcodeScannerScreen> {
  final ValueNotifier<int> qtyNotifier = ValueNotifier<int>(1);

  @override
  Widget build(BuildContext context) {
    return ScannerScreen.multiscan(
      toolBar: const BatchToolBar(),
      allowDuplicates: true,
      detectionTimeoutMs: widget.detectionTimeoutMs,
      sameItemCooldownMs: widget.sameItemCooldownMs,
      enableSoundAndVibration: widget.enableSoundAndVibration,
      scannerViewConfig: ScannerViewConfig.barcode(
        overlayStyle: widget.overlayStyle ?? const ScannerOverlayStyle(borderColor: Colors.blue),
        offsetFromCenter: widget.offsetFromCenter,
        allowedFormats: widget.allowedFormats,
      ),
      onCameraScan: (barcode) {
        final qty = qtyNotifier.value;
        widget.onScan(barcode, qty);
        // After scan reset qty to 1
        qtyNotifier.value = 1;
      },
      stackChildren: [
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 100,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<int>(
            valueListenable: qtyNotifier,
            builder: (context, qty, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleButton(
                    icon: Icons.remove,
                    onPressed: () {
                      if (qty > 1) qtyNotifier.value--;
                    },
                  ),
                  Text(
                    qty.toString(),
                    style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  _CircleButton(
                    icon: Icons.add,
                    onPressed: () {
                      qtyNotifier.value++;
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CircleButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white54,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: Colors.white,
          size: 35,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
