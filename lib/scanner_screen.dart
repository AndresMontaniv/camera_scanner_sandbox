import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' show BarcodeFormat, MobileScannerController, BarcodeCapture, CameraFacing, DetectionSpeed;

import 'scanner_view.dart';
import 'scanner_overlay.dart';
import 'scanner_top_bar.dart';
import 'flash_toggle_button.dart';
import 'circle_close_button.dart';

// ─── Layout Constants ───────────────────────────────────────────────────────
// Default vertical offsets that nudge the scan-window overlay upward from the
// screen center, accounting for visual balance with the toolbar at the top.
const Offset _qrOffset = Offset(0.0, -50.0);
const Offset _barcodeOffset = Offset(0.0, -80.0);

/// Internal routing mode enum — set once by the named constructor and never
/// changed. The `_ScannerScreenState` switches on this to decide how to
/// route scanned data (pop a single value, accumulate a batch, or stream).
enum _ScanMode { single, batchPop, callbackStream }

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

// ─── ScannerScreen ──────────────────────────────────────────────────────────

/// A production-grade, unified barcode-scanner widget that supports **nine**
/// visual × data-routing combinations through three named constructors and
/// two configuration objects.
///
/// ### Visual/Hardware Configuration
/// Handled entirely by [ToolBarConfig] (toolbar buttons and callbacks)
/// and [ScannerViewConfig] (scan window shape, overlay styling, and allowed
/// barcode formats).  This keeps every constructor's parameter list short.
///
/// ### Data-Routing Modes (named constructors)
///
/// | Constructor                                 | Return type on pop   | Real-time callback? |
/// |---------------------------------------------|----------------------|---------------------|
/// | [ScannerScreen.singleScan]                  | `String?`            | No                  |
/// | [ScannerScreen.multiScanBatchPop]            | `List<String>`       | Per-scan via [onScanSubmitted] |
/// | [ScannerScreen.multiScanCallbackStream]      | `void` (nothing)     | Per-scan via [onCameraScan]     |
///
/// ### Hardware Safety
/// This widget implements an [_isPopping] **hardware safety tripwire**.  The
/// flag is flipped to `true` the instant a valid scan or back-button event
/// begins the teardown sequence.  Every barcode listener checks this flag
/// first, guaranteeing the camera sensor is fully locked and detached before
/// the screen animates away — preventing "ghost scans," deactivated-widget
/// context crashes, and native camera-lock hangs.
class ScannerScreen extends StatefulWidget {
  /// When `false`, scans that match a value already in the internal list are
  /// silently rejected (or routed to [onScanRejected] if provided).
  final bool allowDuplicates;

  /// The minimum milliseconds between *any* two decode callbacks from the
  /// native camera pipeline.  Tuning this down increases responsiveness but
  /// raises CPU load.
  final int detectionTimeoutMs;

  /// The minimum milliseconds before the *same* barcode value is accepted
  /// again.  Only enforced in multi-scan modes; single-scan ignores this
  /// because the scanner locks immediately after the first read.
  final int sameItemCooldownMs;

  /// Additional widgets layered on top of the camera preview inside the
  /// [ScannerView] stack (e.g., instructional text, brand logos).
  final List<Widget>? stackChildren;

  /// Toolbar configuration object.  Pass `null` or omit to hide the toolbar
  /// entirely.
  final ToolBarConfig? toolBarConfig;

  /// Visual/hardware configuration object that determines the overlay shape
  /// and allowed barcode formats.
  final ScannerViewConfig? scannerViewConfig;

  /// Fires after every accepted scan in multi-scan modes.  Useful for
  /// triggering haptic feedback or UI animations without needing the
  /// scanned value (which is routed through [onCameraScan] or the pop result).
  final void Function()? onScanSubmitted;

  /// Real-time scan callback — the primary data channel for the
  /// [multiScanCallbackStream] constructor.  This is `null` in the other
  /// two modes.
  final void Function(String)? onCameraScan;

  /// Fires when a scan is **rejected** because [allowDuplicates] is `false`
  /// and the value already exists in the internal list.  Useful for showing
  /// "already scanned" toasts.
  final void Function(String rejected)? onScanRejected;

