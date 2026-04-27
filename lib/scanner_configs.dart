part of 'scanner_screen.dart';

/// Internal routing mode enum — set once by the named constructor and never
/// changed. The `_ScannerScreenState` switches on this to decide how to
/// route scanned data (pop a single value, accumulate a batch, or stream).
enum _ScanMode { single, multiscan }

// ─── Configuration Object: ToolBarConfig ─────────────────────────────

/// **Configuration Object Pattern** — encapsulates every toolbar-related
/// parameter into a single object so the main [ScannerScreen] constructors
/// stay clean and free of parameter bloat.
///
/// Two factory shapes are provided:
///
/// * **[ToolBarConfig.new]** — for single-scan or simple multi-scan
///   scenarios where only the flash and close buttons are relevant.
/// * **[ToolBarConfig.multiscan]** — additionally exposes the
///   "scanned list" button, its builder, and its tap callback, which only
///   make sense when the scanner accumulates multiple items.
///
/// If every button flag is `false`, [shouldBuildToolBar] returns `false` and
/// the toolbar widget is omitted from the tree entirely, saving a layout pass.
class ToolBarConfig {
  /// Master flag — `true` when *all* individual button flags are off.
  final bool _hideToolBar;

  /// Whether the flash/torch toggle button is shown in the toolbar.
  final bool showFlashButton;

  /// Whether the close/dismiss button is shown in the toolbar.
  final bool showCloseButton;

  /// Whether the badge-style "scanned items list" button is shown.
  /// Only meaningful in multi-scan modes.
  final bool showScannedListButton;

  /// Optional error handler surfaced when the platform torch API throws.
  final void Function(Object error)? onFlashButtonError;

  /// Optional callback fired when the user taps the scanned-list button.
  /// When `null`, the default bottom-sheet list is presented instead.
  final void Function(BuildContext, List<String>)? onShowScannedListPressed;

  /// Optional builder that replaces the default scanned-list button widget
  /// entirely, giving full visual control to the caller.
  final Widget Function(BuildContext, List<String>)? showScannedListBuilder;

  /// Creates a toolbar configuration for **single-scan** or simple layouts.
  ///
  /// The scanned-list button is always hidden in this variant because there
  /// is no internal list to display.
  const ToolBarConfig({
    this.showFlashButton = true,
    this.showCloseButton = true,
    this.onFlashButtonError,
  }) : showScannedListButton = false,
       onShowScannedListPressed = null,
       showScannedListBuilder = null,
       _hideToolBar = !showFlashButton && !showCloseButton;

  /// Creates a toolbar configuration for **multi-scan** layouts.
  ///
  /// Exposes the scanned-list button and its customization hooks alongside
  /// the standard flash and close buttons.
  const ToolBarConfig.multiscan({
    this.showFlashButton = true,
    this.showCloseButton = true,
    this.showScannedListButton = true,
    this.onFlashButtonError,
    this.onShowScannedListPressed,
    this.showScannedListBuilder,
  }) : _hideToolBar = !showFlashButton && !showCloseButton && !showScannedListButton;

  ToolBarConfig transformToRegular() => ToolBarConfig(
    showFlashButton: showFlashButton,
    showCloseButton: showCloseButton,
    onFlashButtonError: onFlashButtonError,
  );

  /// Returns `true` when at least one button is visible, meaning the toolbar
  /// widget should be inserted into the overlay stack.
  bool get shouldBuildToolBar => !_hideToolBar;
}

/// Null-safe convenience extension so callers can query toolbar flags directly
/// on a nullable [DefaultToolBarConfig?] without verbose null-checks.
extension ToolBarConfigExtension on ToolBarConfig? {
  bool get shouldBuildToolBar => this == null ? false : this!.shouldBuildToolBar;

  bool get showFlashButton => this == null ? false : this!.showFlashButton;
  bool get showCloseButton => this == null ? false : this!.showCloseButton;
  bool get showScannedListButton => this == null ? false : this!.showScannedListButton;

  ToolBarConfig? transformToRegular() => this?.transformToRegular();
}

// ─── Configuration Object: ScannerViewConfig ────────────────────────────────

/// **Configuration Object Pattern** — encapsulates all visual and
/// hardware-facing scanner parameters (scan window, overlay style, and
/// allowed barcode formats) into a single object.
///
/// Three named constructors provide opinionated presets:
///
/// * **[ScannerViewConfig.new]** (`.custom()`) — full manual control.  The
///   caller supplies an arbitrary [Rect] scan window and an unrestricted
///   format list.  Use this when the built-in presets don't fit.
///
/// * **[ScannerViewConfig.qrCode]** — optimized for 2D/matrix codes.
///   Renders a responsive **1 : 1 square** overlay and locks
///   [allowedFormats] to `[BarcodeFormat.qrCode]`, eliminating accidental
///   1D reads that would otherwise waste decode cycles.
///
/// * **[ScannerViewConfig.barcode]** — optimized for horizontal 1D
///   product barcodes (EAN-13, UPC-A, Code 128, etc.).  Renders a wide
///   landscape-oriented overlay.  When [allowedFormats] is left empty, the
///   controller defaults to the full [_horizontal1DFormats] set; when a
///   subset is passed, only formats that *also* appear in that allow-list
///   are kept — preventing callers from accidentally enabling 2D codes
///   through this constructor.

/// Determines the visual shape of the scan window overlay.
enum _OverlayMode { custom, qrCode, barcode }

class ScannerViewConfig {
  /// Internal overlay shape discriminator set by the chosen constructor.
  final _OverlayMode _mode;

  /// An explicit scan-window rectangle. Only used by the default/custom
  /// constructor; the preset constructors compute their own windows
  /// responsively.
  final Rect? scanWindow;

  /// Vertical/horizontal nudge applied to the preset scan-window position.
  /// Ignored by the custom constructor.
  final Offset? offsetFromCenter;

  /// Optional visual styling for the overlay painter (border color, corner
  /// radius, background dim color, etc.).
  final ScannerOverlayStyle? overlayStyle;

  /// Barcode symbologies the controller will attempt to decode.
  /// An empty list means "accept everything the device supports."
  final List<BarcodeFormat> allowedFormats;

  /// Creates a scanner with a **custom** scan window and format list.
  ///
  /// [scanWindow] lets the caller supply an arbitrary [Rect] for the detection
  /// region. When `null`, no scan-window restriction is applied.
  ///
  /// [allowedFormats] will passed directly to the controller with no filtering.
  /// When empty (the default), all formats supported by the device are
  /// detected.
  const ScannerViewConfig({
    this.scanWindow,
    this.overlayStyle,
    this.allowedFormats = const <BarcodeFormat>[],
  }) : _mode = _OverlayMode.custom,
       offsetFromCenter = null;

  /// Creates a scanner optimized for **QR / 2D matrix codes**.
  ///
  /// The scan window is a responsive 1:1 square.
  const ScannerViewConfig.qrCode({
    this.overlayStyle,
    this.offsetFromCenter,
  }) : _mode = _OverlayMode.qrCode,
       scanWindow = null,
       allowedFormats = const [BarcodeFormat.qrCode];

  /// Creates a scanner optimized for **1D product barcodes**.
  ///
  /// [allowedFormats] defaults to the standard set of store-product 1D
  /// symbologies. The caller may pass a subset to narrow detection further.
  const ScannerViewConfig.barcode({
    this.overlayStyle,
    this.offsetFromCenter,
    this.allowedFormats = const [],
  }) : _mode = _OverlayMode.barcode,
       scanWindow = null;
}
