import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FlashToggleButton extends StatelessWidget {
  final MobileScannerController? controller;
  final void Function(Object error)? onError;

  const FlashToggleButton({
    super.key,
    this.controller,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return _buildDisabledButton();
    }

    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller!,
      builder: (_, state, _) {
        if (state.torchState == TorchState.unavailable) {
          return _buildDisabledButton();
        }
        final isOn = state.torchState == TorchState.on;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: isOn ? Colors.white : Colors.black45,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isOn ? Icons.flash_on : Icons.flash_off,
              color: isOn ? Colors.black : Colors.white,
              size: 28,
            ),
            onPressed: () async {
              try {
                await controller?.toggleTorch();
              } catch (e) {
                debugPrint('Scanner Package: Failed to toggle torch - $e');
                onError?.call(e);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDisabledButton() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black26,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          Icons.flash_off,
          color: Colors.white24,
          size: 28,
        ),
        onPressed: null,
      ),
    );
  }
}
