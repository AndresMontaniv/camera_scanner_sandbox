import 'package:flutter/foundation.dart';

class BarcodeScannerController extends ChangeNotifier {
  bool _isCameraActive = false;
  bool _isTransitioning = false;

  bool get isCameraActive => _isCameraActive;
  bool get isTransitioning => _isTransitioning;

  Future<void> Function()? _toggleCallback;

  // Used by the View to bind its hardware toggle function
  void attach(Future<void> Function() toggleCallback) {
    _toggleCallback = toggleCallback;
  }

  // Used by the View to sync its hardware state to the outside world
  void updateState({required bool active, required bool transitioning}) {
    _isCameraActive = active;
    _isTransitioning = transitioning;
    notifyListeners();
  }

  // Public method for external buttons (like a SearchBar icon) to call
  Future<void> toggle() async {
    if (_toggleCallback != null) {
      await _toggleCallback!();
    }
  }
}
