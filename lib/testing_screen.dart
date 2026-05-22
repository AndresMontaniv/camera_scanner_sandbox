import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoTextField, OverlayVisibilityMode;

import 'inline_scanner/inline_scanner.dart';

class TestingScreen extends StatefulWidget {
  const TestingScreen({super.key});

  @override
  State<TestingScreen> createState() => _TestingScreenState();
}

class _TestingScreenState extends State<TestingScreen> {
  final List<String> _scannedItems = [];
  final BarcodeScannerController _scannerController = BarcodeScannerController();

  // Pre-compiled shape (Finding #2 — avoid allocation on every ListenableBuilder rebuild)
  static final _scannerButtonShape = WidgetStateProperty.all(
    RoundedRectangleBorder(
      side: const BorderSide(color: Colors.black45),
      borderRadius: BorderRadius.circular(10.0),
    ),
  );

  void _onScanned(String barcode) {
    _scannedItems.add(barcode);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
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
            BarcodeScannerView(
              controller: _scannerController,
              showToggleButton: false,
              onBarcodeScanned: _onScanned,
            ),
            const Divider(height: 50),
            Row(
              children: [
                const Expanded(
                  child: CupertinoTextField(
                    readOnly: true,
                    placeholder: 'Search Products',
                    keyboardType: TextInputType.number,
                    clearButtonMode: OverlayVisibilityMode.editing,
                    prefix: Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(
                        Icons.search,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                ),
                //
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ListenableBuilder(
                    listenable: _scannerController,
                    builder: (context, _) {
                      final isActive = _scannerController.isCameraActive;
                      final isTransitioning = _scannerController.isTransitioning;

                      return IconButton(
                        onPressed: isTransitioning ? null : _scannerController.toggle,
                        icon: isTransitioning
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(isActive ? Icons.close : Icons.barcode_reader),
                        style: ButtonStyle(
                          shape: _scannerButtonShape,
                          visualDensity: VisualDensity.comfortable,
                          backgroundColor: WidgetStatePropertyAll(isActive ? Colors.red.shade100 : Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
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
