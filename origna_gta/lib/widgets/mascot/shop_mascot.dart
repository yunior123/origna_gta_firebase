// coverage:ignore-file
import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:url_launcher/url_launcher.dart';

/// Documentation for MascotController
class MascotController extends ChangeNotifier {
  Offset _lookTarget = Offset.zero;
  bool _isJumping = false;
  double _excitementLevel = 0.0;

  double get excitementLevel => _excitementLevel;
  bool get isJumping => _isJumping;
  Offset get lookTarget => _lookTarget;

  Future<void> jump() async {
    if (_isJumping) return;
    _isJumping = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));
    _isJumping = false;
    notifyListeners();
  }

  void lookAt(Offset target) {
    _lookTarget = target;
    notifyListeners();
  }

  void setExcitement(double level) {
    _excitementLevel = level.clamp(0.0, 1.0);
    notifyListeners();
  }
}

/// Documentation for MascotPainter
class MascotPainter extends CustomPainter {
  final double idleValue;
  final double jumpValue;
  final double blinkValue;
  final double breathingValue;
  final Offset lookTarget;
  final double excitement;

  MascotPainter({
    required this.idleValue,
    required this.jumpValue,
    required this.blinkValue,
    required this.breathingValue,
    required this.lookTarget,
    required this.excitement,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height * 0.55;

    final hoverOffset = math.sin(idleValue * math.pi * 2) * 2;
    final jumpOffset = -math.sin(jumpValue * math.pi) * (size.height * 0.25);
    final breathingScale = 1.0 + (math.sin(breathingValue * math.pi) * 0.03);

    canvas.save();
    canvas.translate(centerX, centerY + hoverOffset + jumpOffset);
    canvas.scale(breathingScale, 2.0 - breathingScale); // Squish and stretch for breathing

    _drawShadow(canvas, size, jumpValue);
    _drawBody(canvas, size);
    _drawScarf(canvas, size);
    _drawFace(canvas, size);
    _drawAntenna(canvas, size);
    _drawHands(canvas, size);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MascotPainter oldDelegate) =>
      idleValue != oldDelegate.idleValue ||
      jumpValue != oldDelegate.jumpValue ||
      blinkValue != oldDelegate.blinkValue ||
      breathingValue != oldDelegate.breathingValue ||
      lookTarget != oldDelegate.lookTarget ||
      excitement != oldDelegate.excitement;

  void _drawAntenna(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = DesignTokens.outline
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final wobble = math.sin(idleValue * math.pi * 2) * 2;

    canvas.drawLine(Offset(0, -size.height * 0.3), Offset(wobble, -size.height * 0.45), linePaint);

    final ballPaint = Paint()
      ..shader = RadialGradient(
        colors: [DesignTokens.tertiary, DesignTokens.tertiary.withValues(alpha: 0.8)],
      ).createShader(Rect.fromCircle(center: Offset(wobble, -size.height * 0.48), radius: size.width * 0.08));

    // Antenna glow
    canvas.drawCircle(
      Offset(wobble, -size.height * 0.48),
      size.width * 0.12,
      Paint()
        ..color = DesignTokens.tertiary.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(wobble, -size.height * 0.48), size.width * 0.08, ballPaint);
  }

  void _drawBody(Canvas canvas, Size size) {
    // Body gradient for depth
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [DesignTokens.primary, DesignTokens.secondary],
      ).createShader(Rect.fromCenter(center: const Offset(0, 0), width: size.width * 0.6, height: size.height * 0.5));

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 0), width: size.width * 0.65, height: size.height * 0.55),
      Radius.circular(size.width * 0.25), // More rounded/cute
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Cute blush markers
    final blushPaint = Paint()
      ..color = DesignTokens.tertiary.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(-size.width * 0.2, size.height * 0.1), size.width * 0.05, blushPaint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.1), size.width * 0.05, blushPaint);

    // High quality shine
    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: 0.4), Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(-size.width * 0.25, -size.height * 0.2, size.width * 0.4, size.height * 0.2));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-size.width * 0.25, -size.height * 0.2, size.width * 0.3, size.height * 0.1), Radius.circular(size.width * 0.1)),
      shinePaint,
    );
  }

  void _drawEye(Canvas canvas, Offset center, Paint paint, double radius) {
    if (blinkValue > 0.1) {
      final strokePaint = Paint()
        ..color = DesignTokens.accent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0.2, math.pi - 0.4, false, strokePaint);
    } else {
      // Glow
      canvas.drawCircle(
        center,
        radius * 1.2,
        Paint()
          ..color = DesignTokens.accent.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(center, radius, Paint()..color = DesignTokens.accent);
      // Pupil highlight
      canvas.drawCircle(center - Offset(radius * 0.3, radius * 0.3), radius * 0.2, Paint()..color = Colors.white);
    }
  }

  void _drawFace(Canvas canvas, Size size) {
    final facePaint = Paint()..color = DesignTokens.darkSurface;
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -size.height * 0.05), width: size.width * 0.45, height: size.height * 0.28),
      Radius.circular(size.width * 0.1),
    );
    canvas.drawRRect(faceRect, facePaint);

    final eyePaint = Paint()
      ..color = DesignTokens.accent
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2);

    final lookX = lookTarget.dx * 4;
    final lookY = lookTarget.dy * 3;

    _drawEye(
      canvas,
      Offset(-size.width * 0.1 + lookX, -size.height * 0.05 + lookY),
      eyePaint,
      size.width * 0.06, // Larger eyes
    );
    _drawEye(canvas, Offset(size.width * 0.1 + lookX, -size.height * 0.05 + lookY), eyePaint, size.width * 0.06);
  }

  void _drawHands(Canvas canvas, Size size) {
    final handPaint = Paint()..color = DesignTokens.textOnPrimary;
    final handY = size.height * 0.08 + (math.sin(idleValue * math.pi * 2 + 1) * 3);

    // Rounded paws
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(-size.width * 0.32, handY), width: size.width * 0.12, height: size.width * 0.12),
        Radius.circular(size.width * 0.04),
      ),
      handPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width * 0.32, handY), width: size.width * 0.12, height: size.width * 0.12),
        Radius.circular(size.width * 0.04),
      ),
      handPaint,
    );
  }

  void _drawScarf(Canvas canvas, Size size) {
    final scarfPaint = Paint()..color = DesignTokens.accent;

    final scarfRect = Rect.fromCenter(center: Offset(0, size.height * 0.22), width: size.width * 0.6, height: size.height * 0.12);
    canvas.drawRRect(RRect.fromRectAndRadius(scarfRect, Radius.circular(size.height * 0.04)), scarfPaint);

    // Scarf tail
    canvas.save();
    canvas.translate(size.width * 0.28, size.height * 0.25);
    canvas.rotate(-0.1 + (math.sin(idleValue * math.pi * 2) * 0.2));

    final tailPath = Path()
      ..moveTo(-size.width * 0.08, 0)
      ..lineTo(size.width * 0.06, 0)
      ..quadraticBezierTo(size.width * 0.1, size.height * 0.1, size.width * 0.08, size.height * 0.25)
      ..lineTo(-size.width * 0.05, size.height * 0.25)
      ..close();
    canvas.drawPath(tailPath, scarfPaint);
    canvas.restore();
  }

  void _drawShadow(Canvas canvas, Size size, double jumpHeight) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1 * (1 - jumpHeight))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final jumpOffset = -math.sin(jumpHeight * math.pi) * (size.height * 0.25);
    final shadowScale = 1 - (jumpHeight * 0.4);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, size.height * 0.45 - jumpOffset), width: size.width * 0.6 * shadowScale, height: size.height * 0.12 * shadowScale),
      shadowPaint,
    );
  }
}

