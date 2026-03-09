// coverage:ignore-file
import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:url_launcher/url_launcher.dart';

/// Documentation for CanadianMoose
class CanadianMoose extends StatefulWidget {
  final MooseController controller;
  final double size;
  final bool showSpeechBubble;

  const CanadianMoose({super.key, required this.controller, this.size = 90, this.showSpeechBubble = true});

  @override
  State<CanadianMoose> createState() => _CanadianMooseState();
}

/// Documentation for MooseController
class MooseController extends ChangeNotifier {
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
    await Future.delayed(const Duration(milliseconds: 800));
    _isJumping = false;
    notifyListeners();
  }

  void lookAt(Offset target) {
    final dx = target.dx.clamp(-1.0, 1.0);
    final dy = target.dy.clamp(-1.0, 1.0);
    _lookTarget = Offset(dx, dy);
    notifyListeners();
  }

  void setExcitement(double level) {
    _excitementLevel = level.clamp(0.0, 1.0);
    notifyListeners();
  }
}

/// Documentation for MoosePainter
class MoosePainter extends CustomPainter {
  final double idleValue;
  final double jumpValue;
  final double blinkValue;
  final double earWiggle;
  final double breathingValue;
  final Offset lookTarget;
  final double excitement;

  MoosePainter({
    required this.idleValue,
    required this.jumpValue,
    required this.blinkValue,
    required this.earWiggle,
    required this.breathingValue,
    required this.lookTarget,
    required this.excitement,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height * 0.55;

    final hoverY = math.sin(idleValue * math.pi * 2) * 2;
    final jumpY = -math.sin(jumpValue * math.pi) * (size.height * 0.2);
    final breathingScale = 1.0 + (math.sin(breathingValue * math.pi) * 0.02);

    canvas.save();
    canvas.translate(centerX, centerY + hoverY + jumpY);
    canvas.scale(breathingScale, 2.0 - breathingScale);
    canvas.rotate(lookTarget.dx * 0.05);

    _drawShadow(canvas, size, jumpValue);
    _drawBody(canvas, size);
    _drawScarf(canvas, size);
    _drawHead(canvas, size);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MoosePainter oldDelegate) =>
      idleValue != oldDelegate.idleValue ||
      jumpValue != oldDelegate.jumpValue ||
      blinkValue != oldDelegate.blinkValue ||
      earWiggle != oldDelegate.earWiggle ||
      breathingValue != oldDelegate.breathingValue ||
      lookTarget != oldDelegate.lookTarget ||
      excitement != oldDelegate.excitement;

  void _drawAntlers(Canvas canvas, Size size) {
    final antlerPaint = Paint()..color = const Color(0xFFEFEBE9);

    // Left
    canvas.save();
    canvas.translate(-size.width * 0.2, -size.height * 0.15);
    canvas.rotate(-0.15);
    _drawSingleAntler(canvas, size, antlerPaint);
    canvas.restore();

    // Right
    canvas.save();
    canvas.translate(size.width * 0.2, -size.height * 0.15);
    canvas.rotate(0.15);
    canvas.scale(-1, 1);
    _drawSingleAntler(canvas, size, antlerPaint);
    canvas.restore();
  }

  void _drawBody(Canvas canvas, Size size) {
    final bodyPaint = Paint()..color = const Color(0xFF6D4C41);
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, size.height * 0.1), width: size.width * 0.6, height: size.height * 0.45),
      Radius.circular(size.width * 0.2),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Lighter belly
    final bellyPaint = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, size.height * 0.15), width: size.width * 0.35, height: size.height * 0.3), bellyPaint);
  }

  void _drawEars(Canvas canvas, Size size) {
    final earPaint = Paint()..color = const Color(0xFF6D4C41);
    final wiggle = math.sin(earWiggle * math.pi * 2) * 0.1;

    // Left
    canvas.save();
    canvas.translate(-size.width * 0.22, -size.height * 0.05);
    canvas.rotate(-0.4 + wiggle);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 0), width: size.width * 0.12, height: size.height * 0.08), earPaint);
    canvas.restore();

    // Right
    canvas.save();
    canvas.translate(size.width * 0.22, -size.height * 0.05);
    canvas.rotate(0.4 - wiggle);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 0), width: size.width * 0.12, height: size.height * 0.08), earPaint);
    canvas.restore();
  }

  void _drawEyes(Canvas canvas, Size size) {
    final lookX = lookTarget.dx * 3;
    final lookY = lookTarget.dy * 2;

    final eyePosL = Offset(-size.width * 0.1 + lookX, -size.height * 0.02 + lookY);
    final eyePosR = Offset(size.width * 0.1 + lookX, -size.height * 0.02 + lookY);

    if (blinkValue > 0.1) {
      final blinkPaint = Paint()
        ..color = const Color(0xFF3E2723)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCenter(center: eyePosL, width: size.width * 0.08, height: size.height * 0.04), 0.2, 2.7, false, blinkPaint);
      canvas.drawArc(Rect.fromCenter(center: eyePosR, width: size.width * 0.08, height: size.height * 0.04), 0.2, 2.7, false, blinkPaint);
    } else {
      // Large kawaii eyes
      final eyeRadius = size.width * 0.06;
      canvas.drawCircle(eyePosL, eyeRadius, Paint()..color = Colors.white);
      canvas.drawCircle(eyePosR, eyeRadius, Paint()..color = Colors.white);
      canvas.drawCircle(eyePosL, eyeRadius * 0.7, Paint()..color = Colors.black);
      canvas.drawCircle(eyePosR, eyeRadius * 0.7, Paint()..color = Colors.black);
      // Highlights
      canvas.drawCircle(eyePosL - Offset(eyeRadius * 0.3, eyeRadius * 0.3), eyeRadius * 0.25, Paint()..color = Colors.white);
      canvas.drawCircle(eyePosR - Offset(eyeRadius * 0.3, eyeRadius * 0.3), eyeRadius * 0.25, Paint()..color = Colors.white);
    }

    // Blush
    final blushPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(-size.width * 0.18, size.height * 0.05), size.width * 0.05, blushPaint);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.05), size.width * 0.05, blushPaint);
  }

  void _drawHead(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(lookTarget.dx * 3, lookTarget.dy * 2 - size.height * 0.25);

    _drawAntlers(canvas, size);

    // Head shape - cuter, more rounded
    final headPaint = Paint()..color = const Color(0xFF795548);
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 0), width: size.width * 0.5, height: size.height * 0.38),
      Radius.circular(size.width * 0.18),
    );

    _drawEars(canvas, size);
    canvas.drawRRect(headRect, headPaint);

    // Snout
    final snoutPaint = Paint()..color = const Color(0xFFA1887F);
    final snoutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, size.height * 0.08), width: size.width * 0.52, height: size.height * 0.22),
      Radius.circular(size.width * 0.12),
    );
    canvas.drawRRect(snoutRect, snoutPaint);

    _drawEyes(canvas, size);
    _drawNostrils(canvas, size);

    canvas.restore();
  }

  void _drawNostrils(Canvas canvas, Size size) {
    final nostrilPaint = Paint()..color = const Color(0xFF4E342E);
    canvas.drawCircle(Offset(-size.width * 0.08, size.height * 0.14), 2, nostrilPaint);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.14), 2, nostrilPaint);

    final mouthPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final mouthPath = Path()
      ..moveTo(-size.width * 0.04, size.height * 0.2)
      ..quadraticBezierTo(0, size.height * 0.24, size.width * 0.04, size.height * 0.2);
    canvas.drawPath(mouthPath, mouthPaint);
  }

  void _drawScarf(Canvas canvas, Size size) {
    final scarfPaint = Paint()..color = DesignTokens.primary;
    final scarfRect = Rect.fromCenter(center: Offset(0, -size.height * 0.05), width: size.width * 0.55, height: size.height * 0.12);
    canvas.drawRRect(RRect.fromRectAndRadius(scarfRect, Radius.circular(size.height * 0.03)), scarfPaint);

    // Scarf tail
    canvas.save();
    canvas.translate(size.width * 0.25, -size.height * 0.02);
    canvas.rotate(-0.1 + (math.sin(idleValue * math.pi * 2) * 0.15));
    final tailPath = Path()
      ..moveTo(-size.width * 0.06, 0)
      ..lineTo(size.width * 0.05, 0)
      ..quadraticBezierTo(size.width * 0.08, size.height * 0.1, size.width * 0.05, size.height * 0.2)
      ..lineTo(-size.width * 0.04, size.height * 0.2)
      ..close();
    canvas.drawPath(tailPath, scarfPaint);
    canvas.restore();
  }

  void _drawShadow(Canvas canvas, Size size, double jumpHeight) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1 * (1 - jumpHeight))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final jumpOffset = -math.sin(jumpHeight * math.pi) * (size.height * 0.2);
    final shadowScale = 1 - (jumpHeight * 0.3);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, size.height * 0.45 - jumpOffset), width: size.width * 0.6 * shadowScale, height: size.height * 0.12 * shadowScale),
      shadowPaint,
    );
  }

  void _drawSingleAntler(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    path.addOval(Rect.fromLTWH(0, -size.height * 0.1, size.width * 0.25, size.height * 0.15));
    path.addOval(Rect.fromLTWH(size.width * 0.05, -size.height * 0.15, size.width * 0.08, size.height * 0.1));
    path.addOval(Rect.fromLTWH(size.width * 0.15, -size.height * 0.16, size.width * 0.06, size.height * 0.12));
    canvas.drawPath(path, paint);
  }
}

