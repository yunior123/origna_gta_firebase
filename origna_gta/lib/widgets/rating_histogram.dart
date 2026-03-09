import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';

/// Displays a 5-star rating breakdown as a bar histogram.
///
/// [counts] — list of 5 ints: [count5star, count4star, count3star, count2star, count1star]
/// [total]  — sum of all counts (used to compute bar fill ratio)
class RatingHistogram extends StatelessWidget {
  final List<int> counts;
  final int total;

  const RatingHistogram({
    super.key,
    required this.counts,
    required this.total,
  }) : assert(counts.length == 5, 'counts must have exactly 5 elements');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: List.generate(5, (i) {
        final star = 5 - i;
        final count = counts[i];
        final ratio = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$star',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star_rounded, size: 14, color: DesignTokens.warning),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    color: DesignTokens.warning,
                    backgroundColor: isDark
                        ? DesignTokens.darkSurfaceVariant
                        : DesignTokens.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    color: DesignTokens.textDisabled,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
