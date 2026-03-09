```markdown
---
description: >
  Design and implement a new screen or major UI component from scratch.
  Produces world-class, responsive, accessible, animated Flutter UI
  inspired by GitHub, Stripe, and Linear design systems.
---

# Design New Screen

Use the `uiux-expert` agent to design and build a new screen.

## Steps

1. **Understand Requirements** — What is the screen for? What data does it display?
   What actions can the user take?

2. **Choose Layout Pattern** — Based on the content type, select from:
   - **Hero + Content** — Landing/marketing pages
   - **List/Grid** — Product catalog, order history
   - **Detail** — Product detail, order detail
   - **Form** — Checkout, registration, add product
   - **Dashboard** — Admin panel, seller dashboard
   - **Empty State** — When there's no data yet

3. **Read Design System** — Load these before coding:
   - `origna_gta/lib/utils/design_tokens.dart`
   - `origna_gta/lib/utils/glassmorphism.dart`
   - `origna_gta/lib/utils/responsive_layout.dart`
   - `origna_gta/lib/widgets/*.dart` (all available components)

4. **Build Mobile-First** — Implement the mobile layout first.

5. **Add Responsive Breakpoints** — Enhance for tablet and desktop.

6. **Add Animations** — Entrance, interaction, and state change animations.

7. **Add Accessibility** — Semantics, focus order, contrast verification.

8. **Add Loading/Error/Empty States** — ShimmerLoading, error messages, empty state.

9. **Connect to ViewModel** — Wire up to the appropriate Riverpod provider.

10. **Self-Audit** — Run through the UI audit checklist before declaring done.

```
