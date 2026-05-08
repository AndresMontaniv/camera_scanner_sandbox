import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_overlay.dart';
import 'scanner_screen.dart';

class PosBarcodeScannerScreen extends StatefulWidget {
  final void Function(String barcode, int qty) onScan;
  final List<BarcodeFormat> allowedFormats;
  final int detectionTimeoutMs;
  final int sameItemCooldownMs;
  final bool enableSoundAndVibration;
  final Offset? offsetFromCenter;
  final ScannerOverlayStyle? overlayStyle;

  const PosBarcodeScannerScreen({
    super.key,
    required this.onScan,
    this.allowedFormats = const <BarcodeFormat>[],
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.enableSoundAndVibration = true,
    this.offsetFromCenter,
    this.overlayStyle,
  });

  @override
  State<PosBarcodeScannerScreen> createState() => _PosBarcodeScannerScreenState();
}

class _PosBarcodeScannerScreenState extends State<PosBarcodeScannerScreen> {
  final ValueNotifier<int> qtyNotifier = ValueNotifier<int>(1);
  final ValueNotifier<int> totalItemsNotifier = ValueNotifier<int>(0);
  Map<String, int> scannedBarcodes = {};

  void _onShowScanListPressed() {
    final length = totalItemsNotifier.value;
    final list = scannedBarcodes.entries.toList();
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
                        'Scanned Barcodes ($length)',
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
                if (list.isEmpty)
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
                      itemCount: scannedBarcodes.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final qty = item.value;
                        final barcode = item.key;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade900,
                            child: Text('$qty x'),
                          ),
                          title: Text(
                            barcode,
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

  Widget _buildScanListButton() {
    return ValueListenableBuilder<int>(
      valueListenable: totalItemsNotifier,
      builder: (ctx, total, _) {
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
              onPressed: _onShowScanListPressed,
              icon: const Icon(
                Icons.shopping_cart_checkout_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }

  void _onCameraScan(String barcode) {
    final qty = qtyNotifier.value;
    widget.onScan(barcode, qty);
    scannedBarcodes[barcode] = (scannedBarcodes[barcode] ?? 0) + qty;
    totalItemsNotifier.value += qty;
    // After scan reset qty to 1
    qtyNotifier.value = 1;
  }

  @override
  void dispose() {
    qtyNotifier.dispose();
    totalItemsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScannerScreen.multiscan(
      toolBar: StandardToolBar(
        showSwitchCameraButton: false,
        trailing: [_buildScanListButton()],
      ),
      allowDuplicates: true,
      detectionTimeoutMs: widget.detectionTimeoutMs,
      sameItemCooldownMs: widget.sameItemCooldownMs,
      enableSoundAndVibration: widget.enableSoundAndVibration,
      scannerViewConfig: ScannerViewConfig.barcode(
        overlayStyle: widget.overlayStyle ?? const ScannerOverlayStyle(borderColor: Colors.blue),
        offsetFromCenter: widget.offsetFromCenter,
        allowedFormats: widget.allowedFormats,
      ),
      onCameraScan: _onCameraScan,
      stackChildren: [
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 100,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<int>(
            valueListenable: qtyNotifier,
            builder: (context, qty, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleButton(
                    icon: Icons.remove,
                    onPressed: () {
                      if (qty > 1) qtyNotifier.value--;
                    },
                  ),
                  Text(
                    qty.toString(),
                    style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  _CircleButton(
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
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CircleButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white54,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: Colors.white,
          size: 35,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
