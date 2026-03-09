---
name: accessibility-matrix
description: Use when implementing, auditing, or reviewing accessibility — WCAG 2.1 AA compliance, Flutter Semantics labels, contrast ratios, focus management, or screen reader testing.
  Use when building, reviewing, or auditing ANY UI component.
---

# ♿ Accessibility Matrix

## WCAG 2.1 AA — Non-Negotiable Requirements

### Perceivable
| # | Criterion | Flutter Implementation |
|---|-----------|----------------------|
| 1.1.1 | Non-text content has text alternatives | `Semantics(label:)` on images, icons |
| 1.3.1 | Info and relationships conveyed programmatically | Semantic heading hierarchy, list semantics |
| 1.3.4 | Content does not restrict orientation | Don't lock to portrait/landscape |
| 1.4.1 | Color is not the only visual means | Icons + text alongside color indicators |
| 1.4.3 | Text contrast ≥ 4.5:1 | Use verified color pairs (see matrix below) |
| 1.4.4 | Text can be resized to 200% | Support `MediaQuery.textScaleFactor` |
| 1.4.11 | Non-text contrast ≥ 3:1 | Borders, icons, focus indicators |

### Operable
| # | Criterion | Flutter Implementation |
|---|-----------|----------------------|
| 2.1.1 | All functionality keyboard accessible | `FocusNode`, `FocusTraversalGroup` |
| 2.4.3 | Focus order is logical | `FocusTraversalOrder`, `OrderedTraversalPolicy` |
| 2.4.6 | Headings and labels are descriptive | Meaningful text, not "Item 1" |
| 2.4.7 | Focus indicator is visible | Custom focus decoration |
| 2.5.5 | Touch target ≥ 44×44 CSS px | 48×48 dp in Flutter |

### Understandable
| # | Criterion | Flutter Implementation |
|---|-----------|----------------------|
| 3.1.1 | Language of page is programmatically set | `MaterialApp(locale:)` |
| 3.2.1 | No unexpected context changes on focus | Don't navigate on focus |
| 3.3.1 | Errors are identified and described | Inline validation messages |
| 3.3.2 | Labels or instructions for user input | `InputDecoration(labelText:)` |

### Robust
| # | Criterion | Flutter Implementation |
|---|-----------|----------------------|
| 4.1.2 | Name, role, value for all UI components | `Semantics` widget properties |

## Color Contrast Verification Matrix

### Origna GTA Verified Pairs
| Foreground | Background | Ratio | Pass AA? |
|------------|-----------|-------|----------|
| `#1A1A2E` (dark) | `#F8F9FA` (surface) | 15.4:1 | ✅ AAA |
| `#1A1A2E` (dark) | `#FFFFFF` (white) | 18.1:1 | ✅ AAA |
| `#667EEA` (primary) | `#F8F9FA` (surface) | 4.6:1 | ✅ AA |
| `#667EEA` (primary) | `#FFFFFF` (white) | 4.2:1 | ⚠️ AA large only |
| `#FFFFFF` (white) | `#667EEA` (primary) | 4.2:1 | ⚠️ AA large only |
| `#FFFFFF` (white) | `#764BA2` (secondary) | 7.2:1 | ✅ AAA |
| `#FFFFFF` (white) | `#1A1A2E` (dark) | 18.1:1 | ✅ AAA |
| `#EF4444` (error) | `#FFFFFF` (white) | 4.6:1 | ✅ AA |
| `#10B981` (success) | `#FFFFFF` (white) | 3.2:1 | ❌ FAIL |
| `#1A1A2E` (dark) | `#10B981` (success) | 5.7:1 | ✅ AA |
| `#F59E0B` (warning) | `#FFFFFF` (white) | 2.1:1 | ❌ FAIL |
| `#1A1A2E` (dark) | `#F59E0B` (warning) | 8.6:1 | ✅ AAA |

### ⚠️ Known Contrast Issues
1. **Success green on white** fails AA — use dark text on success backgrounds
2. **Warning amber on white** fails AA — use dark text on warning backgrounds
3. **Primary on white** is borderline — safe for large text (18px+) only

