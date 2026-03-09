# OrignaGTA — Stitch v2 Design Strategy
**Date:** 2026-03-03
**Account:** yr62813@gmail.com
**Project ID:** 1000227951598429623
**Theme:** Dark only
**Platforms:** Mobile · Tablet · Desktop/Web

---

## Design System Anchor
| Token | Value |
|---|---|
| Background | `#0F0F1E` body · `#1A1A2E` page · `#16213E` surface · `#1E1E32` card |
| Primary gradient | `#667EEA → #764BA2` (135°) |
| Accents | cyan `#5CE1E6` · success `#10B981` · error `#EF4444` · warning `#F59E0B` · coral `#FF6B6B` |
| Text | `#FFFFFF` · `#94A3B8` secondary · `#64748B` muted |
| Font | Inter (400/500/600/700/800/900) |
| Cards | `border-radius: 16px` · `border: rgba(102,126,234,0.15)` · purple shadow |
| Glass | `rgba(255,255,255,0.04)` + `backdrop-filter: blur(12px)` |
| Bottom nav | Home · Search · Cart · Profile |

## UX Improvements Over Account 1
- Glassmorphism headers, hero banners, nav bars
- Trust badges on product detail (Verified Seller · Fast Shipper · Ships CA)
- Sticky bottom CTA on product detail
- Progress stepper on checkout
- Revenue sparklines on seller dashboard
- Profile completion progress bar
- Premium paywall blur overlay (chat, photo reviews)
- Social proof "X viewing" on trending products
- Mermaid-style navigation flow map

## Screen Inventory (44 screens)
### Design System (4)
- [DS] Design System & Tokens
- [DS] Components — Buttons, Inputs, Badges
- [DS] Components — Product Cards & Lists
- [DS] Components — Navigation, Modals & States

### Auth (4)
- [Auth] Login
- [Auth] Registration
- [Auth] Email Verification & Forgot Password
- [Auth] Password Reset Success

### Home & Discovery (4)
- [Home] Mobile Feed
- [Home] Tablet Feed
- [Home] Desktop Web Feed
- [Search] Results & Filters

### Product (5)
- [Product] Detail — Mobile
- [Product] Detail — Desktop
- [Product] Q&A + Write Review
- [Product] Video Player
- [Categories] Browse Categories

### Cart & Checkout (4)
- [Cart] Shopping Cart
- [Checkout] Shipping Address
- [Checkout] Payment Method
- [Checkout] Review & Order Success

### Orders (2)
- [Orders] Order History
- [Orders] Order Detail + Return

### Profile & Account (3)
- [Profile] User Profile
- [Profile] Edit Profile
- [Settings] Settings & Notifications

### Favorites & Notifications (1)
- [Favorites] Saved Items

### Premium (2)
- [Premium] Go Premium + Active State
- [Premium] Chat Feature

### Seller (5)
- [Seller] Dashboard — Mobile
- [Seller] Dashboard — Desktop
- [Seller] Products List + Add Product
- [Seller] Orders + Earnings
- [Seller] Registration Steps

### Admin (1)
- [Admin] Admin Panel — Desktop

### States (2)
- [States] Empty & Error States Collection
- [States] Loading Skeletons

### Onboarding & Misc (3)
- [Onboarding] Welcome Screen
- [App] Miscellaneous Screens
- [Promo] Coupon & Promo States

### Seller Tools (1)
- [Seller] Warehouse & Inventory

### Desktop (2)
- [Desktop] Cart + Checkout
- [Desktop] Orders + Profile

### Flow Maps (1)
- [Flow] App Navigation Map

## Credit Budget
- 44 screens × ~3 credits = ~132 credits used
- Remaining buffer: ~218 credits for iterations
- 15 redesign credits reserved for post-review polishing
