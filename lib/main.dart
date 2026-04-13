import 'package:flutter/material.dart';

import 'functions.dart';

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
                title: const Text('Single Scan QR Code'),
                subtitle: const Text('Scans only one QR code and closes the screen'),
                onTap: () async {
                  final String? scanned = await scanQrCodeWithCamera(context);
                  debugPrint('scanned: $scanned');

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
                title: const Text('Single Barcode Scanner '),
                subtitle: const Text('Scans only one barcode and closes the screen'),
                onTap: () async {
                  final String? scanned = await scanBarcodeWithCamera(context);
                  debugPrint('scanned: $scanned');

                  // Developers can use the pre build method that calls the scanner
                  // Or they can write the onTap by themself like so:
                  // final String? scannedCode = await Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (_) => const SingleScanBarcodeScreen(
                  //       allowedFormats: [BarcodeFormat.ean13],
                  //       overlayStyle: ScannerOverlayStyle(borderColor: Colors.green),
                  //     ),
                  //   ),
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
