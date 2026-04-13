import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_overlay.dart';

/// A highly optimized, boilerplate-free wrapper around [MobileScanner] that
/// handles responsive overlays, error states, and app lifecycle management
/// automatically.
///
/// [ScannerView] uses a [Stack] internally so consumers can layer
/// arbitrary widgets (toolbars, guides, flash toggles) on top of the live
/// camera feed without managing the underlying [MobileScanner] plumbing.
///
/// Three constructors are provided for common use-cases:
///
/// * [ScannerView.new] — fully custom, unopinionated scanner layout.
/// * [ScannerView.qrCode] — responsive 1:1 square scan window for 2D
///   matrix codes.
/// * [ScannerView.barcode] — responsive horizontal scan window for 1D
///   barcodes.
class ScannerView extends StatelessWidget {
  /// The [BoxFit] strategy used by the camera preview.
  ///
  /// Defaults to [BoxFit.cover] so the camera feed fills the entire screen
  /// without letterboxing.
  final BoxFit fit;

  /// An optional pixel offset applied to the scan window's center.
  ///
  /// Positive `dy` values push the window downward, which is useful for
  /// accommodating a top app bar or status-bar inset.
  final Offset? offsetFromCenter;

  /// Whether the camera should refocus when the user taps on the preview.
  ///
  /// Defaults to `false`.
  final bool tapToFocus;

  /// A manually specified scan window rectangle in logical pixels.
  ///
  /// ⚠️ BEST PRACTICE: Use the [ScannerView.qrCode] or
  /// [ScannerView.barcode] constructors instead of hardcoding this value
  /// for truly responsive layouts.
  final Rect? scanWindow;

  /// Whether to automatically render the default [ScannerOverlay] around the
  /// computed [scanWindow].
  ///
  /// Defaults to `true` in the [ScannerView.qrCode] and
  /// [ScannerView.barcode] constructors to mimic `mobile_scanner`
  /// behavior, and to `false` in the default constructor.
  final bool autoDrawOverlay;

  /// Whether [MobileScanner] should automatically pause and resume the camera
  /// when the app goes to the background and foreground.
  ///
  /// Defaults to `true`.
  final bool useAppLifecycleState;

  /// Additional widgets layered on top of the camera preview inside the
  /// internal [Stack].
  ///
  /// Use this to add toolbars, scan-line animations, instructional text, or
  /// any other overlay without rebuilding the scanner.
  final List<Widget> stackChildren;

  /// The minimum size change (in logical pixels) required before the
  /// [MobileScanner] recalculates the scan window.
  ///
  /// Defaults to `0.0`, meaning every layout change triggers an update.
  final double scanWindowUpdateThreshold;

  /// An optional style applied to the default [ScannerOverlay].
  ///
  /// Only takes effect when [autoDrawOverlay] is `true`.
  final ScannerOverlayStyle? overlayStyle;

  /// An optional external [MobileScannerController].
  ///
  /// When `null`, [MobileScanner] creates and manages its own controller
  /// internally.
  final MobileScannerController? controller;

  /// Called every time one or more barcodes are detected within the
  /// [scanWindow].
  final void Function(BarcodeCapture)? onDetect;

  /// A builder that provides a placeholder widget displayed while the camera
  /// hardware is initializing.
  ///
  /// When `null`, a default black screen with a subtle white spinner is shown
  /// to prevent a jarring flash during the 300 ms–800 ms initialization phase.
  final Widget Function(BuildContext)? placeholderBuilder;

  /// A builder that provides a fully custom overlay widget drawn on top of the
  /// camera preview.
  ///
  /// When provided, this takes precedence over [autoDrawOverlay] and
  /// [overlayStyle].
  final Widget Function(BuildContext, BoxConstraints)? overlayBuilder;

  /// A builder that provides a custom error widget when the scanner encounters
  /// a [MobileScannerException].
  ///
  /// When `null`, a default black screen with a white error icon and message
  /// is displayed.
  final Widget Function(BuildContext, MobileScannerException)? errorBuilder;

  /// Internal function reference used by named constructors to calculate a
  /// responsive scan window at build time.
  final Rect Function(BuildContext, {Offset? offsetFromCenter})? _calculateScanWindow;

