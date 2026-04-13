import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mobile_scanner/mobile_scanner.dart' show BarcodeFormat, MobileScannerController, BarcodeCapture, CameraFacing, DetectionSpeed;

import 'scanner_view.dart';
import 'scanner_top_bar.dart';
import 'scanner_overlay.dart';

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
       allowedFormats = const <BarcodeFormat>[];

  /// Creates a scanner optimized for **1D product barcodes**.
  ///
  /// [allowedFormats] lets the caller restrict which 1D symbologies are
  /// accepted. When empty (the default), all common store-product formats are
  /// allowed. Any format not in the built-in 1D list is silently filtered out.
  const SingleScanScreen.barcode({
    super.key,
    this.overlayStyle,
    this.onFlashButtonError,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.detectionTimeoutMs = 250,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _mode = _ScanMode.barcode,
       scanWindow = null;

  @override
  State<SingleScanScreen> createState() => _SingleScanScreenState();
}

class _SingleScanScreenState extends State<SingleScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController controller;
  StreamSubscription<BarcodeCapture>? _subscription;

  bool _isPopping = false;

  // ── Offset per mode ──────────────────────────────────────────────────
  static const Offset _qrOffset = Offset(0.0, -50.0);
  static const Offset _barcodeOffset = Offset(0.0, -80.0);

  // ── 1-D barcode format whitelist ─────────────────────────────────────
  static const List<BarcodeFormat> _storeProductFormats = [
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
  ];

  /// Returns the effective barcode formats for the controller.
  ///
  /// For QR mode this is always `[BarcodeFormat.qrCode]`.
  /// For barcode mode the caller's [allowedFormats] are intersected with
  /// [_storeProductFormats]; if the intersection is empty (or the caller
  /// passed nothing) the full whitelist is used instead.
  List<BarcodeFormat> _getEffectiveFormats() {
    if (widget._mode == _ScanMode.custom) {
      return widget.allowedFormats;
    }
    if (widget._mode == _ScanMode.qrCode) {
      return const [BarcodeFormat.qrCode];
    }

    if (widget.allowedFormats.isEmpty) {
      return _storeProductFormats;
    }

    final filtered = widget.allowedFormats.where((format) => _storeProductFormats.contains(format)).toList();

    if (filtered.isEmpty) {
      debugPrint(
        'Scanner Package Warning: All provided formats were filtered out. '
        'Defaulting to all 1D formats.',
      );
      return _storeProductFormats;
    }

    return filtered;
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

    switch (widget._mode) {
      case _ScanMode.custom:
        return ScannerView(
          fit: BoxFit.cover,
          controller: controller,
          autoDrawOverlay: true,
          useAppLifecycleState: false,
          scanWindow: widget.scanWindow,
          overlayStyle: widget.overlayStyle,
          stackChildren: stackChildren,
        );
      case _ScanMode.qrCode:
        return ScannerView.qrCode(
          fit: BoxFit.cover,
          controller: controller,
          useAppLifecycleState: false,
          overlayStyle: widget.overlayStyle,
          offsetFromCenter: _qrOffset,
          stackChildren: stackChildren,
        );
      case _ScanMode.barcode:
        return ScannerView.barcode(
          fit: BoxFit.cover,
          controller: controller,
          useAppLifecycleState: false,
          overlayStyle: widget.overlayStyle,
          offsetFromCenter: _barcodeOffset,
          stackChildren: stackChildren,
        );
    }
  }
}
