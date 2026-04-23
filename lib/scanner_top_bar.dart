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
  final MobileScannerController? controller;
  final void Function(Object error)? onFlashButtonError;

  // Custom Constructor Properties
  final Widget? leading;
  final List<Widget>? trailing;

  /// The highly opinionated, pre-built top bar.
  /// Includes a close button and an optional flash toggle.
  const ScannerTopBar({
    super.key,
    required MobileScannerController this.controller,
    this.onFlashButtonError,
    this.showFlashButton = true,
    this.showCloseButton = true,
    this.padding = const EdgeInsets.all(16.0),
  }) : assert(showCloseButton || showFlashButton, assertMsg),
       _isCustom = false,
       leading = null,
       trailing = null;

  /// The unopinionated, custom top bar.
  /// Allows passing arbitrary widgets to the leading and trailing edges.
  const ScannerTopBar.custom({
    super.key,
    this.padding = const EdgeInsets.all(16.0),
    this.leading,
    this.trailing,
  }) : _isCustom = true,
       showFlashButton = false,
       showCloseButton = false,
       controller = null,
       onFlashButtonError = null;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      left: true,
      right: true,
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: padding,
          // Route to the highly-optimized default, or the flexible custom layout
          child: _isCustom ? _buildCustomLayout() : _buildDefaultLayout(),
        ),
      ),
    );
  }

  /// Extremely fast layout for exactly 2 predictable widgets
  Widget _buildDefaultLayout() {
    if (!showCloseButton && !showFlashButton) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showCloseButton) const _CircleCloseButton(),
        if (showFlashButton)
          _FlashToggleButton(
            controller: controller,
            onError: onFlashButtonError,
          ),
      ],
    );
  }

  /// Flexible layout that prevents overflow crashes with multiple trailing widgets
  Widget _buildCustomLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading ?? const SizedBox.shrink(),
        if (trailing != null && trailing!.isNotEmpty)
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12.0,
              runSpacing: 12.0,
              children: trailing!,
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
  const _DisabledFlashButton();

  @override
  Widget build(BuildContext context) {
    return const _CircleButton(
      icon: Icons.flash_off,
      iconColor: Colors.white24,
      backgroundColor: Colors.black26,
    );
  }
}

class _FlashToggleButton extends StatelessWidget {
  final MobileScannerController? controller;
  final void Function(Object error)? onError;

  const _FlashToggleButton({
    this.controller,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    if (controller == null) {
      return const _DisabledFlashButton();
    }

    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller!,
      builder: (_, state, _) {
        if (state.torchState == TorchState.unavailable) {
          return const _DisabledFlashButton();
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
