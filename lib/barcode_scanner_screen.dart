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
       allowDuplicates = false,
       sameItemCooldownMs = 0,
       detectionTimeoutMs = 250,
       hideToolBar = hideToolBar || (!showFlashButton && !showCloseButton),
       showScannedListButton = false;

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

  const BarcodeScannerScreen.multiScanCallbackStream({
    super.key,
    this.onCameraScan,
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
        // Lock hardware to prevent ghost scans during the exit animation
        _isPopping = true;
        if (!mounted) return;
        final navigator = Navigator.of(context);
        await _subscription?.cancel();
        await controller.stop();
        navigator.pop(rawValue);
        break;

      case _ScanMode.batchPop:
        // If allowDuplicates is false, reject items already in the list
        if (!widget.allowDuplicates && scannedItemsNotifier.value.contains(rawValue)) return;
        // Otherwise, add to the list
        scannedItemsNotifier.value = List<String>.from([...scannedItemsNotifier.value, rawValue]);
        break;

      case _ScanMode.callbackStream:
        // If allowDuplicates is false, reject items already in the list
        if (!widget.allowDuplicates && scannedItemsNotifier.value.contains(rawValue)) return;

        // Otherwise, store it and fire the callback
        scannedItemsNotifier.value = List<String>.from([...scannedItemsNotifier.value, rawValue]);
        widget.onCameraScan?.call(rawValue);

        break;
    }
  }

  Future<void> _popBackWithListResult() async {
    if (_isPopping) return;
    _isPopping = true;

    if (!mounted) return;
    final navigator = Navigator.of(context);

    await _subscription?.cancel();
    await controller.stop();

    navigator.pop<List<String>>(scannedItemsNotifier.value);
  }

  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    print('OnPopInvokedWithResult : $didPop and result:\n$result');

    // If a programmatic pop already happened, we don't need to do anything.
    if (didPop) return;

    // The tripwire
    if (_isPopping) return;
    _isPopping = true;

    if (!mounted) return;
    final navigator = Navigator.of(context);

    await _subscription?.cancel();
    await controller.stop();

    // Now that the hardware is safely dead, route the data!
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

  void _onShowScanListPressed(BuildContext ctx, List<String> list) {
    // TODO later: Open a Modal or temp screen to show the scanned items
    // For now just debugPrinting it to make a point
    debugPrint('Scanned items: $list');
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
