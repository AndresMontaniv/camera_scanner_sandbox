import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'scanner_overlay.dart';
import 'scanner_screen.dart';

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
      home: const TestMatrixScreen(),
    );
  }
}

class TestMatrixScreen extends StatelessWidget {
  const TestMatrixScreen({super.key});

  // Our mock hardware reject beep/buzz
  void _playRejectBuzz(String barcode) {
    HapticFeedback.heavyImpact();
    debugPrint('🚨 REJECTED DUPLICATE: $barcode');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('9-in-1 Scanner Matrix Test')),
      body: ListView(
        children: [
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
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerScreen.singleScan(
                    scannerViewConfig: const ScannerViewConfig.qrCode(
                      overlayStyle: ScannerOverlayStyle(borderColor: Colors.blue),
                    ),
                    toolBarConfig: const ToolBarConfig(),
                    onScanRejected: _playRejectBuzz,
                  ),
                ),
              );
              debugPrint('✅ Single QR Result: $result');
            },
          ),
          ListTile(
            title: const Text('Single + Barcode'),
            trailing: const Icon(Icons.view_column),
            onTap: () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerScreen.singleScan(
                    scannerViewConfig: const ScannerViewConfig.barcode(
                      overlayStyle: ScannerOverlayStyle(borderColor: Colors.pink),
                      offsetFromCenter: Offset(0, 100),
                    ),
                    toolBarConfig: const ToolBarConfig(),
                    onScanRejected: _playRejectBuzz,
                  ),
                ),
              );
              debugPrint('✅ Single Barcode Result: $result');
            },
          ),
          ListTile(
            title: const Text('Single + Custom'),
            trailing: const Icon(Icons.fullscreen),
            onTap: () async {
              final screenSize = MediaQuery.sizeOf(context);
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerScreen.singleScan(
                    scannerViewConfig: ScannerViewConfig(
                      scanWindow: Rect.fromCenter(center: screenSize.center(Offset.zero), width: 200, height: 200),
                    ),
                  ),
                ),
              );
              debugPrint('✅ Single Custom Result: $result');
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
            title: const Text('Batch + QR Code (Allow Duplicates)'),
            subtitle: const Text('Test cart list button'),
            trailing: const Icon(Icons.qr_code),
            onTap: () async {
              final result = await Navigator.push<List<String>>(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerScreen.multiScanBatchPop(
                    scannerViewConfig: const ScannerViewConfig.qrCode(),
                    toolBarConfig: const ToolBarConfig.multiscan(),
                    allowDuplicates: false,
                    onScanRejected: _playRejectBuzz,
                  ),
                ),
              );
              debugPrint('🛒 Batch QR Result: $result');
            },
          ),
          ListTile(
            title: const Text('Batch + Barcode (REJECT Duplicates)'),
            subtitle: const Text('Scan same item twice to test Reject buzz'),
            trailing: const Icon(Icons.view_column),
            onTap: () async {
              final result = await Navigator.push<List<String>>(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerScreen.multiScanBatchPop(
                    scannerViewConfig: const ScannerViewConfig.barcode(),
                    toolBarConfig: const ToolBarConfig.multiscan(),
                    allowDuplicates: false,
                    onScanRejected: _playRejectBuzz,
                  ),
                ),
              );
              debugPrint('🛒 Batch Barcode Result: $result');
            },
          ),
          ListTile(
            title: const Text('Batch + Custom'),
            trailing: const Icon(Icons.fullscreen),
            onTap: () async {
              final result = await Navigator.push<List<String>>(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerScreen.multiScanBatchPop(
                    scannerViewConfig: const ScannerViewConfig(),
                    toolBarConfig: const ToolBarConfig.multiscan(),
                  ),
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
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerScreen.multiScanCallbackStream(
                    scannerViewConfig: const ScannerViewConfig.qrCode(),
                    onDetect: (barcode) => debugPrint('🌊 STREAM DETECTED: $barcode'),
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Stream + Barcode (REJECT Duplicates)'),
            subtitle: const Text('Scan same item twice to test Reject buzz'),
            trailing: const Icon(Icons.view_column),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerScreen.multiScanCallbackStream(
                    scannerViewConfig: const ScannerViewConfig.barcode(),
                    allowDuplicates: false,
                    onDetect: (barcode) => debugPrint('🌊 STREAM DETECTED: $barcode'),
                    onScanRejected: _playRejectBuzz,
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Stream + Custom'),
            trailing: const Icon(Icons.fullscreen),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScannerScreen.multiScanCallbackStream(
                    scannerViewConfig: const ScannerViewConfig(),
                    onDetect: (barcode) => debugPrint('🌊 STREAM DETECTED: $barcode'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
