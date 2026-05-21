import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoTextField, OverlayVisibilityMode;

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
                  child: IconButton(
                    onPressed: () {
                      // Here is where we will toggle the LiveBarcodeScanner widget from ON or OFF
                    },
                    icon: const Icon(Icons.barcode_reader),
                    style: ButtonStyle(
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          side: const BorderSide(color: Colors.black45),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      visualDensity: VisualDensity.comfortable,
                      backgroundColor: const WidgetStatePropertyAll(Colors.white),
                    ),
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
