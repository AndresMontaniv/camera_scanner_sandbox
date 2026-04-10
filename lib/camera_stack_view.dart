import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_overlay.dart';
import 'scanner_error_widget.dart';

const double _scanWindowUpdateThreshold = 0.0;

class CameraStackView extends StatelessWidget {
  final BoxFit fit;
  final bool tapToFocus;
  final Rect? scanWindow;
  final bool useAppLifecycleState;
  final List<Widget> stackChildren;
  final double scanWindowUpdateThreshold;
  final MobileScannerController? controller;
  final void Function(BarcodeCapture)? onDetect;
  final Widget Function(BuildContext, MobileScannerException)? errorBuilder;
  final Widget Function(BuildContext, BoxConstraints)? overlayBuilder;
  final Widget Function(BuildContext)? placeholderBuilder;

  const CameraStackView({
    super.key,
    this.onDetect,
    this.controller,
    this.scanWindow,
    this.errorBuilder,
    this.overlayBuilder,
    this.placeholderBuilder,
    this.fit = BoxFit.cover,
    this.tapToFocus = false,
    this.useAppLifecycleState = true,
    this.scanWindowUpdateThreshold = 0.0,
    this.stackChildren = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            fit: fit,
            onDetect: onDetect,
            tapToFocus: tapToFocus,
            controller: controller,
            scanWindow: scanWindow,
            placeholderBuilder: placeholderBuilder,
            useAppLifecycleState: useAppLifecycleState,
            scanWindowUpdateThreshold: _scanWindowUpdateThreshold,
            errorBuilder: errorBuilder ?? (_, error) => ScannerErrorWidget(error: error),
            overlayBuilder: scanWindow == null
                ? null
                : (_, constraints) => ScannerOverlay(
                    constraints: constraints,
                    scanWindow: scanWindow!,
                  ),
          ),
          ...stackChildren,
        ],
      ),
    );
  }
}
