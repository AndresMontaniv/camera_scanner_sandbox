import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' show BarcodeFormat, MobileScannerController, BarcodeCapture, CameraFacing, DetectionSpeed;

import 'scanner_view.dart';
import 'scanner_overlay.dart';
import 'scanner_top_bar.dart';
import 'flash_toggle_button.dart';
import 'circle_close_button.dart';

const Offset _barcodeOffset = Offset(0.0, -80.0);

enum _ScanMode { single, batchPop, callbackStream }

/// A highly optimized 1D barcode scanner that supports three routing modes:
/// 1. [singleScan]: Scans a single barcode, safely shuts down the camera, and pops returning a `String?`.
/// 2. [multiScanBatchPop]: Allows continuous scanning into an internal cart, popping returning a `List<String>`.
/// 3. [multiScanCallbackStream]: Continuously scans and fires the [onCameraScan] callback for each valid frame.
///
/// This widget implements an `_isPopping` hardware safety tripwire to guarantee
/// the camera sensor is completely locked down and detached before the screen animates away.
class BarcodeScannerScreen extends StatefulWidget {
  final bool showFlashButton;
  final bool showCloseButton;
  final bool allowDuplicates;
  final bool showScannedListButton;
  final bool hideToolBar;
  final int detectionTimeoutMs;
  final int sameItemCooldownMs;
  final Offset? offsetFromCenter;
  final List<Widget>? stackChildren;
  final ScannerOverlayStyle? overlayStyle;
  final List<BarcodeFormat> allowedFormats;
  final void Function(String)? onCameraScan;
  final void Function(BuildContext, List<String>)? onShowScannedListPressed;
  final Widget Function(BuildContext, List<String>)? showScannedListBuilder;

  /// Internal flag set by the named constructors.
  final _ScanMode _mode;

