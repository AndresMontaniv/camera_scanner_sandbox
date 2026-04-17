import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mobile_scanner/mobile_scanner.dart' show BarcodeFormat, MobileScannerController, BarcodeCapture, CameraFacing, DetectionSpeed;

import 'scanner_view.dart';
import 'scanner_overlay.dart';
import 'scanner_top_bar.dart';
import 'flash_toggle_button.dart';
import 'circle_close_button.dart';

// ── Default offsets per overlay mode ─────────────────────────────────
const Offset _qrOffset = Offset(0.0, -50.0);
const Offset _barcodeOffset = Offset(0.0, -80.0);

// ── Internal enums (invisible to package consumers) ─────────────────

/// Determines the visual shape of the scan window overlay.
enum _OverlayMode { custom, qrCode, barcode }

/// Determines the data-routing and navigation behavior.
enum _RoutingMode { singleScan, batchPop, callbackStream }

/// A unified scanner screen that supports **9 combinations** of overlay
/// shape × data-routing mode.
///
/// ### Overlay modes
/// * **custom** — Fully custom scan window and format list.
/// * **qrCode** — Responsive 1:1 square optimized for 2D matrix codes.
/// * **barcode** — Responsive horizontal rectangle optimized for 1D barcodes.
///
/// ### Routing modes
/// * **singleScan** — Scans one code, safely shuts down the camera, and pops
///   returning a `String?`.
/// * **batchPop** — Continuously scans into an internal cart, then pops
///   returning a `List<String>` when the user exits.
/// * **callbackStream** — Continuously scans and fires the [onCameraScan]
///   callback for each valid frame. Does not return data on pop.
///
/// This widget implements an `_isPopping` hardware safety tripwire to guarantee
/// the camera sensor is completely locked down and detached before the screen
/// animates away.
class DxScannerScreen extends StatefulWidget {
  final bool showFlashButton;
  final bool showCloseButton;
  final bool allowDuplicates;
  final bool showScannedListButton;
  final bool hideToolBar;
  final int detectionTimeoutMs;
  final int sameItemCooldownMs;
  final Rect? scanWindow;
  final Offset? offsetFromCenter;
  final List<Widget>? stackChildren;
  final ScannerOverlayStyle? overlayStyle;
  final List<BarcodeFormat> allowedFormats;
  final void Function(String)? onCameraScan;
  final void Function()? onScanSubmited;
  final void Function(String rejected)? onScanRejected;
  final void Function(Object error)? onFlashButtonError;
  final void Function(BuildContext, List<String>)? onShowScannedListPressed;
  final Widget Function(BuildContext, List<String>)? showScannedListBuilder;

  /// Internal flags set by the named constructors.
  final _OverlayMode _overlayMode;
  final _RoutingMode _routingMode;

  // ════════════════════════════════════════════════════════════════════
  // SINGLE SCAN constructors — scan one, pop String?
  // ════════════════════════════════════════════════════════════════════

  /// Scans a single code using a **custom** scan window, then pops `String?`.
  ///
  /// [scanWindow] lets the caller supply an arbitrary [Rect] for the detection
  /// region. When `null`, no scan-window restriction is applied.
  const DxScannerScreen.singleScan({
    super.key,
    this.scanWindow,
    this.overlayStyle,
    this.stackChildren,
    this.onFlashButtonError,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.detectionTimeoutMs = 250,
    bool hideToolBar = false,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _overlayMode = _OverlayMode.custom,
       _routingMode = _RoutingMode.singleScan,
       offsetFromCenter = null,
       onCameraScan = null,
       onScanSubmited = null,
       onScanRejected = null,
       onShowScannedListPressed = null,
       showScannedListBuilder = null,
       allowDuplicates = false,
       sameItemCooldownMs = 0,
       showScannedListButton = false,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton);

  /// Scans a single **QR / 2D matrix code**, then pops `String?`.
  ///
  /// The scan window is a responsive 1:1 square.
  const DxScannerScreen.singleScanQrCode({
    super.key,
    this.overlayStyle,
    this.offsetFromCenter,
    this.stackChildren,
    this.onFlashButtonError,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.detectionTimeoutMs = 250,
    bool hideToolBar = false,
    this.allowedFormats = const [BarcodeFormat.qrCode],
  }) : _overlayMode = _OverlayMode.qrCode,
       _routingMode = _RoutingMode.singleScan,
       scanWindow = null,
       onCameraScan = null,
       onScanSubmited = null,
       onScanRejected = null,
       onShowScannedListPressed = null,
       showScannedListBuilder = null,
       allowDuplicates = false,
       sameItemCooldownMs = 0,
       showScannedListButton = false,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton);

