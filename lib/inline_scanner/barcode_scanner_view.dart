import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:native_haptics_and_audio/native_haptics_and_audio.dart';

import 'barcode_scanner_controller.dart';

// The Enhanced Theme Enum
enum ActionButtonTheme {
  light,
  dark
  ; // <-- Semicolon is required here before declaring methods

  // Encapsulated const styling
  ButtonStyle get buttonStyle {
    switch (this) {
      case ActionButtonTheme.light:
        return const ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(Color(0xD9FFFFFF)), // 85% White
          iconColor: WidgetStatePropertyAll(Colors.black54),
        );
      case ActionButtonTheme.dark:
        return const ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(Colors.black54),
          iconColor: WidgetStatePropertyAll(Color(0xD9FFFFFF)),
        );
    }
  }
}

class BarcodeScannerView extends StatefulWidget {
  final double maxWidth;
  final void Function(String barcode) onBarcodeScanned;
  final bool enableSoundAndVibration;
  final int sameItemCooldownMs;
  final Duration idleTimeout;
  final BarcodeScannerController? controller;
  final bool showToggleButton;
  final ActionButtonTheme actionButtonTheme;

  const BarcodeScannerView({
    super.key,
    required this.onBarcodeScanned,
    this.maxWidth = 400.0,
    this.enableSoundAndVibration = true,
    this.sameItemCooldownMs = 1500,
    this.idleTimeout = const Duration(seconds: 90),
    this.controller,
    this.showToggleButton = true,
    this.actionButtonTheme = ActionButtonTheme.light,
  }) : assert(
         maxWidth >= 200.0 && maxWidth <= 600.0,
         'BarcodeScannerView: maxWidth must be between 200.0 and 600.0 to ensure scanning performance.',
       );

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> with WidgetsBindingObserver {
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
  final Stopwatch _cooldownWatch = Stopwatch();

  final _effects = NativeHapticsAndAudioRepository.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effects.initialize();
    _subscription = _controller.barcodes.listen(_onBarcodeDetected);
    widget.controller?.attach(_toggleCamera);
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
        unawaited(_controller.stop());
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

  static const _animationDuration = Duration(milliseconds: 300);

  // Pre-compiled button styles (Finding #7 — avoid allocation on every rebuild)
  static final _activeToggleStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.red.shade700,
    foregroundColor: Colors.white,
  );
  static final _inactiveToggleStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.blue.shade700,
    foregroundColor: Colors.white,
  );

  Future<void> _toggleCamera() async {
    if (_isTransitioning) return;
    setState(() => _isTransitioning = true);
    widget.controller?.updateState(active: _isCameraActive, transitioning: true);

    if (_isCameraActive) {
      // Shutting down
      setState(() => _isCameraActive = false);
      widget.controller?.updateState(active: false, transitioning: true);
      await Future.delayed(_animationDuration); // Wait for window blind to close

      if (!mounted) return; // Guard: Did user leave screen during animation?
      await _controller.stop();
      _idleTimer?.cancel();
    } else {
      // Starting up
      await _controller.start();

      if (!mounted) return; // Guard: Did user leave screen while hardware booted?
      setState(() => _isCameraActive = true);
      widget.controller?.updateState(active: true, transitioning: true);
      _resetIdleTimer();
    }

    if (mounted) {
      setState(() => _isTransitioning = false);
      await widget.controller?.updateState(active: _isCameraActive, transitioning: false);
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null) return;

    // Stream Cooldown Logic (prevents rapid-fire duplicate scans of the same item)
    if (rawValue == _lastScannedCode && _cooldownWatch.isRunning) {
      if (_cooldownWatch.elapsedMilliseconds < widget.sameItemCooldownMs) return;
    }

    _lastScannedCode = rawValue;
    _cooldownWatch
      ..reset()
      ..start();

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
                      child: Stack(
                        children: [
                          // 1. The Camera Hardware (Pushed to background)
                          Positioned.fill(
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

                          // 2. The Minimalist Overlay
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: AnimatedOpacity(
                              opacity: (_isCameraActive && !_isTransitioning) ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 150),
                              child: IgnorePointer(
                                ignoring: !_isCameraActive || _isTransitioning,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Close 'X' Button
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      style: widget.actionButtonTheme.buttonStyle,
                                      onPressed: _toggleCamera,
                                    ),
                                    // Flashlight Toggle (Micro-rebuilds only when tapped)
                                    ValueListenableBuilder<MobileScannerState>(
                                      valueListenable: _controller,
                                      builder: (context, state, child) {
                                        return IconButton(
                                          icon: Icon(
                                            state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                                          ),
                                          style: widget.actionButtonTheme.buttonStyle,
                                          onPressed: () => _controller.toggleTorch(),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (widget.showToggleButton) ...[
                  const SizedBox(height: 12),
                  // 2. The External Control Layer
                  ElevatedButton.icon(
                    style: (_isCameraActive ? _activeToggleStyle : _inactiveToggleStyle).copyWith(
                      minimumSize: WidgetStatePropertyAll(Size(currentWidth, 48)),
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
              ],
            );
          },
        ),
      ),
    );
  }
}