/// Documentation for MooseTips
class MooseTips {
  static List<String> get _tips => [
    'mascot.moose_tip_local_support'.tr(),
    'mascot.moose_tip_fast_shipping'.tr(),
    'mascot.moose_tip_secure_payments'.tr(),
    'mascot.moose_tip_local_biz'.tr(),
    'mascot.moose_tip_cart_saves'.tr(),
    'mascot.moose_tip_become_seller'.tr(),
    'mascot.moose_tip_get_help'.tr(),
    'mascot.moose_tip_made_in_canada'.tr(),
  ];

  static String getTipForIndex(int index) => _tips[index % _tips.length];
}

class _CanadianMooseState extends State<CanadianMoose> with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _jumpController;
  late AnimationController _blinkController;
  late AnimationController _earWiggleController;
  late AnimationController _bubbleController;
  late AnimationController _breathingController;
  Timer? _blinkTimer;
  Timer? _tipTimer;
  Timer? _speechBubbleTimer;
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
              right: widget.size * 0.4,
              bottom: widget.size * 0.85,
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
          // Moose
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
                  animation: Listenable.merge([
                    _idleController,
                    _jumpController,
                    _blinkController,
                    _earWiggleController,
                    _breathingController,
                    widget.controller,
                  ]),
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: MoosePainter(
                        idleValue: _idleController.value,
                        jumpValue: _jumpController.value,
                        blinkValue: _blinkController.value,
                        earWiggle: _earWiggleController.value,
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
    _speechBubbleTimer?.cancel();
    _idleController.dispose();
    _jumpController.dispose();
    _blinkController.dispose();
    _earWiggleController.dispose();
    _bubbleController.dispose();
    _breathingController.dispose();
    widget.controller.removeListener(_handleCommand);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _jumpController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scheduleNextBlink();
    _earWiggleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _bubbleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _breathingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);

    if (widget.showSpeechBubble) {
      _speechBubbleTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  MooseTips.getTipForIndex(_currentTipIndex),
                  key: ValueKey<int>(_currentTipIndex),
                  style: TextStyle(color: DesignTokens.textPrimary, fontSize: 11, fontFamily: 'Inter', fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _launchSupportEmail,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.contact_support_outlined, color: DesignTokens.primary, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Support',
                        style: TextStyle(color: DesignTokens.primary, fontSize: 10, fontWeight: FontWeight.w700),
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

  Future<void> _launchSupportEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@orignaventures.ca',
      queryParameters: {'subject': 'Support Request - Origna GTA App', 'body': 'Hello Origna GTA Support Team,\n\n'},
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        await launchUrl(Uri.parse('mailto:support@orignaventures.ca'));
      }
    } catch (e) {
      debugPrint('Could not launch email: $e');
    }
  }

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(Duration(milliseconds: 3000 + math.Random().nextInt(2000)), () async {
      if (!mounted) return;
      await _blinkController.forward();
      if (!mounted) return;
      await _blinkController.reverse();
      _scheduleNextBlink();
    });
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

class _ModernBubbleTail extends CustomPainter {
  final Color color;
  const _ModernBubbleTail({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
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
