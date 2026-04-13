// This functions will be part of the package in the future

import 'package:flutter/material.dart';

import 'single_scan_barcode_screen.dart';
import 'single_scan_qrcode_screen.dart';

Future<String?> scanBarcodeWithCamera(BuildContext context) async {
  try {
    final String? scannedCode = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => const SingleScanBarcodeScreen()));

    if (scannedCode != null) {
      debugPrint('Successfully scanned: $scannedCode');
    }

    return scannedCode;
  } catch (e, stackTrace) {
    debugPrint('Error scanning barcode: $e\n$stackTrace');
    return null;
  }
}

Future<String?> scanQrCodeWithCamera(BuildContext context) async {
  try {
    final String? scannedCode = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => const SingleScanQrCodeScreen()));

    if (scannedCode != null) {
      debugPrint('Successfully scanned: $scannedCode');
    }

    return scannedCode;
  } catch (e, stackTrace) {
    debugPrint('Error scanning QrCode: $e\n$stackTrace');
    return null;
  }
}

// Rect functions

// --- LAYOUT CONSTANTS ---
const double _qrSizeRatio = 0.70;
const double _qrMinSize = 200.0;
const double _qrMaxSize = 350.0;

const double _barcodeWidthRatio = 0.85;
const double _barcodeMinWidth = 250.0;
const double _barcodeMaxWidth = 400.0;
const double _barcodeHeight = 130.0;

/// Returns a perfectly responsive square Rect for QR Code scanning.
Rect calculateQrCodeScanWindow(BuildContext context, {Offset? offsetFromCenter}) {
  final offset = offsetFromCenter ?? Offset.zero;
  final screenSize = MediaQuery.sizeOf(context);
  final double baseSize = screenSize.shortestSide * _qrSizeRatio;
  final double scanSize = baseSize.clamp(_qrMinSize, _qrMaxSize);

  return Rect.fromCenter(
    center: screenSize.center(offset),
    width: scanSize,
    height: scanSize,
  );
}

/// Returns a responsive horizontal Rect optimized for 1D barcodes.
Rect calculateBarcodeScanWindow(BuildContext context, {Offset? offsetFromCenter}) {
  final offset = offsetFromCenter ?? Offset.zero;
  final screenSize = MediaQuery.sizeOf(context);
  final double baseWidth = screenSize.shortestSide * _barcodeWidthRatio;
  final double scanWidth = baseWidth.clamp(_barcodeMinWidth, _barcodeMaxWidth);

  return Rect.fromCenter(
    center: screenSize.center(offset),
    width: scanWidth,
    height: _barcodeHeight,
  );
}
