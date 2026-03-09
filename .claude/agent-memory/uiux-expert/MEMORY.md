# UI/UX Expert Agent Memory

## Audit Status (2026-03-03)
- Full code audit completed: 13 files, grades B- to A-
- Report saved to `docs/GEMINI_DESIGN_AUDIT.md`
- See `audit-findings.md` for detailed per-screen notes

## Critical Gap: No ResponsiveLayout Usage
- Zero screens use the `ResponsiveLayout(mobilePlus:, tablet:, desktop:)` widget
- All screens render phone-first layout constrained with `ConstrainedBox(maxWidth:)` on desktop
- No sidebar nav on desktop, no side-by-side layouts anywhere
- This is the single biggest design gap in the app

## Design Token Issues
- `gloopBlur` typo (should be `glassBlur`) in design_tokens.dart line 120
- Alias mismatch: code uses `radius8/12/16`, docs say `radiusSm/radiusMd/radiusLg`
- Missing: immersive 3-stop gradient as const (only adaptive 2-stop exists)

## categories_screen.dart = Worst Screen (C+)
- 42 hardcoded Color(0xFF...) values for category gradients (lines 28-50)
- Subcategory area has zero dark mode support (Container color: Colors.white, line 154)
- No background gradient, no entrance animations on tiles

## profile_screen.dart = Most Repetitive (B)
- 15 identical `_buildMenuItem` calls with same layout pattern
- No visual grouping or section headers between categories
- Sign-in button uses ElevatedButton instead of ModernButton (line 109)

## "GTA" in OrignaGTA = Greater Toronto Area (NOT Grand Theft Auto)
- All translation references are geographic (local sellers, shipping, market)
- No game-themed placeholder text found

## Things Working Well
- Design tokens used consistently (no random Colors.* in most screens)
- FadeSlideIn + stagger animation in all 10 screens
- Shimmer loading in product grids and cart
- GlassContainer used appropriately (6 screens, never on list items)
- Dark mode supported in most screens
- Accessibility: Semantics labels on most interactive elements
