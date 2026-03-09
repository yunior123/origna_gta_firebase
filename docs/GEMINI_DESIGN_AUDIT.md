# Gemini Design Audit — OrignaGTA
*Generated 2026-03-02 via Gemini CLI analyzing Flutter web screenshots*

## Screens Audited
- Home page (loaded state, desktop 1440x900)
- Login page

## Findings

### Typography
- Login title (40px) vs Home header (24px) — inconsistent scale across entry/main
- Category labels (13px) and tagline (13px) too similar — no hierarchy
- Footer copyright/links (11px) below WCAG AA minimum for small text

### Color & Branding
- AppBar dark navy-violet gradient pulls focus from products
- BETA/DEV ribbon is expected (intentional by design)
- `textSecondary` (#6B7280) may fail WCAG AA on tinted backgrounds

### Layout
- ~40% of viewport consumed before first product (Header + Tagline + Search + Categories)
- Search bar vertically tall inside GlassContainer
- Mascot/chat bot overlaps product grid on smaller screens

### UX
- French locale showing by default on dev (`fr-FR` browser locale) — expected behavior
- Products take ~25s to load on cold start (dev Firestore cold-start latency)
- No sorting (price Low→High, Newest, Rating)
- No product quick-view / quick-add

### Missing E-commerce Essentials
- No hero/promotional banner section
- No sort controls
- No quick-add to cart from product list

## Top 3 Recommended Improvements (prioritized by impact)
1. **Compact header area** — Move tagline into AppBar subtitle or remove it; reduce category chip padding → brings products above the fold
2. **Align login/home typography scale** — Login title: 28-32px max to match app header scale
3. **Hero section** — Add a 2-3 slot promotional banner above the search bar (featured products, active deals)

## Performance Observation
- Home screen cold-start on dev: ~25s (Firestore + auth cold start)
- Should be ~3-5s in production (warm containers, faster network)
- Consider: add product count to Firestore meta-doc to avoid full query on cold start

## Product Cards (current state)
- Gradient placeholder (camera icon) when no image — correct fallback ✓
- Price, rating, favorites all displaying ✓
- TREND badge working ✓
- Skeleton shimmer during load ✓

---

# Claude Design Audit — OrignaGTA (Full Screen Audit)
*Generated 2026-03-03 via Claude Opus 4.6 — source code analysis of 13 files*

## Methodology
Static analysis of Flutter source code against the OrignaGTA design system defined in
`design_tokens.dart`, `responsive_layout.dart`, and the UI/UX agent's design system bible.
Focus areas: design token violations, responsive gaps, animation coverage, glass effects,
accessibility, dark mode, and repetitive layout patterns.

---

## 1. design_tokens.dart

**GRADE: B+**

### Issues Found

| # | Line | Issue | Impact | Fix |
|---|------|-------|--------|-----|
| 1 | 120 | Typo: `gloopBlur` should be `glassBlur` | LOW | Rename to `glassBlur` for consistency with `glassOpacity` |
| 2 | - | Missing named radius aliases (`radiusSm`, `radiusMd`, etc.) | MEDIUM | The system prompt documents `radiusSm=8`, `radiusMd=12`, `radiusLg=16` etc. but the actual file uses `radius8`, `radius12`, etc. Not technically wrong but diverges from the documented API names, which may confuse new contributors. |
| 3 | - | No `spacingXs`/`spacingMd`/`spacingLg` aliases | LOW | Same issue as radii -- tokens exist as `spacing4`, `spacing12`, etc. but the documented API says `spacingXs`, `spacingMd`. Either update docs or add aliases. |
| 4 | - | Missing `backgroundGradient` as a static const | MEDIUM | The immersive 3-stop gradient `#1F235A -> #2F3B8F -> #764BA2` exists only as `gradientStart/Middle/End` constants but no pre-built gradient constant matching the hero section spec. Only `backgroundGradient(isDark:)` exists, which produces a different 2-stop adaptive gradient. |
| 5 | 142 | Light mode `backgroundGradient` uses `Color(0xFFF0F2FF)` — hardcoded inline, not a named token | LOW | Extract as `static const Color backgroundLight = Color(0xFFF0F2FF)` |

---

## 2. responsive_layout.dart

**GRADE: A-**

### Issues Found

| # | Line | Issue | Impact | Fix |
|---|------|-------|--------|-----|
| 1 | - | `ResponsiveLayout` constructor takes `mobilePlus`, `tablet`, `desktop` — the "mobile" breakpoint (< 320) has no separate slot | LOW | This is documented as intentional. Fine. |
| 2 | - | `ResponsiveGridView` uses `GridView.builder` (not sliver) | MEDIUM | Cannot be composed inside a `CustomScrollView`. All screens using `CustomScrollView` must build their own `SliverGrid`, defeating the purpose of the reusable widget. Consider adding a `SliverResponsiveGridView`. |
| 3 | - | `ResponsiveGridView` has no `childAspectRatio` parameter | MEDIUM | All callers must rebuild their own grid delegate with product card aspect ratios. |

---

## 3. home_screen.dart

**GRADE: B**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | - | **No `ResponsiveLayout` usage** — the screen uses a single layout for all breakpoints | HIGH | No tablet sidebar, no desktop sidebar navigation. On desktop, it is just a wider phone layout. Should switch to a `ResponsiveLayout` with sidebar nav on desktop (per the design spec's "Bottom Nav -> Sidebar Nav" pattern). |
| 2 | ~489-493 | Tagline consumes vertical space before products — 40% of viewport above fold is non-product content (confirmed by previous Gemini audit) | HIGH | Move tagline into AppBar subtitle or remove. Compact the search/filter/category area. |
| 3 | - | No hero section / promotional banner — per design spec, home should have a gradient hero with CTA | MEDIUM | Add a featured products carousel or hero banner above the search bar. |
| 4 | - | `_categoryColors` in `_CategoryChips` builds chip gradients inline instead of referencing tokens — however these are intentional category-unique gradients, not brand colors | LOW | Acceptable; they are decorative. |
| 5 | - | Product grid uses `_getCardAspectRatio()` with manual breakpoint math instead of `ResponsiveBreakpoints.getValue()` | LOW | Refactor to use the responsive utility. |
| 6 | - | Mascot (Sparky / Moose) selection is based on day parity (`day % 2`) — quirky but not a design issue | LOW | No action needed; this is an intentional feature. |
| 7 | - | `_RecentlyViewedSection` — good horizontal carousel pattern, correctly placed | PASS | - |
| 8 | - | FadeSlideIn and shimmer loading are properly used for product grid | PASS | - |

### What Works Well
- Design tokens used consistently throughout
- `ConstrainedBox(maxWidth: contentMaxWidth)` centers content on desktop
- Category chips have animated gradients
- Sort and filter controls present
- Recently viewed section adds engagement
- Pull-to-refresh implemented
- Pagination loader present
- Legal footer with privacy/terms links

---

## 4. productdetails_screen.dart

**GRADE: B+**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | - | **No responsive side-by-side layout on tablet/desktop** — product image and info are always stacked vertically | HIGH | On tablet+, image gallery should be on the left (40-50% width) and product info on the right. The "Stack -> Side-by-Side" responsive pattern from the blueprint is not implemented. |
| 2 | 100 | `backgroundColor: Colors.white` on SliverAppBar — should use `DesignTokens.surface` or theme color | LOW | Change to `isDark ? DesignTokens.darkSurface : DesignTokens.surface` (already done for the `bottom` section, but not the main `backgroundColor`). |
| 3 | - | Sticky bottom CTA (`_StickyBottomCTA`) is present — good pattern | PASS | - |
| 4 | - | Image gallery uses `PageView.builder` with shimmer placeholder — good | PASS | - |
| 5 | - | Product name uses `ShaderMask` gradient text — premium visual feel | PASS | - |
| 6 | - | Price section uses gradient container with shadow — well-designed | PASS | - |
| 7 | - | `GlassContainer` used for product description — appropriate usage | PASS | - |
| 8 | - | Delivery info card, digital product info, variant section, reviews, Q&A, similar products — all present and complete | PASS | - |
| 9 | - | Skeleton loading (`_ProductDetailSkeleton`) with shimmer — good loading state | PASS | - |
| 10 | - | Content constrained to `contentMaxWidth` on desktop — correct | PASS | - |

### What Works Well
- Most polished screen in the audit
- Comprehensive feature set: video, ratings histogram, Q&A, stock notifications
- Delivery estimate chips with color-coded icons
- Trust badges for seller
- ShaderMask gradient text for premium feel
- Proper accessibility: Semantics on images, buttons, header

---

## 5. cart_screen.dart

**GRADE: B+**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | - | **No desktop/tablet two-column layout** — cart items list and order summary are always stacked vertically | MEDIUM | On tablet+, cart items should be on the left (60%) and the summary on the right (40%), per the "Checkout Flow" pattern. |
| 2 | - | Cart uses `ResponsiveBreakpoints.getValue` for `maxWidth` constraint — correctly adapts width on different breakpoints | PASS | - |
| 3 | - | `FadeSlideIn` on each cart item with stagger — good entrance animation | PASS | - |
| 4 | - | Shimmer skeleton for loading cart items — proper loading state | PASS | - |
| 5 | - | `AnimatedEmptyState` with mascot for empty cart — delightful | PASS | - |
| 6 | - | Free shipping progress bar (`_FreeShippingBar`) — great e-commerce pattern | PASS | - |
| 7 | - | Unavailable items warning banner — good edge case handling | PASS | - |
| 8 | - | Summary section has `ShaderMask` gradient for subtotal — premium feel | PASS | - |

### What Works Well
- One of the better screens: proper loading/error/empty states
- Granular Riverpod optimization (each cart item watches its own provider)
- Background gradient matches design system
- Pull-to-refresh on cart items list

---

## 6. checkout_screen.dart

**GRADE: B+**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | - | **No responsive side-by-side layout on desktop** — form and order summary are stacked | MEDIUM | Per the Checkout Flow pattern: on desktop, form section on left, order summary sidebar on right. |
| 2 | 20-115 | `_CheckoutStepper` — well-implemented 3-step progress indicator with gradient connectors | PASS | - |
| 3 | - | `GlassContainer` used for address card and digital delivery info — appropriate | PASS | - |
| 4 | - | Responsive spacing via `ResponsiveBreakpoints.getSpacing()` — correctly used | PASS | - |
| 5 | - | Buyer protection banner, security info, terms checkbox — comprehensive checkout UX | PASS | - |
| 6 | - | Coupon code section present | PASS | - |
| 7 | - | Order review bottom sheet before final payment — good anti-mistake pattern | PASS | - |

### What Works Well
- Most feature-complete checkout: step indicator, address management, delivery options,
  payment provider selection, coupon codes, order summary, terms acceptance, buyer protection
- Dark mode properly supported with `isDark` checks throughout
- Audit fix comments show active maintenance (`AUDIT FIX [CRITICAL]`)

---

## 7. profile_screen.dart

**GRADE: B**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | - | **Every menu item looks identical** — same icon-in-gradient-box, title, subtitle, chevron. No visual differentiation between primary actions (Orders, Seller Dashboard), settings, and danger zone | HIGH | Group items with section headers. Use different icon background colors for different sections (e.g., seller items use secondary gradient, settings use neutral). Add visual separators between groups. |
| 2 | - | Profile header card with gradient + avatar + decorative blobs — premium look | PASS | - |
| 3 | 109-121 | Sign-in button uses `ElevatedButton` instead of `ModernButton` — inconsistent with rest of app | MEDIUM | Replace with `ModernButton(label: 'auth.sign_in'.tr(), icon: Icons.login_rounded, onPressed: ...)` |
| 4 | - | `_buildMenuItem` creates 15+ identical cards — **visually repetitive** | HIGH | See issue #1. This is the most repetitive screen. All items blur together into an undifferentiated list. |
| 5 | - | Theme toggle is the only unique item (3-segment pill) — good differentiation | PASS | - |
| 6 | - | Premium card has gradient border — good distinction from regular items | PASS | - |
| 7 | 130-136 | Responsive maxWidth constraint used — correctly adapts on desktop | PASS | - |
| 8 | - | `FadeSlideIn` with staggered delays on each section — good entrance animation | PASS | - |
| 9 | - | Profile header avatar uses responsive sizing via `ResponsiveBreakpoints.getValue` | PASS | - |

### Key "Repetitive Layout" Issue
The profile screen has ~15 menu items that all use the exact same `_buildMenuItem` layout:
```
[gradient-icon-box] [Title / Subtitle] [chevron >]
```
This creates a flat, undifferentiated list that makes it hard to visually scan. Compare to
GitHub Settings (grouped with bold section headers) or Linear Settings (sidebar categories).

---

## 8. ordersuccess_screen.dart

**GRADE: A-**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | 85-86 | `ConstrainedBox(maxWidth: 500)` — hardcoded value, should use `ResponsiveBreakpoints.getValue` | LOW | Minor — 500px is reasonable for a centered success card. |
| 2 | 418-432 | `_Particle` confetti colors are hardcoded `Color(0xFF...)` values | LOW | These are decorative confetti colors; using brand tokens would look odd. Acceptable. |
| 3 | - | Missing: no confetti particles wrap in `RepaintBoundary` | LOW | The confetti `CustomPaint` runs continuously. Wrapping in `RepaintBoundary` would prevent repainting the rest of the tree. |

### What Works Well
- Custom confetti animation with `CustomPainter` — delightful celebration
- Mascot celebrates with `setExcitement(1.0)` + `jump()` — great brand personality
- `FadeSlideIn` staggered entrance for every element — choreographed reveal
- Delivery window card with date range — useful information
- Purchase summary (value + items) rendered — gap fixed per audit comment
- Two CTAs: "Continue Shopping" (primary) and "View My Orders" (outlined) — good flow
- Analytics tracking via `AnalyticsService.logPurchase`
- Background gradient from design tokens

---

## 9. categories_screen.dart

**GRADE: C+**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | 28-50 | **42 hardcoded `Color(0xFF...)` values** — 21 gradient pairs for category tiles not from design tokens | HIGH | These are per-category unique gradients, which is intentional design. However, they should be defined in a central location (e.g., `DesignTokens.categoryGradients` or a dedicated category theme map) rather than inline in the screen file. This violates the "NEVER hardcode colors" rule. |
| 2 | 154 | `Container(color: Colors.white, ...)` — hardcoded white for subcategory chips background, no dark mode support | HIGH | Should be `isDark ? DesignTokens.darkCard : Colors.white`. The subcategory chip area has zero dark mode support — it will show as a bright white strip in dark mode. |
| 3 | 200 | `const Divider(height: 1)` — uses default Material divider color, not design tokens | LOW | Should use `Divider(color: isDark ? DesignTokens.darkOutline : DesignTokens.outlineVariant)`. |
| 4 | - | **No background gradient** — the main scaffold uses default background | MEDIUM | Other screens use `DesignTokens.backgroundGradient(isDark: isDark)` or `surfaceGradient`. This screen has no body gradient, making it look flat compared to home/orders/cart. |
| 5 | - | No entrance animation on category tiles | MEDIUM | The grid items appear instantly. Should use staggered `FadeSlideIn` or `AnimatedListItem` per the animation choreography spec. |
| 6 | - | `_getCrossAxisCount` uses custom breakpoints (600/900/1200) instead of `ResponsiveBreakpoints.getGridColumns()` | LOW | Minor inconsistency. The custom breakpoints produce 3/4/5/6 columns which is reasonable for smaller tiles. |
| 7 | - | Product list inside category detail uses `ResponsiveBreakpoints.getGridColumns()` — correct | PASS | - |
| 8 | - | Shimmer loading in product list — correct loading state | PASS | - |
| 9 | - | AnimatedContainer on subcategory chips — smooth state transition | PASS | - |

---

## 10. orders_screen.dart

**GRADE: B**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | - | **No desktop layout adaptation** — orders are a single list even on wide screens | MEDIUM | On desktop, could show a master-detail layout: order list on left, selected order detail on right. |
| 2 | 84 | Loading state uses `ModernLoadingIndicator()` — not a shimmer skeleton | MEDIUM | Per the design spec, loading states should use shimmer placeholders, not spinners. Replace with skeleton order cards using `Shimmer.fromColors`. |
| 3 | - | Filter chips properly use gradient for selected state + AnimatedContainer | PASS | - |
| 4 | - | `FadeSlideIn` stagger on order list items — correct entrance animation | PASS | - |
| 5 | - | Background gradient from design tokens | PASS | - |
| 6 | - | Pending approvals banner — good pattern for action items | PASS | - |
| 7 | - | `ConstrainedBox(maxWidth: contentMaxWidth)` — correct desktop constraint | PASS | - |
| 8 | - | Pull-to-refresh with branded color | PASS | - |

---

## 11. seller_orders_screen.dart

**GRADE: B**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | - | **Nearly identical structure to orders_screen.dart** — same list layout, same card pattern, same constraint approach | MEDIUM | Both buyer and seller order screens look the same except for the earnings summary card at top. Consider differentiating the seller view (e.g., action-oriented cards with ship/tracking prominently featured). |
| 2 | 353 | Tooltip message contains raw string interpolation `'Gross: \$...'` — not localized | MEDIUM | Should use a translation key with named args. |
| 3 | - | `_EarningsSummaryCard` at top — good differentiation from buyer screen | PASS | - |
| 4 | - | `_UnansweredQaBadge` in AppBar — good seller notification pattern | PASS | - |
| 5 | - | `FadeSlideIn` stagger on order cards — correct | PASS | - |
| 6 | - | Background gradient, branded loading indicator | PASS | - |
| 7 | - | Suspended account state handled | PASS | - |
| 8 | 181 | `ConstrainedBox(maxWidth: 700)` — hardcoded, should use `ResponsiveBreakpoints.contentMaxWidth` | LOW | Inconsistent with other screens that use 1200. |

---

## 12. modern_product_card.dart

**GRADE: B+**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | 69-87 | `_shipFromLabel` — string "Ships from:" is hardcoded English, not localized | HIGH | Should use `'product.ships_from'.tr()` translation key. |
| 2 | 108 | `Border.all(color: Colors.white.withValues(alpha: 0.1))` — looks wrong in light mode (invisible white border on white card) | LOW | Consider `isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent` |
| 3 | - | Hover scale animation (1.0 -> 1.05) on `MouseRegion` — nice desktop interaction | PASS | - |
| 4 | - | Proper `Semantics` with full product info (name, price, rating, sale price) | PASS | - |
| 5 | - | Out-of-stock overlay with greyscale filter — good visual treatment | PASS | - |
| 6 | - | Trending badge with gradient glow — eye-catching | PASS | - |
| 7 | - | Add-to-cart button meets 48dp touch target requirement | PASS | - |
| 8 | - | Image error fallback with branded icon | PASS | - |

---

## 13. order_widgets.dart

**GRADE: B+**

### Issues Found

| # | Line(s) | Issue | Impact | Fix |
|---|---------|-------|--------|-----|
| 1 | 301-302 | `OrderStatusTimeline` — uses `Colors.white12` and `Colors.black12` for inactive steps instead of `DesignTokens.timelineInactiveDark/Light` | MEDIUM | Design tokens already has `timelineInactiveDark = Color(0xFF3A3A50)` and `timelineInactiveLight = Color(0xFFE0E4EE)`. These should be used instead of generic white/black opacity. |
| 2 | 394 | Same issue in `SellerPackageTimeline` — `Colors.white12`/`Colors.black12` | MEDIUM | Same fix as #1. |
| 3 | 245 | `DigitalItemActions` uses `Theme.of(context).colorScheme.surfaceContainerHighest` — Material 3 system color, not design token | LOW | Replace with `isDark ? DesignTokens.darkCard : DesignTokens.surfaceVariant` for consistency. |
| 4 | - | Both timeline widgets use `AnimatedContainer` for step circles — smooth transitions | PASS | - |
| 5 | - | Gradient connector lines between completed steps — premium look | PASS | - |
| 6 | - | `PendingApprovalsBanner` uses gradient + glow shadow — attention-grabbing | PASS | - |
| 7 | - | Status config maps use correct semantic colors from `DesignTokens` | PASS | - |

---

## Cross-Cutting Issues

### 1. NO `ResponsiveLayout` Widget Used Anywhere (HIGH)

None of the 10 audited screens use the `ResponsiveLayout(mobilePlus:, tablet:, desktop:)` widget.
Every screen renders a single phone-first layout, constrained with `ConstrainedBox(maxWidth:)` on
desktop. This means:

- **No sidebar navigation on desktop** (spec says bottom nav should become sidebar)
- **No side-by-side layouts** (product detail: image + info; checkout: form + summary)
- **No master-detail** for orders on desktop
- Desktop experience is just a wider phone layout centered on screen

**This is the single biggest design gap across the entire app.**

### 2. Repetitive Screen Pattern (MEDIUM)

Multiple screens follow the exact same structure:
```
Scaffold(
  appBar: AppBarFactory.simple(...),
  body: Container(
    gradient: backgroundGradient,
    child: Center(
      child: ConstrainedBox(maxWidth: ...,
        child: [loading/error/empty/data states]
      )
    )
  )
)
```

This is structurally correct but visually repetitive. Each screen feels the same because the
header (AppBarFactory gradient), body gradient, and card styles are identical. The profile screen
is the worst offender with 15 identical menu items.

### 3. GTA-Themed Content Check (PASS - NOT a game reference)

The "GTA" in OrignaGTA refers to the **Greater Toronto Area** (geographic region in Canada), NOT
Grand Theft Auto. All translation references confirmed:
- "Browse local GTA sellers!" — refers to Toronto area sellers
- "Reach customers across the GTA" — geographic market
- "Fast GTA shipping" — local delivery in Toronto region

**No game-themed placeholder text found anywhere.** All UI strings are legitimate marketplace
content.

### 4. Glass Effects Usage (PASS)

`GlassContainer` is used appropriately in 6 screens:
- Home (search bar overlay)
- Product Detail (description section)
- Checkout (address card, digital delivery info)
- Login (form card)
- Seller Registration (form sections)
- Edit Address (form)

No overuse on list items or body text containers.

### 5. Animation Coverage (GOOD)

- `FadeSlideIn` + stagger: used in 10/10 screens for list items
- `AnimatedEmptyState`: used in all empty states
- `AnimatedContainer`: used for chip selections, filter states
- Shimmer: used for product grids, cart item skeletons, product detail skeleton
- Custom confetti animation on order success
- Mascot animations on home and success screens

**Missing**: No screen-level entrance choreography (the "Hero Section Load" pattern from the
animation spec is not implemented on any screen).

---

## Summary Grades

| Screen | Grade | Top Issue |
|--------|-------|-----------|
| design_tokens.dart | B+ | `gloopBlur` typo; missing immersive gradient const |
| responsive_layout.dart | A- | `ResponsiveGridView` not sliver-compatible |
| home_screen.dart | B | No ResponsiveLayout; no hero section; 40% above-fold waste |
| productdetails_screen.dart | B+ | No side-by-side on tablet/desktop |
| cart_screen.dart | B+ | No two-column layout on desktop |
| checkout_screen.dart | B+ | No form+summary side-by-side on desktop |
| profile_screen.dart | B | 15 identical menu items; visually repetitive |
| ordersuccess_screen.dart | A- | Minor: confetti not in RepaintBoundary |
| categories_screen.dart | C+ | 42 hardcoded colors; no dark mode on subcategory area; no animations |
| orders_screen.dart | B | Spinner instead of shimmer; no desktop adaptation |
| seller_orders_screen.dart | B | Nearly identical to buyer orders; hardcoded tooltip string |
| modern_product_card.dart | B+ | "Ships from:" not localized |
| order_widgets.dart | B+ | Timeline uses Colors.white12 instead of DesignTokens |

---

## Top 10 Improvements (Ranked by Impact)

| # | Impact | Screen(s) | Improvement |
|---|--------|-----------|-------------|
| 1 | HIGH | ALL | Implement `ResponsiveLayout` — desktop sidebar nav, tablet adaptations, side-by-side layouts |
| 2 | HIGH | home_screen | Add hero section / promotional banner; compact above-fold area |
| 3 | HIGH | profile_screen | Group menu items with section headers; add visual differentiation between groups |
| 4 | HIGH | categories_screen | Fix dark mode on subcategory chips; add background gradient; add tile entrance animations |
| 5 | HIGH | modern_product_card | Localize "Ships from:" string via translation keys |
| 6 | MEDIUM | categories_screen | Move 42 hardcoded category colors to a central token location |
| 7 | MEDIUM | orders_screen | Replace `ModernLoadingIndicator` with shimmer skeleton cards |
| 8 | MEDIUM | order_widgets | Use `DesignTokens.timelineInactiveDark/Light` instead of `Colors.white12/black12` |
| 9 | MEDIUM | productdetails_screen | Add responsive side-by-side layout for tablet/desktop |
| 10 | MEDIUM | checkout_screen, cart_screen | Add two-column layout on desktop (content + summary sidebar) |
