import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'circle_close_button.dart';
import 'flash_toggle_button.dart';

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
        if (showCloseButton) const CircleCloseButton(),
        if (showFlashButton)
          FlashToggleButton(
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
