---
name: design-system-bible
description: Use when building UI components, implementing new screens, or auditing design consistency — covers DesignTokens, components, layout patterns, and implementation rules for OrignaGTA.
  Use when building or reviewing ANY UI component.
---

# 🎨 Design System Bible

## Source of Truth
`origna_gta/lib/utils/design_tokens.dart` — ALL visual decisions flow from here.

## Cardinal Rules
1. **NEVER hardcode colors** — always `DesignTokens.primary`, `DesignTokens.error`, etc.
2. **NEVER hardcode spacing** — always `DesignTokens.spacingXs` through `spacingXl`
3. **NEVER hardcode radii** — always `DesignTokens.radiusSm` through `radiusFull`
4. **NEVER use `withOpacity()`** — use `withValues(alpha:)` or `Color.fromRGBO`
5. **ALWAYS use Material 3** — `useMaterial3: true` is enforced in ThemeData

## Component Catalog

### Buttons
| Component | File | Use Case |
|-----------|------|----------|
| `ModernButton` | `widgets/modern_button.dart` | Primary/secondary CTAs |
| `GlassButton` | `utils/glassmorphism.dart` | Premium overlaid CTAs |
| `ScaleBounce` | `widgets/animations.dart` | Icon/small tap targets |

#### ModernButton Variants
```dart
// Primary (gradient background, white text)
ModernButton(text: 'Submit', onPressed: _submit)

// With loading state
ModernButton(text: 'Submit', onPressed: _submit, isLoading: true)

// Outline variant
ModernButton(text: 'Cancel', onPressed: _cancel, isOutline: true)
```

### Cards
| Component | File | Use Case |
|-----------|------|----------|
| `ModernCard` | `widgets/modern_card.dart` | Content containers |
| `GlassCard` | `utils/glassmorphism.dart` | Premium feature cards |
| `ModernProductCard` | `widgets/modern_product_card.dart` | Product grid items |

### Text Fields
| Component | File | Use Case |
|-----------|------|----------|
| `ModernTextField` | `widgets/modern_text_field.dart` | All form inputs |

### Navigation
| Component | File | Use Case |
|-----------|------|----------|
| `ModernAppBar` | `widgets/modern_navbar.dart` | Glassmorphic top bar |
| `ModernBottomNavBar` | `widgets/modern_navbar.dart` | Bottom navigation |
| `GlassAppBar` | `utils/glassmorphism.dart` | Immersive top bar |
| `CustomAppBar` | `widgets/custom_appbar.dart` | Standard gradient bar |

### Layout
| Component | File | Use Case |
|-----------|------|----------|
| `ResponsiveLayout` | `utils/responsive_layout.dart` | Adaptive builder |
| `ResponsiveGridView` | `utils/responsive_layout.dart` | Auto-column grid |
| `ResponsiveContainer` | `utils/responsive_layout.dart` | Max-width container |

## Theme Configuration (app.dart)
- Material 3 enabled
- ColorScheme seeded from `DesignTokens.primary`
- Scaffold background: `DesignTokens.surface`
- Font: `'Roboto'` (ThemeData), `'Inter'` (DesignTokens — use for headings)
- AppBar: white, 0 elevation, dark text
- Buttons: radius 12, primary color, white text
- Inputs: filled white, radius 12, primary focus color
- Cards: elevation 0, radius 16, white, no surface tint
- Dividers: grey[200]

## Semantic Color Usage
| Context | Color Token | Icon |
|---------|-------------|------|
| Money/Payment | `DesignTokens.success` | `Icons.payments` |
| Shipping | `DesignTokens.info` | `Icons.local_shipping` |
| Warning/Low Stock | `DesignTokens.warning` | `Icons.warning_amber` |
| Error/Failed | `DesignTokens.error` | `Icons.error_outline` |
| Premium/Featured | `DesignTokens.secondary` | `Icons.star` |
| New/Badge | `DesignTokens.tertiary` | `Icons.fiber_new` |
| Active/Selected | `DesignTokens.primary` | `Icons.check_circle` |
| Neutral/Disabled | `DesignTokens.outline` | `Icons.remove_circle_outline` |

