import 'package:flutter/foundation.dart';

class BarcodeScannerController extends ChangeNotifier {
  bool _isCameraActive = false;
  bool _isTransitioning = false;

  bool get isCameraActive => _isCameraActive;
  bool get isTransitioning => _isTransitioning;

  Future<void> Function()? _toggleCallback;

  // Use a Stopwatch to measure exactly how long the hardware takes to boot
  final Stopwatch _stopwatch = Stopwatch();
  final Duration _minUxTransition = const Duration(milliseconds: 500);

  // Used by the View to bind its hardware toggle function
  void attach(Future<void> Function() toggleCallback) {
    _toggleCallback = toggleCallback;
  }

  // Used by the View to sync its hardware state to the outside world
  Future<void> updateState({required bool active, required bool transitioning}) async {
    _isCameraActive = active;

    if (transitioning) {
      // 1. Hardware just started booting up. Lock the button and start the timer.
      _isTransitioning = true;
      _stopwatch
        ..reset()
        ..start();
      notifyListeners();
    } else {
      // 2. Hardware just finished! (Camera is now physically open and scanning)
      _stopwatch.stop();

      // 3. How fast was the hardware?
      final elapsed = _stopwatch.elapsed;

      if (elapsed < _minUxTransition) {
        // Hardware was faster than our 400ms UX floor. Pad the remaining time.
        await Future.delayed(_minUxTransition - elapsed);
      }

      // 4. Minimum time has passed. Unlock the external button.
      _isTransitioning = false;
      notifyListeners();
    }
  }

  // Public method for external buttons to call
  Future<void> toggle() async {
    // Prevent double-calls while already transitioning
    if (_toggleCallback != null && !_isTransitioning) {
      await _toggleCallback!();
    }
  }
}