  /// Internal flag set by the named constructors.
  final _ScanMode _mode;

  /// **Single-Scan Mode** — opens the scanner to read exactly **one** barcode.
  ///
  /// ### Flow
  /// 1. The camera starts and waits for a valid decode.
  /// 2. On the first successful read the [_isPopping] tripwire fires,
  ///    instantly locking the hardware to prevent ghost scans.
  /// 3. The barcode stream subscription is cancelled, and `controller.stop()`
  ///    is awaited so the native camera fully releases.
  /// 4. `Navigator.pop(rawValue)` returns the scanned `String?` to the
  ///    caller.
  ///
  /// Because only one value is ever captured:
  /// * [allowDuplicates] is hard-coded to `false`.
  /// * [sameItemCooldownMs] is `0` (irrelevant).
  /// * [onCameraScan] and [onScanSubmitted] are forced to `null`.
  const ScannerScreen.singleScan({
    super.key,
    this.stackChildren,
    this.toolBarConfig,
    this.onScanRejected,
    this.scannerViewConfig,
  }) : _mode = _ScanMode.single,
       onCameraScan = null,
       onScanSubmitted = null,
       allowDuplicates = false,
       sameItemCooldownMs = 0,
       detectionTimeoutMs = 250;

  /// **Multi-Scan Batch-Pop Mode** — opens the scanner for continuous
  /// scanning, accumulating results in an internal list.
  ///
  /// ### Flow
  /// 1. Each valid barcode is appended to [scannedItemsNotifier].
  /// 2. [onScanSubmitted] fires after every accepted scan (if provided).
  /// 3. When the user taps Close or presses the system back button, the
  ///    [_isPopping] tripwire fires, hardware shuts down cleanly, and
  ///    `Navigator.pop<List<String>>(scannedItems)` returns the full batch
  ///    to the calling screen.
  ///
  /// ### Duplicate handling
  /// * [allowDuplicates] defaults to `true` — the same barcode can appear
  ///   in the list multiple times.
  /// * When set to `false`, duplicate values are silently dropped and
  ///   [onScanRejected] fires (if provided).
  ///
  /// Note: [onScanRejected] is only wired when [allowDuplicates] is `false`.
  /// The inverted boolean in the initializer list (`!allowDuplicates ?
  /// onScanRejected : null`) ensures we never allocate a rejection callback
  /// that can never fire.
  const ScannerScreen.multiScanBatchPop({
    super.key,
    this.stackChildren,
    this.toolBarConfig,
    this.onScanSubmitted,
    this.scannerViewConfig,
    this.allowDuplicates = true,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    void Function(String)? onScanRejected,
  }) : _mode = _ScanMode.batchPop,
       onScanRejected = !allowDuplicates ? onScanRejected : null,
       onCameraScan = null;

  /// **Multi-Scan Callback-Stream Mode** — opens the scanner for continuous
  /// scanning, firing [onDetect] for every valid frame.
  ///
  /// ### Flow
  /// 1. Each valid barcode triggers the [onDetect] callback (exposed as
  ///    [onCameraScan] internally), passing data to the parent in real-time.
  /// 2. [onScanSubmitted] fires after every accepted scan (if provided).
  /// 3. On pop, **no data is returned** — the parent already has everything
  ///    via the callback stream.
  ///
  /// ### Duplicate handling
  /// Same rules as [multiScanBatchPop]: [onScanRejected] is only wired when
  /// [allowDuplicates] is `false`.
  ///
  /// ### Use case
  /// Ideal for POS terminals, inventory counters, or any flow where the
  /// parent needs to react to each scan immediately (e.g., playing a sound,
  /// updating a running total) rather than waiting for the batch on pop.
  const ScannerScreen.multiScanCallbackStream({
    super.key,
    required void Function(String) onDetect,
    this.stackChildren,
    this.toolBarConfig,
    this.onScanSubmitted,
    this.scannerViewConfig,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.allowDuplicates = true,
    void Function(String)? onScanRejected,
  }) : _mode = _ScanMode.callbackStream,
       onCameraScan = onDetect,
       onScanRejected = !allowDuplicates ? onScanRejected : null;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

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

// ─── State ──────────────────────────────────────────────────────────────────

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  late MobileScannerController controller;
  StreamSubscription<BarcodeCapture>? _subscription;

