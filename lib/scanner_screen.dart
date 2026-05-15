import 'dart:async';

import 'package:flutter/material.dart';
import 'package:native_haptics_and_audio/native_haptics_and_audio.dart';
import 'package:mobile_scanner/mobile_scanner.dart'
    show BarcodeFormat, MobileScannerController, MobileScannerState, TorchState, BarcodeCapture, CameraFacing, DetectionSpeed;

import 'scanner_view.dart';
import 'scanner_overlay.dart';

part 'scanner_configs.dart';
part 'scanner_top_bar.dart';

// ─── ScannerScreen ──────────────────────────────────────────────────────────

/// A production-grade, unified barcode-scanner widget that supports **nine**
/// visual × data-routing combinations through two named constructors and
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
/// | [ScannerScreen.multiscan]                   | `List<String>?`      | Optional via [onCameraScan] |
///
/// Note: [ScannerScreen.multiscan] handles both batch routing (accumulating a list and returning it on pop)
/// and stream routing (firing [onCameraScan] continuously as barcodes are scanned).
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
  final ScannerToolBar? toolBar;

  /// Visual/hardware configuration object that determines the overlay shape
  /// and allowed barcode formats.
  final ScannerViewConfig? scannerViewConfig;

  /// Real-time scan callback — the primary data channel for the stream
  /// routing mode of the [multiscan] constructor. This is `null` in
  /// single scan mode.
  final void Function(String)? onCameraScan;

  /// Fires when a scan is **rejected** because [allowDuplicates] is `false`
  /// and the value already exists in the internal list.  Useful for showing
  /// "already scanned" toasts.
  final void Function(String rejected)? onScanRejected;

  final bool enableSoundAndVibration;

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
  /// * [onCameraScan] is forced to `null`.
  const ScannerScreen.singleScan({
    super.key,
    this.stackChildren,
    this.toolBar,
    this.onScanRejected,
    this.scannerViewConfig,
    this.enableSoundAndVibration = true,
  }) : _mode = _ScanMode.single,
       onCameraScan = null,
       allowDuplicates = false,
       sameItemCooldownMs = 0,
       detectionTimeoutMs = 250,
       assert(toolBar is! BatchToolBar);

  /// **Multi-Scan Mode** — opens the scanner to read **multiple** barcodes.
  ///
  /// ### Routing Capabilities
  /// This constructor handles two routing paradigms simultaneously:
  /// 1. **Batch Routing**: Acts as a shopping cart. Every accepted scan is
  ///    added to an internal list, which is returned as `List<String>?` when
  ///    the screen is popped.
  /// 2. **Stream Routing**: If [onCameraScan] is provided, every accepted scan
  ///    fires this callback in real-time.
  const ScannerScreen.multiscan({
    super.key,
    this.stackChildren,
    this.toolBar,
    this.scannerViewConfig,
    this.onCameraScan,
    this.allowDuplicates = true,
    this.detectionTimeoutMs = 250,
    this.sameItemCooldownMs = 1500,
    this.enableSoundAndVibration = true,
    void Function(String)? onScanRejected,
  }) : _mode = _ScanMode.multiscan,
       onScanRejected = !allowDuplicates ? onScanRejected : null;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

// ─── State ──────────────────────────────────────────────────────────────────

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  late MobileScannerController controller;

  // Reference to your Native Sounds and Vibration plugin
  final _effects = NativeHapticsAndAudioRepository.instance;

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
    _effects.initialize();
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
  //   • single    → lock hardware, pop with the raw value.
  //   • multiscan → append to list (with optional duplicate rejection),
  //                 AND fire the real-time callback if provided.
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
        _playSuccessFeedback();

        // Cache the navigator reference BEFORE the async gap.  After
        // `controller.stop()` the widget may already be deactivated, and
        // calling `Navigator.of(context)` on a deactivated widget throws.
        final navigator = Navigator.of(context);
        await _subscription?.cancel();
        await controller.stop(); // Wait for physical hardware to release

        navigator.pop(rawValue);
        break;

      case _ScanMode.multiscan:
        if (!widget.allowDuplicates && scannedItemsNotifier.value.contains(rawValue)) {
          _playRejectedFeedback();
          widget.onScanRejected?.call(rawValue);
          return;
        }

        _playSuccessFeedback();
        scannedItemsNotifier.value = List<String>.from([...scannedItemsNotifier.value, rawValue]);
        widget.onCameraScan?.call(rawValue);
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

  Future<void> _playSuccessFeedback() async {
    if (!widget.enableSoundAndVibration) return;
    await Future.wait([
      _effects.playHaptic(PosHaptic.success),
      _effects.playSound(PosSound.scannerBeep),
    ]);
  }

  Future<void> _playRejectedFeedback() async {
    if (!widget.enableSoundAndVibration) return;
    await Future.wait([
      _effects.playHaptic(PosHaptic.error),
      _effects.playSound(PosSound.warningBeep),
    ]);
  }

  Widget? _buildToolBarUI() {
    final toolbar = widget.toolBar;
    if (toolbar == null || !toolbar.shouldBuild) return null;
    if (toolbar is BatchToolBar) {
      if (widget._mode == _ScanMode.single) {
        debugPrint('Switching ToolBar to `StandardToolBar` for Single Scan');
        return _ScannerTopBar(
          toolBar: toolbar.toStandard(),
          controller: controller,
          popBackWithListResult: _popBack,
        );
      } else {
        return _ScannerBatchTopBar(
          toolBar: toolbar,
          controller: controller,
          popBackWithListResult: _popBack,
          scannedItemsNotifier: scannedItemsNotifier,
        );
      }
    }
    return _ScannerTopBar(
      toolBar: toolbar,
      controller: controller,
      popBackWithListResult: _popBack,
    );
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
    final toolBar = _buildToolBarUI();

    final List<Widget> stackChildren = [
      ?toolBar,
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
