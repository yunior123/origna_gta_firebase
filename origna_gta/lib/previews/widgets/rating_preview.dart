// coverage:ignore-file
/// Flutter Widget Previewer — RatingHistogram variants.
/// Run: flutter widget-preview start
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/rating_histogram.dart';

import 'package:origna_gta/previews/_preview_theme.dart';

// ─── Perfect rating (all 5-star) ─────────────────────────────────────────────

@Preview(name: 'Perfect — all 5-star', group: 'RatingHistogram')
Widget previewRatingPerfect() => previewWrapper(
  child: RatingHistogram(
    counts: [120, 0, 0, 0, 0], // [5★, 4★, 3★, 2★, 1★]
    total: 120,
  ),
);

// ─── Mixed rating ─────────────────────────────────────────────────────────────

@Preview(name: 'Mixed — realistic distribution', group: 'RatingHistogram')
Widget previewRatingMixed() => previewWrapper(
  child: RatingHistogram(
    counts: [84, 31, 12, 7, 4], // [5★, 4★, 3★, 2★, 1★]
    total: 138,
  ),
);

// ─── Low rating ───────────────────────────────────────────────────────────────

@Preview(name: 'Low — mostly 1-2 star', group: 'RatingHistogram')
Widget previewRatingLow() => previewWrapper(
  child: RatingHistogram(
    counts: [3, 5, 14, 28, 50], // [5★, 4★, 3★, 2★, 1★]
    total: 100,
  ),
);

// ─── Empty (no reviews yet) ───────────────────────────────────────────────────

@Preview(name: 'Empty — no reviews', group: 'RatingHistogram')
Widget previewRatingEmpty() => previewWrapper(
  child: RatingHistogram(
    counts: [0, 0, 0, 0, 0],
    total: 0,
  ),
);

// ─── Light theme variant ──────────────────────────────────────────────────────

@Preview(name: 'Mixed — light theme', group: 'RatingHistogram', brightness: Brightness.light)
Widget previewRatingMixedLight() => previewWrapper(
  theme: previewLightTheme,
  background: DesignTokens.surface,
  child: RatingHistogram(
    counts: [84, 31, 12, 7, 4],
    total: 138,
  ),
);

// ─── All variants stacked ─────────────────────────────────────────────────────

@Preview(name: 'All variants', group: 'RatingHistogram')
Widget previewRatingAllVariants() => previewGrid(
  children: [
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perfect (120 reviews)',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        RatingHistogram(counts: [120, 0, 0, 0, 0], total: 120),
      ],
    ),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mixed (138 reviews)',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        RatingHistogram(counts: [84, 31, 12, 7, 4], total: 138),
      ],
    ),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Low (100 reviews)',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        RatingHistogram(counts: [3, 5, 14, 28, 50], total: 100),
      ],
    ),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No reviews yet',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        RatingHistogram(counts: [0, 0, 0, 0, 0], total: 0),
      ],
    ),
  ],
);
