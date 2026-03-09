---
name: responsive-blueprint
description: Use when building or reviewing responsive layouts — breakpoints, grid system, adaptive patterns, and ResponsiveBreakpoints implementation techniques for OrignaGTA.
---

# 📱 Responsive Blueprint

## Source: `origna_gta/lib/utils/responsive_layout.dart`

## Breakpoint System
| Name | Min Width | Max Width | Columns | Side Padding | Use Case |
|------|-----------|-----------|---------|-------------|----------|
| `mobile` | 320px | 479px | 1 | 16px | Phones (portrait) |
| `mobilePlus` | 480px | 767px | 2 | 16px | Large phones, small tablets |
| `tablet` | 768px | 1023px | 3 | 24px | Tablets, laptop browsers |
| `desktop` | 1024px | ∞ | 4 | 32px | Desktop browsers |

## Responsive Widgets

### ResponsiveLayout (Primary Builder)
```dart
ResponsiveLayout(
  mobile: _buildMobileView(),     // Required — base layout
  tablet: _buildTabletView(),     // Optional — falls back to mobile
  desktop: _buildDesktopView(),   // Optional — falls back to tablet or mobile
)
```

### ResponsiveGridView (Auto-Column Grid)
```dart
ResponsiveGridView(
  children: products.map((p) => ProductCard(product: p)).toList(),
  // Automatically uses 1/2/3/4 columns based on breakpoint
)
```

### ResponsiveContainer (Max-Width Wrapper)
```dart
ResponsiveContainer(
  child: content,
  // Centers content with max-width constraint
)
```

### ResponsiveText (Scaling Typography)
```dart
ResponsiveText(
  'Product Name',
  style: ResponsiveTextStyle.heading2,
  // Auto-scales based on screen width
)
```

## Adaptive Layout Patterns

### Pattern 1: Stack → Side-by-Side
```
MOBILE (< 768px):          TABLET+ (≥ 768px):
┌────────────────┐         ┌──────────┬──────────┐
│   Image        │         │          │ Title    │
│                │         │  Image   │ Price    │
├────────────────┤         │          │ CTA      │
│ Title          │         │          │          │
│ Price          │         └──────────┴──────────┘
│ CTA            │
└────────────────┘

Implementation:
  if (isTabletOrAbove)
    Row(children: [imageSection, Expanded(child: infoSection)])
  else
    Column(children: [imageSection, infoSection])
```

### Pattern 2: Bottom Sheet → Side Panel
```
MOBILE:                    DESKTOP:
┌────────────────┐         ┌──────────────┬─────────┐
│ Main Content   │         │              │ Filter  │
│                │         │ Main Content │ Panel   │
│                │         │              │         │
├────────────────┤         │              │         │
│ ▲ Filters      │         └──────────────┴─────────┘
│ (bottom sheet) │
└────────────────┘
```

### Pattern 3: Bottom Nav → Sidebar Nav
```
MOBILE:                    DESKTOP:
┌────────────────┐         ┌────┬─────────────────┐
│                │         │Nav │                  │
│ Content        │         │    │ Content          │
│                │         │    │                  │
├────────────────┤         │    │                  │
│ 🏠 🛒 👤 ☰    │         └────┴─────────────────┘
└────────────────┘
```

### Pattern 4: Single Column → Multi-Column
```
MOBILE (1 col):   MOBILE+ (2 col):   TABLET (3 col):   DESKTOP (4 col):
┌──────┐          ┌─────┬─────┐      ┌────┬────┬────┐  ┌───┬───┬───┬───┐
│ Card │          │Card │Card │      │Card│Card│Card│  │ C │ C │ C │ C │
├──────┤          ├─────┼─────┤      ├────┼────┼────┤  ├───┼───┼───┼───┤
│ Card │          │Card │Card │      │Card│Card│Card│  │ C │ C │ C │ C │
├──────┤          └─────┴─────┘      └────┴────┴────┘  └───┴───┴───┴───┘
│ Card │
└──────┘
```

## Implementation Checklist

### Before Building
- [ ] Identify which pattern(s) apply to this screen
- [ ] Design mobile layout FIRST
- [ ] Plan tablet adaptations
- [ ] Plan desktop enhancements

### During Building
- [ ] Use `ResponsiveLayout` for major layout switches
- [ ] Use `ResponsiveGridView` for product grids, card grids
- [ ] Use `MediaQuery.of(context).size.width` for fine-tuning
- [ ] Use `LayoutBuilder` for parent-constrained sizing
- [ ] Use `Flexible` / `Expanded` instead of fixed widths
- [ ] Test horizontal overflow at each breakpoint

### Touch Target Rules
| Device | Minimum Target | Recommended |
|--------|---------------|-------------|
| Mobile | 48 × 48 dp | 56 × 56 dp |
| Tablet | 44 × 44 dp | 48 × 48 dp |
| Desktop | 36 × 36 dp | 40 × 40 dp |

### Typography Scaling
| Style | Mobile | Tablet | Desktop |
|-------|--------|--------|---------|
| Display | 28px | 32px | 40px |
| H1 | 24px | 28px | 32px |
| H2 | 20px | 22px | 24px |
| Body | 14px | 15px | 16px |
| Caption | 12px | 13px | 14px |

### Image Sizing
```dart
// ALWAYS provide cacheWidth for performance
Image.network(
  url,
  cacheWidth: MediaQuery.of(context).size.width > 768
    ? 800 : 400,  // Higher res for larger screens
  fit: BoxFit.cover,
)
```

## Common Mistakes
- ❌ Fixed pixel widths → use `Flexible`, `Expanded`, fractions
- ❌ Single layout for all sizes → use `ResponsiveLayout`
- ❌ Horizontal scrolling (unintentional) → wrap in `SingleChildScrollView` or fix layout
- ❌ Tiny touch targets on mobile → enforce 48dp minimum
- ❌ Desktop layout identical to mobile → waste of space
- ❌ Text too wide on desktop → constrain to ~680px max

