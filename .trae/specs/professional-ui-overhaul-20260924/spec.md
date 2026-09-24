# Professional UI Overhaul Spec

## Problem / Users / Goals / Non-Goals

### Problem
Current app UI works functionally, but:
- Cards use 8px radius with no shadows — they look "flat" and dated, not professional or SaaS-style
- No elevation/shadow system across the app, giving inconsistent depth
- Login/dashboard screen use simple colors instead of branded gradients
- Form inputs are plain — no focused animation, no consistent outline style
- POS product cards and deal tiles lack polish (no soft depth, no subtle gradient)
- High-value screens (Home Dashboard, POS, Login, Add Product, Product List) should look premium without losing the POS/retail "functional" feel

### Primary Users
- Store owner/admin (uses Dashboard, Reports, Settings)
- Cashier (uses POS 80% of the time)
- Manager (uses Products, Customers, Purchases)

### Goals
1. Make the app look **premium/professional** (SaaS/POS dashboard grade) using depth, gradients, and rounded corners
2. Apply changes **systemically** via the existing `ThemeProvider` so ALL screens automatically upgrade (inputs, cards, decorations, buttons)
3. Pay special attention to **high-visibility screens**: Login, Home Dashboard, POS, Add Product Form, Product List, Deals
4. Keep **100% existing behavior** — no logic changes, no data schema changes, no new features
5. Preserve and improve both **Light AND Dark** modes, with the existing gold/amber primary accent

### Non-Goals
- ❌ No new screens, no new features, no new controllers
- ❌ No database or logic changes
- ❌ No changing fonts to new external packages (use system/Flutter defaults only)
- ❌ No restructuring widgets for state management
- ❌ No responsive breakpoint changes
- ❌ No changing existing icon libraries

---

## Constraints / Dependencies / Assumptions / Open Questions

### Constraints
- Must use existing `ThemeProvider` (ChangeNotifier) in `lib/providers/theme_provider.dart` as the single source of truth
- Existing code uses `theme.glassDecoration`, `theme.glassInputDecoration`, `theme.glassBackground`, `theme.glassListDecoration` everywhere — preserve these methods (upgrade their internals, do NOT rename)
- Existing buttons, colors, highlight behavior (gold/amber `0xFF8B6914 / 0xFFB8860B`) must stay
- Light mode AND Dark mode must both look equally polished

### Dependencies
- Only packages already in `pubspec.yaml` allowed — no new packages

### Assumptions
- User wants a "modern SaaS / admin dashboard / POS" feel: soft drop shadows, 16px radius cards, subtle accent gradients, elevated containers, strong text contrast
- User prefers consistent use of their existing gold/amber branding (already used in dashboard highlights)
- Home screen stat cards are particularly important — they should look like premium KPI tiles
- Deal tiles and product tiles in POS should have polish that matches existing "Product Card" preference per memory (gradients, shadows, custom cards priority)

### Open Questions (resolution: proceed with conservative, industry-standard defaults)
- Q: Should buttons become fully gradient-filled or keep flat with elevation? → A: Keep `highlight` solid primary color for buttons + add soft elevation/shadow. Add gradient variants for primary CTA wrappers only (stat cards, deal cards).

---

## Requirements (Functional + Non-Functional)

### FR1 — Theme System Upgrade (theme_provider.dart)
Upgrade existing decoration helpers, new elevation/shadow/scaling getters:
- Larger border radius tokens: `radiusList=12`, `radiusCard=16`, `radiusInput=12`, `radiusGlass=16` (keep names same, values change)
- Typography tokens preserve names but strengthen headline/font weights definitions
- New methods added:
  - `cardShadow` → 2–3 layered `BoxShadow` (soft drop shadow) depending on dark/light
  - `elevatedCardDecoration` → surface color + border radius 16 + shadow + 1px subtle border (used by all cards, tiles, panels)
  - `statCardDecoration(List<Color> gradientColors?)` → gradient-filled stat card for Home KPIs
  - `primaryButtonStyle` (getter → `ButtonStyle`)
  - Upgrade existing `glassDecoration` → now uses elevated shape + soft shadows instead of flat borders
  - Upgrade `glassListDecoration` → softer tile look
  - Upgrade `glassInputDecoration` → elevated focused state, thicker highlight border (2px), slightly larger input padding
  - Upgrade `glassBackground` → true subtle gradient background for screens
  - New helper: `badgeDecoration(Color color)` for status badges

### FR2 — Login Screen (login_screen.dart)
- Wrap everything in branded gradient Scaffold background (theme-aware: light gradient for light mode, deep gradient for dark)
- Center login card inside a max-width constrained elevated card with rounded 24 radius + shadow
- Inputs/buttons inherit from upgraded theme decorations; add "remember me" row polish
- Quick-login account cards (saved profiles) now use elevated card tiles with hover/tap scale animation
- Keep all existing functionality and fields

### FR3 — Home / Dashboard Screen (home_screen.dart)
- Stat cards (Products, Customers, Sales, Deals) converted to premium gradient-filled tiles using new `statCardDecoration` helper; icon in small elevated circle container; value bold and large; label small/caption; subtle arrow icon
- Module/feature access cards (Customers, POS, Products, Deals, Expenses, Reports, etc.) use new elevated card decorations with icon in tinted container + clear labels
- AppBar/header area: properly themed, sync status display with small badge
- Keep existing stat numbers and tap navigation exactly