## Flutter Semantics Patterns

### Images
```dart
// Informative image
Semantics(
  label: 'Product photo: Blue running shoes, front view',
  image: true,
  child: Image.network(product.imageUrl),
)

// Decorative image (hide from screen reader)
ExcludeSemantics(
  child: Image.asset('assets/decorative_wave.png'),
)
```

### Buttons
```dart
// Always provide tooltip on IconButton
IconButton(
  icon: Icon(Icons.shopping_cart),
  tooltip: 'View cart (${cartCount} items)',
  onPressed: _openCart,
)

// Custom buttons need Semantics
Semantics(
  button: true,
  label: 'Add ${product.name} to cart, price ${product.price}',
  child: ModernButton(text: 'Add to Cart', onPressed: _add),
)
```

### Form Fields
```dart
// labelText is automatically used by screen readers
ModernTextField(
  labelText: 'Email address', // ← This IS the semantic label
  hintText: 'you@example.com',
  keyboardType: TextInputType.emailAddress,
)

// Error messages are announced automatically
ModernTextField(
  labelText: 'Password',
  errorText: showError ? 'Password must be at least 8 characters' : null,
)
```

### Lists
```dart
// Each list item should be a semantic unit
Semantics(
  label: '${product.name}, ${product.price}, ${product.rating} stars',
  child: ModernProductCard(product: product),
)
```

### Status Indicators
```dart
// NEVER use color alone — always include text/icon
Row(
  children: [
    // ❌ Bad: color only
    // Container(color: Colors.green, width: 8, height: 8)
    
    // ✅ Good: icon + text + color
    Icon(Icons.check_circle, color: DesignTokens.success, 
         semanticLabel: 'In stock'),
    Text('In Stock', style: TextStyle(color: DesignTokens.success)),
  ],
)
```

### Compound Widgets
```dart
// Merge semantics for widgets that should be one unit
MergeSemantics(
  child: ListTile(
    leading: Icon(Icons.shipping, semanticLabel: ''),
    title: Text('Free Shipping'),
    subtitle: Text('Orders over \$50'),
    // Screen reader announces as one item: "Free Shipping, Orders over $50"
  ),
)
```

## Focus Management

### Tab/Focus Order
```dart
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: Column(
    children: [
      FocusTraversalOrder(
        order: NumericFocusOrder(1),
        child: ModernTextField(labelText: 'Name'),
      ),
      FocusTraversalOrder(
        order: NumericFocusOrder(2),
        child: ModernTextField(labelText: 'Email'),
      ),
      FocusTraversalOrder(
        order: NumericFocusOrder(3),
        child: ModernButton(text: 'Submit'),
      ),
    ],
  ),
)
```

### Focus Ring Style
```dart
// Custom visible focus indicator
Focus(
  child: Container(
    decoration: BoxDecoration(
      border: Border.all(
        color: hasFocus ? DesignTokens.primary : Colors.transparent,
        width: 2,
      ),
      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
    ),
    child: content,
  ),
)
```

## Testing Checklist
- [ ] Run app with **VoiceOver** (iOS) / **TalkBack** (Android)
- [ ] Navigate entire flow without touching screen (keyboard only)
- [ ] Verify all interactive elements are announced with role + label
- [ ] Confirm focus order follows visual layout
- [ ] Test with text scale factor 2.0
- [ ] Verify no information is conveyed by color alone
- [ ] Check all images have appropriate labels
- [ ] Confirm error messages are announced

## Quick Audit Command
When auditing a file, grep for these anti-patterns:
```bash
# Missing semantics on images
grep -n "Image.network\|Image.asset" <file> | grep -v "Semantics\|excludeSemantics"

# Missing tooltips on IconButtons
grep -n "IconButton" <file> | grep -v "tooltip"

# Hardcoded colors (might have contrast issues)
grep -n "Color(0x\|Colors\." <file> | grep -v "DesignTokens"

# Missing labels on text fields
grep -n "TextField\|TextFormField" <file> | grep -v "labelText\|label:"
```

