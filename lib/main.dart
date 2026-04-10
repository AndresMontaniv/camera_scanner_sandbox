import 'package:flutter/material.dart';

import 'functions.dart';
import 'barcode_scanner_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            children: [
              ListTile(
                title: const Text('Simple QR Scanner'),
                subtitle: const Text('Fixed Square Overlay to point to the QR Code'),
                onTap: () async {
                  final String? scanned = await scanQrCodeWithCamera(context);
                  print('scanned: $scanned');

                  // Developers can use the pre build method that calls the scanner
                  // Or they can write the onTap by themself like so:
                  // final String? scannedCode = await Navigator.push(
                  //   context,
                  //   MaterialPageRoute(builder: (_) => const SingleScanQrCodeScreen()),
                  // );

                  // if (scannedCode != null) {
                  //   debugPrint('Successfully scanned: $scannedCode');
                  // }
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Barcode Scanner Screen'),
                subtitle: const Text('Ultimate version of the UPC barcode scanner'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => BarcodeScannerScreen(
                        showFlashButton: true,
                        showQtyControls: true,
                        onCameraScan: (barcode, qty) {
                          print('Simple Barcode: $barcode  | qty: $qty');
                        },
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Single Barcode Scanner '),
                subtitle: const Text('Scans only one barcode and closes the screen'),
                onTap: () async {
                  final String? scanned = await scanBarcodeWithCamera(context);
                  print('scanned: $scanned');

                  // Developers can use the pre build method that calls the scanner
                  // Or they can write the onTap by themself like so:
                  // final String? scannedCode = await Navigator.push(
                  //   context,
                  //   MaterialPageRoute(builder: (_) => const SingleScanBarcodeScreen()),
                  // );

                  // if (scannedCode != null) {
                  //   debugPrint('Successfully scanned: $scannedCode');
                  // }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
