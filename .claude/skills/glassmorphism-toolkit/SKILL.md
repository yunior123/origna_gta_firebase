---
name: glassmorphism-toolkit
description: Use when adding frosted glass UI elements, reviewing glass effect performance, or auditing glassmorphism consistency — component catalog, GPU tips, implementation patterns.
---

# 🪟 Glassmorphism Toolkit

## Source: `origna_gta/lib/utils/glassmorphism.dart`

## The Glass Design Philosophy
Glassmorphism creates **depth and hierarchy** through translucent layers with backdrop blur.
It signals **premium, floating, and interactive** elements.

## When to Use (and NOT to use)

### ✅ Perfect For
| Element | Why | Component |
|---------|-----|-----------|
| **Navigation bars** | Floats above content, always visible | `GlassAppBar` |
| **Floating actions** | Needs visual separation from background | `GlassFloatingActionButton` |
| **Modal overlays** | Creates depth between modal and background | `GlassModal` |
| **Premium cards** | Highlights featured/premium content | `GlassCard` |
| **Notification badges** | Needs to stand out without being opaque | `GlassBadge` |
| **Hero sections** | Creates immersive, modern feel | `GlassContainer` |
| **Overlay controls** | Media player controls, image viewer tools | `GlassButton` |

### ❌ Never For
| Element | Why | Use Instead |
|---------|-----|-------------|
| **Body text containers** | Blur reduces readability | `ModernCard` |
| **Form inputs** | Users need clear text fields | `ModernTextField` |
| **List items** | Performance — blur on 50+ items kills FPS | `ModernCard` |
| **Error messages** | Must be immediately clear | Solid colored container |
| **Data tables** | Readability is paramount | Standard `DataTable` |
| **Small text/labels** | Blur behind reduces legibility | Solid background |

## Component Reference

### GlassAppBar
```dart
GlassAppBar(
  title: 'Products',
  blurIntensity: GlassBlurIntensity.medium, // sigma: 10
  leading: BackButton(),
  actions: [CartIcon()],
)
```

### GlassCard
```dart
GlassCard(
  blurIntensity: GlassBlurIntensity.light, // sigma: 6
  child: Column(
    children: [
      Text('Featured Product'),
      Text('\$99.99'),
    ],
  ),
)
```

### GlassButton
```dart
GlassButton(
  text: 'Add to Cart',
  onPressed: _addToCart,
  blurIntensity: GlassBlurIntensity.subtle, // sigma: 3
)
```

### GlassFloatingActionButton
```dart
GlassFloatingActionButton(
  icon: Icons.add,
  onPressed: _createProduct,
  // Built-in scale animation on press
)
```

### GlassModal
```dart
showDialog(
  context: context,
  builder: (_) => GlassModal(
    child: ConfirmationContent(),
  ),
)
```

### GlassBadge
```dart
GlassBadge(
  count: cartItemCount,
  // Notification badge with glass effect
)
```

### GlassContainer (Generic)
```dart
GlassContainer(
  blurIntensity: GlassBlurIntensity.strong, // sigma: 15
  borderRadius: DesignTokens.radiusXl,
  child: HeroContent(),
)
```

## Blur Intensities
| Level | Sigma | Visual Effect | Performance Cost |
|-------|-------|---------------|-----------------|
| `subtle` | 3 | Barely there, hint of depth | Low |
| `light` | 6 | Soft separation, readable bg | Low-Medium |
| `medium` | 10 | Clear glass effect | Medium |
| `strong` | 15 | Prominent frosted glass | Medium-High |
| `extreme` | 25 | Heavy frost, fully obscured bg | High |

## Performance Guidelines

### DO
- Use `subtle` or `light` for elements that scroll
- Limit glass effects to **max 3-4 visible** at once
- Use `RepaintBoundary` around glass containers
- Cache blur results when possible (static backgrounds)
- Test on lowest-tier target device

### DON'T
- Don't use `extreme` blur on frequently-updating content
- Don't stack multiple glass containers (blur-on-blur is expensive)
- Don't animate blur intensity (sigma changes are expensive)
- Don't use glass on `ListView.builder` items
- Don't use glass if the background is solid color (pointless)

## Combining Glass with Gradients
```dart
// Premium hero section
Container(
  decoration: BoxDecoration(
    gradient: DesignTokens.backgroundGradient,
  ),
  child: GlassContainer(
    blurIntensity: GlassBlurIntensity.light,
    child: Column(
      children: [
        Text('Premium Feature',
          style: TextStyle(color: Colors.white, fontSize: 28)),
        GlassButton(text: 'Get Started', onPressed: _start),
      ],
    ),
  ),
)
```

## Glass Opacity
Default glass opacity is `0.8` (defined in `DesignTokens.glassOpacity`).
Default blur is `15` sigma (defined in `DesignTokens.glassBlur`).

To customize:
```dart
GlassContainer(
  blurIntensity: GlassBlurIntensity.medium,
  // Opacity is controlled internally via DesignTokens.glassOpacity
  child: content,
)
```

