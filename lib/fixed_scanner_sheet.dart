import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:native_haptics_and_audio/native_haptics_and_audio.dart';
import 'scanner_overlay.dart';

class FixedScannerSheet extends StatefulWidget {
  final void Function(String barcode) onBarcodeScanned;
  final int sameItemCooldownMs;

  const FixedScannerSheet({
    super.key,
    required this.onBarcodeScanned,
    this.sameItemCooldownMs = 1500,
  });

  @override
  State<FixedScannerSheet> createState() => _FixedScannerSheetState();
}

class _FixedScannerSheetState extends State<FixedScannerSheet> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
  );
  StreamSubscription<BarcodeCapture>? _subscription;

  String? _lastScannedCode;
  DateTime? _lastScanTime;

  final _effects = NativeHapticsAndAudioRepository.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effects.initialize();
    _controller.start();
    _subscription = _controller.barcodes.listen(_onBarcodeDetected);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _subscription?.pause();
        _controller.stop();
        break;
      case AppLifecycleState.resumed:
        _controller.start();
        _subscription?.resume();
        break;
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null) return;

    if (rawValue == _lastScannedCode && _lastScanTime != null) {
      final elapsed = DateTime.now().difference(_lastScanTime!).inMilliseconds;
      if (elapsed < widget.sameItemCooldownMs) return;
    }

    _lastScannedCode = rawValue;
    _lastScanTime = DateTime.now();

    Future.wait([
      _effects.playHaptic(PosHaptic.success),
      _effects.playSound(PosSound.scannerBeep),
    ]);

    widget.onBarcodeScanned(rawValue);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _controller
      ..stop()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.30, // 30% Fixed Height
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              fit: BoxFit.cover,
              useAppLifecycleState: false,
              overlayBuilder: (context, scannerConstraints) {
                final size = scannerConstraints.biggest;
                final scanWindow = Rect.fromCenter(
                  center: size.center(Offset.zero),
                  width: 280.0,
                  height: 100.0,
                );
                return ScannerOverlay(
                  scanWindow: scanWindow,
                  constraints: scannerConstraints,
                );
              },
            ),
            // Floating Drag Handle
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
