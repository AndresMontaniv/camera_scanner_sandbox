import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mobile_scanner/mobile_scanner.dart' show BarcodeFormat, MobileScannerController, BarcodeCapture, CameraFacing, DetectionSpeed;

import 'scanner_view.dart';
import 'scanner_top_bar.dart';
import 'scanner_overlay.dart';

// ── Offset per mode ──────────────────────────────────────────────────
const Offset _qrOffset = Offset(0.0, -50.0);
const Offset _barcodeOffset = Offset(0.0, -80.0);

/// Determines which scan mode the unified screen operates in.
enum _ScanMode { custom, qrCode, barcode }

/// A unified single-scan screen that detects one code, triggers haptic
/// feedback, and pops the result back to the caller.
///
/// Three constructors are provided:
///
/// * [SingleScanScreen.new] — fully custom scan window and format list.
/// * [SingleScanScreen.qrCode] — optimized for 2D matrix codes.
/// * [SingleScanScreen.barcode] — optimized for 1D product barcodes.
class SingleScanScreen extends StatefulWidget {
  final bool showFlashButton;
  final bool showCloseButton;
  final Rect? scanWindow;
  final int detectionTimeoutMs;
  final List<BarcodeFormat> allowedFormats;
  final ScannerOverlayStyle? overlayStyle;
  final void Function(Object error)? onFlashButtonError;

  /// Internal flag set by the named constructors.
  final _ScanMode _mode;

  /// Creates a scanner with a **custom** scan window and format list.
  ///
  /// [scanWindow] lets the caller supply an arbitrary [Rect] for the detection
  /// region. When `null`, no scan-window restriction is applied.
  ///
  /// [allowedFormats] is passed directly to the controller with no filtering.
  /// When empty (the default), all formats supported by the device are
  /// detected.
  const SingleScanScreen({
    super.key,
    this.scanWindow,
    this.overlayStyle,
    this.onFlashButtonError,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.detectionTimeoutMs = 250,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _mode = _ScanMode.custom;

  /// Creates a scanner optimized for **QR / 2D matrix codes**.
  ///
  /// The scan window is a responsive 1:1 square.
  const SingleScanScreen.qrCode({
    super.key,
    this.overlayStyle,
    this.onFlashButtonError,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.detectionTimeoutMs = 250,
  }) : _mode = _ScanMode.qrCode,
       scanWindow = null,
       allowedFormats = const [BarcodeFormat.qrCode];

  /// Creates a scanner optimized for **1D product barcodes**.
  ///
  /// [allowedFormats] defaults to the standard set of store-product 1D
  /// symbologies. The caller may pass a subset to narrow detection further.
  const SingleScanScreen.barcode({
    super.key,
    this.overlayStyle,
    this.onFlashButtonError,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.detectionTimeoutMs = 250,
    this.allowedFormats = const [],
  }) : _mode = _ScanMode.barcode,
       scanWindow = null;

  @override
  State<SingleScanScreen> createState() => _SingleScanScreenState();
}

const List<BarcodeFormat> _storeProductFormats = [
  BarcodeFormat.code128,
  BarcodeFormat.code39,
  BarcodeFormat.code93,
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
];

class _SingleScanScreenState extends State<SingleScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController controller;
  StreamSubscription<BarcodeCapture>? _subscription;

  bool _isPopping = false;

  List<BarcodeFormat> _getEffectiveFormats() {
    if (widget._mode == _ScanMode.barcode) {
      // If empty, use all default 1D formats
      if (widget.allowedFormats.isEmpty) {
        return _storeProductFormats;
      }
      // Intersection: Strip out any formats not in the 1D list
      return widget.allowedFormats.where((f) => _storeProductFormats.contains(f)).toList();
    }
    // For .custom and .qrCode, trust the widget's allowedFormats
    return widget.allowedFormats;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    controller = MobileScannerController(
      torchEnabled: false,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: widget.detectionTimeoutMs,
      formats: _getEffectiveFormats(),
    );
    _subscribeToBarcodes();
  }

  void _subscribeToBarcodes() {
    _subscription = controller.barcodes.listen((barcode) async {
      if (_isPopping) return;

      final rawValue = barcode.barcodes.firstOrNull?.rawValue;

      if (rawValue != null) {
        _isPopping = true;
        unawaited(HapticFeedback.heavyImpact());

        if (!mounted) return;
        final navigator = Navigator.of(context);

        await _subscription?.cancel();
        await controller.stop();

        navigator.pop(rawValue);
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
    final List<Widget> stackChildren = (widget.showCloseButton || widget.showFlashButton)
        ? [
            ScannerTopBar(
              controller: controller,
              showFlashButton: widget.showFlashButton,
              showCloseButton: widget.showCloseButton,
              onFlashButtonError: widget.onFlashButtonError,
            ),
          ]
        : [];

    ScannerView scannerWidget;

    switch (widget._mode) {
      case _ScanMode.custom:
        scannerWidget = ScannerView(
          fit: BoxFit.cover,
          controller: controller,
          autoDrawOverlay: true,
          useAppLifecycleState: false,
          scanWindow: widget.scanWindow,
          overlayStyle: widget.overlayStyle,
          stackChildren: stackChildren,
        );
        break;
      case _ScanMode.qrCode:
        scannerWidget = ScannerView.qrCode(
          fit: BoxFit.cover,
          controller: controller,
          useAppLifecycleState: false,
          overlayStyle: widget.overlayStyle,
          offsetFromCenter: _qrOffset,
          stackChildren: stackChildren,
        );
        break;
      case _ScanMode.barcode:
        scannerWidget = ScannerView.barcode(
          fit: BoxFit.cover,
          controller: controller,
          useAppLifecycleState: false,
          overlayStyle: widget.overlayStyle,
          offsetFromCenter: _barcodeOffset,
          stackChildren: stackChildren,
        );
        break;
    }
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _isPopping = true;
        controller.stop();
      },
      child: scannerWidget,
    );
  }
}
