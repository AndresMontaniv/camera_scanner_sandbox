import 'package:flutter/material.dart';

import 'scanner_overlay.dart';
import 'scanner_screen.dart';

class PosBarcodeScannerScreen extends StatefulWidget {
  const PosBarcodeScannerScreen({super.key});

  @override
  State<PosBarcodeScannerScreen> createState() => _PosBarcodeScannerScreenState();
}

class _PosBarcodeScannerScreenState extends State<PosBarcodeScannerScreen> {
  final ValueNotifier<int> qtyNotifier = ValueNotifier<int>(1);

  @override
  Widget build(BuildContext context) {
    return ScannerScreen.multiscan(
      scannerViewConfig: const ScannerViewConfig.barcode(
        overlayStyle: ScannerOverlayStyle(borderColor: Colors.blue),
      ),
      onCameraScan: (barcode) {
        // barcode scan result
        print('Barcode: $barcode');
        final qty = qtyNotifier.value;
        // Here we can call the new method for now just a print
        // later we will call `widget.onScan(barcode, qty)`
        print('This barcode x times: $barcode x $qty');
      },
      stackChildren: [
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
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  const _CircleButton({
    required this.icon,
    this.iconColor = Colors.white,
    this.backgroundColor = Colors.black45,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: iconColor,
          size: 28,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
