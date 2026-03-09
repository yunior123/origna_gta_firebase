/// Glassmorphism design system for OrignaGta
/// Provides blur effects, frosted glass containers, and modern glassmorphic styling
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';

/// Glassmorphic appbar header
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final GlassBlurIntensity blurIntensity;
  final Color backgroundColor;
  final double elevation;

  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.blurIntensity = GlassBlurIntensity.light,
    this.backgroundColor = DesignTokens.surface,
    this.elevation = 2,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurIntensity.value, sigmaY: blurIntensity.value),
        child: AppBar(
          title: Text(title),
          actions: actions,
          backgroundColor: backgroundColor.withValues(alpha: 0.7),
          elevation: elevation,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
        ),
      ),
    );
  }
}

/// Glassmorphic notification badge
class GlassBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final GlassBlurIntensity blurIntensity;
  final double padding;

  const GlassBadge({super.key, required this.label, this.backgroundColor, this.textColor, this.blurIntensity = GlassBlurIntensity.subtle, this.padding = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurIntensity.value, sigmaY: blurIntensity.value),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padding * 1.5, vertical: padding),
          decoration: BoxDecoration(
            color: (backgroundColor ?? Colors.blue).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor ?? Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism blur levels
enum GlassBlurIntensity {
  subtle(3.0), // Barely noticeable blur
  light(6.0), // Light frosted glass effect
  medium(10.0), // Standard glassmorphism
  strong(15.0), // Heavy blur, very opaque feel
  extreme(25.0); // Maximum blur effect

  final double value;
  const GlassBlurIntensity(this.value);
}

/// Frosted glass button with glassmorphism effect
class GlassButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final GlassBlurIntensity blurIntensity;
  final Color? backgroundColor;
  final double borderRadius;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.blurIntensity = GlassBlurIntensity.light,
    this.backgroundColor,
    this.borderRadius = 8.0,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

/// Glassmorphic card for product/content display
class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final GlassBlurIntensity blurIntensity;
  final double? width;
  final double? height;
  final EdgeInsets padding;
  final Color backgroundColor;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.blurIntensity = GlassBlurIntensity.medium,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor = DesignTokens.surface,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: blurIntensity.value, sigmaY: blurIntensity.value),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphic floating action button
class GlassFloatingActionButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final GlassBlurIntensity blurIntensity;
  final Color backgroundColor;
  final double size;

  const GlassFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.blurIntensity = GlassBlurIntensity.light,
    this.backgroundColor = DesignTokens.surface,
    this.size = 56,
  });

  @override
  State<GlassFloatingActionButton> createState() => _GlassFloatingActionButtonState();
}

/// Glassmorphic modal/dialog background
class GlassModal extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDismiss;
  final GlassBlurIntensity blurIntensity;
  final Color backgroundColor;

  const GlassModal({
    super.key,
    required this.child,
    this.onDismiss,
    this.blurIntensity = GlassBlurIntensity.medium,
    this.backgroundColor = const Color(0xFF000000),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: backgroundColor.withValues(alpha: 0.4),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurIntensity.value, sigmaY: blurIntensity.value),
          child: GestureDetector(
            onTap: () {}, // Prevent dismissal when tapping modal content
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _GlassButtonState extends State<GlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: widget.blurIntensity.value, sigmaY: widget.blurIntensity.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: (widget.backgroundColor ?? Colors.white).withValues(alpha: _isPressed ? 0.5 : 0.7),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.0),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isPressed ? 0.12 : 0.08), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[Icon(widget.icon, size: 18), const SizedBox(width: 8)],
                Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassFloatingActionButtonState extends State<GlassFloatingActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _onTapDown(),
        onTapUp: (_) => _onTapUp(),
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Tooltip(
            message: widget.tooltip ?? '',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.size / 2),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: widget.blurIntensity.value, sigmaY: widget.blurIntensity.value),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.backgroundColor.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.0),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Icon(widget.icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  void _onTapCancel() => _controller.reverse();

  void _onTapDown() => _controller.forward();

  void _onTapUp() {
    _controller.reverse();
    widget.onPressed();
  }
}
