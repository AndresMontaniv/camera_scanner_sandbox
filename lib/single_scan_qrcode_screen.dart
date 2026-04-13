import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mobile_scanner/mobile_scanner.dart' show BarcodeFormat, MobileScannerController, BarcodeCapture, CameraFacing, DetectionSpeed;

import 'scanner_view.dart';
import 'scanner_top_bar.dart';
import 'scanner_overlay.dart';

const Offset _offsetFromCenter = Offset(0.0, -50.0);

class SingleScanQrCodeScreen extends StatefulWidget {
  final bool showFlashButton;
  final bool showCloseButton;
  final int detectionTimeoutMs;
  final ScannerOverlayStyle? overlayStyle;
  final void Function(Object error)? onFlashButtonError;
  const SingleScanQrCodeScreen({
    super.key,
    this.overlayStyle,
    this.onFlashButtonError,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.detectionTimeoutMs = 250,
  });

  @override
  State<SingleScanQrCodeScreen> createState() => _SingleScanQrCodeScreenState();
}

class _SingleScanQrCodeScreenState extends State<SingleScanQrCodeScreen> with WidgetsBindingObserver {
  late final MobileScannerController controller;
  StreamSubscription<BarcodeCapture>? _subscription;

  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    controller = MobileScannerController(
      torchEnabled: false,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: widget.detectionTimeoutMs,
      formats: const [BarcodeFormat.qrCode],
    );
    _subscribeToBarcodes();
  }

  void _subscribeToBarcodes() {
    _subscription = controller.barcodes.listen((capture) async {
      if (_isPopping || capture.barcodes.isEmpty) return;

      final barcode = capture.barcodes.first;
      final rawValue = barcode.rawValue;

      if (rawValue != null) {
        _isPopping = true;

        unawaited(HapticFeedback.heavyImpact());

        await _subscription?.cancel();
        await controller.stop();

        if (mounted) {
          Navigator.of(context).pop(rawValue);
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _subscription?.pause();
        controller.stop();
        break;
      case AppLifecycleState.resumed:
        _subscription?.resume();
        controller.start();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScannerView.qrCode(
      fit: BoxFit.cover,
      controller: controller,
      useAppLifecycleState: false,
      overlayStyle: widget.overlayStyle,
      offsetFromCenter: _offsetFromCenter,
      stackChildren: [
        ScannerTopBar(
          controller: controller,
          showFlashButton: widget.showFlashButton,
          showCloseButton: widget.showCloseButton,
          onFlashButtonError: widget.onFlashButtonError,
        ),
      ],
    );
  }
}