/// Documentation for MascotTips
class MascotTips {
  static const List<String> _emojis = ['🛍️', '💳', '🚚', '⭐', '🔍', '🏷️', '💬', '🍁'];
  static const List<String> _keys = [
    'mascot.tip_browse',
    'mascot.tip_secure',
    'mascot.tip_ships',
    'mascot.tip_rate',
    'mascot.tip_find',
    'mascot.tip_filter',
    'mascot.tip_questions',
    'mascot.tip_canadian',
  ];

  static String getTipForIndex(int index) {
    final i = index % _keys.length;
    return '${_emojis[i]} ${_keys[i].tr()}';
  }
}

/// Documentation for ShopMascot
class ShopMascot extends StatefulWidget {
  final MascotController controller;
  final double size;
  final bool showSpeechBubble;

  const ShopMascot({super.key, required this.controller, this.size = 80, this.showSpeechBubble = true});

  @override
  State<ShopMascot> createState() => _ShopMascotState();
}

class _ModernBubbleTail extends CustomPainter {
  final Color color;
  const _ModernBubbleTail({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.2, 0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShopMascotState extends State<ShopMascot> with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _jumpController;
  late AnimationController _blinkController;
  late AnimationController _bubbleController;
  late AnimationController _breathingController;
  Timer? _blinkTimer;
  Timer? _tipTimer;
  Timer? _initialBubbleTimer;
  int _currentTipIndex = 0;
  bool _isBubbleVisible = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Speech Bubble - more robust positioning
          if (widget.showSpeechBubble && _isBubbleVisible)
            Positioned(
              right: widget.size * 0.4, // Adjusted for better alignment
              bottom: widget.size * 0.8, // Raised slightly for breathing room
              child: AnimatedBuilder(
                animation: _bubbleController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _bubbleController.value,
                    child: Transform.scale(scale: 0.8 + (_bubbleController.value * 0.2), alignment: Alignment.bottomRight, child: _buildSpeechBubble()),
                  );
                },
              ),
            ),
          // Mascot
          Positioned(
            right: 0,
            bottom: 0,
            child: MouseRegion(
              onHover: (event) {
                final dx = (event.localPosition.dx - widget.size / 2) / (widget.size / 2);
                final dy = (event.localPosition.dy - widget.size / 2) / (widget.size / 2);
                widget.controller.lookAt(Offset(dx.clamp(-1, 1), dy.clamp(-1, 1)));
              },
              child: GestureDetector(
                onTap: () {
                  widget.controller.jump();
                  if (!_isBubbleVisible) {
                    setState(() => _isBubbleVisible = true);
                    _bubbleController.forward();
                  }
                },
                child: AnimatedBuilder(
                  animation: Listenable.merge([_idleController, _jumpController, _blinkController, _breathingController, widget.controller]),
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: MascotPainter(
                        idleValue: _idleController.value,
                        jumpValue: _jumpController.value,
                        blinkValue: _blinkController.value,
                        breathingValue: _breathingController.value,
                        lookTarget: widget.controller.lookTarget,
                        excitement: widget.controller.excitementLevel,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _tipTimer?.cancel();
    _initialBubbleTimer?.cancel();
    _idleController.dispose();
    _jumpController.dispose();
    _blinkController.dispose();
    _bubbleController.dispose();
    _breathingController.dispose();
    widget.controller.removeListener(_handleCommand);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _jumpController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scheduleNextBlink();
    _bubbleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _breathingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    if (widget.showSpeechBubble) {
      _initialBubbleTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && widget.showSpeechBubble) {
          setState(() => _isBubbleVisible = true);
          _bubbleController.forward();
          _startTipRotation();
        }
      });
    }

    widget.controller.addListener(_handleCommand);
  }

  Widget _buildSpeechBubble() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
              BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: -2),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  MascotTips.getTipForIndex(_currentTipIndex),
                  key: ValueKey<int>(_currentTipIndex),
                  style: TextStyle(color: DesignTokens.textPrimary, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showContactDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: DesignTokens.primaryGradient.begin,
                      end: DesignTokens.primaryGradient.end,
                      colors: DesignTokens.primaryGradient.colors.map((c) => c.withValues(alpha: 0.1)).toList(),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, color: DesignTokens.primary, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'mascot.get_help'.tr(),
                        style: TextStyle(color: DesignTokens.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Modern tail
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CustomPaint(
            size: const Size(16, 12),
            painter: const _ModernBubbleTail(color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _handleCommand() {
    if (widget.controller.isJumping && !_jumpController.isAnimating) {
      _jumpController.forward(from: 0).then((_) => _jumpController.reverse());
    }
  }

  Future<void> _launchUrl(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch url: $e');
    }
  }

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(Duration(milliseconds: 2000 + math.Random().nextInt(2000)), () async {
      if (!mounted) return;
      await _blinkController.forward();
      if (!mounted) return;
      await _blinkController.reverse();
      _scheduleNextBlink();
    });
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark ? DesignTokens.darkSurface : Colors.white,
        title: Text(
          'profile.contact_us'.tr(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(ctx).brightness == Brightness.dark ? DesignTokens.textOnDark : DesignTokens.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('profile.contact_us_desc'.tr(), style: TextStyle(color: DesignTokens.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            Semantics(
              link: true,
              label: 'link-email-support',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _launchUrl(
                    Uri(
                      scheme: 'mailto',
                      path: 'support@orignaventures.ca',
                      queryParameters: {'subject': 'Support Request - Origna GTA App', 'body': 'Hello Origna GTA Support Team,\n\n'},
                    ),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  splashColor: DesignTokens.primary.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(Icons.email_outlined, color: DesignTokens.primary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'support@orignaventures.ca',
                          style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Semantics(
              link: true,
              label: 'link-website',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _launchUrl(Uri.parse('https://orignaventures.ca')),
                  borderRadius: BorderRadius.circular(12),
                  splashColor: DesignTokens.primary.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(Icons.language, color: DesignTokens.primary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'orignaventures.ca',
                          style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.close'.tr(), style: TextStyle(color: DesignTokens.primary)),
          ),
        ],
      ),
    );
  }

  void _startTipRotation() {
    _tipTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() => _currentTipIndex++);
      } else {
        timer.cancel();
      }
    });
  }
}
