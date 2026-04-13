// This functions will be part of the package in the future

import 'package:flutter/material.dart';

import 'single_scan_screen.dart';

Future<String?> scanBarcodeWithCamera(BuildContext context) async {
  try {
    final String? scannedCode = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => const SingleScanScreen.barcode()));

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
    ).push(MaterialPageRoute(builder: (_) => const SingleScanScreen.qrCode()));

    if (scannedCode != null) {
      debugPrint('Successfully scanned: $scannedCode');
    }

    return scannedCode;
  } catch (e, stackTrace) {
    debugPrint('Error scanning QrCode: $e\n$stackTrace');
    return null;
  }
}
