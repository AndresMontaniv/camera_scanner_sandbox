import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_overlay.dart';
import 'scanner_screen.dart';

Future<String?> openCameraSingleScanner(
  BuildContext context, {
  List<Widget>? stackChildren,
  ToolBarConfig? toolBarConfig,
  void Function(String)? onScanRejected,
  ScannerViewConfig? scannerViewConfig,
  bool enableSoundAndVibration = true,
}) async {
  try {
    final String? scannedItem =
        await Navigator.of(
          context,
          rootNavigator: true,
        ).push(
          MaterialPageRoute(
            builder: (_) => ScannerScreen.singleScan(
              toolBarConfig: toolBarConfig,
              stackChildren: stackChildren,
              onScanRejected: onScanRejected,
              scannerViewConfig: scannerViewConfig,
              enableSoundAndVibration: enableSoundAndVibration,
            ),
          ),
        );

    if (scannedItem != null) {
      debugPrint('Successfully scanned: $scannedItem');
    }

    return scannedItem;
  } catch (e, stackTrace) {
    debugPrint('Error on scanning: $e\n$stackTrace');
    return null;
  }
}

Future<String?> openBarcodeScannerSingleScan(
  BuildContext context, {
  List<Widget>? stackChildren,
  void Function(String)? onScanRejected,
  ScannerViewConfig? scannerViewConfig,
  ScannerOverlayStyle? overlayStyle,
  Offset? offsetFromCenter,
  ToolBarConfig? toolBarConfig,
  List<BarcodeFormat> allowedFormats = const [],
  bool enableSoundAndVibration = true,
}) async {
  return openCameraSingleScanner(
    context,
    stackChildren: stackChildren,
    onScanRejected: onScanRejected,
    scannerViewConfig: ScannerViewConfig.barcode(
      overlayStyle: overlayStyle,
      offsetFromCenter: offsetFromCenter,
      allowedFormats: allowedFormats,
    ),
    toolBarConfig: toolBarConfig ?? const ToolBarConfig(),
    enableSoundAndVibration: enableSoundAndVibration,
  );
}

Future<String?> openQrCodeScannerSingleScan(
  BuildContext context, {
  List<Widget>? stackChildren,
  void Function(String)? onScanRejected,
  ScannerViewConfig? scannerViewConfig,
  ScannerOverlayStyle? overlayStyle,
  Offset? offsetFromCenter,
  ToolBarConfig? toolBarConfig,
  bool enableSoundAndVibration = true,
}) async {
  return openCameraSingleScanner(
    context,
    stackChildren: stackChildren,
    onScanRejected: onScanRejected,
    scannerViewConfig: ScannerViewConfig.qrCode(
      overlayStyle: overlayStyle,
      offsetFromCenter: offsetFromCenter,
    ),
    toolBarConfig: toolBarConfig ?? const ToolBarConfig(),
    enableSoundAndVibration: enableSoundAndVibration,
  );
}
