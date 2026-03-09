/// Modern loading indicator with glassmorphism aesthetic
/// Replaces raw CircularProgressIndicator throughout the app
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';

/// A styled loading indicator consistent with the OrignaGTA 2100 design system.
///
/// Use instead of raw [CircularProgressIndicator] for consistent loading UX.
///
/// Variants:
/// - [ModernLoadingIndicator] — inline spinner (e.g. inside buttons, fields)
/// - [ModernLoadingIndicator.fullScreen] — centered overlay with optional message
/// - [ModernLoadingIndicator.small] — compact 16×16 spinner for tight spaces
class ModernLoadingIndicator extends StatelessWidget {
  /// Diameter of the spinner.
  final double size;

  /// Stroke width.
  final double strokeWidth;

  /// Primary color of the spinner arc.
  final Color? color;

  /// Optional label shown below the spinner (only in non-inline mode).
  final String? message;

  /// Whether to center the indicator and fill available space.
  final bool centered;

  /// Padding around the indicator.
  final EdgeInsets padding;

  const ModernLoadingIndicator({
    super.key,
    this.size = 24,
    this.strokeWidth = 2.5,
    this.color,
    this.message,
    this.centered = true,
    this.padding = EdgeInsets.zero,
  });

  /// Full-screen centered loading indicator with optional message.
  const ModernLoadingIndicator.fullScreen({super.key, this.message, this.color})
    : size = 32,
      strokeWidth = 3.0,
      centered = true,
      padding = const EdgeInsets.all(16);

  /// Compact spinner for tight spaces (buttons, badges).
  const ModernLoadingIndicator.small({super.key, this.color})
    : size = 16,
      strokeWidth = 2.0,
      message = null,
      centered = false,
      padding = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final indicator = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: _SpinningArc(
              size: size,
              strokeWidth: strokeWidth,
              color: color ?? DesignTokens.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(
                fontSize: 13,
                color: DesignTokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    if (centered) {
      return Center(child: indicator);
    }
    return indicator;
  }
}

class _SpinningArc extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const _SpinningArc({
    required this.size,
    required this.strokeWidth,
    required this.color,
  });

  @override
  State<_SpinningArc> createState() => _SpinningArcState();
}

class _SpinningArcState extends State<_SpinningArc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _SpinnerArcPainter(
          color: widget.color,
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

class _SpinnerArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _SpinnerArcPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: 0.18);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(
      rect.center,
      (size.width / 2) - (strokeWidth / 2),
      trackPaint,
    );
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      math.pi * 1.35,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinnerArcPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
