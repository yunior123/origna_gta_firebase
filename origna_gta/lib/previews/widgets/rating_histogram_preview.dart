// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/widgets/rating_histogram.dart';

@Preview(name: 'Rating Histogram — Variants', group: 'RatingHistogram')
Widget previewHistogramVariants() => previewGrid(
  children: [
    RatingHistogram(counts: [45, 12, 5, 2, 1], total: 65),
    RatingHistogram(counts: [100, 50, 20, 10, 5], total: 185),
    RatingHistogram(counts: [0, 0, 0, 0, 0], total: 0),
  ],
);

@Preview(name: 'Rating Histogram Light — Variants', group: 'RatingHistogram')
Widget previewHistogramVariantsLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    RatingHistogram(counts: [45, 12, 5, 2, 1], total: 65),
    RatingHistogram(counts: [100, 50, 20, 10, 5], total: 185),
    RatingHistogram(counts: [0, 0, 0, 0, 0], total: 0),
  ],
);
