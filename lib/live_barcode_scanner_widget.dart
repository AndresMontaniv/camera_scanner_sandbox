import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:native_haptics_and_audio/native_haptics_and_audio.dart';

class LiveBarcodeScannerWidget extends StatefulWidget {
  final double maxWidth;
  final void Function(String barcode) onBarcodeScanned;
  final bool enableSoundAndVibration;
  final int sameItemCooldownMs;
  final Duration idleTimeout;

  const LiveBarcodeScannerWidget({
    super.key,
    required this.onBarcodeScanned,
    this.maxWidth = 400.0,
    this.enableSoundAndVibration = true,
    this.sameItemCooldownMs = 1500,
    this.idleTimeout = const Duration(seconds: 30),
  }) : assert(
         maxWidth >= 200.0 && maxWidth <= 600.0,
         'LiveBarcodeScannerWidget: maxWidth must be between 200.0 and 600.0 to ensure scanning performance.',
       );

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
  bool _isTransitioning = false;
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
      _idleTimer = Timer(widget.idleTimeout, _toggleCamera);
    }
  }

  void _toggleCamera() {
    if (_isTransitioning) return;
    if (_isCameraActive) {
      _stopCamera();
    } else {
      _startCamera();
    }
  }

  void _startCamera() async {
    setState(() => _isTransitioning = true);
    await _controller.start();
    if (!mounted) return;
    setState(() {
      _isCameraActive = true;
      _isTransitioning = false;
    });
    _resetIdleTimer();
  }

  static const _animationDuration = Duration(milliseconds: 300);

  void _stopCamera() async {
    setState(() => _isTransitioning = true);
    setState(() => _isCameraActive = false);
    // Let the AnimatedSize collapse before killing the hardware.
    await Future.delayed(_animationDuration);
    _cancelIdleTimer();
    await _controller.stop();
    if (!mounted) return;
    setState(() => _isTransitioning = false);
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
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate the perfectly locked dimensions
            final double currentWidth = constraints.maxWidth;
            final double cameraHeight = currentWidth / 2.5;

            return Column(
              mainAxisSize: MainAxisSize.min, // Keep it tight
              children: [
                // 1. The Camera Window – expands from 0 → cameraHeight
                // MARK: - Camera Window
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRect(
                    child: AnimatedContainer(
                      duration: _animationDuration,
                      curve: Curves.easeInOut,
                      height: _isCameraActive ? cameraHeight : 0,
                      width: currentWidth,
                      // OverflowBox prevents the camera feed from squishing during the animation.
                      // It acts like a window blind smoothly revealing the full-size feed.
                      child: OverflowBox(
                        minHeight: cameraHeight,
                        maxHeight: cameraHeight,
                        alignment: Alignment.topCenter,
                        child: MobileScanner(
                          key: const ValueKey('scanner'),
                          fit: BoxFit.cover,
                          controller: _controller,
                          useAppLifecycleState: false,
                          scanWindow: Rect.fromLTWH(0, 0, currentWidth, cameraHeight),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                // 2. The External Control Layer
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCameraActive ? Colors.red.shade700 : Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: Size(currentWidth, 48),
                  ),
                  icon: _isTransitioning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_isCameraActive ? Icons.stop : Icons.play_arrow),
                  label: _isTransitioning ? const SizedBox.shrink() : Text(_isCameraActive ? 'Stop Camera' : 'Start Camera'),
                  onPressed: _isTransitioning ? null : _toggleCamera,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
