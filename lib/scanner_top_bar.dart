part of 'scanner_screen.dart';

const assertMsg =
    'Scanner Package Error: ScannerTopBar must show at least one button (close or flash or camera_toogle). If you want an empty top bar, remove the ScannerTopBar from the widget tree entirely for better performance.';

class _ScannerTopBar extends StatelessWidget {
  final ScannerToolBar toolBar;
  final MobileScannerController? controller;
  final void Function()? popBackWithListResult;

  const _ScannerTopBar({
    required this.toolBar,
    this.controller,
    this.popBackWithListResult,
  });

  @override
  Widget build(BuildContext context) {
    return _ToolBarLayoutShell(
      config: toolBar,
      child: switch (toolBar) {
        CustomToolBar custom => custom.toolbarBuilder(context, controller),
        BatchToolBar _ => throw StateError(
          'Scanner Package Error: You passed a BatchToolBar to ScannerTopBar. '
          'Use ScannerTopBar instead.',
        ),
        StandardToolBar standard => _SharedButtonsRow(
          config: standard,
          controller: controller,
          popBackWithListResult: popBackWithListResult,
        ),
      },
    );
  }
}

class _ScannerBatchTopBar extends StatelessWidget {
  final BatchToolBar toolBar;
  final ValueNotifier<List<String>> scannedItemsNotifier;
  final MobileScannerController? controller;
  final void Function()? popBackWithListResult;

  const _ScannerBatchTopBar({
    required this.toolBar,
    required this.scannedItemsNotifier,
    this.controller,
    this.popBackWithListResult,
  });

  @override
  Widget build(BuildContext context) {
    return _ToolBarLayoutShell(
      config: toolBar,
      child: _SharedButtonsRow(
        config: toolBar,
        controller: controller,
        popBackWithListResult: popBackWithListResult,
        extraTrailingWidget: _SmartCartButton(toolBar: toolBar, notifier: scannedItemsNotifier),
      ),
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

class _ToolBarLayoutShell extends StatelessWidget {
  final ScannerToolBar config;
  final Widget child;

  const _ToolBarLayoutShell({required this.config, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!config.shouldBuild) return const SizedBox.shrink();

    return SafeArea(
      child: Align(
        alignment: config.alignment,
        child: Padding(
          padding: config.padding,
          child: child,
        ),
      ),
    );
  }
}

class _SharedButtonsRow extends StatelessWidget {
  final StandardToolBar config;
  final MobileScannerController? controller;
  final Widget? extraTrailingWidget;
  final void Function()? popBackWithListResult;

  const _SharedButtonsRow({
    required this.config,
    this.controller,
    this.extraTrailingWidget,
    this.popBackWithListResult,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Visibility(
          visible: config.showCloseButton,
          child: _CircleCloseButton(pop: popBackWithListResult),
        ),
        if (config.showFlashButton || config.showSwitchCameraButton || extraTrailingWidget != null)
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12.0,
              runSpacing: 12.0,
              children: [
                if (config.showFlashButton) _FlashToggleButton(controller: controller, onError: config.onActionButtonError),
                if (config.showSwitchCameraButton) _SwitchCameraButton(controller: controller, onError: config.onActionButtonError),
                ?extraTrailingWidget,
                ...?config.trailing,
              ],
            ),
          ),
      ],
    );
  }
}

class _SmartCartButton extends StatelessWidget {
  final BatchToolBar toolBar;
  final ValueNotifier<List<String>> notifier;

  const _SmartCartButton({
    required this.toolBar,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Should we even build it?
    if (!toolBar.showScannedListButton) return const SizedBox.shrink();

    // 2. Listen to the barcode stream
    return ValueListenableBuilder<List<String>>(
      valueListenable: notifier,
      builder: (ctx, scannedItems, _) {
        // 3. Did the dev provide a fully custom button?
        if (toolBar.listButtonBuilder != null) {
          return toolBar.listButtonBuilder!.call(ctx, scannedItems);
        }

        // 4. Fallback to our native badge button
        return _ScannedItemsButton(
          total: scannedItems.length,
          onPressed: () {
            if (toolBar.onShowScannedListPressed != null) {
              // Custom bottom sheet / routing
              toolBar.onShowScannedListPressed!.call(ctx, scannedItems);
            } else {
              // Native bottom sheet
              _showDefaultBottomSheet(ctx, scannedItems);
            }
          },
        );
      },
    );
  }

  void _showDefaultBottomSheet(BuildContext context, List<String> scannedItems) {
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

                // Empty State
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
}
