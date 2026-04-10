import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'circle_button.dart';
import 'flash_toggle_button.dart';
import 'scanner_overlay.dart';
import 'scanner_error_widget.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool showQtyControls;
  final bool showFlashButton;
  final int detectionTimeoutMs;
  final int sameItemCooldownMs;
  final ScannerOverlayStyle? style;
  final void Function(String barcode, int qty)? onCameraScan;

  const BarcodeScannerScreen({
    super.key,
    this.style,
    this.onCameraScan,
    this.showQtyControls = true,
    this.showFlashButton = false,
    this.sameItemCooldownMs = 1500,
    this.detectionTimeoutMs = 250,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with WidgetsBindingObserver {
  late MobileScannerController controller;
  StreamSubscription<BarcodeCapture>? _subscription;

  final ValueNotifier<int> qtyNotifier = ValueNotifier<int>(1);
  final ValueNotifier<int> totalItemsNotifier = ValueNotifier<int>(0);

  String? _lastScannedCode;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    controller = MobileScannerController(
      detectionTimeoutMs: widget.detectionTimeoutMs,
      detectionSpeed: DetectionSpeed.normal,
      torchEnabled: false,
      formats: [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
    _subscribeToBarcodes();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Release native camera resources when not in foreground.
        _subscription?.pause();
        controller.stop();
        break;
      case AppLifecycleState.resumed:
        // Re-acquire camera and resume the barcode stream.
        controller.start();
        _subscription?.resume();
        break;
    }
  }

  void _subscribeToBarcodes() {
    _subscription = controller.barcodes.listen((capture) {
      if (capture.barcodes.isEmpty) return;

      final rawValue = capture.barcodes.first.rawValue;
      if (rawValue == null) return;

      if (rawValue == _lastScannedCode && _lastScanTime != null) {
        final elapsed = DateTime.now().difference(_lastScanTime!).inMilliseconds;
        if (elapsed < widget.sameItemCooldownMs) return;
      }

      _lastScannedCode = rawValue;
      _lastScanTime = DateTime.now();

      unawaited(HapticFeedback.heavyImpact());

      _addScannedItem(rawValue);
    });
  }

  void _addScannedItem(String barcode) {
    widget.onCameraScan?.call(barcode, qtyNotifier.value);
    totalItemsNotifier.value += qtyNotifier.value;
    qtyNotifier.value = 1;
  }

  void _popBack() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    controller.dispose();
    qtyNotifier.dispose();
    totalItemsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(const Offset(0, -80.0)),
      width: 280,
      height: 130,
    );
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            fit: BoxFit.cover,
            scanWindow: scanWindow,
            controller: controller,
            scanWindowUpdateThreshold: 0.0,
            errorBuilder: (_, error) => ScannerErrorWidget(error: error),
            overlayBuilder: (_, constraints) => ScannerOverlay(
              constraints: constraints,
              scanWindow: scanWindow,
            ),
          ),

          if (widget.showQtyControls)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<int>(
                valueListenable: qtyNotifier,
                builder: (context, qty, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CircleButton(
                        icon: Icons.remove,
                        onPressed: () {
                          if (qty > 1) qtyNotifier.value--;
                        },
                      ),
                      Text(
                        qty.toString(),
                        style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      CircleButton(
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

          SafeArea(
            top: false,
            right: false,
            left: false,
            bottom: true,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15.0, 0.0, 10.0, 45.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: totalItemsNotifier,
                      builder: (_, total, _) {
                        return Badge(
                          label: Text(total.toString()),
                          isLabelVisible: total > 0,
                          textStyle: const TextStyle(fontSize: 14.0),
                          padding: const EdgeInsets.all(1.5),
                          child: ElevatedButton(
                            onPressed: _popBack,
                            style: ElevatedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Cerrar Camara'),
                          ),
                        );
                      },
                    ),
                    Visibility(
                      visible: widget.showFlashButton,
                      child: FlashToggleButton(controller: controller),
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
