part of 'scanner_screen.dart';

const assertMsg =
    'Scanner Package Error: ScannerTopBar must show at least one button (close or flash). If you want an empty top bar, remove the ScannerTopBar from the widget tree entirely for better performance.';

class ScannerTopBar extends StatelessWidget {
  // Shared Properties
  final EdgeInsetsGeometry padding;
  final bool _isCustom;

  // Default Constructor Properties
  final bool showFlashButton;
  final bool showCloseButton;
  final bool showSwitchCameraButton;
  final MobileScannerController? controller;
  final void Function(Object error)? onActionError;
  final void Function()? popBackWithListResult;

  // Custom Constructor Properties
  final Widget? child;
  final List<Widget>? trailing;

  final AlignmentGeometry alignment;

  /// The highly opinionated, pre-built top bar.
  /// Includes a close button and an optional flash toggle.
  const ScannerTopBar({
    super.key,
    required this.controller,
    this.onActionError,
    this.showFlashButton = true,
    this.showCloseButton = true,
    this.showSwitchCameraButton = true,
    this.trailing,
    this.popBackWithListResult,
    this.padding = const EdgeInsets.all(16.0),
    this.alignment = Alignment.topCenter,
  }) : assert(showCloseButton || showFlashButton || showSwitchCameraButton, assertMsg),
       _isCustom = false,
       child = null;

  /// The unopinionated, custom top bar.
  /// Allows passing arbitrary widgets to the leading and trailing edges.
  const ScannerTopBar.builder({
    super.key,
    this.child,
    this.controller,
    this.alignment = Alignment.topCenter,
    this.padding = const EdgeInsets.all(16.0),
  }) : _isCustom = true,
       trailing = null,
       popBackWithListResult = null,
       showFlashButton = false,
       showCloseButton = false,
       showSwitchCameraButton = false,
       onActionError = null;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: padding,
          // Route to the highly-optimized default, or the flexible custom layout
          child: _isCustom ? child : _buildDefaultLayout(),
        ),
      ),
    );
  }

  Widget _buildDefaultLayout() {
    if (!showCloseButton && !showFlashButton && !showSwitchCameraButton) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Default close button
        Visibility(
          visible: showCloseButton,
          child: _CircleCloseButton(pop: popBackWithListResult),
        ),
        // Default trailing widgets
        if (showFlashButton || showSwitchCameraButton)
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12.0,
              runSpacing: 12.0,
              children: [
                if (showFlashButton)
                  _FlashToggleButton(
                    controller: controller,
                    onError: onActionError,
                  ),
                if (showSwitchCameraButton)
                  _SwitchCameraButton(
                    controller: controller,
                    onError: onActionError,
                  ),
                ...?trailing,
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Private Toolbar Buttons ────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  const _CircleButton({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: iconColor,
          size: 28,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _CircleCloseButton extends StatelessWidget {
  final void Function()? pop;
  const _CircleCloseButton({this.pop});

  @override
  Widget build(BuildContext context) {
    return _CircleButton(
      icon: Icons.close,
      iconColor: Colors.white,
      backgroundColor: Colors.black45,
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          if (pop != null) {
            pop?.call();
          } else {
            Navigator.of(context).pop();
          }
        } else {
          debugPrint('CircleCloseButton: No routes to pop');
        }
      },
    );
  }
}

class _DisabledFlashButton extends StatelessWidget {
  final IconData icon;
  const _DisabledFlashButton({required this.icon});
  const _DisabledFlashButton.flash() : icon = Icons.flash_off;
  const _DisabledFlashButton.camera() : icon = Icons.camera_alt_outlined;

  @override
  Widget build(BuildContext context) {
    return _CircleButton(
      icon: icon,
      iconColor: Colors.white24,
      backgroundColor: Colors.black26,
      onPressed: null,
    );
  }
}

class _FlashToggleButton extends StatelessWidget {
  final MobileScannerController? controller;
  final void Function(Object error)? onError;

  const _FlashToggleButton({this.controller, this.onError});

  @override
  Widget build(BuildContext context) {
    const disableButton = _DisabledFlashButton.flash();
    if (controller == null) {
      return disableButton;
    }

    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller!,
      builder: (_, state, _) {
        if (state.torchState == TorchState.unavailable) {
          return disableButton;
        }
        final isOn = state.torchState == TorchState.on;
        return _CircleButton(
          icon: isOn ? Icons.flash_on : Icons.flash_off,
          iconColor: isOn ? Colors.black : Colors.white,
          backgroundColor: isOn ? Colors.white : Colors.black45,
          onPressed: () async {
            try {
              await controller?.toggleTorch();
            } catch (e) {
              debugPrint('Scanner Package: Failed to toggle torch - $e');
              onError?.call(e);
            }
          },
        );
      },
    );
  }
}

class _SwitchCameraButton extends StatelessWidget {
  final MobileScannerController? controller;
  final void Function(Object error)? onError;

  const _SwitchCameraButton({this.controller, this.onError});

  @override
  Widget build(BuildContext context) {
    const disableButton = _DisabledFlashButton.camera();
    if (controller == null) {
      return disableButton;
    }
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller!,
      builder: (_, state, _) {
        if (!state.isInitialized) {
          return disableButton;
        }
        final isBack = state.cameraDirection == CameraFacing.back;
        return _CircleButton(
          icon: isBack ? Icons.camera_front : Icons.cameraswitch_outlined,
          iconColor: Colors.white,
          backgroundColor: Colors.black45,
          onPressed: () async {
            try {
              await controller?.switchCamera();
            } catch (e) {
              debugPrint('Scanner Package: Failed to switch camera - $e');
              onError?.call(e);
            }
          },
        );
      },
    );
  }
}
