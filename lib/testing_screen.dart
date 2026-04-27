import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:native_haptics_and_audio/native_haptics_and_audio.dart';

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
            const SizedBox(height: 30),
            const Text('Scanned Codes:'),
            Expanded(
              child: ListView.builder(
                itemCount: _scannedItems.length,
                itemBuilder: (context, index) {
                  return Text(_scannedItems[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveBarcodeScannerWidget extends StatefulWidget {
  final double width;
  final double height;
  final void Function(String barcode) onBarcodeScanned;
  final bool enableSoundAndVibration;
  final int sameItemCooldownMs;

  const LiveBarcodeScannerWidget({
    super.key,
    required this.onBarcodeScanned,
    this.width = 300,
    this.height = 130,
    this.enableSoundAndVibration = true,
    this.sameItemCooldownMs = 1500,
  });

  @override
  State<LiveBarcodeScannerWidget> createState() => _LiveBarcodeScannerWidgetState();
}

class _LiveBarcodeScannerWidgetState extends State<LiveBarcodeScannerWidget> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
  );
  StreamSubscription<BarcodeCapture>? _subscription;

  bool _isCameraActive = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  final _effects = NativeHapticsAndAudioRepository.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _controller.barcodes.listen(_onBarcodeDetected);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the camera isn't even active, we don't care about backgrounding.
    if (!_isCameraActive) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _subscription?.pause();
        _controller.stop();
        break;
      case AppLifecycleState.resumed:
        _controller.start();
        _subscription?.resume();
        break;
    }
  }

  void _toggleCamera() {
    if (_isCameraActive) {
      _stopCamera();
    } else {
      _startCamera();
    }
  }

  void _startCamera() async {
    setState(() {
      _isCameraActive = true;
    });
    await _controller.start();
  }

  void _stopCamera() async {
    setState(() {
      _isCameraActive = false;
    });
    await _controller.stop();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null) return;

    // Stream Cooldown Logic (prevents rapid-fire duplicate scans of the same item)
    if (rawValue == _lastScannedCode && _lastScanTime != null) {
      final elapsed = DateTime.now().difference(_lastScanTime!).inMilliseconds;
      if (elapsed < widget.sameItemCooldownMs) return;
    }

    _lastScannedCode = rawValue;
    _lastScanTime = DateTime.now();

    // Trigger Native Hardware Feedback
    if (widget.enableSoundAndVibration) {
      Future.wait([
        _effects.playHaptic(PosHaptic.success),
        _effects.playSound(PosSound.scannerBeep),
      ]);
    }

    // Pass data up to the Cart screen
    widget.onBarcodeScanned(rawValue);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Keep it tight
      children: [
        // 1. The Camera Window (Unobstructed)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: _isCameraActive
                ? MobileScanner(
                    controller: _controller,
                    fit: BoxFit.cover,
                    useAppLifecycleState: false,
                  )
                : Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white24,
                        size: 48,
                      ),
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 12), // Beautiful spacing
        // 2. The External Control Layer
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCameraActive ? Colors.red.shade700 : Colors.blue.shade700,
            foregroundColor: Colors.white,
            minimumSize: Size(widget.width, 48), // Match camera width for symmetry
          ),
          icon: Icon(_isCameraActive ? Icons.stop : Icons.play_arrow),
          label: Text(_isCameraActive ? 'Stop Camera' : 'Start Camera'),
          onPressed: _toggleCamera,
        ),
      ],
    );
  }
}
