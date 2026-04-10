import 'package:flutter/material.dart';

class ScannerOverlayStyle {
  final double opacity;
  final Color borderColor;
  final Color opacityColor;
  final double borderWidth;
  final double borderRadius;

  const ScannerOverlayStyle({
    double? opacity,
    Color? borderColor,
    Color? opacityColor,
    double? borderWidth,
    double? borderRadius,
  }) : opacity = opacity ?? 0.5,
       borderWidth = borderWidth ?? 2.5,
       borderRadius = borderRadius ?? 12.0,
       borderColor = borderColor ?? Colors.white,
       opacityColor = opacityColor ?? Colors.black;
}

class ScannerOverlay extends StatelessWidget {
  final BoxConstraints constraints;
  final Rect scanWindow;
  final ScannerOverlayStyle? style;

  const ScannerOverlay({
    super.key,
    required this.constraints,
    required this.scanWindow,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: constraints,
      child: CustomPaint(
        painter: _OverlayPainter(
          scanWindow: scanWindow,
          style: style,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The highly optimized painter
class _OverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final ScannerOverlayStyle style;

  const _OverlayPainter({
    required this.scanWindow,
    ScannerOverlayStyle? style,
  }) : style = style ?? const ScannerOverlayStyle();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw the semi-transparent background
    final backgroundPaint = Paint()
      ..color = style.opacityColor.withValues(alpha: style.opacity)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // We use your exact scanWindow Rect here
    final scanRRect = RRect.fromRectAndRadius(
      scanWindow,
      Radius.circular(style.borderRadius),
    );

    final cutoutPath = Path()
      ..addRRect(scanRRect)
      ..close();

    // Path.combine is highly performant. It punches the hole out
    // mathematically before drawing, avoiding the need for expensive BlendModes.
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, backgroundPaint);

    // 2. Draw the border
    final borderPaint = Paint()
      ..color = style.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.borderWidth;

    canvas.drawRRect(scanRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow || oldDelegate.style != style;
  }
}
