/// This file implements the Facade pattern for the [ScannerScreen] widget,
/// providing the primary public API for developers. It abstracts away the
/// internal configuration objects and presents nine clean, distinct functions
/// (Single, Batch, and Stream × Custom, Barcode, and QR Code) for simple integration.
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_overlay.dart';
import 'scanner_screen.dart';

/// Opens the scanner for a **Single** scan with a custom overlay configuration.
///
/// Locks the camera hardware immediately after the first successful read
/// and returns the scanned value as a `String?`. Returns `null` if canceled.
Future<String?> scanCustom(
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

/// Opens the scanner for a **Single** scan optimized for horizontal Barcodes.
///
/// Locks the camera hardware immediately after the first successful read
/// and returns the scanned value as a `String?`. Returns `null` if canceled.
Future<String?> scanBarcode(
  BuildContext context, {
  List<Widget>? stackChildren,
  void Function(String)? onScanRejected,
  ScannerOverlayStyle? overlayStyle,
  Offset? offsetFromCenter,
  ToolBarConfig? toolBarConfig = const ToolBarConfig(),
  List<BarcodeFormat> allowedFormats = const [],
  bool enableSoundAndVibration = true,
}) async {
  return scanCustom(
    context,
    stackChildren: stackChildren,
    onScanRejected: onScanRejected,
    scannerViewConfig: ScannerViewConfig.barcode(
      overlayStyle: overlayStyle,
      offsetFromCenter: offsetFromCenter,
      allowedFormats: allowedFormats,
    ),
    toolBarConfig: toolBarConfig,
    enableSoundAndVibration: enableSoundAndVibration,
  );
}

/// Opens the scanner for a **Single** scan optimized for QR Codes.
///
/// Locks the camera hardware immediately after the first successful read
/// and returns the scanned value as a `String?`. Returns `null` if canceled.
Future<String?> scanQrCode(
  BuildContext context, {
  List<Widget>? stackChildren,
  void Function(String)? onScanRejected,
  ScannerOverlayStyle? overlayStyle,
  Offset? offsetFromCenter,
  ToolBarConfig? toolBarConfig = const ToolBarConfig(),
  bool enableSoundAndVibration = true,
}) async {
  return scanCustom(
    context,
    stackChildren: stackChildren,
    onScanRejected: onScanRejected,
    scannerViewConfig: ScannerViewConfig.qrCode(
      overlayStyle: overlayStyle,
      offsetFromCenter: offsetFromCenter,
    ),
    toolBarConfig: toolBarConfig,
    enableSoundAndVibration: enableSoundAndVibration,
  );
}

/// Opens the scanner in **Batch** mode with a custom overlay configuration.
///
/// Acts as a shopping cart: the user can scan multiple items. When the
/// user closes the screen, it returns the accumulated `List<String>?`.
Future<List<String>?> scanCustomBatch(
  BuildContext context, {
  List<Widget>? stackChildren,
  ToolBarConfig? toolBarConfig,
  ScannerViewConfig? scannerViewConfig,
  bool allowDuplicates = true,
  int detectionTimeoutMs = 250,
  int sameItemCooldownMs = 1500,
  bool enableSoundAndVibration = true,
  void Function(String)? onScanRejected,
}) async {
  try {
    final List<String>? scannedItems =
        await Navigator.of(
          context,
          rootNavigator: true,
        ).push(
          MaterialPageRoute(
            builder: (_) => ScannerScreen.multiscan(
              toolBarConfig: toolBarConfig,
              stackChildren: stackChildren,
              onScanRejected: onScanRejected,
              allowDuplicates: allowDuplicates,
              detectionTimeoutMs: detectionTimeoutMs,
              sameItemCooldownMs: sameItemCooldownMs,
              scannerViewConfig: scannerViewConfig,
              enableSoundAndVibration: enableSoundAndVibration,
            ),
          ),
        );

    if (scannedItems != null) {
      debugPrint('Successfully scanned: $scannedItems');
    }

    return scannedItems;
  } catch (e, stackTrace) {
    debugPrint('Error on scanning: $e\n$stackTrace');
    return null;
  }
}

/// Opens the scanner in **Batch** mode optimized for horizontal Barcodes.
///
/// Acts as a shopping cart: the user can scan multiple items. When the
/// user closes the screen, it returns the accumulated `List<String>?`.
Future<List<String>?> scanBarcodeBatch(
  BuildContext context, {
  List<Widget>? stackChildren,
  ToolBarConfig? toolBarConfig = const ToolBarConfig.multiscan(),
  bool allowDuplicates = true,
  int detectionTimeoutMs = 250,
  int sameItemCooldownMs = 1500,
  bool enableSoundAndVibration = true,
  void Function(String)? onScanRejected,
  Offset? offsetFromCenter,
  ScannerOverlayStyle? overlayStyle,
  List<BarcodeFormat> allowedFormats = const [],
}) async {
  return scanCustomBatch(
    context,
    stackChildren: stackChildren,
    allowDuplicates: allowDuplicates,
    detectionTimeoutMs: detectionTimeoutMs,
    sameItemCooldownMs: sameItemCooldownMs,
    onScanRejected: onScanRejected,
    scannerViewConfig: ScannerViewConfig.barcode(
      overlayStyle: overlayStyle,
      offsetFromCenter: offsetFromCenter,
      allowedFormats: allowedFormats,
    ),
    toolBarConfig: toolBarConfig,
    enableSoundAndVibration: enableSoundAndVibration,
  );
}

/// Opens the scanner in **Batch** mode optimized for QR Codes.
///
/// Acts as a shopping cart: the user can scan multiple items. When the
/// user closes the screen, it returns the accumulated `List<String>?`.
Future<List<String>?> scanQrCodeBatch(
  BuildContext context, {
  List<Widget>? stackChildren,
  ToolBarConfig? toolBarConfig = const ToolBarConfig.multiscan(),
  bool allowDuplicates = true,
  int detectionTimeoutMs = 250,
  int sameItemCooldownMs = 1500,
  bool enableSoundAndVibration = true,
  void Function(String)? onScanRejected,
  Offset? offsetFromCenter,
  ScannerOverlayStyle? overlayStyle,
}) async {
  return scanCustomBatch(
    context,
    stackChildren: stackChildren,
    allowDuplicates: allowDuplicates,
    detectionTimeoutMs: detectionTimeoutMs,
    sameItemCooldownMs: sameItemCooldownMs,
    onScanRejected: onScanRejected,
    scannerViewConfig: ScannerViewConfig.qrCode(
      overlayStyle: overlayStyle,
      offsetFromCenter: offsetFromCenter,
    ),
    toolBarConfig: toolBarConfig,
    enableSoundAndVibration: enableSoundAndVibration,
  );
}

/// Opens the scanner in **Stream** mode with a custom overlay configuration.
///
/// Streams real-time data to the [onCameraScan] callback as each item is
/// successfully scanned. The `Future<void>` completes when the user closes
/// the scanner screen.
Future<void> scanCustomStream(
  BuildContext context, {
  required void Function(String) onCameraScan,
  List<Widget>? stackChildren,
  ToolBarConfig? toolBarConfig,
  ScannerViewConfig? scannerViewConfig,
  bool allowDuplicates = true,
  int detectionTimeoutMs = 250,
  int sameItemCooldownMs = 1500,
  bool enableSoundAndVibration = true,
  void Function(String)? onScanRejected,
}) async {
  try {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ScannerScreen.multiscan(
          toolBarConfig: toolBarConfig,
          stackChildren: stackChildren,
          onScanRejected: onScanRejected,
          onCameraScan: onCameraScan,
          allowDuplicates: allowDuplicates,
          detectionTimeoutMs: detectionTimeoutMs,
          sameItemCooldownMs: sameItemCooldownMs,
          scannerViewConfig: scannerViewConfig,
          enableSoundAndVibration: enableSoundAndVibration,
        ),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('Error on scanning: $e\n$stackTrace');
  }
}

/// Opens the scanner in **Stream** mode optimized for horizontal Barcodes.
///
/// Streams real-time data to the [onCameraScan] callback as each item is
/// successfully scanned. The `Future<void>` completes when the user closes
/// the scanner screen.
Future<void> scanBarcodeStream(
  BuildContext context, {
  required void Function(String) onCameraScan,
  List<Widget>? stackChildren,
  ToolBarConfig? toolBarConfig = const ToolBarConfig.multiscan(),
  bool allowDuplicates = true,
  int detectionTimeoutMs = 250,
  int sameItemCooldownMs = 1500,
  bool enableSoundAndVibration = true,
  void Function(String)? onScanRejected,
  ScannerOverlayStyle? overlayStyle,
  Offset? offsetFromCenter,
  List<BarcodeFormat> allowedFormats = const [],
}) async => scanCustomStream(
  context,
  stackChildren: stackChildren,
  onScanRejected: onScanRejected,
  onCameraScan: onCameraScan,
  allowDuplicates: allowDuplicates,
  detectionTimeoutMs: detectionTimeoutMs,
  sameItemCooldownMs: sameItemCooldownMs,
  scannerViewConfig: ScannerViewConfig.barcode(
    overlayStyle: overlayStyle,
    offsetFromCenter: offsetFromCenter,
    allowedFormats: allowedFormats,
  ),
  toolBarConfig: toolBarConfig,
  enableSoundAndVibration: enableSoundAndVibration,
);

/// Opens the scanner in **Stream** mode optimized for QR Codes.
///
/// Streams real-time data to the [onCameraScan] callback as each item is
/// successfully scanned. The `Future<void>` completes when the user closes
/// the scanner screen.
Future<void> scanQrCodeStream(
  BuildContext context, {
  required void Function(String) onCameraScan,
  List<Widget>? stackChildren,
  ToolBarConfig? toolBarConfig = const ToolBarConfig.multiscan(),
  bool allowDuplicates = true,
  int detectionTimeoutMs = 250,
  int sameItemCooldownMs = 1500,
  bool enableSoundAndVibration = true,
  void Function(String)? onScanRejected,
  ScannerOverlayStyle? overlayStyle,
  Offset? offsetFromCenter,
}) async => scanCustomStream(
  context,
  stackChildren: stackChildren,
  onScanRejected: onScanRejected,
  onCameraScan: onCameraScan,
  allowDuplicates: allowDuplicates,
  detectionTimeoutMs: detectionTimeoutMs,
  sameItemCooldownMs: sameItemCooldownMs,
  scannerViewConfig: ScannerViewConfig.qrCode(
    overlayStyle: overlayStyle,
    offsetFromCenter: offsetFromCenter,
  ),
  toolBarConfig: toolBarConfig,
  enableSoundAndVibration: enableSoundAndVibration,
);
