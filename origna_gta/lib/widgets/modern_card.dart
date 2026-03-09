import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// Modern 2100 Card with glassmorphism and hover effects
class ModernCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final bool enableHoverScale;
  final double? width;
  final double? height;
  final String? semanticLabel;

  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(DesignTokens.spacing16),
    this.borderRadius = const BorderRadius.all(Radius.circular(DesignTokens.radius16)),
    this.enableHoverScale = true,
    this.width,
    this.height,
    this.semanticLabel,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _elevationAnimation,
          builder: (context, child) {
            final card = GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? (isDark ? DesignTokens.darkSurfaceVariant.withValues(alpha: 0.6) : DesignTokens.surface),
                  borderRadius: widget.borderRadius,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: DesignTokens.primary.withValues(alpha: 0.1),
                      blurRadius: _elevationAnimation.value,
                      offset: Offset(0, _elevationAnimation.value / 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: widget.borderRadius,
                  child: Padding(padding: widget.padding, child: widget.child),
                ),
              ),
            );
            if (widget.semanticLabel != null) {
              return Semantics(label: widget.semanticLabel, child: card);
            }
            // WCAG 4.1.2: Interactive cards must have a semantic role
            if (widget.onTap != null) {
              return Semantics(button: true, child: card);
            }
            return card;
          },
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
    _controller = AnimationController(duration: DesignTokens.durationNormal, vsync: this);
    _elevationAnimation = Tween<double>(begin: 8, end: 16).animate(_controller);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(CurvedAnimation(parent: _controller, curve: DesignTokens.easeOutCubic));
  }

  void _onHover(bool isHovering) {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.linux) {
      return;
    }
    if (widget.enableHoverScale && widget.onTap != null) {
      if (isHovering) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }
}
