import 'package:flutter/material.dart';

/// Documentation for StandalonePromoWidget
class StandalonePromoWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String discountText;
  final bool isDark;
  final VoidCallback? onTap;

  const StandalonePromoWidget({super.key, required this.title, required this.subtitle, required this.discountText, required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [const Color(0xFF1E1E1E), const Color(0xFF2C2C2C)] : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(color: isDark ? const Color(0xFFFF5252) : const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(16.0)),
            child: Text(
              discountText,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.0, letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 16.0),
          Text(
            title,
            style: TextStyle(
              fontSize: 28.0,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1976D2),
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            subtitle,
            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF455A64), height: 1.5),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24.0),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : const Color(0xFF1976D2),
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                    elevation: 0,
                  ),
                  child: const Text('Shop Now', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
