/// Sandbox / Test Matrix for the 9-in-1 scanner configurations.
///
/// This application provides a simple UI to test and verify all nine
/// combinations of visual overlays and data routing modes exposed by
/// the [ScannerScreen] facade.
library;

import 'package:flutter/material.dart';

import 'functions.dart';
import 'scanner_overlay.dart';
import 'scanner_screen.dart';
import 'testing_screen.dart';
import 'pos_barcode_scanner_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner Matrix Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TestingScreen(),
    );
  }
}

class TestMatrixScreen extends StatelessWidget {
  const TestMatrixScreen({super.key});

  void _showResult(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Scanner Sandbox')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'EXPERIMENTAL SCANNERS',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            title: const Text('Go to Test Screen'),
            trailing: const Icon(Icons.qr_code),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TestingScreen(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('POS with qty buttons'),
            trailing: const Icon(Icons.shopping_bag_outlined),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PosBarcodeScannerScreen(
                    onScan: (barcode, qty) {
                      debugPrint('This barcode x times: $barcode x $qty');
                      if (!context.mounted) return;
                      _showResult(context, 'This barcode x times: $barcode x $qty');
                    },
                  ),
                ),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              '1. SINGLE SCAN MODE',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            title: const Text('Single + QR Code'),
            trailing: const Icon(Icons.qr_code),
            onTap: () async {
              final result = await scanQrCode(
                context,
                overlayStyle: const ScannerOverlayStyle(borderColor: Colors.blue),
              );
              debugPrint('✅ Single QR Result: $result');
              if (!context.mounted) return;
              _showResult(context, 'Single QR: $result');
            },
          ),
          ListTile(
            title: const Text('Single + Barcode'),
            trailing: const Icon(Icons.view_column),
            onTap: () async {
              final result = await scanBarcode(
                context,
                overlayStyle: const ScannerOverlayStyle(borderColor: Colors.pink),
              );
              debugPrint('✅ Single Barcode Result: $result');
              if (!context.mounted) return;
              _showResult(context, 'Single Barcode: $result');
            },
          ),
          ListTile(
            title: const Text('Single + Custom'),
            trailing: const Icon(Icons.fullscreen),
            onTap: () async {
              final screenSize = MediaQuery.sizeOf(context);
              final result = await scanCustom(
                context,
                scannerViewConfig: ScannerViewConfig(
                  scanWindow: Rect.fromCenter(center: screenSize.center(Offset.zero), width: 200, height: 200),
                ),
              );
              debugPrint('✅ Single Custom Result: $result');
              if (!context.mounted) return;
              _showResult(context, 'Single Custom: $result');
            },
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              '2. BATCH POP MODE',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
            ),
          ),
          ListTile(
            title: const Text('Batch + QR Code (REJECT Duplicates)'),
            subtitle: const Text('Test cart list button'),
            trailing: const Icon(Icons.qr_code),
            onTap: () async {
              final result = await scanQrCodeBatch(context, allowDuplicates: false);
              debugPrint('🛒 Batch QR Result: $result');
            },
          ),
          ListTile(
            title: const Text('Batch + Barcode (Allow Duplicates)'),
            subtitle: const Text('Scan same item twice to test'),
            trailing: const Icon(Icons.view_column),
            onTap: () async {
              final result = await scanBarcodeBatch(context, allowDuplicates: true);
              debugPrint('🛒 Batch Barcode Result: $result');
            },
          ),
          ListTile(
            title: const Text('Batch + Custom'),
            trailing: const Icon(Icons.fullscreen),
            onTap: () async {
              final screenSize = MediaQuery.sizeOf(context);
              final result = await scanCustomBatch(
                context,
                toolBar: const BatchToolBar(),
                scannerViewConfig: ScannerViewConfig(
                  scanWindow: Rect.fromCenter(center: screenSize.center(Offset.zero), width: 80, height: 300),
                  overlayStyle: const ScannerOverlayStyle(borderColor: Colors.yellow, borderRadius: 40.0),
                ),
              );
              debugPrint('🛒 Batch Custom Result: $result');
            },
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              '3. CALLBACK STREAM MODE',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
          ListTile(
            title: const Text('Stream + QR Code'),
            subtitle: const Text('Watch debug console for real-time prints'),
            trailing: const Icon(Icons.qr_code),
            onTap: () async {
              await scanQrCodeStream(
                context,
                onCameraScan: (qrCode) {
                  debugPrint('🌊 STREAM DETECTED: $qrCode');
                  _showResult(context, 'Stream QR: $qrCode');
                },
              );
            },
          ),
          ListTile(
            title: const Text('Stream + Barcode (REJECT Duplicates)'),
            subtitle: const Text('Scan same item twice to test Reject buzz'),
            trailing: const Icon(Icons.view_column),
            onTap: () async {
              await scanBarcodeStream(
                context,
                allowDuplicates: false,
                onCameraScan: (barcode) {
                  debugPrint('🌊 STREAM DETECTED: $barcode');
                  _showResult(context, 'Stream Barcode: $barcode');
                },
              );
            },
          ),
          ListTile(
            title: const Text('Stream + Custom'),
            trailing: const Icon(Icons.fullscreen),
            onTap: () async {
              await scanCustomStream(
                context,
                onCameraScan: (barcode) {
                  debugPrint('🌊 STREAM DETECTED: $barcode');
                  _showResult(context, 'Stream Custom: $barcode');
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