  /// Single source of truth for the list of successfully scanned barcode
  /// values.  Wrapped in a [ValueNotifier] so the toolbar badge can rebuild
  /// reactively without triggering a full [setState] on the camera preview.
  final ValueNotifier<List<String>> scannedItemsNotifier = ValueNotifier<List<String>>([]);

  // ── Same-item cooldown state ──────────────────────────────────────────
  // These two fields implement a lightweight time-based throttle that
  // prevents the same physical barcode from registering multiple times
  // while the user holds it under the camera.  Only active in multi-scan
  // modes; single-scan locks the entire pipeline on the first read.
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  // ── Hardware Safety Tripwire ──────────────────────────────────────────
  // `_isPopping` is a one-shot flag that is flipped to `true` the INSTANT
  // a valid scan (in single mode) or a back-button / close-button press
  // begins the async teardown sequence.
  //
  // WHY: Between the moment we decide to pop and the moment the native
  // camera actually releases (an async gap of ~50-200 ms), the barcode
  // stream can still deliver frames.  Without this flag those "ghost
  // scans" would attempt to call `Navigator.pop()` on a widget that is
  // already mid-disposal, causing "deactivated widget" exceptions or
  // leaving the native camera in a locked state on some Android devices.
  //
  // Every entry point that touches the barcode stream checks `_isPopping`
  // first and returns immediately if it's `true`.
  bool _isPopping = false;

  /// Resolves the effective barcode format list for the controller.
  ///
  /// * **Barcode mode with empty allow-list:** returns [_horizontal1DFormats].
  /// * **Barcode mode with a caller-supplied subset:** intersects the subset
  ///   against [_horizontal1DFormats] to prevent accidental 2D inclusion.
  /// * **All other modes:** passes the caller's list through unchanged.
  List<BarcodeFormat> _getEffectiveFormats() {
    final allowedFormats = widget.scannerViewConfig?.allowedFormats ?? [];
    if (widget.scannerViewConfig?._mode == _OverlayMode.barcode) {
      if (allowedFormats.isEmpty) {
        return _horizontal1DFormats;
      }
      return allowedFormats.where((f) => _horizontal1DFormats.contains(f)).toList();
    }
    return allowedFormats;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = MobileScannerController(
      torchEnabled: false,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: widget.detectionTimeoutMs,
      formats: _getEffectiveFormats(),
    );
    _subscribeToBarcodes();
  }

