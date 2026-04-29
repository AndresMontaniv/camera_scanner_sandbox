import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:native_haptics_and_audio/native_haptics_and_audio.dart';
import 'scanner_overlay.dart';

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
              height: 100.0,
              onBarcodeScanned: _onScanned,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return DraggableScrollableSheet(
                      initialChildSize: 0.30,
                      minChildSize: 0.30,
                      maxChildSize: 0.9,
                      snap: true,
                      snapSizes: const [0.30, 0.5, 0.9],
                      builder: (context, scrollController) {
                        return BottomSheetScannerWidget(
                          onBarcodeScanned: _onScanned,
                          scrollController: scrollController,
                        );
                      },
                    );
                  },
                );
              },
              icon: const Icon(Icons.vertical_align_top),
              label: const Text('Open Draggable Bottom Sheet'),
            ),

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

class LiveBarcodeScannerWidget extends StatefulWidget {
  final double width;
  final double height;
  final void Function(String barcode) onBarcodeScanned;
  final bool enableSoundAndVibration;
  final int sameItemCooldownMs;
  final Duration idleTimeout;

  const LiveBarcodeScannerWidget({
    super.key,
    required this.onBarcodeScanned,
    this.width = 300,
    this.height = 130,
    this.enableSoundAndVibration = true,
    this.sameItemCooldownMs = 1500,
    this.idleTimeout = const Duration(seconds: 30),
  });

  @override
  State<LiveBarcodeScannerWidget> createState() => _LiveBarcodeScannerWidgetState();
}

class _LiveBarcodeScannerWidgetState extends State<LiveBarcodeScannerWidget> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    initialZoom: 1.5,
  );
  StreamSubscription<BarcodeCapture>? _subscription;
  Timer? _idleTimer;

  bool _isCameraActive = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  final _effects = NativeHapticsAndAudioRepository.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effects.initialize();
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
        _cancelIdleTimer();
        _subscription?.pause();
        _controller.stop();
        break;
      case AppLifecycleState.resumed:
        _controller.start();
        _subscription?.resume();
        _resetIdleTimer();
        break;
    }
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
  }

  void _resetIdleTimer() {
    _cancelIdleTimer();
    if (_isCameraActive) {
      _idleTimer = Timer(widget.idleTimeout, _stopCamera);
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
    _resetIdleTimer();
  }

  void _stopCamera() async {
    setState(() {
      _isCameraActive = false;
    });
    _cancelIdleTimer();
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

    _resetIdleTimer();

    // Pass data up to the Cart screen
    widget.onBarcodeScanned(rawValue);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelIdleTimer();
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
            child: Container(
              color: Colors.black, // Kills the white flash
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isCameraActive
                    ? MobileScanner(
                        key: const ValueKey('scanner'),
                        controller: _controller,
                        fit: BoxFit.cover,
                        useAppLifecycleState: false,
                      )
                    : Container(
                        key: const ValueKey('placeholder'),
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

class BottomSheetScannerWidget extends StatefulWidget {
  final void Function(String barcode) onBarcodeScanned;
  final ScrollController scrollController;
  final int sameItemCooldownMs;

  const BottomSheetScannerWidget({
    super.key,
    required this.onBarcodeScanned,
    required this.scrollController,
    this.sameItemCooldownMs = 1500,
  });

  @override
  State<BottomSheetScannerWidget> createState() => _BottomSheetScannerWidgetState();
}

class _BottomSheetScannerWidgetState extends State<BottomSheetScannerWidget> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
  );
  StreamSubscription<BarcodeCapture>? _subscription;

  String? _lastScannedCode;
  DateTime? _lastScanTime;

  final _effects = NativeHapticsAndAudioRepository.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effects.initialize();
    _controller.start();
    _subscription = _controller.barcodes.listen(_onBarcodeDetected);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null) return;

    if (rawValue == _lastScannedCode && _lastScanTime != null) {
      final elapsed = DateTime.now().difference(_lastScanTime!).inMilliseconds;
      if (elapsed < widget.sameItemCooldownMs) return;
    }

    _lastScannedCode = rawValue;
    _lastScanTime = DateTime.now();

    Future.wait([
      _effects.playHaptic(PosHaptic.success),
      _effects.playSound(PosSound.scannerBeep),
    ]);

    widget.onBarcodeScanned(rawValue);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _controller
      ..stop()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: widget.scrollController,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    fit: BoxFit.cover,
                    useAppLifecycleState: false,
                    overlayBuilder: (context, scannerConstraints) {
                      final size = scannerConstraints.biggest;
                      final scanWindow = Rect.fromCenter(
                        center: size.center(Offset.zero),
                        width: 280.0,
                        height: 100.0,
                      );
                      return ScannerOverlay(
                        scanWindow: scanWindow,
                        constraints: scannerConstraints,
                      );
                    },
                  ),
                  // Floating Drag Handle
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white54,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
