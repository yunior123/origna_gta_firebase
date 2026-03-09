---
name: animation-choreography
description: Use when adding motion to screens, reviewing animation quality, or fixing animation stutter — timing curves, choreography sequences, and implementation patterns.
---

# 🎬 Animation Choreography Guide

## Core Principle: Motion = Meaning
Every animation must answer: **What is this telling the user?**

| Purpose | Example | Duration | Curve |
|---------|---------|----------|-------|
| **Feedback** | Button press scale | 100-150ms | `easeOutCubic` |
| **Transition** | Page navigation | 300ms | `easeInOutCubic` |
| **Entrance** | Card appearing | 200-400ms | `easeOutCubic` |
| **Exit** | Dismissing item | 150-200ms | `easeInCubic` |
| **Emphasis** | Success checkmark | 600ms | `elasticOut` |
| **Loading** | Shimmer sweep | 1500ms | `linear` (repeating) |

## Available Widgets & When to Use

### Entry Animations
```dart
// Single item fade + slide
FadeSlideIn(
  delay: Duration(milliseconds: 200),
  child: MyWidget(),
)

// List with staggered entries (50ms per item)
StaggeredList(
  children: items.map((i) => ItemCard(item: i)).toList(),
)

// Simple fade in
FadeInWidget(
  duration: Duration(milliseconds: 400),
  child: MyWidget(),
)
```

### Interaction Animations
```dart
// Tap to scale (buttons, cards)
TapScaleAnimation(
  child: MyButton(),
)

// Scale bounce (icons, small elements)
ScaleBounce(
  child: Icon(Icons.favorite),
)
```

### Loading Animations
```dart
// Skeleton shimmer (replace CircularProgressIndicator!)
ShimmerLoading(
  width: double.infinity,
  height: 200,
  borderRadius: DesignTokens.radiusLg,
)

// Animated number counter
AnimatedCounter(
  value: totalPrice,
  duration: Duration(milliseconds: 500),
)
```

### Page Transitions
```dart
// Slide + fade transition (use instead of MaterialPageRoute!)
context.pushAnimated(
  ProductDetailScreen(product: product),
  direction: SlideDirection.right,
);

// Replace current page
context.pushReplacementAnimated(HomeScreen());
```

### Success Animations
```dart
// Drawn checkmark
AnimatedCheckmark(
  size: 64,
  color: DesignTokens.success,
)

// Bounce emphasis
BounceAnimation(
  child: Icon(Icons.check_circle, size: 80),
)
```

### Empty States
```dart
// Animated empty state (scale + fade)
AnimatedEmptyState(
  icon: Icons.shopping_cart_outlined,
  title: 'Your cart is empty',
  subtitle: 'Start adding products to your cart',
  action: ModernButton(
    text: 'Browse Products',
    onPressed: () => context.pushAnimated(HomeScreen()),
  ),
)
```

## Choreography Recipes

### Screen Load Sequence
```
Timeline:
  0ms    → Scaffold renders (instant)
  0ms    → ShimmerLoading placeholders visible
  ~500ms → Data arrives
  0ms    → Shimmer → Real content (AnimatedSwitcher, 300ms)
  0ms    → Header FadeSlideIn (from top, 200ms)
  100ms  → First card FadeSlideIn (from bottom)
  150ms  → Second card FadeSlideIn
  200ms  → Third card FadeSlideIn
  ...    → 50ms stagger per item, max 8 items
  400ms  → FAB scales in (ScaleBounce)
```

### Add to Cart Micro-Interaction
```
Timeline:
  0ms   → Button scales down to 0.95 (TapScaleAnimation)
  100ms → Button scales back to 1.0
  100ms → Cart icon in navbar bounces (BounceAnimation)
  200ms → Badge count animates up (AnimatedCounter)
  200ms → Brief success color flash on button
  500ms → SnackBar slides up from bottom
```

### Pull to Refresh
```
Timeline:
  Drag  → Indicator appears with spring physics
  Release → Indicator snaps to loading position
  ~1s   → Data refreshes
  0ms   → Old items fade out (150ms)
  50ms  → New items stagger in (50ms × n)
  Done  → Indicator springs back up
```

### Delete Item (Swipe)
```
Timeline:
  Swipe → Item slides right, red background reveals
  Release → If past threshold:
    0ms   → Item scales to 0.95 + continues sliding out
    200ms → Item height animates to 0
    300ms → Gap closes (AnimatedSize)
    300ms → SnackBar with "Undo" appears
```

## Performance Rules
1. **Use `AnimatedBuilder`** — not `setState` in animation callbacks
2. **Use `TweenAnimationBuilder`** for simple single-property animations
3. **Dispose controllers** — always `_controller.dispose()` in `dispose()`
4. **RepaintBoundary** — wrap complex animated widgets
5. **`vsync: this`** — always use `TickerProviderStateMixin`
6. **Avoid `Curves.bounceOut`** — it causes frame drops; use `Curves.elasticOut` sparingly

## Anti-Patterns (NEVER DO)
- ❌ `CircularProgressIndicator()` as loading state → use `ShimmerLoading`
- ❌ `MaterialPageRoute` for navigation → use `SlidePageRoute` / `context.pushAnimated`
- ❌ Instant list appearance → use `StaggeredList` or `AnimatedListItem`
- ❌ `Navigator.push` without animation → use extension methods
- ❌ Animation duration > 600ms → feels sluggish
- ❌ Animation on EVERY scroll pixel → use `NotificationListener` with throttle

