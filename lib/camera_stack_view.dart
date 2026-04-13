import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'functions.dart';
import 'scanner_overlay.dart';
import 'scanner_error_widget.dart';

class CameraStackView extends StatelessWidget {
  final BoxFit fit;
  final Offset? offsetFromCenter;
  final bool tapToFocus;
  final Rect? scanWindow;
  final bool autoDrawOverlay;
  final bool useAppLifecycleState;
  final List<Widget> stackChildren;
  final double scanWindowUpdateThreshold;
  final ScannerOverlayStyle? overlayStyle;
  final MobileScannerController? controller;
  final void Function(BarcodeCapture)? onDetect;
  final Widget Function(BuildContext)? placeholderBuilder;
  final Widget Function(BuildContext, BoxConstraints)? overlayBuilder;
  final Widget Function(BuildContext, MobileScannerException)? errorBuilder;
  final Rect Function(BuildContext, {Offset? offsetFromCenter})? _calculateScanWindow;

  const CameraStackView({
    super.key,
    this.onDetect,
    this.controller,
    this.scanWindow,
    this.errorBuilder,
    this.overlayStyle,
    this.overlayBuilder,
    this.placeholderBuilder,
    this.fit = BoxFit.cover,
    this.tapToFocus = false,
    this.autoDrawOverlay = false,
    this.useAppLifecycleState = true,
    this.scanWindowUpdateThreshold = 0.0,
    this.stackChildren = const <Widget>[],
  }) : _calculateScanWindow = null,
       offsetFromCenter = Offset.zero;

  const CameraStackView.qrCode({
    super.key,
    this.onDetect,
    this.controller,
    this.errorBuilder,
    this.offsetFromCenter,
    this.overlayStyle,
    this.placeholderBuilder,
    this.fit = BoxFit.cover,
    this.tapToFocus = false,
    this.useAppLifecycleState = true,
    this.scanWindowUpdateThreshold = 0.0,
    this.stackChildren = const <Widget>[],
  }) : scanWindow = null,
       overlayBuilder = null,
       autoDrawOverlay = true,
       _calculateScanWindow = calculateQrCodeScanWindow;

  const CameraStackView.barCode({
    super.key,
    this.onDetect,
    this.controller,
    this.errorBuilder,
    this.offsetFromCenter,
    this.overlayStyle,
    this.placeholderBuilder,
    this.fit = BoxFit.cover,
    this.tapToFocus = false,
    this.useAppLifecycleState = true,
    this.scanWindowUpdateThreshold = 0.0,
    this.stackChildren = const <Widget>[],
  }) : scanWindow = null,
       overlayBuilder = null,
       autoDrawOverlay = true,
       _calculateScanWindow = calculateBarcodeScanWindow;

  @override
  Widget build(BuildContext context) {
    final overlayRect = _calculateScanWindow?.call(context, offsetFromCenter: offsetFromCenter) ?? scanWindow;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            fit: fit,
            onDetect: onDetect,
            tapToFocus: tapToFocus,
            controller: controller,
            scanWindow: overlayRect,
            placeholderBuilder: placeholderBuilder,
            useAppLifecycleState: useAppLifecycleState,
            scanWindowUpdateThreshold: scanWindowUpdateThreshold,
            errorBuilder: errorBuilder ?? (_, error) => ScannerErrorWidget(error: error),
            overlayBuilder:
                overlayBuilder ??
                (overlayRect == null || !autoDrawOverlay
                    ? null
                    : (_, constraints) => ScannerOverlay(
                        style: overlayStyle,
                        scanWindow: overlayRect,
                        constraints: constraints,
                      )),
          ),
          ...stackChildren,
        ],
      ),
    );
  }
}
