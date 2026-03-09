// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/animations.dart';

@Preview(name: 'Fade & Stagger', group: 'Animations')
Widget previewAnimations() => previewGrid(
  children: [
    FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: DesignTokens.darkCard, borderRadius: BorderRadius.circular(DesignTokens.radius16)),
        child: const Text(
          'Faded In ✓',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.all(24),
      child: StaggeredList(
        children: [
          for (int i = 1; i <= 4; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: DesignTokens.darkCard, borderRadius: BorderRadius.circular(DesignTokens.radius12)),
              child: Text('Item $i', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    ),
  ],
);

@Preview(name: 'Empty States', group: 'Animations')
Widget previewEmptyStates() => previewGrid(
  children: [
    AnimatedEmptyState(
      icon: Icons.favorite_border_rounded,
      title: 'No favorites yet',
      subtitle: 'Tap the heart icon on any product to save it here.',
      action: ElevatedButton(onPressed: () {}, child: const Text('Browse Products')),
    ),
    const AnimatedEmptyState(icon: Icons.shopping_cart_outlined, title: 'Your cart is empty', subtitle: 'Start adding items to see them here.'),
    const AnimatedEmptyState(icon: Icons.inbox_outlined, title: 'No orders yet', subtitle: 'Your completed orders will appear here.', showMascot: true),
  ],
);

@Preview(name: 'Fade & Stagger Light', group: 'Animations')
Widget previewAnimationsLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: DesignTokens.darkCard, borderRadius: BorderRadius.circular(DesignTokens.radius16)),
        child: const Text(
          'Faded In ✓',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.all(24),
      child: StaggeredList(
        children: [
          for (int i = 1; i <= 4; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: DesignTokens.darkCard, borderRadius: BorderRadius.circular(DesignTokens.radius12)),
              child: Text('Item $i', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    ),
  ],
);

@Preview(name: 'Empty States Light', group: 'Animations')
Widget previewEmptyStatesLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    AnimatedEmptyState(
      icon: Icons.favorite_border_rounded,
      title: 'No favorites yet',
      subtitle: 'Tap the heart icon on any product to save it here.',
      action: ElevatedButton(onPressed: () {}, child: const Text('Browse Products')),
    ),
    const AnimatedEmptyState(icon: Icons.shopping_cart_outlined, title: 'Your cart is empty', subtitle: 'Start adding items to see them here.'),
    const AnimatedEmptyState(icon: Icons.inbox_outlined, title: 'No orders yet', subtitle: 'Your completed orders will appear here.', showMascot: true),
  ],
);
