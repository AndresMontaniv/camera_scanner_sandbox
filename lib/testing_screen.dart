import 'package:flutter/material.dart';

import 'live_barcode_scanner_widget.dart';

class TestingScreen extends StatefulWidget {
  const TestingScreen({super.key});

  @override
  State<TestingScreen> createState() => _TestingScreenState();
}

class _TestingScreenState extends State<TestingScreen> {
  final List<String> _scannedItems = [];

  void _onScanned(String barcode) {
    _scannedItems.add(barcode);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testing Screen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            LiveBarcodeScannerWidget(
              onBarcodeScanned: _onScanned,
            ),

            // const SizedBox(height: 20.0),
            // ElevatedButton.icon(
            //   onPressed: () {
            //     showDraggableScannerSheet(context, onBarcodeScanned: _onScanned);
            //   },
            //   icon: const Icon(Icons.vertical_align_top),
            //   label: const Text('Open Draggable Bottom Sheet'),
            // ),
            // const SizedBox(height: 20.0),
            // ElevatedButton.icon(
            //   onPressed: () {
            //     showFixedScannerSheet(context, onBarcodeScanned: _onScanned);
            //   },
            //   icon: const Icon(Icons.vertical_shades),
            //   label: const Text('Open Fixed Width Bottom Sheet'),
            // ),
            // const SizedBox(height: 20.0),
            // ElevatedButton.icon(
            //   onPressed: () async {
            //     await scanBarcodeStream(
            //       context,
            //       allowDuplicates: true,
            //       onCameraScan: (barcode) => _onScanned(barcode),
            //     );
            //   },
            //   icon: const Icon(Icons.open_in_full),
            //   label: const Text('Open Full Screen 1D Scanner'),
            // ),
            const Divider(height: 30),
            Text('Scanned Codes: ${_scannedItems.length}', style: const TextStyle(fontSize: 25)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20.0),
                itemCount: _scannedItems.length,
                itemBuilder: (context, index) {
                  return Text(
                    _scannedItems[index],
                    style: const TextStyle(fontSize: 18),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
