import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_view.dart';
import 'circle_button.dart';
import 'scanner_overlay.dart';
import 'flash_toggle_button.dart';

const Offset _barcodeOffset = Offset(0.0, -80.0);
const String _closeButtonText = 'Close Scanner';

class MultiScanBarcodeScreen extends StatefulWidget {
  final bool showQtyControls;
  final bool showFlashButton;
  final int detectionTimeoutMs;
  final int sameItemCooldownMs;
  final String? closeButtonText;
  final ButtonStyle? closeButtonStyle;
  final ScannerOverlayStyle? overlayStyle;
  final List<BarcodeFormat> allowedFormats;
  final void Function(String barcode, int qty)? onCameraScan;
  final Widget Function(BuildContext, int, Widget?)? closeButtonBuilder;

  const MultiScanBarcodeScreen({
    super.key,
    this.overlayStyle,
    this.onCameraScan,
    this.closeButtonText,
    this.closeButtonStyle,
    this.closeButtonBuilder,
    this.showQtyControls = true,
    this.showFlashButton = false,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.allowedFormats = const <BarcodeFormat>[],
  });

  @override
  State<MultiScanBarcodeScreen> createState() => _MultiScanBarcodeScreenState();
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

class _MultiScanBarcodeScreenState extends State<MultiScanBarcodeScreen> with WidgetsBindingObserver {
  late MobileScannerController controller;
  StreamSubscription<BarcodeCapture>? _subscription;

  final ValueNotifier<int> qtyNotifier = ValueNotifier<int>(1);
  final ValueNotifier<int> totalItemsNotifier = ValueNotifier<int>(0);

  final Map<String, int> _cart = {};

  String? _lastScannedCode;
  DateTime? _lastScanTime;

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
      if (capture.barcodes.isEmpty) return;

      final rawValue = capture.barcodes.first.rawValue;
      if (rawValue == null) return;

      if (rawValue == _lastScannedCode && _lastScanTime != null) {
        final elapsed = DateTime.now().difference(_lastScanTime!).inMilliseconds;
        if (elapsed < widget.sameItemCooldownMs) return;
      }

      _lastScannedCode = rawValue;
      _lastScanTime = DateTime.now();

      unawaited(HapticFeedback.heavyImpact());

      _addScannedItem(rawValue);
    });
  }

  void _addScannedItem(String rawValue) {
    final currentQty = qtyNotifier.value;

    // 1. Add or update the cart
    _cart[rawValue] = (_cart[rawValue] ?? 0) + currentQty;

    // 2. Reset the UI multiplier back to 1 for the next scan
    qtyNotifier.value = 1;

    // 3. Update the total items badge mathematically
    totalItemsNotifier.value = _cart.values.fold(0, (sum, qty) => sum + qty);

    // 4. Fire the real-time stream callback if the developer provided it
    widget.onCameraScan?.call(rawValue, currentQty);
  }

  void _popBack() {
    // Return the batch cart data to the parent screen
    Navigator.of(context).pop(_cart);
  }

  @override
  void dispose() {
    qtyNotifier.dispose();
    totalItemsNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScannerView.barcode(
      fit: BoxFit.cover,
      controller: controller,
      useAppLifecycleState: false,
      overlayStyle: widget.overlayStyle,
      offsetFromCenter: _barcodeOffset,
      stackChildren: [
        if (widget.showQtyControls)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<int>(
              valueListenable: qtyNotifier,
              builder: (context, qty, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CircleButton(
                      icon: Icons.remove,
                      onPressed: () {
                        if (qty > 1) qtyNotifier.value--;
                      },
                    ),
                    Text(
                      qty.toString(),
                      style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    CircleButton(
                      icon: Icons.add,
                      onPressed: () {
                        qtyNotifier.value++;
                      },
                    ),
                  ],
                );
              },
            ),
          ),

        SafeArea(
          top: false,
          right: true,
          left: true,
          bottom: true,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15.0, 0.0, 15.0, 45.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: totalItemsNotifier,
                    builder:
                        widget.closeButtonBuilder ??
                        (_, total, _) {
                          return Badge(
                            label: Text(total.toString()),
                            isLabelVisible: total > 0,
                            textStyle: const TextStyle(fontSize: 14.0),
                            padding: const EdgeInsets.all(1.5),
                            child: ElevatedButton(
                              onPressed: _popBack,
                              style:
                                  widget.closeButtonStyle ??
                                  ElevatedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                              child: Text(widget.closeButtonText ?? _closeButtonText),
                            ),
                          );
                        },
                  ),
                  Visibility(
                    visible: widget.showFlashButton,
                    child: FlashToggleButton(controller: controller),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