  /// Creates a fully custom, unopinionated scanner layout.
  ///
  /// No scan window is calculated automatically and no overlay is drawn.
  /// Use this constructor when you need complete control over the scan region
  /// and visual presentation.
  const ScannerView({
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

  /// Creates a scanner with an automatically calculated, responsive **1:1
  /// square** scan window optimized for 2D matrix codes (QR, Data Matrix,
  /// Aztec, etc.).
  ///
  /// The scan window size is derived from the device's shortest side and
  /// clamped to sane min/max bounds so it looks correct on phones and tablets
  /// alike. An overlay is drawn by default.
  const ScannerView.qrCode({
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
       _calculateScanWindow = _calculateQrCodeScanWindow;

  /// Creates a scanner with an automatically calculated, responsive
  /// **horizontal rectangle** scan window optimized for 1D barcodes (EAN-13,
  /// Code 128, UPC-A, etc.).
  ///
  /// The scan window width is derived from the device's shortest side and
  /// clamped to sane min/max bounds while maintaining a fixed, narrow height
  /// that encourages the user to align the barcode horizontally. An overlay is
  /// drawn by default.
  const ScannerView.barcode({
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
       _calculateScanWindow = _calculateBarcodeScanWindow;

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
            useAppLifecycleState: useAppLifecycleState,
            scanWindowUpdateThreshold: scanWindowUpdateThreshold,
            placeholderBuilder: placeholderBuilder ?? (_) => const _DefaultScannerPlaceholder(),
            errorBuilder: errorBuilder ?? (_, error) => _ScannerErrorWidget(error: error),
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

// ==========================================
// PRIVATE LAYOUT HELPERS (Invisible to package users)
// ==========================================

// Layout constants are isolated here as top-level privates so they never
// pollute the public API surface of the package.

// QR code scan window sizing.
// The window is a 1:1 square whose side length equals 70 % of the device's
// shortest side, clamped between 200 lp and 350 lp.
const double _qrSizeRatio = 0.70;
const double _qrMinSize = 200.0;
const double _qrMaxSize = 350.0;

// Barcode scan window sizing.
// The window width equals 85 % of the shortest side, clamped between 250 lp
// and 400 lp. Height is fixed at 130 lp to keep the guide narrow.
const double _barcodeWidthRatio = 0.85;
const double _barcodeMinWidth = 250.0;
const double _barcodeMaxWidth = 400.0;
const double _barcodeHeight = 130.0;

// Calculates a responsive 1:1 square scan window for QR / 2D codes.
// The base size is derived from the shortest screen dimension so the window
// scales proportionally across phones and tablets, and then clamped to
// [_qrMinSize, _qrMaxSize] to prevent it from becoming too small on compact
// devices or unnecessarily large on tablets.
Rect _calculateQrCodeScanWindow(BuildContext context, {Offset? offsetFromCenter}) {
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

// Calculates a responsive horizontal rectangle scan window for 1D barcodes.
// Width is proportional to the shortest screen dimension and clamped to
// [_barcodeMinWidth, _barcodeMaxWidth]. Height is fixed at [_barcodeHeight]
// so the guide stays narrow, encouraging the user to align the barcode
// horizontally.
Rect _calculateBarcodeScanWindow(BuildContext context, {Offset? offsetFromCenter}) {
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

// ==========================================
// PRIVATE UI HELPERS
// ==========================================

// Default placeholder shown while the camera hardware initializes.
// Displays a black screen with a subtle white spinner to prevent the jarring
// black-frame flash that occurs during the 300 ms–800 ms hardware
// initialization phase on most devices.
class _DefaultScannerPlaceholder extends StatelessWidget {
  const _DefaultScannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Match the typical camera background
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white54, // Subtle white spinner so it isn't blinding
          strokeWidth: 2.0,
        ),
      ),
    );
  }
}

class _ScannerErrorWidget extends StatelessWidget {
  const _ScannerErrorWidget({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    String errorMessage;

    switch (error.errorCode) {
      case MobileScannerErrorCode.controllerUninitialized:
        errorMessage = 'Controller not ready.';
        break;
      case MobileScannerErrorCode.permissionDenied:
        errorMessage = 'Permission denied';
        break;
      case MobileScannerErrorCode.unsupported:
        errorMessage = 'Scanning is unsupported on this device';
        break;
      default:
        errorMessage = 'Generic Error';
        break;
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Icon(Icons.error, color: Colors.white),
            ),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              error.errorDetails?.message ?? '',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