### FR4 — POS Screen (pos_screen.dart + pos/ widgets)
- Top bar (search, customer, back, menu) — buttons use consistent elevated chip/button style with shadows
- Category selector chips upgrade: selected chip = gradient fill + shadow + bold label; unselected = elevated outlined
- Product Tile (`pos_product_tile.dart`) and Deal Tile (`pos_product_grid.dart`) upgrade: use new elevated card; image area with subtle tint; name/price section polished; add tap feedback (splash with highlight overlay)
- Cart section (`pos_cart_section.dart`) and cart item tiles: elevated tile, quantity badge style, remove/plus buttons use consistent style
- All POS spacing and radii tuned for the new professional look

### FR5 — Forms (Add Product, Add Supplier, etc.)
- Focus on `add_product_screen.dart` as the representative form
- Sectional "grouped card" approach: each logical group (Basic Info, Pricing, Stock, Tax/Discount) wrapped in a new elevated card with section header
- Inputs use upgraded `glassInputDecoration` with 2px focused border
- Save/Cancel action buttons: prominent elevated CTA style

### FR6 — List Screens (Product List, Customer List, Sales History, Units, etc.)
- Focus on `product_list_screen.dart` as representative
- List tiles use `glassListDecoration` with elevated style
- Search bar is a properly elevated pill-shaped input with icon + hint
- Empty state gets improved illustration (icon in tinted card)
- AppBar uses consistent theming

### NFR1 — Responsive & Density
- Desktop (wide) density: keep it high but not cramped; cards have minimum padding 12, tiles minimum 8 vertical pad
- Mobile (narrow): layout still flows, cards don't exceed width, text ellipsis maintained

### NFR2 — Theme Fidelity (Light + Dark)
- Every new decoration helper returns correct light/dark variant using `_isDark`
- Shadows in dark mode = darker/opaque; shadows in light mode = lighter/softer
- Text contrast preserved at all times: primary text at least 4.5:1 against backgrounds

### NFR3 — Backwards Compatibility
- All existing method signatures in `ThemeProvider` must keep same names + same positional/named parameters. Add new optional parameters only.
- Existing callers (hundreds of uses of `glassDecoration` etc.) work without modification

---

## Acceptance Criteria

### Rule AC1 — ThemeProvider API Backwards Compatible
Every existing public method/getter in ThemeProvider retains its call signature: `glassDecoration`, `glassListDecoration`, `glassInputDecoration`, `glassBackground`, `glassCircleDecoration`, `whiteAlpha`, `bgGradient`, `highlight`, `card`, `surface`, `background`, `textPrimary`, `textSecondary`, `toggleActiveColor`, `switchActiveColor`, `businessColors`, `radius*` constants, `isWideScreen`.

Evidence: Search project for `theme.` / `ThemeProvider.` calls — none should show analyzer/IDE errors after changes.

### Rule AC2 — Login Screen Uses Gradient Background + Elevated Card
Login page scaffold background uses gradient; form sits inside constrained elevated card with shadow; no visual overflow.

### Rule AC3 — Home Dashboard Stat Cards Have Gradient + Shadow
Each stat card (Products/Customers/Sales/Deals) shows:
- Per-card colored gradient (e.g., blue-indigo for products, green-emerald for sales, amber-orange for customers, purple for deals — using existing gradient presets in theme)
- Icon in small container with secondary tint
- Large bold numeric value
- Descriptive caption
- Layered drop shadow visible (NOT flat)
- Click navigation still works

### Rule AC4 — POS Product/Deal Tiles Use Elevated Card + Corner Radius ≥ 16 + Shadows
Both `_buildDealTile` (pos_product_grid.dart) and `POSProductTile` (pos_product_tile.dart) render:
- corner radius ≥ 16
- elevation / boxShadow layered effects
- proper tap InkWell splash within rounded clip
- NO RenderFlex overflow in 3/4/6 columns (as reported in prior overflow bug)

### Rule AC5 — Add Product Form Inputs Render With 2px Focused Highlight Border
Open Add Product; focus Name field → focused border uses highlight color with 2.0px stroke; unfocused has 1.0px divider.

### Rule AC6 — Light + Dark Work Equally
Toggle theme; Login/Home/POS screens look polished in both; no illegible white-on-white or black-on-black.

### Rule AC7 — No Behavior Changes
Existing flow: login → dashboard → POS / add product → save → list: works exactly as before. No tap handlers changed. No data entry logic changed.

### Rubric AC8 — Overall Professional Aesthetic Quality (0-5)
Evaluative dimension: Does the final app look like a premium commercial SaaS/POS tool?
- 1: Looks basic/barely better than default Material
- 3: Solid, clean, modern but generic
- 5: Distinctive premium feel with layered depth, cohesive gradients, strong visual hierarchy, consistent polish, "ready to ship to paying clients" look

**Pass threshold: ≥ 4**

Evidence sources: Visual inspection of Login, Home, POS, Add Product, Product list screens after implementation.

### Rubric AC9 — Cohesion / Consistency (0-5)
Evaluative: Are the same radii, shadow weights, text styles used everywhere?
- 1: Inconsistent (some cards 8px, some 20px; some with shadows, some not)
- 3: Mostly consistent, few stray styles
- 5: 100% consistent visual language — radius, shadow, text scale, border, button look match across all screens

**Pass threshold: ≥ 4**