  /// Scans a single **1D barcode**, then pops `String?`.
  ///
  /// [allowedFormats] defaults to the standard set of store-product 1D
  /// symbologies. The caller may pass a subset to narrow detection further.
  const DxScannerScreen.singleScanBarcode({
    super.key,
    this.overlayStyle,
    this.offsetFromCenter,
    this.stackChildren,
    this.onFlashButtonError,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.detectionTimeoutMs = 250,
    bool hideToolBar = false,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _overlayMode = _OverlayMode.barcode,
       _routingMode = _RoutingMode.singleScan,
       scanWindow = null,
       onCameraScan = null,
       onScanSubmited = null,
       onScanRejected = null,
       onShowScannedListPressed = null,
       showScannedListBuilder = null,
       allowDuplicates = false,
       sameItemCooldownMs = 0,
       showScannedListButton = false,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton);

  // ════════════════════════════════════════════════════════════════════
  // BATCH POP constructors — multi scan, pop List<String>
  // ════════════════════════════════════════════════════════════════════

  /// Continuously scans with a **custom** overlay, storing results in a cart.
  /// Pops returning `List<String>` on exit.
  const DxScannerScreen.batchPop({
    super.key,
    this.scanWindow,
    this.overlayStyle,
    this.stackChildren,
    this.onFlashButtonError,
    this.showScannedListBuilder,
    this.onShowScannedListPressed,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.allowDuplicates = true,
    this.showScannedListButton = true,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.onScanSubmited,
    void Function(String)? onScanRejected,
    bool hideToolBar = false,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _overlayMode = _OverlayMode.custom,
       _routingMode = _RoutingMode.batchPop,
       offsetFromCenter = null,
       onCameraScan = null,
       onScanRejected = allowDuplicates ? onScanRejected : null,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton && !showScannedListButton);

  /// Continuously scans **QR / 2D codes** into a batch cart. Pops `List<String>`.
  const DxScannerScreen.batchPopQrCode({
    super.key,
    this.overlayStyle,
    this.offsetFromCenter,
    this.stackChildren,
    this.onFlashButtonError,
    this.showScannedListBuilder,
    this.onShowScannedListPressed,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.allowDuplicates = true,
    this.showScannedListButton = true,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.onScanSubmited,
    void Function(String)? onScanRejected,
    bool hideToolBar = false,
    this.allowedFormats = const [BarcodeFormat.qrCode],
  }) : _overlayMode = _OverlayMode.qrCode,
       _routingMode = _RoutingMode.batchPop,
       scanWindow = null,
       onCameraScan = null,
       onScanRejected = allowDuplicates ? onScanRejected : null,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton && !showScannedListButton);

  /// Continuously scans **1D barcodes** into a batch cart. Pops `List<String>`.
  const DxScannerScreen.batchPopBarcode({
    super.key,
    this.overlayStyle,
    this.offsetFromCenter,
    this.stackChildren,
    this.onFlashButtonError,
    this.showScannedListBuilder,
    this.onShowScannedListPressed,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.allowDuplicates = true,
    this.showScannedListButton = true,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.onScanSubmited,
    void Function(String)? onScanRejected,
    bool hideToolBar = false,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _overlayMode = _OverlayMode.barcode,
       _routingMode = _RoutingMode.batchPop,
       scanWindow = null,
       onCameraScan = null,
       onScanRejected = allowDuplicates ? onScanRejected : null,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton && !showScannedListButton);

  // ════════════════════════════════════════════════════════════════════
  // CALLBACK STREAM constructors — multi scan, fire callback
  // ════════════════════════════════════════════════════════════════════

  /// Continuously scans with a **custom** overlay, firing [onDetect] for every
  /// valid scan. Does not return data on pop.
  const DxScannerScreen.callbackStream({
    super.key,
    required void Function(String) onDetect,
    this.scanWindow,
    this.overlayStyle,
    this.stackChildren,
    this.onFlashButtonError,
    this.showScannedListBuilder,
    this.onShowScannedListPressed,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.showScannedListButton = true,
    this.allowDuplicates = true,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.onScanSubmited,
    void Function(String)? onScanRejected,
    bool hideToolBar = false,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _overlayMode = _OverlayMode.custom,
       _routingMode = _RoutingMode.callbackStream,
       offsetFromCenter = null,
       onCameraScan = onDetect,
       onScanRejected = allowDuplicates ? onScanRejected : null,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton && !showScannedListButton);

  /// Continuously scans **QR / 2D codes**, firing [onDetect] per valid scan.
  const DxScannerScreen.callbackStreamQrCode({
    super.key,
    required void Function(String) onDetect,
    this.overlayStyle,
    this.offsetFromCenter,
    this.stackChildren,
    this.onFlashButtonError,
    this.showScannedListBuilder,
    this.onShowScannedListPressed,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.showScannedListButton = true,
    this.allowDuplicates = true,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.onScanSubmited,
    void Function(String)? onScanRejected,
    bool hideToolBar = false,
    this.allowedFormats = const [BarcodeFormat.qrCode],
  }) : _overlayMode = _OverlayMode.qrCode,
       _routingMode = _RoutingMode.callbackStream,
       scanWindow = null,
       onCameraScan = onDetect,
       onScanRejected = allowDuplicates ? onScanRejected : null,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton && !showScannedListButton);

  /// Continuously scans **1D barcodes**, firing [onDetect] per valid scan.
  const DxScannerScreen.callbackStreamBarcode({
    super.key,
    required void Function(String) onDetect,
    this.overlayStyle,
    this.offsetFromCenter,
    this.stackChildren,
    this.onFlashButtonError,
    this.showScannedListBuilder,
    this.onShowScannedListPressed,
    this.showCloseButton = true,
    this.showFlashButton = true,
    this.showScannedListButton = true,
    this.allowDuplicates = true,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.onScanSubmited,
    void Function(String)? onScanRejected,
    bool hideToolBar = false,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _overlayMode = _OverlayMode.barcode,
       _routingMode = _RoutingMode.callbackStream,
       scanWindow = null,
       onCameraScan = onDetect,
       onScanRejected = allowDuplicates ? onScanRejected : null,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton && !showScannedListButton);

  @override
  State<DxScannerScreen> createState() => _DxScannerScreenState();
}

// ── Shared constants ────────────────────────────────────────────────

const List<BarcodeFormat> _storeProductFormats = [
  BarcodeFormat.code128,
  BarcodeFormat.code39,
  BarcodeFormat.code93,
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
];

// ════════════════════════════════════════════════════════════════════
// STATE
// ════════════════════════════════════════════════════════════════════

class _DxScannerScreenState extends State<DxScannerScreen> with WidgetsBindingObserver {
  late MobileScannerController controller;
  StreamSubscription<BarcodeCapture>? _subscription;

  final ValueNotifier<List<String>> scannedItemsNotifier = ValueNotifier<List<String>>([]);

  String? _lastScannedCode;
  DateTime? _lastScanTime;

  /// Hardware safety tripwire — once `true`, no further scans, pops, or
  /// camera commands are allowed.
  bool _isPopping = false;

  // ── Format resolution (overlay-aware) ────────────────────────────

  List<BarcodeFormat> _getEffectiveFormats() {
    switch (widget._overlayMode) {
      case _OverlayMode.qrCode:
        // QR overlay: trust the widget's formats (defaults to [BarcodeFormat.qrCode])
        return widget.allowedFormats;

      case _OverlayMode.barcode:
        // Barcode overlay: intersect with 1D store-product symbologies
        if (widget.allowedFormats.isEmpty) return _storeProductFormats;
        return widget.allowedFormats.where((f) => _storeProductFormats.contains(f)).toList();

      case _OverlayMode.custom:
        // Custom: pass-through, no filtering
        return widget.allowedFormats;
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Release native camera resources when not in foreground.
        _subscription?.pause();
        controller.stop();
        break;
      case AppLifecycleState.resumed:
        // Re-acquire camera and resume the barcode stream.
        controller.start();
        _subscription?.resume();
        break;
    }
  }

  @override
  void dispose() {
    scannedItemsNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  // ── Barcode subscription ─────────────────────────────────────────

  void _subscribeToBarcodes() {
    _subscription = controller.barcodes.listen((capture) {
      if (_isPopping) return;

      if (capture.barcodes.isEmpty) return;

      final rawValue = capture.barcodes.first.rawValue;
      if (rawValue == null) return;

      // Only apply cooldown for multi-scan modes
      if (widget._routingMode != _RoutingMode.singleScan) {
        if (rawValue == _lastScannedCode && _lastScanTime != null) {
          final elapsed = DateTime.now().difference(_lastScanTime!).inMilliseconds;
          if (elapsed < widget.sameItemCooldownMs) return;
        }

        _lastScannedCode = rawValue;
        _lastScanTime = DateTime.now();
      }

      _addScannedItem(rawValue);
    });
  }

  // ── Data routing ─────────────────────────────────────────────────

  Future<void> _addScannedItem(String rawValue) async {
    switch (widget._routingMode) {
      case _RoutingMode.singleScan:
        // TRIPWIRE: Instantly lock hardware to prevent ghost scans from slipping in
        // during the async await gap or the exit animation.
        _isPopping = true;
        unawaited(HapticFeedback.heavyImpact());
        if (!mounted) return;

        // Cache the navigator BEFORE the async gap to avoid deactivated widget context crashes.
        final navigator = Navigator.of(context);
        await _subscription?.cancel();
        await controller.stop(); // Wait for physical hardware to release

        navigator.pop(rawValue);
        break;

      case _RoutingMode.batchPop:
        // Check duplicate rules before updating the single source of truth.
        if (!widget.allowDuplicates && scannedItemsNotifier.value.contains(rawValue)) {
          widget.onScanRejected?.call(rawValue);
          return;
        }
        scannedItemsNotifier.value = List<String>.from([...scannedItemsNotifier.value, rawValue]);
        widget.onScanSubmited?.call();
        break;

      case _RoutingMode.callbackStream:
        // Respect duplicate rules for the stream.
        if (!widget.allowDuplicates && scannedItemsNotifier.value.contains(rawValue)) {
          widget.onScanRejected?.call(rawValue);
          return;
        }
        scannedItemsNotifier.value = List<String>.from([...scannedItemsNotifier.value, rawValue]);

        // Fire the real-time stream
        widget.onCameraScan?.call(rawValue);
        widget.onScanSubmited?.call();
        break;
    }
  }

  // ── Exit routes ──────────────────────────────────────────────────

  Future<void> _popBackWithListResult() async {
    // Prevent double-tapping the close button
    if (_isPopping) return;
    _isPopping = true;

    if (!mounted) return;
    final navigator = Navigator.of(context);

    // Safely await hardware spin-down to prevent camera lock crashes on the next screen
    await _subscription?.cancel();
    await controller.stop();

    navigator.pop<List<String>>(scannedItemsNotifier.value);
  }

  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    // If didPop is true, a programmatic pop just succeeded. We do nothing.
    if (didPop) return;

    // The user triggered a system back swipe. Intercept it and lock the hardware.
    if (_isPopping) return;
    _isPopping = true;

    if (!mounted) return;
    final navigator = Navigator.of(context);

    await _subscription?.cancel();
    await controller.stop();

    // Now that the hardware is safely dead, route the data manually.
    if (widget._routingMode == _RoutingMode.singleScan) {
      navigator.pop();
    } else {
      navigator.pop(scannedItemsNotifier.value);
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // 1. Build the ScannerView based on the overlay axis
    final ScannerView scannerView;

    // Toolbar children — shared across all overlay modes
    final List<Widget> toolbarChildren = [];
    if (!widget.hideToolBar) {
      toolbarChildren.add(
        _DefaultToolBar(
          controller: controller,
          scannedItemsNotifier: scannedItemsNotifier,
          showCloseButton: widget.showCloseButton,
          showFlashButton: widget.showFlashButton,
          showScannedListButton: widget.showScannedListButton,
          onFlashButtonError: widget.onFlashButtonError,
          popBackWithListResult: widget._routingMode == _RoutingMode.singleScan ? null : _popBackWithListResult,
          showScannedListBuilder: widget.showScannedListBuilder,
          onShowScannedListPressed: widget.onShowScannedListPressed,
        ),
      );
    }

    final allStackChildren = [
      ...toolbarChildren,
      ...?widget.stackChildren,
    ];

    switch (widget._overlayMode) {
      case _OverlayMode.custom:
        scannerView = ScannerView(
          fit: BoxFit.cover,
          controller: controller,
          autoDrawOverlay: true,
          useAppLifecycleState: false,
          scanWindow: widget.scanWindow,
          overlayStyle: widget.overlayStyle,
          stackChildren: allStackChildren,
        );
        break;
      case _OverlayMode.qrCode:
        scannerView = ScannerView.qrCode(
          fit: BoxFit.cover,
          controller: controller,
          useAppLifecycleState: false,
          overlayStyle: widget.overlayStyle,
          offsetFromCenter: widget.offsetFromCenter ?? _qrOffset,
          stackChildren: allStackChildren,
        );
        break;
      case _OverlayMode.barcode:
        scannerView = ScannerView.barcode(
          fit: BoxFit.cover,
          controller: controller,
          useAppLifecycleState: false,
          overlayStyle: widget.overlayStyle,
          offsetFromCenter: widget.offsetFromCenter ?? _barcodeOffset,
          stackChildren: allStackChildren,
        );
        break;
    }

    // 2. Wrap with PopScope based on the routing axis
    if (widget._routingMode == _RoutingMode.callbackStream) {
      return scannerView;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: scannerView,
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// DEFAULT TOOLBAR (ported from BarcodeScannerScreen)
// ════════════════════════════════════════════════════════════════════

class _DefaultToolBar extends StatelessWidget {
  final bool showCloseButton;
  final bool showFlashButton;
  final bool showScannedListButton;
  final MobileScannerController? controller;
  final ValueNotifier<List<String>> scannedItemsNotifier;
  final void Function()? popBackWithListResult;
  final void Function(Object error)? onFlashButtonError;
  final void Function(BuildContext, List<String>)? onShowScannedListPressed;
  final Widget Function(BuildContext, List<String>)? showScannedListBuilder;

  const _DefaultToolBar({
    required this.controller,
    required this.scannedItemsNotifier,
    required this.showCloseButton,
    required this.showFlashButton,
    required this.showScannedListButton,
    required this.popBackWithListResult,
    required this.showScannedListBuilder,
    required this.onShowScannedListPressed,
    this.onFlashButtonError,
  });

  void _onShowScanListPressed(BuildContext context, List<String> scannedItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scanned Items (${scannedItems.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Empty State (Just in case)
                if (scannedItems.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No items scanned yet.',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  )
                // Scrollable List
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: scannedItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade900,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            scannedItems[index],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScannerTopBar.custom(
      leading: showCloseButton ? CircleCloseButton(pop: popBackWithListResult) : null,
      trailing: [
        Visibility(
          visible: showFlashButton,
          child: FlashToggleButton(
            controller: controller,
            onError: onFlashButtonError,
          ),
        ),
        Visibility(
          visible: showScannedListButton,
          child: ValueListenableBuilder<List<String>>(
            valueListenable: scannedItemsNotifier,
            builder: (ctx, scannedItems, _) {
              if (showScannedListBuilder != null) {
                return showScannedListBuilder!.call(ctx, scannedItems);
              }
              final total = scannedItems.length;
              return Badge(
                label: Text(total.toString()),
                isLabelVisible: total > 0,
                textStyle: const TextStyle(fontSize: 14.0),
                padding: const EdgeInsets.all(1.5),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => onShowScannedListPressed != null
                        ? onShowScannedListPressed!.call(ctx, scannedItems)
                        : _onShowScanListPressed(ctx, scannedItems),
                    icon: const Icon(Icons.list, color: Colors.white, size: 28),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