  // ── App Lifecycle Management ──────────────────────────────────────────
  // The camera is a shared hardware resource.  If the app goes to the
  // background we MUST release it, otherwise:
  //   1. Battery drains from an active camera pipeline nobody is watching.
  //   2. On some Android OEMs the camera stays locked, blocking other apps.
  //
  // On resume we re-acquire the camera and unpause the barcode stream.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Release native camera resources when not in foreground.
        _subscription?.pause();
        controller.stop();
        break;
      case AppLifecycleState.resumed:
        // Re-acquire camera and resume the barcode stream.
        controller.start();
        _subscription?.resume();
        break;
    }
  }

  /// Subscribes to the native barcode capture stream and applies three
  /// layers of filtering before routing the value to [_addScannedItem]:
  ///
  /// 1. **Tripwire check** — if [_isPopping] is `true`, bail immediately.
  /// 2. **Null / empty guard** — discard frames with no barcodes or no raw
  ///    value (e.g., a partial decode the OS couldn't resolve).
  /// 3. **Same-item cooldown** (multi-scan only) — if the same barcode
  ///    value arrives within [sameItemCooldownMs] of its last acceptance,
  ///    drop it silently. This prevents rapid-fire duplicates when the
  ///    user holds a barcode under the camera for several seconds.
  void _subscribeToBarcodes() {
    _subscription = controller.barcodes.listen((capture) {
      // ── Layer 1: Tripwire ──
      // If a pop/shutdown is already in flight, reject everything.
      if (_isPopping) return;

      // ── Layer 2: Null / empty guard ──
      if (capture.barcodes.isEmpty) return;

      final rawValue = capture.barcodes.first.rawValue;
      if (rawValue == null) return;

      // ── Layer 3: Same-item cooldown (multi-scan only) ──
      // Single-scan doesn't need a cooldown because the tripwire locks
      // the entire pipeline after the first successful read.
      if (widget._mode != _ScanMode.single) {
        if (rawValue == _lastScannedCode && _lastScanTime != null) {
          final elapsed = DateTime.now().difference(_lastScanTime!).inMilliseconds;
          if (elapsed < widget.sameItemCooldownMs) return;
        }

        _lastScannedCode = rawValue;
        _lastScanTime = DateTime.now();
      }

      _addScannedItem(rawValue);
    });
  }

  // ── Core Routing Switch ───────────────────────────────────────────────
  //
  // This method is the single entry point for every accepted barcode.  It
  // switches on `_ScanMode` to decide how to route the value:
  //
  //   • single       → lock hardware, pop with the raw value.
  //   • batchPop     → append to list (with optional duplicate rejection).
  //   • callbackStream → append to list AND fire the real-time callback.
  //
  // Each branch handles its own duplicate-rejection logic so that the
  // `onScanRejected` callback fires in the right context.
  Future<void> _addScannedItem(String rawValue) async {
    switch (widget._mode) {
      case _ScanMode.single:
        // ── TRIPWIRE: Instantly lock hardware ──
        // This is the most critical line in single-scan mode.  By setting
        // `_isPopping = true` BEFORE the async gap, we guarantee that no
        // subsequent barcode frame can sneak through `_subscribeToBarcodes`
        // while we're awaiting `controller.stop()` or the exit animation.
        _isPopping = true;
        if (!mounted) return;

        // Cache the navigator reference BEFORE the async gap.  After
        // `controller.stop()` the widget may already be deactivated, and
        // calling `Navigator.of(context)` on a deactivated widget throws.
        final navigator = Navigator.of(context);
        await _subscription?.cancel();
        await controller.stop(); // Wait for physical hardware to release

        navigator.pop(rawValue);
        break;

      case _ScanMode.batchPop:
        // ── Duplicate rejection gate ──
        // When `allowDuplicates` is false, check the single source of truth
        // (scannedItemsNotifier) for an existing entry.  If found, fire the
        // optional `onScanRejected` callback so the parent can show a toast
        // or play an error haptic, then bail — the value never enters the list.
        if (!widget.allowDuplicates && scannedItemsNotifier.value.contains(rawValue)) {
          widget.onScanRejected?.call(rawValue);
          return;
        }
        // Append to the list by creating a new List instance (required to
        // trigger ValueNotifier listeners — mutating in place won't notify).
        scannedItemsNotifier.value = List<String>.from([...scannedItemsNotifier.value, rawValue]);
        widget.onScanSubmitted?.call();
        break;

      case _ScanMode.callbackStream:
        // ── Duplicate rejection gate (same logic as batchPop) ──
        if (!widget.allowDuplicates && scannedItemsNotifier.value.contains(rawValue)) {
          widget.onScanRejected?.call(rawValue);
          return;
        }
        scannedItemsNotifier.value = List<String>.from([...scannedItemsNotifier.value, rawValue]);

        // Fire the real-time stream callback — this is the primary data
        // channel in callbackStream mode.  The parent receives every
        // accepted value immediately, without waiting for pop.
        widget.onCameraScan?.call(rawValue);
        widget.onScanSubmitted?.call();
        break;
    }
  }

  // ── Close-Button / Programmatic Pop ───────────────────────────────────
  //
  // Called when the user taps the close button (multi-scan modes) or when
  // we need a controlled exit that returns the accumulated batch.
  //
  // The sequence mirrors single-scan's teardown:
  //   1. Flip the tripwire to reject any in-flight barcode frames.
  //   2. Cache the navigator BEFORE the async gap.
  //   3. Cancel the stream subscription and stop the camera hardware.
  //   4. Pop with the accumulated list.
  Future<void> _popBack() async {
    // Prevent double-tapping the close button from triggering two pops.
    if (_isPopping) return;
    _isPopping = true;

    if (!mounted) return;
    final navigator = Navigator.of(context);

    await _subscription?.cancel();
    await controller.stop();

    // Now that the hardware is safely dead, route the data manually.
    // Single mode returns nothing (the user backed out without scanning).
    // Multi modes return the accumulated list (which may be empty).
    if (widget._mode == _ScanMode.single) {
      navigator.pop();
    } else {
      navigator.pop<List<String>>(scannedItemsNotifier.value);
    }
  }

  // ── PopScope / System Back-Button Interception ────────────────────────
  //
  // WHY we wrap the ENTIRE screen in a PopScope with `canPop: false`:
  //
  // On Android, the system back gesture (swipe or hardware button)
  // triggers an immediate `Navigator.pop()`.  If we let that happen
  // BEFORE the camera is stopped, two things break:
  //
  //   1. "Deactivated widget" context crash — the framework tries to
  //      look up an InheritedWidget on a widget that's already been
  //      removed from the tree.
  //   2. Native camera lock — the platform channel never receives the
  //      `stop` command, so the camera stays allocated.  The next screen
  //      that tries to open the camera will hang or throw.
  //
  // By setting `canPop: false` we intercept the system gesture HERE,
  // run our own safe teardown, and then manually call `navigator.pop()`
  // once the hardware is confirmed dead.
  //
  // The `didPop` flag tells us whether a PROGRAMMATIC pop (one we
  // initiated ourselves via `navigator.pop()`) already succeeded.  If
  // `true`, we don't need to do anything — our teardown has already run.
  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    // If didPop is true, a programmatic pop just succeeded. We do nothing.
    if (didPop) return;

    // The user triggered a system back swipe. Intercept it and lock the hardware.
    _popBack();
  }

  @override
  void dispose() {
    scannedItemsNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Assemble the overlay stack: toolbar first (if configured), then any
    // caller-supplied children layered on top.
    final toolBarConfig = widget._mode == _ScanMode.single ? widget.toolBarConfig?.transformToRegular() : widget.toolBarConfig;

    final List<Widget> stackChildren = [
      if (toolBarConfig?.shouldBuildToolBar ?? false)
        _DefaultToolBar(
          config: toolBarConfig,
          controller: controller,
          popBackWithListResult: _popBack,
          scannedItemsNotifier: scannedItemsNotifier,
        ),
      ...?widget.stackChildren,
    ];

    // Build the appropriate ScannerView variant based on the overlay mode.
    ScannerView scannerView;
    switch (widget.scannerViewConfig?._mode) {
      case null:
      case _OverlayMode.custom:
        scannerView = ScannerView(
          fit: BoxFit.cover,
          controller: controller,
          autoDrawOverlay: true,
          useAppLifecycleState: false,
          scanWindow: widget.scannerViewConfig?.scanWindow,
          overlayStyle: widget.scannerViewConfig?.overlayStyle,
          stackChildren: stackChildren,
        );
        break;
      case _OverlayMode.qrCode:
        scannerView = ScannerView.qrCode(
          fit: BoxFit.cover,
          controller: controller,
          useAppLifecycleState: false,
          overlayStyle: widget.scannerViewConfig?.overlayStyle,
          offsetFromCenter: widget.scannerViewConfig?.offsetFromCenter ?? _qrOffset,
          stackChildren: stackChildren,
        );
        break;
      case _OverlayMode.barcode:
        scannerView = ScannerView.barcode(
          fit: BoxFit.cover,
          controller: controller,
          useAppLifecycleState: false,
          overlayStyle: widget.scannerViewConfig?.overlayStyle,
          offsetFromCenter: widget.scannerViewConfig?.offsetFromCenter ?? _barcodeOffset,
          stackChildren: stackChildren,
        );
        break;
    }

    // ── PopScope wrapper ──
    // `canPop: false` prevents the system back gesture from popping
    // before our teardown runs.  See `_onPopInvokedWithResult` for the
    // full rationale.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: scannerView,
    );
  }
}

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
      leading: config.showCloseButton ? CircleCloseButton(pop: popBackWithListResult) : null,
      trailing: [
        Visibility(
          visible: config.showFlashButton,
          child: FlashToggleButton(controller: controller),
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
