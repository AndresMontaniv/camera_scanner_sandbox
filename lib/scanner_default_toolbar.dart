part of 'scanner_screen.dart';

// ─── Layout Constants ───────────────────────────────────────────────────────
// Default vertical offsets that nudge the scan-window overlay upward from the
// screen center, accounting for visual balance with the toolbar at the top.
const Offset _qrOffset = Offset(0.0, -50.0);
const Offset _barcodeOffset = Offset(0.0, -80.0);

// ─── Barcode Format Allow-List ──────────────────────────────────────────────
/// The canonical set of horizontal 1D barcode symbologies commonly found on
/// retail and warehouse products.  Used as the default format list when the
/// caller selects [ScannerViewConfig.barcode] without specifying a custom
/// subset.  Keeping this explicit (instead of an empty list which means
/// "accept all") prevents the controller from wasting decode cycles on 2D
/// matrix codes when the overlay is clearly a horizontal strip.
const List<BarcodeFormat> _horizontal1DFormats = [
  BarcodeFormat.code128,
  BarcodeFormat.code39,
  BarcodeFormat.code93,
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.itf14,
  BarcodeFormat.codabar,
];

// ─── Default Toolbar Widget ─────────────────────────────────────────────────

/// Internal toolbar widget rendered at the top of the scanner overlay.
///
/// Contains up to three elements:
/// * **Close button** (leading) — triggers [_popBackWithListResult] for a
///   safe hardware shutdown + pop.
/// * **Flash toggle** (trailing) — toggles the device torch via the
///   [MobileScannerController].
/// * **Scanned list badge** (trailing) — shows the count of scanned items;
///   tapping it opens a bottom sheet (or fires the caller's custom handler).
class _DefaultToolBar extends StatelessWidget {
  final ToolBarConfig? config;
  final MobileScannerController? controller;
  final ValueNotifier<List<String>> scannedItemsNotifier;
  final void Function()? popBackWithListResult;

  const _DefaultToolBar({
    required this.config,
    required this.controller,
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
    final onShowScannedListPressed = config?.onShowScannedListPressed;
    return ScannerTopBar.custom(
      leading: config.showCloseButton ? _CircleCloseButton(pop: popBackWithListResult) : null,
      trailing: [
        Visibility(
          visible: config.showFlashButton,
          child: _FlashToggleButton(controller: controller),
        ),
        Visibility(
          visible: config.showScannedListButton,
          child: ValueListenableBuilder<List<String>>(
            valueListenable: scannedItemsNotifier,
            builder: (ctx, scannedItems, _) {
              final showScannedListBuilder = config?.showScannedListBuilder;
              // If the caller supplied a fully custom builder, hand off to it.
              if (showScannedListBuilder != null) {
                return showScannedListBuilder.call(ctx, scannedItems);
              }
              // Otherwise render the default badge-over-icon button.
              final total = scannedItems.length;
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
                    onPressed: () => onShowScannedListPressed != null
                        ? onShowScannedListPressed.call(ctx, scannedItems)
                        : _onShowScanListPressed(ctx, scannedItems),
                    icon: const Icon(Icons.list, color: Colors.white, size: 28),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
