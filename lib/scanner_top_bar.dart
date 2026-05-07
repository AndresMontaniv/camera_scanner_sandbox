part of 'scanner_screen.dart';

const assertMsg =
    'Scanner Package Error: ScannerTopBar must show at least one button (close or flash or camera_toogle). If you want an empty top bar, remove the ScannerTopBar from the widget tree entirely for better performance.';

class ScannerTopBar extends StatelessWidget {
  final ScannerToolBar toolBar;
  final MobileScannerController? controller;
  final void Function()? popBackWithListResult;

  const ScannerTopBar({
    super.key,
    this.controller,
    required this.toolBar,
    this.popBackWithListResult,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: toolBar.alignment,
        child: Padding(
          padding: toolBar.padding,
          child: _buildDefaultLayout(context),
        ),
      ),
    );
  }

  Widget _buildDefaultLayout(BuildContext context) {
    switch (toolBar) {
      case StandardToolBar():
        return _buildStandardToolBar();
      case CustomToolBar():
        final customToolbar = toolBar as CustomToolBar;
        return customToolbar.toolbarBuilder(context, controller);
    }
  }

  Widget _buildStandardToolBar() {
    final standardToolBar = toolBar as StandardToolBar;
    if (!standardToolBar.shouldBuild) {
      return const SizedBox.shrink();
    }
    final showCloseButton = standardToolBar.showCloseButton;
    final showFlashButton = standardToolBar.showFlashButton;
    final showSwitchCameraButton = standardToolBar.showSwitchCameraButton;
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
                    onError: standardToolBar.onActionButtonError,
                  ),
                if (showSwitchCameraButton)
                  _SwitchCameraButton(
                    controller: controller,
                    onError: standardToolBar.onActionButtonError,
                  ),
                ...?standardToolBar.trailing,
              ],
            ),
          ),
      ],
    );
  }
}

class ScannerBatchTopBar extends StatelessWidget {
  final BatchToolBar toolBar;
  final ValueNotifier<List<String>> scannedItemsNotifier;
  final MobileScannerController? controller;
  final void Function()? popBackWithListResult;

  const ScannerBatchTopBar({
    super.key,
    this.controller,
    required this.toolBar,
    required this.scannedItemsNotifier,
    required this.popBackWithListResult,
  });

  /// Default bottom-sheet that displays the list of scanned items.
  /// Used when [onShowScannedListPressed] is not provided by the caller.
  void _onShowScanListPressed(BuildContext context, List<String> scannedItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scanned Items (${scannedItems.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Empty State (Just in case)
                if (scannedItems.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No items scanned yet.',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  )
                // Scrollable List
                else
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: scannedItems.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade900,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            scannedItems[index],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: toolBar.alignment,
        child: Padding(
          padding: toolBar.padding,
          child: _buildDefaultLayout(),
        ),
      ),
    );
  }

  Widget _buildDefaultLayout() {
    if (!toolBar.shouldBuild) {
      return const SizedBox.shrink();
    }
    final showCloseButton = toolBar.showCloseButton;
    final showFlashButton = toolBar.showFlashButton;
    final showSwitchCameraButton = toolBar.showSwitchCameraButton;
    final showBatchButton = toolBar.showScannedListButton;
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
                    onError: toolBar.onActionButtonError,
                  ),
                if (showSwitchCameraButton)
                  _SwitchCameraButton(
                    controller: controller,
                    onError: toolBar.onActionButtonError,
                  ),
                if (showBatchButton)
                  ValueListenableBuilder<List<String>>(
                    valueListenable: scannedItemsNotifier,
                    builder: (ctx, scannedItems, _) {
                      final onShowScannedListPressed = toolBar.onShowScannedListPressed;
                      final listButtonBuilder = toolBar.listButtonBuilder;
                      // If the caller supplied a fully custom builder, hand off to it.
                      if (listButtonBuilder != null) {
                        return listButtonBuilder.call(ctx, scannedItems);
                      }
                      // Otherwise render the default badge-over-icon button.
                      final total = scannedItems.length;
                      return _ScannedItemsButton(
                        total: total,
                        onPressed: () {
                          if (onShowScannedListPressed != null) {
                            onShowScannedListPressed.call(ctx, scannedItems);
                          } else {
                            _onShowScanListPressed(ctx, scannedItems);
                          }
                        },
                      );
                    },
                  ),
                ...?toolBar.trailing,
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

class _ScannedItemsButton extends StatelessWidget {
  final int total;
  final void Function() onPressed;

  const _ScannedItemsButton({
    required this.total,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Badge(
      label: Text(total.toString()),
      isLabelVisible: total > 0,
      textStyle: const TextStyle(fontSize: 14.0),
      padding: const EdgeInsets.all(1.5),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.list, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