  /// Opens the scanner to read exactly one barcode.
  ///
  /// The hardware will instantly lock upon the first successful read,
  /// await safe sensor shutdown, and pop the navigation stack returning a [String?].
  const BarcodeScannerScreen.singleScan({
    super.key,
    this.overlayStyle,
    this.offsetFromCenter,
    this.stackChildren,
    this.onShowScannedListPressed,
    this.showFlashButton = true,
    this.showCloseButton = true,
    bool hideToolBar = false,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _mode = _ScanMode.single,
       onCameraScan = null,
       showScannedListBuilder = null,
       // Defaults for single scan where cooldown/duplicates don't apply
       allowDuplicates = false,
       sameItemCooldownMs = 0,
       detectionTimeoutMs = 250,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton),
       showScannedListButton = false;

  /// Opens the scanner for continuous scanning, storing results in an internal cart.
  ///
  /// When the user taps the Close or Back button, the scanner shuts down
  /// and pops the navigation stack returning a [List<String>] of all scanned items.
  const BarcodeScannerScreen.multiScanBatchPop({
    super.key,
    this.overlayStyle,
    this.stackChildren,
    this.offsetFromCenter,
    this.showScannedListBuilder,
    this.onShowScannedListPressed,
    bool hideToolBar = false,
    this.showFlashButton = true,
    this.showCloseButton = true,
    this.allowDuplicates = true,
    this.showScannedListButton = true,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _mode = _ScanMode.batchPop,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton && !showScannedListButton),
       onCameraScan = null;

  /// Opens the scanner for continuous scanning, firing a callback for every valid scan.
  ///
  /// This mode does not return data on pop. Instead, it relies on [onCameraScan]
  /// to pass data to the parent widget in real-time.
  const BarcodeScannerScreen.multiScanCallbackStream({
    super.key,
    required void Function(String) onDetect,
    this.overlayStyle,
    this.stackChildren,
    this.offsetFromCenter,
    this.showScannedListBuilder,
    this.onShowScannedListPressed,
    this.showFlashButton = true,
    this.showCloseButton = true,
    this.showScannedListButton = true,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    bool hideToolBar = false,
    this.allowDuplicates = true,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _mode = _ScanMode.callbackStream,
       onCameraScan = onDetect,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton && !showScannedListButton);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
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

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with WidgetsBindingObserver {
  late MobileScannerController controller;
  StreamSubscription<BarcodeCapture>? _subscription;

  final ValueNotifier<List<String>> scannedItemsNotifier = ValueNotifier<List<String>>([]);

  String? _lastScannedCode;
  DateTime? _lastScanTime;

  bool _isPopping = false;

  List<BarcodeFormat> _getEffectiveFormats() {
    if (widget.allowedFormats.isEmpty) {
      return _storeProductFormats;
    }
    return widget.allowedFormats.where((f) => _storeProductFormats.contains(f)).toList();
  }

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

  void _subscribeToBarcodes() {
    _subscription = controller.barcodes.listen((capture) {
      if (_isPopping) return;

      if (capture.barcodes.isEmpty) return;

      final rawValue = capture.barcodes.first.rawValue;
      if (rawValue == null) return;

      // Only apply cooldown for multi-scan modes
      if (widget._mode != _ScanMode.single) {
        if (rawValue == _lastScannedCode && _lastScanTime != null) {
          final elapsed = DateTime.now().difference(_lastScanTime!).inMilliseconds;
          if (elapsed < widget.sameItemCooldownMs) return;
        }

        _lastScannedCode = rawValue;
        _lastScanTime = DateTime.now();
      }

      unawaited(HapticFeedback.heavyImpact());
      _addScannedItem(rawValue);
    });
  }

  Future<void> _addScannedItem(String rawValue) async {
    switch (widget._mode) {
      case _ScanMode.single:
        // TRIPWIRE: Instantly lock hardware to prevent ghost scans from slipping in
        // during the async await gap or the exit animation.
        _isPopping = true;
        if (!mounted) return;

        // Cache the navigator BEFORE the async gap to avoid deactivated widget context crashes.
        final navigator = Navigator.of(context);
        await _subscription?.cancel();
        await controller.stop(); // Wait for physical hardware to release

        navigator.pop(rawValue);
        break;

      case _ScanMode.batchPop:
        // Check duplicate rules before updating the single source of truth.
        if (!widget.allowDuplicates && scannedItemsNotifier.value.contains(rawValue)) return;
        scannedItemsNotifier.value = List<String>.from([...scannedItemsNotifier.value, rawValue]);
        break;

      case _ScanMode.callbackStream:
        // Respect duplicate rules for the stream.
        if (!widget.allowDuplicates && scannedItemsNotifier.value.contains(rawValue)) return;
        scannedItemsNotifier.value = List<String>.from([...scannedItemsNotifier.value, rawValue]);

        // Fire the real-time stream
        widget.onCameraScan?.call(rawValue);
        break;
    }
  }

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
    print('OnPopInvokedWithResult : $didPop and result:\n$result');

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
    if (widget._mode == _ScanMode.single) {
      navigator.pop();
    } else {
      navigator.pop(scannedItemsNotifier.value);
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

  @override
  Widget build(BuildContext context) {
    final scannerView = ScannerView.barcode(
      fit: BoxFit.cover,
      controller: controller,
      useAppLifecycleState: false,
      overlayStyle: widget.overlayStyle,
      offsetFromCenter: widget.offsetFromCenter ?? _barcodeOffset,
      stackChildren: [
        if (!widget.hideToolBar)
          _DefaultToolBar(
            controller: controller,
            scannedItemsNotifier: scannedItemsNotifier,
            showCloseButton: widget.showCloseButton,
            showFlashButton: widget.showFlashButton,
            showScannedListButton: widget.showScannedListButton,
            popBackWithListResult: _popBackWithListResult,
            showScannedListBuilder: widget.showScannedListBuilder,
            onShowScannedListPressed: widget.onShowScannedListPressed,
          ),
        ...?widget.stackChildren,
      ],
    );
    if (widget._mode == _ScanMode.callbackStream) {
      return scannerView;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: scannerView,
    );
  }
}

class _DefaultToolBar extends StatelessWidget {
  final bool showCloseButton;
  final bool showFlashButton;
  final bool showScannedListButton;
  final MobileScannerController? controller;
  final ValueNotifier<List<String>> scannedItemsNotifier;
  final void Function()? popBackWithListResult;
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
          child: FlashToggleButton(controller: controller),
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
