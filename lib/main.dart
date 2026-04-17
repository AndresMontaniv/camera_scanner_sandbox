import 'package:flutter/material.dart';

import 'dx_scanner_screen.dart';
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
                title: const Text('DxScannerScreen  - QR Code'),
                subtitle: const Text('Scans only one QR code and closes the screen'),
                onTap: () async {
                  final String? scanned = await scanQrCodeWithCamera(context);
                  debugPrint('scanned: $scanned');
                },
              ),

              const Divider(),
              ListTile(
                title: const Text('DxScannerScreen - barcode'),
                subtitle: const Text('Scans only one barcode and closes the screen'),
                onTap: () async {
                  final String? scanned = await scanBarcodeWithCamera(context);
                  debugPrint('scanned: $scanned');
                },
              ),

              const Divider(),
              ListTile(
                title: const Text('DxScannerScreen  - Stream/Callback'),
                subtitle: const Text('Stream/Callback Version'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DxScannerScreen.callbackStreamBarcode(
                        showFlashButton: true,
                        showCloseButton: true,
                        showScannedListButton: true,
                        onDetect: (barcode) {
                          print('Stream Multi Scan: $barcode');
                        },
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('DxScannerScreen  - Single Scan'),
                subtitle: const Text('Single Scan Pop Version'),
                onTap: () async {
                  final String? scanned = await scanBarcodeSingleScan(context);
                  debugPrint('scanned: $scanned');
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('DxScannerScreen  - Batch'),
                subtitle: const Text('Batch Version'),
                onTap: () async {
                  final List<String>? scannedItems = await multiScanBarcode(context);
                  debugPrint('scanned: $scannedItems');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
